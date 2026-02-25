import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, REGION } from "./config";

// ============================================
// Types
// ============================================

interface ReleaseExpiredReservationData {
  gameId: string;
  cohouseId: string;
}

interface CancelReservationRequest {
  gameId: string;
  cohouseId: string;
}

interface DeleteCKRGameRequest {
  gameId: string;
}

// ============================================
// Cloud Task Handlers
// ============================================

/**
 * Cloud Task handler that releases an expired pending reservation.
 *
 * Scheduled by `reserveAndCreatePayment` to run 15 minutes after reservation.
 * Each reservation schedules its own one-shot cleanup task — no permanently
 * running scheduled function.
 *
 * Idempotent:
 * - If the registration has been confirmed → no-op
 * - If the registration has been deleted → no-op
 * - If the registration is still pending → delete it and free the spots
 */
export const releaseExpiredReservation = onTaskDispatched(
  {
    region: REGION,
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 10,
    },
  },
  async (req) => {
    const { gameId, cohouseId } = req.data as ReleaseExpiredReservationData;

    if (!gameId || !cohouseId) {
      console.error("releaseExpiredReservation: missing gameId or cohouseId");
      return;
    }

    const gameRef = db.collection("ckrGames").doc(gameId);
    const regRef = gameRef.collection("registrations").doc(cohouseId);

    await db.runTransaction(async (transaction) => {
      const regDoc = await transaction.get(regRef);

      // Already deleted (e.g. account deletion, manual cleanup)
      if (!regDoc.exists) {
        console.log(
          `Registration ${cohouseId} in game ${gameId} already deleted, skipping`
        );
        return;
      }

      const regData = regDoc.data()!;

      // Already confirmed or in another non-pending state → no-op
      if (regData.status !== "pending") {
        console.log(
          `Registration ${cohouseId} in game ${gameId} has status "${regData.status}", skipping`
        );
        return;
      }

      // Still pending → release the reservation
      const attendingCount = (regData.attendingUserIds as string[])?.length || 0;

      transaction.delete(regRef);
      transaction.update(gameRef, {
        cohouseIDs: admin.firestore.FieldValue.arrayRemove(cohouseId),
        totalRegisteredParticipants: admin.firestore.FieldValue.increment(-attendingCount),
      });

      console.log(
        `Released expired reservation for cohouse ${cohouseId} in game ${gameId} ` +
        `(${attendingCount} spots freed)`
      );
    });
  }
);

/**
 * Client-callable function to immediately cancel a pending reservation.
 *
 * Called when the user cancels the Stripe PaymentSheet or dismisses the
 * payment summary screen. Does the same cleanup as `releaseExpiredReservation`
 * but on-demand instead of after the 15-minute TTL.
 *
 * Idempotent — safe to call multiple times or after the Cloud Task has
 * already cleaned up.
 */
export const cancelReservation = onCall<CancelReservationRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId, cohouseId } = request.data;

    if (!gameId || !cohouseId) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: gameId, cohouseId"
      );
    }

    const gameRef = db.collection("ckrGames").doc(gameId);
    const regRef = gameRef.collection("registrations").doc(cohouseId);

    await db.runTransaction(async (transaction) => {
      const regDoc = await transaction.get(regRef);

      if (!regDoc.exists) {
        console.log(
          `cancelReservation: registration ${cohouseId} in game ${gameId} already deleted`
        );
        return;
      }

      const regData = regDoc.data()!;

      // Verify the caller is the one who reserved this spot
      if (regData.reservedBy && regData.reservedBy !== request.auth!.uid) {
        throw new HttpsError(
          "permission-denied",
          "You can only cancel your own reservation"
        );
      }

      if (regData.status !== "pending") {
        console.log(
          `cancelReservation: registration ${cohouseId} in game ${gameId} has status "${regData.status}", skipping`
        );
        return;
      }

      const attendingCount = (regData.attendingUserIds as string[])?.length || 0;

      transaction.delete(regRef);
      transaction.update(gameRef, {
        cohouseIDs: admin.firestore.FieldValue.arrayRemove(cohouseId),
        totalRegisteredParticipants: admin.firestore.FieldValue.increment(-attendingCount),
      });

      console.log(
        `Cancelled reservation for cohouse ${cohouseId} in game ${gameId} ` +
        `(${attendingCount} spots freed)`
      );
    });

    return { success: true };
  }
);

// ============================================
// Game Deletion
// ============================================

/**
 * Delete a CKR game and all associated data.
 *
 * Cleans up:
 * - All registration documents (ckrGames/{gameId}/registrations/*)
 * - All notification marker documents (ckrGames/{gameId}/notifications/*)
 * - The game document itself
 *
 * Any previously scheduled Cloud Tasks (game reminders, event reminders)
 * will gracefully no-op when they fire, because the task handlers
 * already check `if (!gameDoc.exists) return;`.
 *
 * Admin-only — requires the `admin` custom claim.
 */
export const deleteCKRGame = onCall<DeleteCKRGameRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    if (!request.auth.token.admin) {
      throw new HttpsError("permission-denied", "Admin access required");
    }

    const { gameId } = request.data;

    if (!gameId) {
      throw new HttpsError("invalid-argument", "Missing required field: gameId");
    }

    const gameRef = db.collection("ckrGames").doc(gameId);
    const gameDoc = await gameRef.get();

    if (!gameDoc.exists) {
      throw new HttpsError("not-found", "CKR Game not found");
    }

    // Delete all documents in subcollections using batched writes.
    // Firestore does not cascade deletes to subcollections.
    const subcollections = ["registrations", "notifications"];

    for (const subcollection of subcollections) {
      const snapshot = await gameRef.collection(subcollection).get();

      if (snapshot.empty) continue;

      // Batch delete (max 500 per batch)
      const batches: FirebaseFirestore.WriteBatch[] = [];
      let currentBatch = db.batch();
      let count = 0;

      for (const doc of snapshot.docs) {
        currentBatch.delete(doc.ref);
        count++;

        if (count % 500 === 0) {
          batches.push(currentBatch);
          currentBatch = db.batch();
        }
      }

      batches.push(currentBatch);

      for (const batch of batches) {
        await batch.commit();
      }

      console.log(
        `Deleted ${snapshot.size} documents from ${subcollection} subcollection`
      );
    }

    // Delete the game document
    await gameRef.delete();

    console.log(`CKR Game ${gameId} and all associated data deleted`);
    return { success: true };
  }
);
