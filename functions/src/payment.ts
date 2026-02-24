import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, auth, db, REGION, getStripe } from "./config";
import { getFunctions } from "firebase-admin/functions";

const DEMO_EMAIL = "test_apple@colocskitchenrace.be";
const RESERVATION_TTL_SECONDS = 15 * 60; // 15 minutes

// ============================================
// Types
// ============================================

interface ReserveAndCreatePaymentRequest {
  gameId: string;
  cohouseId: string;
  amountCents: number;
  participantCount: number;
  attendingUserIds: string[];
  averageAge: number;
  cohouseType: string;
}

interface PaymentIntentResponse {
  clientSecret: string | null;
  customerId: string;
  ephemeralKeySecret: string | undefined;
  paymentIntentId: string;
  remainingSpots?: number;
}

// ============================================
// Helpers
// ============================================

/**
 * Check whether the calling user is the demo/Apple-review account.
 */
async function isDemoUser(uid: string): Promise<boolean> {
  const userRecord = await auth.getUser(uid);
  return userRecord.email === DEMO_EMAIL;
}

/**
 * Create Stripe objects (Customer + EphemeralKey + PaymentIntent) for the
 * demo account.  Skips all Firestore validation so the Apple reviewer can
 * see the real Stripe PaymentSheet without needing a real game or cohouse.
 */
async function createDemoPaymentIntent(
  uid: string,
  data: ReserveAndCreatePaymentRequest
): Promise<PaymentIntentResponse> {
  const { gameId, cohouseId, amountCents, participantCount } = data;
  const stripe = getStripe();

  console.log(`[Demo] Creating demo payment intent for ${DEMO_EMAIL}`);

  const customer = await stripe.customers.create({
    name: "Demo Cohouse",
    metadata: { cohouseId, firebaseUid: uid, demo: "true" },
  });

  const ephemeralKey = await stripe.ephemeralKeys.create(
    { customer: customer.id },
    { apiVersion: "2025-02-24.acacia" }
  );

  const paymentIntent = await stripe.paymentIntents.create({
    amount: amountCents,
    currency: "eur",
    customer: customer.id,
    payment_method_types: ["card", "bancontact"],
    metadata: {
      gameId,
      cohouseId,
      participantCount: participantCount.toString(),
      firebaseUid: uid,
      demo: "true",
    },
  });

  return {
    clientSecret: paymentIntent.client_secret,
    customerId: customer.id,
    ephemeralKeySecret: ephemeralKey.secret,
    paymentIntentId: paymentIntent.id,
  };
}

/**
 * Validate the game data for a reservation attempt.
 * Throws HttpsError on any validation failure.
 * Returns { expectedAmount, remainingSpots }.
 */
function validateGameForReservation(
  gameData: FirebaseFirestore.DocumentData,
  cohouseId: string,
  amountCents: number,
  participantCount: number
): { expectedAmount: number; remainingSpots: number } {
  const pricePerPersonCents: number = gameData.pricePerPersonCents || 500;
  const expectedAmount = pricePerPersonCents * participantCount;

  if (amountCents !== expectedAmount) {
    throw new HttpsError(
      "invalid-argument",
      `Amount mismatch: expected ${expectedAmount} cents, got ${amountCents}`
    );
  }

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
  const totalRegistered: number = gameData.totalRegisteredParticipants || 0;
  if (totalRegistered + participantCount > maxParticipants) {
    throw new HttpsError(
      "failed-precondition",
      "Maximum number of participants reached"
    );
  }

  const remainingSpots = maxParticipants - (totalRegistered + participantCount);
  return { expectedAmount, remainingSpots };
}

/**
 * Get or create a Stripe Customer for the given cohouse.
 * Persists the Stripe customer ID back to Firestore if newly created.
 * Also returns the cohouse document reference for later updates.
 */
async function getOrCreateStripeCustomer(
  cohouseId: string,
  firebaseUid: string
): Promise<{ stripeCustomerId: string; cohouseDocRef: FirebaseFirestore.DocumentReference }> {
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
      metadata: { cohouseId, firebaseUid },
    });
    stripeCustomerId = customer.id;
    await cohouseDoc.ref.update({ stripeCustomerId });
  }

  return { stripeCustomerId, cohouseDocRef: cohouseDoc.ref };
}

// ============================================
// Cloud Functions
// ============================================

/**
 * Reserve a spot for a cohouse in a CKR Game and create a Stripe PaymentIntent.
 *
 * This function atomically:
 * 1. Validates game constraints (deadline, capacity, duplicate)
 * 2. Creates a "pending" registration with a 15-minute TTL
 * 3. Reserves the participant slots on the game document
 * 4. Creates Stripe payment objects (Customer + EphemeralKey + PaymentIntent)
 * 5. Schedules a Cloud Task to release the reservation if payment doesn't complete
 *
 * If Stripe creation fails after reservation, the reservation is rolled back immediately.
 * The Cloud Task is a safety net for cases where the client never calls confirmRegistration.
 */
