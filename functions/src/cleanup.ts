import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { admin, db, REGION } from "./config";

// ============================================
// Types
// ============================================

interface ReleaseExpiredReservationData {
  gameId: string;
  cohouseId: string;
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
