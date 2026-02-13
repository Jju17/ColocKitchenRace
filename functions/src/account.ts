import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, REGION } from "./config";

// ============================================
// Types
// ============================================

interface DeleteAccountRequest {
  userId: string; // App-level UUID (not Firebase Auth UID)
}

// ============================================
// Cloud Functions
// ============================================

/**
 * Delete a user account and clean up all associated data.
 *
 * Performs the following cleanup:
 * 1. Verifies the caller owns the account (Auth UID matches userDoc.authId)
 * 2. If user is in a cohouse:
 *    - If user is admin AND the only member → deletes the entire cohouse
 *      (subcollection users, Storage files, game registrations)
 *    - Otherwise → removes user from cohouse membership only
 * 3. Deletes the user's Firestore document
 * 4. Deletes the Firebase Auth account
 *
 * Required by Apple App Store Guideline 5.1.1(v).
 */
export const deleteAccount = onCall<DeleteAccountRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { userId } = request.data;

    if (!userId) {
      throw new HttpsError("invalid-argument", "Missing required field: userId");
    }

    try {
      // 1. Fetch the user document and verify ownership
      const userDoc = await db.collection("users").doc(userId).get();

      if (!userDoc.exists) {
        throw new HttpsError("not-found", "User not found");
      }

      const userData = userDoc.data()!;
      const authUid = userData.authId as string;

      // Security: only the account owner can delete their own account
      if (authUid !== request.auth.uid) {
        throw new HttpsError("permission-denied", "You can only delete your own account");
      }

      const cohouseId = userData.cohouseId as string | undefined;

      // 2. Handle cohouse cleanup
      if (cohouseId) {
        await handleCohouseCleanup(userId, cohouseId);
      }

      // 3. Delete the user document from Firestore
      await db.collection("users").doc(userId).delete();
      console.log(`Deleted user document: users/${userId}`);

      // 4. Delete the Firebase Auth account
      await admin.auth().deleteUser(authUid);
      console.log(`Deleted Firebase Auth account: ${authUid}`);

      console.log(`Account deletion complete for user ${userId} (auth: ${authUid})`);
      return { success: true };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error deleting account:", error);
      throw new HttpsError("internal", "Failed to delete account");
    }
  }
);

/**
 * Handle cohouse-related cleanup when deleting a user account.
 *
 * - If user is the admin AND the only member → delete the entire cohouse
 * - Otherwise → just remove the user from the cohouse membership
 */
async function handleCohouseCleanup(userId: string, cohouseId: string): Promise<void> {
  const cohouseRef = db.collection("cohouses").doc(cohouseId);
  const cohouseDoc = await cohouseRef.get();

  if (!cohouseDoc.exists) {
    // Cohouse already deleted or never existed — nothing to clean
    return;
  }

  const usersSubcollection = cohouseRef.collection("users");
  const usersSnapshot = await usersSubcollection.get();

  // Find our CohouseUser doc in the subcollection
  const myMembership = usersSnapshot.docs.find(
    (doc) => doc.data().userId === userId
  );

  const isAdmin = myMembership?.data().isAdmin === true;
  const isOnlyMember = usersSnapshot.docs.length <= 1;

  if (isAdmin && isOnlyMember) {
    // Delete the entire cohouse and all associated data
    await deleteEntireCohouse(cohouseId, cohouseRef, usersSnapshot);
  } else if (myMembership) {
    // Just remove our membership doc
    await usersSubcollection.doc(myMembership.id).delete();
    console.log(`Removed user ${userId} from cohouse ${cohouseId}`);
  }
}

/**
 * Delete an entire cohouse: subcollection users, Storage files, game registrations.
 */
async function deleteEntireCohouse(
  cohouseId: string,
  cohouseRef: FirebaseFirestore.DocumentReference,
  usersSnapshot: FirebaseFirestore.QuerySnapshot
): Promise<void> {
  const batch = db.batch();

  // 1. Delete all CohouseUser docs in subcollection
  for (const doc of usersSnapshot.docs) {
    batch.delete(doc.ref);
  }

  // 2. Delete the cohouse document itself
  batch.delete(cohouseRef);

  await batch.commit();
  console.log(`Deleted cohouse document and ${usersSnapshot.docs.length} user(s): cohouses/${cohouseId}`);

  // 3. Delete Storage files (best-effort, don't fail if missing)
  const bucket = admin.storage().bucket();
  const filesToDelete = [
    `cohouses/${cohouseId}/id_card.jpg`,
    `cohouses/${cohouseId}/cover_image.jpg`,
  ];

  for (const filePath of filesToDelete) {
    try {
      await bucket.file(filePath).delete();
      console.log(`Deleted storage file: ${filePath}`);
    } catch (error: unknown) {
      // File might not exist — that's fine
      const code = (error as { code?: number }).code;
      if (code !== 404) {
        console.warn(`Failed to delete storage file ${filePath}:`, error);
      }
    }
  }

  // 4. Clean up game registrations
  await cleanupGameRegistrations(cohouseId);
}

/**
 * Remove a cohouse from all CKR game registrations.
 * Deletes registration docs and updates game metadata.
 */
async function cleanupGameRegistrations(cohouseId: string): Promise<void> {
  // Find all games that include this cohouse
  const gamesSnapshot = await db
    .collection("ckrGames")
    .where("cohouseIDs", "array-contains", cohouseId)
    .get();

  for (const gameDoc of gamesSnapshot.docs) {
    const gameId = gameDoc.id;

    // Get registration to know how many participants to subtract
    const regDoc = await db
      .collection("ckrGames")
      .doc(gameId)
      .collection("registrations")
      .doc(cohouseId)
      .get();

    let participantCount = 0;
    if (regDoc.exists) {
      const attendingUserIds = regDoc.data()?.attendingUserIds as string[] | undefined;
      participantCount = attendingUserIds?.length ?? 0;

      // Delete the registration doc
      await regDoc.ref.delete();
      console.log(`Deleted registration: ckrGames/${gameId}/registrations/${cohouseId}`);
    }

    // Update the game: remove cohouseId and decrement participant count
    const updateData: Record<string, unknown> = {
      cohouseIDs: admin.firestore.FieldValue.arrayRemove(cohouseId),
    };

    if (participantCount > 0) {
      updateData.totalRegisteredParticipants =
        admin.firestore.FieldValue.increment(-participantCount);
    }

    await db.collection("ckrGames").doc(gameId).update(updateData);
    console.log(`Updated game ${gameId}: removed cohouse ${cohouseId}, decremented ${participantCount} participants`);
  }
}
