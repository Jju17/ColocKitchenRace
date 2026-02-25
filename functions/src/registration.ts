import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, auth, db, REGION, getStripe } from "./config";
import { parseRequest, requireAuth, confirmRegistrationSchema } from "./schemas";

const DEMO_EMAIL = "test_apple@colocskitchenrace.be";

// ============================================
// Types
// ============================================

interface ConfirmRegistrationRequest {
  gameId: string;
  cohouseId: string;
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

// ============================================
// Cloud Functions
// ============================================

/**
 * Confirm a pending registration after successful Stripe payment.
 *
 * Called by the client after the PaymentSheet completes successfully.
 * Validates the Stripe payment, then transitions the registration
 * from "pending" to "confirmed" within a transaction.
 *
 * If the reservation has expired (15-minute TTL), the confirmation
 * is rejected and the client must restart the registration flow.
 */
export const confirmRegistration = onCall<ConfirmRegistrationRequest>(
  { region: REGION, secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {
    requireAuth(request);
    const { gameId, cohouseId, paymentIntentId } = parseRequest(confirmRegistrationSchema, request.data);

    try {
      // Demo mode: return success directly
      if (await isDemoUser(request.auth!.uid)) {
        console.log(`[Demo] Confirming registration for ${DEMO_EMAIL}`);
        return { success: true };
      }

      // 1. Verify payment via Stripe API (outside transaction — external call)
      const paymentIntent = await getStripe().paymentIntents.retrieve(paymentIntentId);

      if (paymentIntent.status !== "succeeded") {
        throw new HttpsError(
          "failed-precondition",
          `Payment not completed (status: ${paymentIntent.status})`
        );
      }

      if (
        paymentIntent.metadata.gameId !== gameId ||
        paymentIntent.metadata.cohouseId !== cohouseId
      ) {
        throw new HttpsError(
          "invalid-argument",
          "Payment does not match this registration"
        );
      }

      // 2. Confirm reservation in a transaction
      const gameRef = db.collection("ckrGames").doc(gameId);
      const regRef = gameRef.collection("registrations").doc(cohouseId);

      await db.runTransaction(async (transaction) => {
        const regDoc = await transaction.get(regRef);

        if (!regDoc.exists) {
          throw new HttpsError("not-found", "Registration not found");
        }

        const regData = regDoc.data()!;

        // Idempotent: already confirmed → success
        if (regData.status === "confirmed") {
          return;
        }

        if (regData.status !== "pending") {
          throw new HttpsError(
            "failed-precondition",
            `Registration has unexpected status: ${regData.status}`
          );
        }

        // Check if reservation has expired
        const reservedUntil = (regData.reservedUntil as admin.firestore.Timestamp).toDate();
        if (new Date() >= reservedUntil) {
          // Reservation expired but payment succeeded — issue automatic refund
          try {
            await getStripe().refunds.create({
              payment_intent: paymentIntentId,
              reason: "requested_by_customer",
            });
            console.warn(
              `Auto-refunded payment ${paymentIntentId} for expired reservation ` +
              `(cohouse ${cohouseId}, game ${gameId})`
            );
          } catch (refundError) {
            console.error(
              `CRITICAL: Failed to auto-refund payment ${paymentIntentId} for expired reservation:`,
              refundError
            );
          }
          throw new HttpsError(
            "failed-precondition",
            "Reservation has expired. Your payment has been refunded. Please register again."
          );
        }

        // Transition: pending → confirmed
        transaction.update(regRef, {
          status: "confirmed",
          confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
          registeredBy: request.auth!.uid,
          paymentIntentId,
          // Remove reservation-specific fields
          reservedUntil: admin.firestore.FieldValue.delete(),
          reservedAt: admin.firestore.FieldValue.delete(),
          reservedBy: admin.firestore.FieldValue.delete(),
        });
      });

      console.log(
        `Registration confirmed for cohouse ${cohouseId} in game ${gameId} (payment: ${paymentIntentId})`
      );

      return { success: true };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error confirming registration:", error);
      throw new HttpsError("internal", "Failed to confirm registration");
    }
  }
);
