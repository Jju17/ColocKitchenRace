import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import Stripe from "stripe";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const auth = admin.auth();

// Region configuration for Europe (Belgium)
const REGION = "europe-west1";

// Stripe lazy initialization (secret key from Firebase Functions Secrets)
// Set with: firebase functions:secrets:set STRIPE_SECRET_KEY
// Initialized lazily to avoid errors during deployment analysis
// when the secret is not yet available.
let _stripe: Stripe | null = null;
function getStripe(): Stripe {
  if (!_stripe) {
    const key = process.env.STRIPE_SECRET_KEY;
    if (!key) {
      throw new HttpsError("internal", "Stripe secret key is not configured");
    }
    _stripe = new Stripe(key, { apiVersion: "2025-02-24.acacia" });
  }
  return _stripe;
}

// ============================================
// Types
// ============================================

interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface SendToCohouseRequest {
  cohouseId: string;
  notification: NotificationPayload;
}

interface SendToEditionRequest {
  editionId: string;
  notification: NotificationPayload;
}

interface SendToAllRequest {
  notification: NotificationPayload;
}

// ============================================
// Helper Functions
// ============================================

/**
 * Get FCM tokens for users by their IDs
 */
async function getFCMTokensForUsers(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];

  const tokens: string[] = [];

  // Firestore 'in' query supports max 30 items, so we batch
  const batches = [];
  for (let i = 0; i < userIds.length; i += 30) {
    batches.push(userIds.slice(i, i + 30));
  }

  for (const batch of batches) {
    const snapshot = await db
      .collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", batch)
      .get();

    snapshot.docs.forEach((doc) => {
      const fcmToken = doc.data().fcmToken;
      if (fcmToken) {
        tokens.push(fcmToken);
      }
    });
  }

  return tokens;
}

/**
 * Send notifications to multiple tokens
 * Handles token batching (FCM limit: 500 per request)
 */
async function sendToTokens(
  tokens: string[],
  notification: NotificationPayload
): Promise<{ success: number; failure: number }> {
  if (tokens.length === 0) {
    return { success: 0, failure: 0 };
  }

  let success = 0;
  let failure = 0;

  // FCM supports max 500 tokens per multicast
  const batches = [];
  for (let i = 0; i < tokens.length; i += 500) {
    batches.push(tokens.slice(i, i + 500));
  }

  for (const batch of batches) {
    const message: admin.messaging.MulticastMessage = {
      tokens: batch,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data,
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    success += response.successCount;
    failure += response.failureCount;

    // Clean up invalid tokens
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error?.code === "messaging/invalid-registration-token") {
        // Could delete invalid token from Firestore here
        console.log(`Invalid token: ${batch[idx]}`);
      }
    });
  }

  return { success, failure };
}

// ============================================
// Notification History
// ============================================

interface NotificationHistoryEntry {
  target: "all" | "cohouse" | "edition";
  targetId?: string;
  title: string;
  body: string;
  sent: number;
  failed: number;
  message?: string;
  sentBy: string;
  sentAt: FirebaseFirestore.FieldValue;
}

/**
 * Save a notification to the history collection for audit/tracking
 */
async function saveNotificationHistory(entry: NotificationHistoryEntry): Promise<void> {
  try {
    await db.collection("notificationHistory").add(entry);
  } catch (error) {
    // Don't fail the notification if history save fails
    console.error("Failed to save notification history:", error);
  }
}

// ============================================
// Cloud Functions
// ============================================

/**
 * Send notification to all members of a cohouse
 *
 * Usage from admin app or Firebase console:
 * sendNotificationToCohouse({ cohouseId: "xxx", notification: { title: "...", body: "..." } })
 */
export const sendNotificationToCohouse = onCall<SendToCohouseRequest>(
  { region: REGION },
  async (request) => {
    // Verify caller is authenticated (optional: add admin check)
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { cohouseId, notification } = request.data;

    if (!cohouseId || !notification?.title || !notification?.body) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      // Get cohouse users
      const cohouseUsersSnapshot = await db
        .collection("cohouses")
        .doc(cohouseId)
        .collection("users")
        .get();

      // Extract user IDs (users who have linked their account)
      const userIds = cohouseUsersSnapshot.docs
        .map((doc) => doc.data().userId)
        .filter((id): id is string => !!id);

      // Get FCM tokens
      const tokens = await getFCMTokensForUsers(userIds);

      // Send notifications
      const result = await sendToTokens(tokens, notification);

      console.log(`Sent to cohouse ${cohouseId}: ${result.success} success, ${result.failure} failure (${userIds.length} users, ${tokens.length} tokens)`);

      const noUsers = cohouseUsersSnapshot.empty;
      const noTokens = tokens.length === 0;
      const message = noUsers
        ? "No users found in this cohouse"
        : noTokens
          ? `${userIds.length} user(s) found but none have push notifications enabled`
          : result.failure > 0
            ? `${result.failure} delivery failure(s) out of ${tokens.length} token(s)`
            : undefined;

      await saveNotificationHistory({
        target: "cohouse",
        targetId: cohouseId,
        title: notification.title,
        body: notification.body,
        sent: result.success,
        failed: result.failure,
        ...(message && { message }),
        sentBy: request.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: !noUsers && !noTokens && result.failure === 0,
        sent: result.success,
        failed: result.failure,
        totalUsers: userIds.length,
        message: message ?? null,
      };
    } catch (error) {
      console.error("Error sending to cohouse:", error);
      throw new HttpsError("internal", `Failed to send notifications: ${error}`);
    }
  }
);

/**
 * Send notification to all participants of a CKR edition
 *
 * Usage:
 * sendNotificationToEdition({ editionId: "xxx", notification: { title: "...", body: "..." } })
 */
