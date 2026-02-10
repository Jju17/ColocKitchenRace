import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Region configuration for Europe (Belgium)
const REGION = "europe-west1";

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
      .where("id", "in", batch)
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

      console.log(`Sent to cohouse ${cohouseId}: ${result.success} success, ${result.failure} failure`);

      await saveNotificationHistory({
        target: "cohouse",
        targetId: cohouseId,
        title: notification.title,
        body: notification.body,
        sent: result.success,
        failed: result.failure,
        sentBy: request.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        sent: result.success,
        failed: result.failure,
        totalUsers: userIds.length,
      };
    } catch (error) {
      console.error("Error sending to cohouse:", error);
      throw new HttpsError("internal", "Failed to send notifications");
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

      const participantsIds: string[] = editionDoc.data()?.participantsID || [];

      if (participantsIds.length === 0) {
        return {
          success: true,
          sent: 0,
          failed: 0,
          message: "No participants in this edition",
        };
      }

      // Collect all user IDs from all participating cohouses
      const allUserIds: string[] = [];

      for (const cohouseId of participantsIds) {
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

      await saveNotificationHistory({
        target: "edition",
        targetId: editionId,
        title: notification.title,
        body: notification.body,
        sent: result.success,
        failed: result.failure,
        sentBy: request.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        sent: result.success,
        failed: result.failure,
        totalCohouses: participantsIds.length,
        totalUsers: allUserIds.length,
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
      const participantsIds: string[] = gameData?.participantsID || [];

      if (participantsIds.length === 0) {
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
      for (let i = 0; i < participantsIds.length; i += 30) {
        batches.push(participantsIds.slice(i, i + 30));
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
      const orphanedIds = participantsIds.filter((id) => !foundIds.includes(id));
      let removedCount = 0;

      if (orphanedIds.length > 0) {
        console.log(
          `Cleaning up ${orphanedIds.length} orphaned cohouse IDs from participantsID: ${orphanedIds.join(", ")}`
        );

        const cleanedParticipantsIds = participantsIds.filter(
          (id) => !orphanedIds.includes(id)
        );

        // Also clear previous matchedGroups since they reference deleted cohouses
        await db.collection("ckrGames").doc(gameId).update({
          participantsID: cleanedParticipantsIds,
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
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from participantsID)` : "")
        );
      }

      if (points.length < 4) {
        throw new HttpsError(
          "failed-precondition",
          `Need at least 4 cohouses to perform matching, but only ${points.length} remaining` +
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from participantsID)` : "")
        );
      }

      if (points.length % 4 !== 0) {
        throw new HttpsError(
          "failed-precondition",
          `Number of participants (${points.length}) must be a multiple of 4. ` +
          `Current count leaves ${points.length % 4} cohouse(s) unmatched.` +
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from participantsID)` : "")
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
