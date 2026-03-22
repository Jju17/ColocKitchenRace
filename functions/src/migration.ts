/**
 * Migration script for Phase 1: Multi-Edition Architecture
 *
 * Run via: firebase functions:shell > migrateToMultiEdition()
 * Or deploy as a one-shot callable and invoke from CKRAdmin.
 *
 * What it does:
 * 1. Adds multi-edition fields to existing CKR games (editionType, status, createdByAuthUid)
 * 2. Copies challenges from /challenges/{id} to /ckrGames/{gameId}/challenges/{id}
 * 3. Updates the super admin's custom claim from { admin: true } to { role: "super_admin", admin: true }
 */
import { onCall } from "firebase-functions/v2/https";
import { db, auth, REGION } from "./config";
import { requireSuperAdmin } from "./schemas";

export const migrateToMultiEdition = onCall(
  { region: REGION, timeoutSeconds: 300 },
  async (request) => {
    requireSuperAdmin(request);
    const callerUid = request.auth!.uid;
    const results: string[] = [];

    // ── Step 1: Update existing CKR games ──
    const gamesSnapshot = await db.collection("ckrGames").get();
    for (const gameDoc of gamesSnapshot.docs) {
      const data = gameDoc.data();
      const updates: Record<string, unknown> = {};

      if (!data.editionType) updates.editionType = "global";
      if (!data.status) updates.status = "published";
      if (!data.createdByAuthUid) updates.createdByAuthUid = callerUid;

      if (Object.keys(updates).length > 0) {
        await gameDoc.ref.update(updates);
        results.push(`Game ${gameDoc.id}: added multi-edition fields`);
      }
    }

    // ── Step 2: Copy challenges into the latest published game ──
    const latestGameSnapshot = await db
      .collection("ckrGames")
      .where("editionType", "==", "global")
      .orderBy("publishedTimestamp", "desc")
      .limit(1)
      .get();

    if (!latestGameSnapshot.empty) {
      const latestGameId = latestGameSnapshot.docs[0].id;
      const challengesSnapshot = await db.collection("challenges").get();

      for (const challengeDoc of challengesSnapshot.docs) {
        const challengeData = challengeDoc.data();
        const targetRef = db
          .collection("ckrGames")
          .doc(latestGameId)
          .collection("challenges")
          .doc(challengeDoc.id);

        // Only copy if not already there
        const existing = await targetRef.get();
        if (!existing.exists) {
          await targetRef.set(challengeData);

          // Also copy responses subcollection
          const responsesSnapshot = await challengeDoc.ref
            .collection("responses")
            .get();
          for (const responseDoc of responsesSnapshot.docs) {
            await targetRef
              .collection("responses")
              .doc(responseDoc.id)
              .set(responseDoc.data());
          }

          // Also copy notification markers
          const notifSnapshot = await challengeDoc.ref
            .collection("notifications")
            .get();
          for (const notifDoc of notifSnapshot.docs) {
            await targetRef
              .collection("notifications")
              .doc(notifDoc.id)
              .set(notifDoc.data());
          }

          results.push(`Challenge ${challengeDoc.id}: copied to game ${latestGameId}`);
        }
      }
    } else {
      results.push("No published game found — skipping challenge migration");
    }

    // ── Step 3: Update caller's custom claim to include role ──
    try {
      const callerUser = await auth.getUser(callerUid);
      const claims = callerUser.customClaims || {};
      if (!claims.role) {
        await auth.setCustomUserClaims(callerUid, {
          ...claims,
          role: "super_admin",
          admin: true, // Keep legacy compat
        });
        results.push(`Auth claim updated: role=super_admin for ${callerUid}`);
      }
    } catch (error) {
      results.push(`Failed to update auth claim: ${error}`);
    }

    console.log("Migration completed:", results);
    return { success: true, results };
  }
);