export const sendNotificationToEdition = onCall<SendToEditionRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { editionId, notification } = request.data;

    if (!editionId || !notification?.title || !notification?.body) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      // Get edition to find participating cohouses
      const editionDoc = await db.collection("ckrGames").doc(editionId).get();

      if (!editionDoc.exists) {
        throw new HttpsError("not-found", "Edition not found");
      }

      const cohouseIDs: string[] = editionDoc.data()?.cohouseIDs || [];

      if (cohouseIDs.length === 0) {
        const message = "No participants in this edition";
        await saveNotificationHistory({
          target: "edition",
          targetId: editionId,
          title: notification.title,
          body: notification.body,
          sent: 0,
          failed: 0,
          message,
          sentBy: request.auth.uid,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: false, sent: 0, failed: 0, message };
      }

      // Collect all user IDs from all participating cohouses
      const allUserIds: string[] = [];

      for (const cohouseId of cohouseIDs) {
        const cohouseUsersSnapshot = await db
          .collection("cohouses")
          .doc(cohouseId)
          .collection("users")
          .get();

        cohouseUsersSnapshot.docs.forEach((doc) => {
          const userId = doc.data().userId;
          if (userId && !allUserIds.includes(userId)) {
            allUserIds.push(userId);
          }
        });
      }

      // Get FCM tokens
      const tokens = await getFCMTokensForUsers(allUserIds);

      // Send notifications
      const result = await sendToTokens(tokens, notification);

      console.log(`Sent to edition ${editionId}: ${result.success} success, ${result.failure} failure`);

      const noTokens = tokens.length === 0;
      const message = noTokens
        ? `${allUserIds.length} user(s) found but none have push notifications enabled`
        : result.failure > 0
          ? `${result.failure} delivery failure(s) out of ${tokens.length} token(s)`
          : undefined;

      await saveNotificationHistory({
        target: "edition",
        targetId: editionId,
        title: notification.title,
        body: notification.body,
        sent: result.success,
        failed: result.failure,
        ...(message && { message }),
        sentBy: request.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: !noTokens && result.failure === 0,
        sent: result.success,
        failed: result.failure,
        totalCohouses: cohouseIDs.length,
        totalUsers: allUserIds.length,
        message: message ?? null,
      };
    } catch (error) {
      console.error("Error sending to edition:", error);
      throw new HttpsError("internal", "Failed to send notifications");
    }
  }
);

/**
 * Send notification to ALL users via topic
 *
 * This uses FCM topics - all users are automatically subscribed to "all_users" topic
 *
 * Usage:
 * sendNotificationToAll({ notification: { title: "...", body: "..." } })
 */
export const sendNotificationToAll = onCall<SendToAllRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { notification } = request.data;

    if (!notification?.title || !notification?.body) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      const message: admin.messaging.Message = {
        topic: "all_users",
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data,
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const messageId = await messaging.send(message);

      console.log(`Sent to all users via topic, messageId: ${messageId}`);

      await saveNotificationHistory({
        target: "all",
        title: notification.title,
        body: notification.body,
        sent: 0,  // Topic-based, exact count unknown
        failed: 0,
        sentBy: request.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        messageId,
      };
    } catch (error) {
      console.error("Error sending to all:", error);
      throw new HttpsError("internal", "Failed to send notification");
    }
  }
);

// ============================================
// Cohouse Validation Functions
// ============================================

interface CheckDuplicateRequest {
  name: string;
  street: string;
  city: string;
}

/**
 * Check if a cohouse with the same name or address already exists
 */
export const checkDuplicateCohouse = onCall<CheckDuplicateRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { name, street, city } = request.data;

    if (!name || !street || !city) {
      throw new HttpsError("invalid-argument", "Missing required fields: name, street, city");
    }

    try {
      const nameLower = name.trim().toLowerCase();
      const streetLower = street.trim().toLowerCase();
      const cityLower = city.trim().toLowerCase();

      // Check by name
      const nameSnapshot = await db
        .collection("cohouses")
        .where("nameLower", "==", nameLower)
        .limit(1)
        .get();

      if (!nameSnapshot.empty) {
        return { isDuplicate: true, reason: "name" };
      }

      // Check by address (street + city)
      // Uses the lowercased PostalAddress stored as addressLower
      const addressSnapshot = await db
        .collection("cohouses")
        .where("addressLower.street", "==", streetLower)
        .where("addressLower.city", "==", cityLower)
        .limit(1)
        .get();

      if (!addressSnapshot.empty) {
        return { isDuplicate: true, reason: "address" };
      }

      return { isDuplicate: false };
    } catch (error) {
      console.error("Error checking duplicate cohouse:", error);
      throw new HttpsError("internal", "Failed to check for duplicates");
    }
  }
);

interface ValidateAddressRequest {
  street: string;
  city: string;
  postalCode: string;
  country: string;
}

/**
 * Validate an address using Nominatim (OpenStreetMap) geocoding API
 */
export const validateAddress = onCall<ValidateAddressRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { street, city, postalCode, country } = request.data;

    if (!street || !city) {
      throw new HttpsError("invalid-argument", "Missing required fields: street, city");
    }

    try {
      const params = new URLSearchParams({
        format: "json",
        street: street,
        city: city,
        postalcode: postalCode || "",
        country: country || "",
        limit: "1",
        addressdetails: "1",
      });

      const url = `https://nominatim.openstreetmap.org/search?${params.toString()}`;

      const response = await fetch(url, {
        headers: {
          "User-Agent": "ColocKitchenRace/1.0",
          "Accept": "application/json",
        },
      });

      if (!response.ok) {
        throw new Error(`Nominatim returned status ${response.status}`);
      }

      const results = await response.json() as Array<{
        display_name?: string;
        lat?: string;
        lon?: string;
        address?: {
          road?: string;
          house_number?: string;
          city?: string;
          town?: string;
          village?: string;
          postcode?: string;
          country?: string;
        };
      }>;

      if (!results || results.length === 0) {
        return { isValid: false };
      }

      const result = results[0];
      const addr = result.address || {};

      const normalizedCity = addr.city || addr.town || addr.village || null;
      const normalizedStreet = addr.road
        ? (addr.house_number ? `${addr.road} ${addr.house_number}` : addr.road)
        : null;

      return {
        isValid: true,
        normalizedStreet: normalizedStreet,
        normalizedCity: normalizedCity,
        normalizedPostalCode: addr.postcode || null,
        normalizedCountry: addr.country || null,
        latitude: result.lat ? parseFloat(result.lat) : null,
        longitude: result.lon ? parseFloat(result.lon) : null,
      };
    } catch (error) {
      console.error("Error validating address:", error);
      throw new HttpsError("internal", "Failed to validate address");
    }
  }
);

// ============================================
// Payment
// ============================================

interface CreatePaymentIntentRequest {
  gameId: string;
  cohouseId: string;
  amountCents: number;
  participantCount: number;
}

/**
 * Create a Stripe PaymentIntent for CKR registration.
 *
 * Server-side price validation ensures the client can't tamper with the amount.
 * Creates/retrieves a Stripe Customer per cohouse for tracking.
 */
