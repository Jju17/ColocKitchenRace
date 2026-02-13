import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, REGION, getStripe } from "./config";

// ============================================
// Types
// ============================================

interface RegisterForGameRequest {
  gameId: string;
  cohouseId: string;
  attendingUserIds: string[];
  averageAge: number;
  cohouseType: string;
  paymentIntentId?: string;
}

// ============================================
// Cloud Functions
// ============================================

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
