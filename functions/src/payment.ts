import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, auth, db, REGION, getStripe } from "./config";

const DEMO_EMAIL = "test_apple@colocskitchenrace.be";

// ============================================
// Types
// ============================================

interface CreatePaymentIntentRequest {
  gameId: string;
  cohouseId: string;
  amountCents: number;
  participantCount: number;
}

interface PaymentIntentResponse {
  clientSecret: string | null;
  customerId: string;
  ephemeralKeySecret: string | undefined;
  paymentIntentId: string;
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
  data: CreatePaymentIntentRequest
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
 * Validate the game data and return the server-verified amount.
 * Throws HttpsError on any validation failure.
 */
function validateGame(
  gameData: FirebaseFirestore.DocumentData,
  cohouseId: string,
  amountCents: number,
  participantCount: number
): number {
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

  return expectedAmount;
}

/**
 * Get or create a Stripe Customer for the given cohouse.
 * Persists the Stripe customer ID back to Firestore if newly created.
 */
async function getOrCreateStripeCustomer(
  cohouseId: string,
  firebaseUid: string
): Promise<string> {
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

  return stripeCustomerId;
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
      // Demo mode: real Stripe objects, no Firestore validation
      if (await isDemoUser(request.auth.uid)) {
        return createDemoPaymentIntent(request.auth.uid, request.data);
      }

      // 1. Fetch the game and validate price server-side
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const expectedAmount = validateGame(
        gameDoc.data()!,
        cohouseId,
        amountCents,
        participantCount
      );

      // 2. Get or create Stripe Customer for this cohouse
      const stripeCustomerId = await getOrCreateStripeCustomer(
        cohouseId,
        request.auth.uid
      );

      // 3. Create Ephemeral Key for the customer
      const ephemeralKey = await getStripe().ephemeralKeys.create(
        { customer: stripeCustomerId },
        { apiVersion: "2025-02-24.acacia" }
      );

      // 4. Create PaymentIntent
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