export const createPaymentIntent = onCall<CreatePaymentIntentRequest>(
  {
    region: REGION,
    secrets: ["STRIPE_SECRET_KEY"],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId, cohouseId, amountCents, participantCount } = request.data;

    if (!gameId || !cohouseId || !amountCents || !participantCount) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: gameId, cohouseId, amountCents, participantCount"
      );
    }

    try {
      // 1. Fetch the game and validate price server-side
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data()!;
      const pricePerPersonCents: number = gameData.pricePerPersonCents || 500;
      const expectedAmount = pricePerPersonCents * participantCount;

      if (amountCents !== expectedAmount) {
        throw new HttpsError(
          "invalid-argument",
          `Amount mismatch: expected ${expectedAmount} cents, got ${amountCents}`
        );
      }

      // 2. Check registration prerequisites
      const registrationDeadline = (
        gameData.registrationDeadline as admin.firestore.Timestamp
      ).toDate();

      if (new Date() >= registrationDeadline) {
        throw new HttpsError(
          "failed-precondition",
          "Registration deadline has passed"
        );
      }

      const cohouseIDs: string[] = gameData.cohouseIDs || [];
      if (cohouseIDs.includes(cohouseId)) {
        throw new HttpsError("already-exists", "Already registered for this game");
      }

      const maxParticipants: number = gameData.maxParticipants || 100;
      const totalRegisteredParticipants: number = gameData.totalRegisteredParticipants || 0;
      if (totalRegisteredParticipants + participantCount > maxParticipants) {
        throw new HttpsError(
          "failed-precondition",
          "Maximum number of participants reached"
        );
      }

      // 3. Get or create Stripe Customer for this cohouse
      const cohouseSnapshot = await db
        .collection("cohouses")
        .where("id", "==", cohouseId)
        .limit(1)
        .get();

      if (cohouseSnapshot.empty) {
        throw new HttpsError("not-found", "Cohouse not found");
      }

      const cohouseDoc = cohouseSnapshot.docs[0];
      const cohouseData = cohouseDoc.data();
      let stripeCustomerId = cohouseData.stripeCustomerId as string | undefined;

      if (!stripeCustomerId) {
        const customer = await getStripe().customers.create({
          name: cohouseData.name || "Unknown Cohouse",
          metadata: { cohouseId, firebaseUid: request.auth.uid },
        });
        stripeCustomerId = customer.id;

        // Save Stripe customer ID back to Firestore
        await cohouseDoc.ref.update({ stripeCustomerId });
      }

      // 4. Create Ephemeral Key for the customer
      const ephemeralKey = await getStripe().ephemeralKeys.create(
        { customer: stripeCustomerId },
        { apiVersion: "2025-02-24.acacia" }
      );

      // 5. Create PaymentIntent
      // Explicit payment methods: card + Bancontact (Belgium).
      // Link is excluded on purpose (not used in Belgium).
      const paymentIntent = await getStripe().paymentIntents.create({
        amount: expectedAmount,
        currency: "eur",
        customer: stripeCustomerId,
        payment_method_types: ["card", "bancontact"],
        metadata: {
          gameId,
          cohouseId,
          participantCount: participantCount.toString(),
          firebaseUid: request.auth.uid,
        },
      });

      console.log(
        `Payment intent ${paymentIntent.id} created for cohouse ${cohouseId}, game ${gameId}, amount ${expectedAmount} cents`
      );

      return {
        clientSecret: paymentIntent.client_secret,
        customerId: stripeCustomerId,
        ephemeralKeySecret: ephemeralKey.secret,
        paymentIntentId: paymentIntent.id,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error creating payment intent:", error);
      throw new HttpsError("internal", "Failed to create payment intent");
    }
  }
);

// ============================================
// Cohouse Matching
// ============================================

interface RegisterForGameRequest {
  gameId: string;
  cohouseId: string;
  attendingUserIds: string[];
  averageAge: number;
  cohouseType: string;
  paymentIntentId?: string;
}

/**
 * Register a cohouse for a CKR Game edition.
 *
 * Server-side validations:
 * - Registration deadline not passed
 * - Capacity not reached
 * - Cohouse not already registered
 * - Cohouse exists
 *
 * Stores registration metadata in ckrGames/{gameId}/registrations/{cohouseId}
 * and adds the cohouseId to the game's cohouseIDs array.
 * Also increments totalRegisteredParticipants by the number of attending persons.
 */