export const reserveAndCreatePayment = onCall<ReserveAndCreatePaymentRequest>(
  {
    region: REGION,
    secrets: ["STRIPE_SECRET_KEY"],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const {
      gameId, cohouseId, amountCents, participantCount,
      attendingUserIds, averageAge, cohouseType,
    } = request.data;

    if (!gameId || !cohouseId || !amountCents || !participantCount) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: gameId, cohouseId, amountCents, participantCount"
      );
    }

    if (!attendingUserIds || !Array.isArray(attendingUserIds) || attendingUserIds.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "attendingUserIds must be a non-empty array"
      );
    }

    if (!averageAge || !cohouseType) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: averageAge, cohouseType"
      );
    }

    try {
      // Demo mode: real Stripe objects, no Firestore validation
      if (await isDemoUser(request.auth.uid)) {
        return createDemoPaymentIntent(request.auth.uid, request.data);
      }

      // 1. Verify cohouse exists + get/create Stripe customer (outside transaction)
      const { stripeCustomerId, cohouseDocRef } = await getOrCreateStripeCustomer(
        cohouseId,
        request.auth.uid
      );

      // 2. Transactional reservation — atomic read + validate + reserve
      //    Prevents race conditions where two cohouses pass validation
      //    simultaneously and exceed capacity or create duplicate registrations.
      const gameRef = db.collection("ckrGames").doc(gameId);
      const reservationResult = await db.runTransaction(async (transaction) => {
        const gameDoc = await transaction.get(gameRef);

        if (!gameDoc.exists) {
          throw new HttpsError("not-found", "CKR Game not found");
        }

        const gameData = gameDoc.data()!;
        const { expectedAmount, remainingSpots } = validateGameForReservation(
          gameData,
          cohouseId,
          amountCents,
          participantCount
        );

        // Reserve spot: add cohouseId + increment participant count
        transaction.update(gameRef, {
          cohouseIDs: admin.firestore.FieldValue.arrayUnion(cohouseId),
          totalRegisteredParticipants: admin.firestore.FieldValue.increment(attendingUserIds.length),
        });

        // Create pending registration with TTL
        const now = new Date();
        const reservedUntil = new Date(now.getTime() + RESERVATION_TTL_SECONDS * 1000);

        transaction.set(
          gameRef.collection("registrations").doc(cohouseId),
          {
            cohouseId,
            attendingUserIds,
            averageAge,
            cohouseType,
            status: "pending",
            reservedAt: admin.firestore.FieldValue.serverTimestamp(),
            reservedBy: request.auth!.uid,
            reservedUntil: admin.firestore.Timestamp.fromDate(reservedUntil),
          }
        );

        return { expectedAmount, remainingSpots };
      });

      // 3. Create Stripe objects (outside transaction — external API call)
      //    If this fails, we rollback the reservation.
      let paymentIntentResponse: PaymentIntentResponse;
      try {
        const stripe = getStripe();

        const ephemeralKey = await stripe.ephemeralKeys.create(
          { customer: stripeCustomerId },
          { apiVersion: "2025-02-24.acacia" }
        );

        const paymentIntent = await stripe.paymentIntents.create({
          amount: reservationResult.expectedAmount,
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

        paymentIntentResponse = {
          clientSecret: paymentIntent.client_secret,
          customerId: stripeCustomerId,
          ephemeralKeySecret: ephemeralKey.secret,
          paymentIntentId: paymentIntent.id,
          remainingSpots: reservationResult.remainingSpots,
        };

        // Store paymentIntentId on the registration doc (outside transaction, non-critical)
        await gameRef.collection("registrations").doc(cohouseId).update({
          paymentIntentId: paymentIntent.id,
        });
      } catch (stripeError) {
        // Stripe failed after reservation → rollback the reservation
        console.error("Stripe creation failed, rolling back reservation:", stripeError);
        await db.runTransaction(async (transaction) => {
          const regDoc = await transaction.get(
            gameRef.collection("registrations").doc(cohouseId)
          );
          if (regDoc.exists && regDoc.data()?.status === "pending") {
            transaction.delete(gameRef.collection("registrations").doc(cohouseId));
            transaction.update(gameRef, {
              cohouseIDs: admin.firestore.FieldValue.arrayRemove(cohouseId),
              totalRegisteredParticipants: admin.firestore.FieldValue.increment(-attendingUserIds.length),
            });
          }
        });
        throw new HttpsError("internal", "Failed to create payment intent");
      }

      // 4. Update cohouse with cohouseType (outside transaction — non-critical)
      await cohouseDocRef.update({ cohouseType });

      // 5. Schedule Cloud Task to release reservation if payment doesn't complete
      try {
        const queue = getFunctions().taskQueue("releaseExpiredReservation");
        await queue.enqueue(
          { gameId, cohouseId },
          { scheduleDelaySeconds: RESERVATION_TTL_SECONDS }
        );
      } catch (taskError) {
        // Non-critical: if task scheduling fails, the reservation TTL is still
        // enforced by confirmRegistration (it checks reservedUntil).
        console.warn("Failed to schedule cleanup task (non-critical):", taskError);
      }

      console.log(
        `Cohouse ${cohouseId} reserved spot for game ${gameId} with ${attendingUserIds.length} persons. ` +
        `Remaining spots: ${reservationResult.remainingSpots}. Payment intent: ${paymentIntentResponse.paymentIntentId}`
      );

      return paymentIntentResponse;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error in reserveAndCreatePayment:", error);
      throw new HttpsError("internal", "Failed to reserve spot and create payment");
    }
  }
);
