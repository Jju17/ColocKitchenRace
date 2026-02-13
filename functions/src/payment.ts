import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, REGION, getStripe } from "./config";

// ============================================
// Types
// ============================================

interface CreatePaymentIntentRequest {
  gameId: string;
  cohouseId: string;
  amountCents: number;
  participantCount: number;
}

// ============================================
// Cloud Functions
// ============================================

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