export const registerForGame = onCall<RegisterForGameRequest>(
  { region: REGION, secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId, cohouseId, attendingUserIds, averageAge, cohouseType, paymentIntentId } =
      request.data;

    if (!gameId || !cohouseId || !attendingUserIds || !averageAge || !cohouseType) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: gameId, cohouseId, attendingUserIds, averageAge, cohouseType"
      );
    }

    if (!Array.isArray(attendingUserIds) || attendingUserIds.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "attendingUserIds must be a non-empty array"
      );
    }

    try {
      // 1. Fetch the CKR game
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();

      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data()!;
      const cohouseIDs: string[] = gameData.cohouseIDs || [];
      const maxParticipants: number = gameData.maxParticipants || 100;
      const totalRegisteredParticipants: number = gameData.totalRegisteredParticipants || 0;

      // 2. Check registration deadline
      const registrationDeadline = (
        gameData.registrationDeadline as admin.firestore.Timestamp
      ).toDate();

      if (new Date() >= registrationDeadline) {
        throw new HttpsError(
          "failed-precondition",
          "Registration deadline has passed"
        );
      }

      // 3. Check capacity (based on total persons, not cohouses)
      if (totalRegisteredParticipants + attendingUserIds.length > maxParticipants) {
        throw new HttpsError(
          "failed-precondition",
          "Maximum number of participants reached"
        );
      }

      // 4. Check duplicate
      if (cohouseIDs.includes(cohouseId)) {
        throw new HttpsError(
          "already-exists",
          "This cohouse is already registered for this game"
        );
      }

      // 5. Verify cohouse exists
      const cohouseSnapshot = await db
        .collection("cohouses")
        .where("id", "==", cohouseId)
        .limit(1)
        .get();

      if (cohouseSnapshot.empty) {
        throw new HttpsError("not-found", "Cohouse not found");
      }

      const cohouseDocRef = cohouseSnapshot.docs[0].ref;

      // 6. Verify payment if required
      const pricePerPersonCents: number = gameData.pricePerPersonCents || 500;
      if (pricePerPersonCents > 0) {
        if (!paymentIntentId) {
          throw new HttpsError("failed-precondition", "Payment is required");
        }

        const paymentIntentObj = await getStripe().paymentIntents.retrieve(paymentIntentId);

        if (paymentIntentObj.status !== "succeeded") {
          throw new HttpsError(
            "failed-precondition",
            `Payment not completed (status: ${paymentIntentObj.status})`
          );
        }

        // Verify payment metadata matches this registration
        if (
          paymentIntentObj.metadata.gameId !== gameId ||
          paymentIntentObj.metadata.cohouseId !== cohouseId
        ) {
          throw new HttpsError(
            "invalid-argument",
            "Payment does not match this registration"
          );
        }

        const expectedAmount = pricePerPersonCents * attendingUserIds.length;
        if (paymentIntentObj.amount !== expectedAmount) {
          throw new HttpsError(
            "invalid-argument",
            `Payment amount mismatch: expected ${expectedAmount}, got ${paymentIntentObj.amount}`
          );
        }
      }

      // 7. Add cohouseId to game's cohouseIDs and increment participant count
      await db.collection("ckrGames").doc(gameId).update({
        cohouseIDs: admin.firestore.FieldValue.arrayUnion(cohouseId),
        totalRegisteredParticipants: admin.firestore.FieldValue.increment(attendingUserIds.length),
      });

      // 8. Store registration metadata
      const registrationData: Record<string, unknown> = {
        cohouseId,
        attendingUserIds,
        averageAge,
        cohouseType,
        registeredAt: admin.firestore.FieldValue.serverTimestamp(),
        registeredBy: request.auth.uid,
      };

      if (paymentIntentId) {
        registrationData.paymentIntentId = paymentIntentId;
      }

      await db
        .collection("ckrGames")
        .doc(gameId)
        .collection("registrations")
        .doc(cohouseId)
        .set(registrationData);

      // 9. Update cohouse with cohouseType
      await cohouseDocRef.update({ cohouseType });

      const remainingSpots = maxParticipants - (totalRegisteredParticipants + attendingUserIds.length);

      console.log(
        `Cohouse ${cohouseId} registered for game ${gameId} with ${attendingUserIds.length} persons. Remaining spots: ${remainingSpots}`
      );

      return { success: true, remainingSpots };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error registering for game:", error);
      throw new HttpsError("internal", "Failed to register for game");
    }
  }
);

// ============================================
// Cohouse Matching
// ============================================

import {
  CohousePoint,
  computeCubicDistances,
  doubleMatchingHeuristic,
} from "./matching";

interface MatchCohousesRequest {
  gameId: string;
}

/**
 * Match cohouses into groups of 4 based on GPS proximity.
 *
 * Uses the Double Perfect Matching Heuristic:
 * 1. Reads the CKR game to get participating cohouse IDs
 * 2. Fetches GPS coordinates for each cohouse
 * 3. Runs a two-phase matching algorithm (cubic distance metric)
 * 4. Stores the resulting groups back in Firestore
 *
 * Requires: N must be a multiple of 4, all cohouses must have GPS coordinates.
 */
export const matchCohouses = onCall<MatchCohousesRequest>(
  { region: REGION, timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId } = request.data;

    if (!gameId) {
      throw new HttpsError("invalid-argument", "Missing required field: gameId");
    }

    try {
      // 1. Fetch the CKR game
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();

      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data();
      const cohouseIDs: string[] = gameData?.cohouseIDs || [];

      if (cohouseIDs.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "No cohouses registered for this game"
        );
      }

      // 2. Fetch GPS coordinates for all participating cohouses
      const points: CohousePoint[] = [];
      const missingCoords: string[] = [];
      const foundIds: string[] = [];

      // Batch Firestore reads (max 30 per 'in' query)
      const batches = [];
      for (let i = 0; i < cohouseIDs.length; i += 30) {
        batches.push(cohouseIDs.slice(i, i + 30));
      }

      for (const batch of batches) {
        const snapshot = await db
          .collection("cohouses")
          .where("id", "in", batch)
          .get();

        snapshot.docs.forEach((doc) => {
          const data = doc.data();
          const id = data.id as string;
          foundIds.push(id);
          const lat = data.latitude as number | undefined;
          const lon = data.longitude as number | undefined;

          if (lat != null && lon != null) {
            points.push({ id, latitude: lat, longitude: lon });
          } else {
            missingCoords.push(data.name || id);
          }
        });
      }

      // 3. Clean up orphaned IDs (cohouses deleted from Firestore)
      const orphanedIds = cohouseIDs.filter((id) => !foundIds.includes(id));
      let removedCount = 0;

      if (orphanedIds.length > 0) {
        console.log(
          `Cleaning up ${orphanedIds.length} orphaned cohouse IDs from cohouseIDs: ${orphanedIds.join(", ")}`
        );

        const cleanedCohouseIDs = cohouseIDs.filter(
          (id) => !orphanedIds.includes(id)
        );

        // Also clear previous matchedGroups since they reference deleted cohouses
        await db.collection("ckrGames").doc(gameId).update({
          cohouseIDs: cleanedCohouseIDs,
          matchedGroups: admin.firestore.FieldValue.delete(),
          matchedAt: admin.firestore.FieldValue.delete(),
        });

        removedCount = orphanedIds.length;
      }

      if (missingCoords.length > 0) {
        throw new HttpsError(
          "failed-precondition",
          `The following cohouses are missing GPS coordinates: ${missingCoords.join(", ")}. ` +
          "All cohouses must have valid coordinates for matching."
        );
      }

      // 4. Validate remaining count after cleanup
      if (points.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "No cohouses remaining after cleanup" +
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from cohouseIDs)` : "")
        );
      }

      if (points.length < 4) {
        throw new HttpsError(
          "failed-precondition",
          `Need at least 4 cohouses to perform matching, but only ${points.length} remaining` +
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from cohouseIDs)` : "")
        );
      }

      if (points.length % 4 !== 0) {
        throw new HttpsError(
          "failed-precondition",
          `Number of participants (${points.length}) must be a multiple of 4. ` +
          `Current count leaves ${points.length % 4} cohouse(s) unmatched.` +
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from cohouseIDs)` : "")
        );
      }

      console.log(`Starting matching for ${points.length} cohouses...`);

      // 5. Compute cubic distance matrix
      const dCubic = computeCubicDistances(points);

      // 6. Run double matching heuristic
      const groups = doubleMatchingHeuristic(points, dCubic);

      console.log(`Matching complete: ${groups.length} groups of 4 created.`);

      // 7. Store results back in Firestore on the game document
      // Firestore does not support nested arrays, so we wrap each group
      // in an object: [["a","b","c","d"]] → [{ cohouseIds: ["a","b","c","d"] }]
      const matchedGroupsForFirestore = groups.map((g) => ({ cohouseIds: g }));

      await db.collection("ckrGames").doc(gameId).update({
        matchedGroups: matchedGroupsForFirestore,
        matchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        groupCount: groups.length,
        groups: groups,
        removedOrphanedIds: orphanedIds,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error matching cohouses:", error);
      throw new HttpsError("internal", "Failed to match cohouses");
    }
  }
);

// ============================================
// Cohouse Data for Map
// ============================================

interface GetCohousesForMapRequest {
  cohouseIds: string[];
}

interface CohouseMapData {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  userNames: string[];
}

/**
 * Batch-fetch lightweight cohouse data for map display.
 *
 * Returns name, GPS coordinates, and member names for each cohouse ID.
 * This avoids N individual Firestore calls from the client.
 */
export const getCohousesForMap = onCall<GetCohousesForMapRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { cohouseIds } = request.data;

    if (!cohouseIds || !Array.isArray(cohouseIds) || cohouseIds.length === 0) {
      throw new HttpsError("invalid-argument", "Missing required field: cohouseIds (non-empty array)");
    }

    try {
      const results: CohouseMapData[] = [];

      // Fetch cohouse docs in batches of 30 (Firestore 'in' limit)
      const batches = [];
      for (let i = 0; i < cohouseIds.length; i += 30) {
        batches.push(cohouseIds.slice(i, i + 30));
      }

      for (const batch of batches) {
        const snapshot = await db
          .collection("cohouses")
          .where("id", "in", batch)
          .get();

        // For each cohouse doc, also fetch its users subcollection
        for (const doc of snapshot.docs) {
          const data = doc.data();
          const id = data.id as string;
          const name = (data.name as string) || "Unknown";
          const latitude = data.latitude as number | undefined;
          const longitude = data.longitude as number | undefined;

          if (latitude == null || longitude == null) continue;

          // Fetch users subcollection
          const usersSnapshot = await db
            .collection("cohouses")
            .doc(doc.id)
            .collection("users")
            .get();

          const userNames = usersSnapshot.docs
            .map((userDoc) => {
              const userData = userDoc.data();
              const first = (userData.firstName as string) || "";
              const last = (userData.lastName as string) || "";
              return `${first} ${last}`.trim();
            })
            .filter((name) => name.length > 0);

          results.push({ id, name, latitude, longitude, userNames });
        }
      }

      return { success: true, cohouses: results };
    } catch (error) {
      console.error("Error fetching cohouses for map:", error);
      throw new HttpsError("internal", "Failed to fetch cohouse data");
    }
  }
);

// ============================================
// Admin Management
// ============================================

interface SetAdminClaimRequest {
  targetAuthUid: string;
  isAdmin: boolean;
}

/**
 * Set or remove the "admin" custom claim on a Firebase Auth user.
 *
 * This is required for Firestore security rules to check admin status
 * via `request.auth.token.admin == true`.
 *
 * Can only be called by an existing admin. To bootstrap the very first admin,
 * use the Firebase CLI:
 *   firebase functions:shell
 *   > setAdminClaim({ data: { targetAuthUid: "YOUR_AUTH_UID", isAdmin: true }, auth: { uid: "YOUR_AUTH_UID" } })
 *
 * Or set custom claims directly:
 *   admin.auth().setCustomUserClaims("YOUR_AUTH_UID", { admin: true })
 */
export const setAdminClaim = onCall<SetAdminClaimRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const callerUid = request.auth.uid;
    const { targetAuthUid, isAdmin } = request.data;

    if (!targetAuthUid || typeof isAdmin !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: targetAuthUid (string), isAdmin (boolean)"
      );
    }

    // Verify the caller is already an admin (or is the target — for bootstrap)
    const callerToken = request.auth.token;
    const callerIsAdmin = callerToken.admin === true;

    if (!callerIsAdmin) {
      // Allow self-bootstrap only if the user's Firestore doc has isAdmin == true
      // This enables the first admin to set their own custom claim
      const userSnapshot = await db
        .collection("users")
        .where("authId", "==", callerUid)
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        throw new HttpsError("permission-denied", "User not found");
      }

      const userData = userSnapshot.docs[0].data();
      if (userData.isAdmin !== true) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can set admin claims"
        );
      }

      // First-time bootstrap: caller has isAdmin in Firestore but not yet in Auth token
      // Only allow them to set their own claim
      if (targetAuthUid !== callerUid) {
        throw new HttpsError(
          "permission-denied",
          "During bootstrap, you can only set your own admin claim. " +
          "Call this function with your own Auth UID first, then you can promote others."
        );
      }
    }

    try {
      // Set the custom claim
      await auth.setCustomUserClaims(targetAuthUid, { admin: isAdmin });

      console.log(
        `Admin claim ${isAdmin ? "set" : "removed"} for Auth UID: ${targetAuthUid} (by: ${callerUid})`
      );

      return {
        success: true,
        message: `Admin claim ${isAdmin ? "granted to" : "revoked from"} user ${targetAuthUid}`,
      };
    } catch (error) {
      console.error("Error setting admin claim:", error);
      throw new HttpsError("internal", "Failed to set admin claim");
    }
  }
);

// ============================================
// Firestore Triggers
// ============================================

/**
 * Automatically send a notification to all users when a new news is created
 *
 * Triggered when a new document is added to the "news" collection
 */
export const onNewsCreated = onDocumentCreated(
  { document: "news/{newsId}", region: REGION },
  async (event) => {
    const newsData = event.data?.data();

    if (!newsData) {
      console.log("No news data found");
      return;
    }

    const title = newsData.title as string;
    const body = newsData.body as string;

    if (!title || !body) {
      console.log("News missing title or body");
      return;
    }

    try {
      const message: admin.messaging.Message = {
        topic: "all_users",
        notification: {
          title: `📰 ${title}`,
          body: body.length > 100 ? body.substring(0, 100) + "..." : body,
        },
        data: {
          type: "news",
          newsId: event.params.newsId,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const messageId = await messaging.send(message);
      console.log(`News notification sent, messageId: ${messageId}, newsId: ${event.params.newsId}`);
    } catch (error) {
      console.error("Error sending news notification:", error);
    }
  }
);

/**
 * Automatically send a notification to all users when a new challenge is created
 *
 * Triggered when a new document is added to the "challenges" collection
 */
export const onChallengeCreated = onDocumentCreated(
  { document: "challenges/{challengeId}", region: REGION },
  async (event) => {
    const challengeData = event.data?.data();

    if (!challengeData) {
      console.log("No challenge data found");
      return;
    }

    const title = challengeData.title as string;
    const body = challengeData.body as string;

    if (!title) {
      console.log("Challenge missing title");
      return;
    }

    try {
      const message: admin.messaging.Message = {
        topic: "all_users",
        notification: {
          title: `🏆 New challenge: ${title}`,
          body: body
            ? body.length > 100
              ? body.substring(0, 100) + "..."
              : body
            : "A new challenge is available!",
        },
        data: {
          type: "challenge",
          challengeId: event.params.challengeId,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const messageId = await messaging.send(message);
      console.log(
        `Challenge notification sent, messageId: ${messageId}, challengeId: ${event.params.challengeId}`
      );
    } catch (error) {
      console.error("Error sending challenge notification:", error);
    }
  }
);

/**
 * Scheduled function that checks for challenge start/end events every 5 minutes.
 *
 * Sends notifications when:
 * - A challenge has just started (startDate within the last 5 minutes)
 * - A challenge will end in ~30 minutes (endDate between now+25min and now+30min)
 *
 * Uses marker documents in challenges/{id}/notifications/{type} to prevent duplicates.
 */
export const checkChallengeSchedules = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Europe/Brussels",
    region: REGION,
  },
  async () => {
    const now = new Date();
    const fiveMinAgo = new Date(now.getTime() - 5 * 60 * 1000);
    const twentyFiveMinFromNow = new Date(now.getTime() + 25 * 60 * 1000);
    const thirtyMinFromNow = new Date(now.getTime() + 30 * 60 * 1000);

    try {
      // 1. Check for challenges that just started
      const startedSnapshot = await db
        .collection("challenges")
        .where("startDate", ">=", fiveMinAgo)
        .where("startDate", "<=", now)
        .get();

      for (const doc of startedSnapshot.docs) {
        const challengeId = doc.id;
        const data = doc.data();
        const title = data.title as string;
        const endDate = (data.endDate as admin.firestore.Timestamp).toDate();

        // Check if we already sent this notification
        const markerRef = db
          .collection("challenges")
          .doc(challengeId)
          .collection("notifications")
          .doc("started");

        const marker = await markerRef.get();
        if (marker.exists) continue;

        // Send notification
        const message: admin.messaging.Message = {
          topic: "all_users",
          notification: {
            title: `🟢 ${title} has started!`,
            body: `You have until ${endDate.toLocaleString("fr-BE", {
              day: "numeric",
              month: "short",
              hour: "2-digit",
              minute: "2-digit",
            })} to complete it.`,
          },
          data: {
            type: "challenge_started",
            challengeId: challengeId,
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        await messaging.send(message);
        await markerRef.set({ sentAt: admin.firestore.FieldValue.serverTimestamp() });
        console.log(`Challenge started notification sent for: ${title} (${challengeId})`);
      }

      // 2. Check for challenges ending in ~30 minutes
      const endingSoonSnapshot = await db
        .collection("challenges")
        .where("endDate", ">=", twentyFiveMinFromNow)
        .where("endDate", "<=", thirtyMinFromNow)
        .get();

      for (const doc of endingSoonSnapshot.docs) {
        const challengeId = doc.id;
        const data = doc.data();
        const title = data.title as string;

        // Check if we already sent this notification
        const markerRef = db
          .collection("challenges")
          .doc(challengeId)
          .collection("notifications")
          .doc("ending_soon");

        const marker = await markerRef.get();
        if (marker.exists) continue;

        // Send notification
        const message: admin.messaging.Message = {
          topic: "all_users",
          notification: {
            title: `⏰ ${title} ends in 30 minutes!`,
            body: "Hurry up and submit your response!",
          },
          data: {
            type: "challenge_ending_soon",
            challengeId: challengeId,
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        await messaging.send(message);
        await markerRef.set({ sentAt: admin.firestore.FieldValue.serverTimestamp() });
        console.log(`Challenge ending soon notification sent for: ${title} (${challengeId})`);
      }
    } catch (error) {
      console.error("Error in checkChallengeSchedules:", error);
    }
  }
);

// ============================================
// CKR Planning — Event Settings, Confirm, Reveal
// ============================================

interface UpdateEventSettingsRequest {
  gameId: string;
  aperoStartTime: string;   // ISO 8601
  aperoEndTime: string;
  dinerStartTime: string;
  dinerEndTime: string;
  partyStartTime: string;
  partyEndTime: string;
  partyAddress: string;
  partyName: string;
  partyNote?: string;
}

/**
 * Save event settings (time slots + party info) on a CKR game.
 * Called by the admin before confirming the matching.
 */
export const updateEventSettings = onCall<UpdateEventSettingsRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const {
      gameId,
      aperoStartTime, aperoEndTime,
      dinerStartTime, dinerEndTime,
      partyStartTime, partyEndTime,
      partyAddress, partyName, partyNote,
    } = request.data;

    if (!gameId || !aperoStartTime || !aperoEndTime ||
        !dinerStartTime || !dinerEndTime ||
        !partyStartTime || !partyEndTime ||
        !partyAddress || !partyName) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const eventSettings = {
        aperoStartTime: new Date(aperoStartTime),
        aperoEndTime: new Date(aperoEndTime),
        dinerStartTime: new Date(dinerStartTime),
        dinerEndTime: new Date(dinerEndTime),
        partyStartTime: new Date(partyStartTime),
        partyEndTime: new Date(partyEndTime),
        partyAddress,
        partyName,
        ...(partyNote ? { partyNote } : {}),
      };

      await db.collection("ckrGames").doc(gameId).update({ eventSettings });

      console.log(`Event settings saved for game ${gameId}`);
      return { success: true };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error updating event settings:", error);
      throw new HttpsError("internal", "Failed to update event settings");
    }
  }
);

interface ConfirmMatchingRequest {
  gameId: string;
}

/**
 * Confirm the matching by assigning A/B/C/D roles within each group.
 *
 * For each matched group of 4:
 *   - Shuffles the cohouse IDs randomly
 *   - Assigns them as A, B, C, D
 *
 * Schema:
 *   Apéro: A→B (A cooks at B), C→D (C cooks at D)
 *   Dîner: C→A (C cooks at A), D→B (D cooks at B)
 *
 * Requires: matchedGroups and eventSettings to be set.
 */
export const confirmMatching = onCall<ConfirmMatchingRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId } = request.data;

    if (!gameId) {
      throw new HttpsError("invalid-argument", "Missing required field: gameId");
    }

    try {
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data()!;

      if (!gameData.matchedGroups || gameData.matchedGroups.length === 0) {
        throw new HttpsError("failed-precondition", "No matched groups found. Run matching first.");
      }

      if (!gameData.eventSettings) {
        throw new HttpsError("failed-precondition", "Event settings must be configured before confirming.");
      }

      const matchedGroups = gameData.matchedGroups as Array<{ cohouseIds: string[] }>;

      // Fisher-Yates shuffle
      function shuffle<T>(array: T[]): T[] {
        const arr = [...array];
        for (let i = arr.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [arr[i], arr[j]] = [arr[j], arr[i]];
        }
        return arr;
      }

      const groupPlannings = matchedGroups.map((group, index) => {
        const shuffled = shuffle(group.cohouseIds);
        return {
          id: `group-${index + 1}`,
          groupIndex: index + 1,
          cohouseA: shuffled[0],
          cohouseB: shuffled[1],
          cohouseC: shuffled[2],
          cohouseD: shuffled[3],
        };
      });

      await db.collection("ckrGames").doc(gameId).update({
        groupPlannings,
      });

      console.log(`Confirmed matching for game ${gameId}: ${groupPlannings.length} groups with roles assigned`);

      return {
        success: true,
        groupCount: groupPlannings.length,
        groupPlannings,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error confirming matching:", error);
      throw new HttpsError("internal", "Failed to confirm matching");
    }
  }
);

interface RevealPlanningRequest {
  gameId: string;
}

/**
 * Reveal the planning to all participants.
 * Sets isRevealed=true and sends a push notification.
 */
export const revealPlanning = onCall<RevealPlanningRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId } = request.data;

    if (!gameId) {
      throw new HttpsError("invalid-argument", "Missing required field: gameId");
    }

    try {
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data()!;

      if (!gameData.groupPlannings || gameData.groupPlannings.length === 0) {
        throw new HttpsError("failed-precondition", "Matching must be confirmed before revealing.");
      }

      await db.collection("ckrGames").doc(gameId).update({
        isRevealed: true,
        revealedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Send push notification to all registered cohouses
      const cohouseIDs: string[] = gameData.cohouseIDs || [];
      if (cohouseIDs.length > 0) {
        const allUserIds: string[] = [];

        for (const cohouseId of cohouseIDs) {
          const cohouseSnapshot = await db
            .collection("cohouses")
            .where("id", "==", cohouseId)
            .limit(1)
            .get();

          if (cohouseSnapshot.empty) continue;

          const usersSnapshot = await db
            .collection("cohouses")
            .doc(cohouseSnapshot.docs[0].id)
            .collection("users")
            .get();

          usersSnapshot.docs.forEach((doc) => {
            const userId = doc.data().userId;
            if (userId && !allUserIds.includes(userId)) {
              allUserIds.push(userId);
            }
          });
        }

        const tokens = await getFCMTokensForUsers(allUserIds);
        if (tokens.length > 0) {
          await sendToTokens(tokens, {
            title: "🎉 Votre planning CKR est disponible !",
            body: "Découvrez chez qui vous allez cuisiner ce soir !",
          });
        }
      }

      console.log(`Planning revealed for game ${gameId}`);
      return { success: true };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error revealing planning:", error);
      throw new HttpsError("internal", "Failed to reveal planning");
    }
  }
);

interface GetMyPlanningRequest {
  gameId: string;
  cohouseId: string;
}

/**
 * Get the personalized CKR evening planning for a specific cohouse.
 *
 * Returns apéro, dîner, and party info including:
 * - Where to go (address), host/visitor role
 * - Contact phones (host cohouse admin)
 * - Total people count and dietary summary
 */
export const getMyPlanning = onCall<GetMyPlanningRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId, cohouseId } = request.data;

    if (!gameId || !cohouseId) {
      throw new HttpsError("invalid-argument", "Missing required fields: gameId, cohouseId");
    }

    try {
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data()!;

      if (!gameData.isRevealed) {
        throw new HttpsError("failed-precondition", "Planning has not been revealed yet");
      }

      if (!gameData.groupPlannings || !gameData.eventSettings) {
        throw new HttpsError("failed-precondition", "Planning data is incomplete");
      }

      const eventSettings = gameData.eventSettings;
      const groupPlannings = gameData.groupPlannings as Array<{
        groupIndex: number;
        cohouseA: string;
        cohouseB: string;
        cohouseC: string;
        cohouseD: string;
      }>;

      // Find the group containing this cohouse
      const myGroup = groupPlannings.find(
        (g) => g.cohouseA === cohouseId || g.cohouseB === cohouseId ||
               g.cohouseC === cohouseId || g.cohouseD === cohouseId
      );

      if (!myGroup) {
        throw new HttpsError("not-found", "Your cohouse is not in any group");
      }

      // Determine our role (A/B/C/D)
      let myRole: "A" | "B" | "C" | "D";
      if (myGroup.cohouseA === cohouseId) myRole = "A";
      else if (myGroup.cohouseB === cohouseId) myRole = "B";
      else if (myGroup.cohouseC === cohouseId) myRole = "C";
      else myRole = "D";

      // Derive apéro and dîner assignments based on the schema:
      // Apéro: A→B, C→D  |  Dîner: C→A, D→B
      let aperoPartnerCohouseId: string;
      let aperoRole: "host" | "visitor";
      let dinerPartnerCohouseId: string;
      let dinerRole: "host" | "visitor";

      switch (myRole) {
        case "A": // Goes to B for apéro, hosts C for dîner
          aperoPartnerCohouseId = myGroup.cohouseB;
          aperoRole = "visitor";
          dinerPartnerCohouseId = myGroup.cohouseC;
          dinerRole = "host";
          break;
        case "B": // Hosts A for apéro, hosts D for dîner
          aperoPartnerCohouseId = myGroup.cohouseA;
          aperoRole = "host";
          dinerPartnerCohouseId = myGroup.cohouseD;
          dinerRole = "host";
          break;
        case "C": // Goes to D for apéro, goes to A for dîner
          aperoPartnerCohouseId = myGroup.cohouseD;
          aperoRole = "visitor";
          dinerPartnerCohouseId = myGroup.cohouseA;
          dinerRole = "visitor";
          break;
        case "D": // Hosts C for apéro, goes to B for dîner
          aperoPartnerCohouseId = myGroup.cohouseC;
          aperoRole = "host";
          dinerPartnerCohouseId = myGroup.cohouseB;
          dinerRole = "visitor";
          break;
      }

      // Helper: fetch cohouse data (name, address, admin phone)
      async function getCohouseInfo(cId: string) {
        const snapshot = await db
          .collection("cohouses")
          .where("id", "==", cId)
          .limit(1)
          .get();

        if (snapshot.empty) {
          return { name: "Unknown", address: "", phone: null, docId: "" };
        }

        const doc = snapshot.docs[0];
        const data = doc.data();
        const address = data.address || {};
        const fullAddress = [address.street, address.postalCode, address.city]
          .filter(Boolean)
          .join(", ");

        // Get admin user's phone
        const usersSnapshot = await db
          .collection("cohouses")
          .doc(doc.id)
          .collection("users")
          .where("isAdmin", "==", true)
          .limit(1)
          .get();

        let phone: string | null = null;
        if (!usersSnapshot.empty) {
          const adminUserId = usersSnapshot.docs[0].data().userId;
          if (adminUserId) {
            const userSnapshot = await db
              .collection("users")
              .where("id", "==", adminUserId)
              .limit(1)
              .get();
            if (!userSnapshot.empty) {
              phone = userSnapshot.docs[0].data().phoneNumber || null;
            }
          }
        }

        return {
          name: (data.name as string) || "Unknown",
          address: fullAddress,
          phone,
          docId: doc.id,
        };
      }

      // Helper: get attending user IDs from registration
      async function getAttendingUserIds(cId: string): Promise<string[]> {
        const regDoc = await db
          .collection("ckrGames")
          .doc(gameId)
          .collection("registrations")
          .doc(cId)
          .get();

        if (!regDoc.exists) return [];
        return (regDoc.data()?.attendingUserIds as string[]) || [];
      }

      // Helper: fetch dietary preferences for a list of user IDs
      async function getDietarySummary(userIds: string[]): Promise<Record<string, number>> {
        const summary: Record<string, number> = {};
        if (userIds.length === 0) return summary;

        // Batch fetch users (max 30 per 'in' query)
        const batches = [];
        for (let i = 0; i < userIds.length; i += 30) {
          batches.push(userIds.slice(i, i + 30));
        }

        for (const batch of batches) {
          const snapshot = await db
            .collection("users")
            .where("id", "in", batch)
            .get();

          for (const doc of snapshot.docs) {
            const prefs = doc.data().dietaryPreferences as string[] | undefined;
            if (prefs && Array.isArray(prefs)) {
              for (const pref of prefs) {
                const displayName = dietaryDisplayName(pref);
                summary[displayName] = (summary[displayName] || 0) + 1;
              }
            }
          }
        }

        return summary;
      }

      function dietaryDisplayName(raw: string): string {
        switch (raw) {
          case "vegetarian": return "Végétarien";
          case "vegan": return "Végan";
          case "gluten_free": return "Sans gluten";
          case "lactose_free": return "Sans lactose";
          case "nut_free": return "Sans noix";
          default: return raw;
        }
      }

      // Fetch all data in parallel
      const [myInfo, aperoPartnerInfo, dinerPartnerInfo] = await Promise.all([
        getCohouseInfo(cohouseId),
        getCohouseInfo(aperoPartnerCohouseId),
        getCohouseInfo(dinerPartnerCohouseId),
      ]);

      const [myUserIds, aperoPartnerUserIds, dinerPartnerUserIds] = await Promise.all([
        getAttendingUserIds(cohouseId),
        getAttendingUserIds(aperoPartnerCohouseId),
        getAttendingUserIds(dinerPartnerCohouseId),
      ]);

      // Apéro: both our cohouse + partner are present
      const aperoAllUserIds = [...myUserIds, ...aperoPartnerUserIds];
      const aperoDietarySummary = await getDietarySummary(aperoAllUserIds);

      // Dîner: both our cohouse + partner are present
      const dinerAllUserIds = [...myUserIds, ...dinerPartnerUserIds];
      const dinerDietarySummary = await getDietarySummary(dinerAllUserIds);

      // Determine addresses and contacts based on role
      const aperoAddress = aperoRole === "host" ? myInfo.address : aperoPartnerInfo.address;
      const aperoHostPhone = aperoRole === "host" ? myInfo.phone : aperoPartnerInfo.phone;
      const aperoVisitorPhone = aperoRole === "host" ? aperoPartnerInfo.phone : myInfo.phone;

      const dinerAddress = dinerRole === "host" ? myInfo.address : dinerPartnerInfo.address;
      const dinerHostPhone = dinerRole === "host" ? myInfo.phone : dinerPartnerInfo.phone;
      const dinerVisitorPhone = dinerRole === "host" ? dinerPartnerInfo.phone : myInfo.phone;

      // Convert Firestore Timestamps to ISO strings
      function toISO(val: unknown): string {
        if (val instanceof admin.firestore.Timestamp) {
          return val.toDate().toISOString();
        }
        if (val instanceof Date) {
          return val.toISOString();
        }
        return String(val);
      }

      return {
        success: true,
        planning: {
          apero: {
            role: aperoRole,
            cohouseName: aperoPartnerInfo.name,
            address: aperoAddress,
            hostPhone: aperoHostPhone,
            visitorPhone: aperoVisitorPhone,
            totalPeople: aperoAllUserIds.length,
            dietarySummary: aperoDietarySummary,
            startTime: toISO(eventSettings.aperoStartTime),
            endTime: toISO(eventSettings.aperoEndTime),
          },
          diner: {
            role: dinerRole,
            cohouseName: dinerPartnerInfo.name,
            address: dinerAddress,
            hostPhone: dinerHostPhone,
            visitorPhone: dinerVisitorPhone,
            totalPeople: dinerAllUserIds.length,
            dietarySummary: dinerDietarySummary,
            startTime: toISO(eventSettings.dinerStartTime),
            endTime: toISO(eventSettings.dinerEndTime),
          },
          party: {
            name: eventSettings.partyName,
            address: eventSettings.partyAddress,
            startTime: toISO(eventSettings.partyStartTime),
            endTime: toISO(eventSettings.partyEndTime),
            note: eventSettings.partyNote || null,
          },
        },
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error getting planning:", error);
      throw new HttpsError("internal", "Failed to get planning");
    }
  }
);
