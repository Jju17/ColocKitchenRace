import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, REGION } from "./config";
import {
  CohousePoint,
  computeCubicDistances,
  doubleMatchingHeuristic,
} from "./matching";

// ============================================
// Types
// ============================================

interface MatchCohousesRequest {
  gameId: string;
}

// ============================================
// Cloud Functions
// ============================================

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
      const cohouseIDs: string[] = gameData?.cohouseIDs || [];

      if (cohouseIDs.length === 0) {
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
      for (let i = 0; i < cohouseIDs.length; i += 30) {
        batches.push(cohouseIDs.slice(i, i + 30));
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
      const orphanedIds = cohouseIDs.filter((id) => !foundIds.includes(id));
      let removedCount = 0;

      if (orphanedIds.length > 0) {
        console.log(
          `Cleaning up ${orphanedIds.length} orphaned cohouse IDs from cohouseIDs: ${orphanedIds.join(", ")}`
        );

        const cleanedCohouseIDs = cohouseIDs.filter(
          (id) => !orphanedIds.includes(id)
        );

        // Also clear previous matchedGroups since they reference deleted cohouses
        await db.collection("ckrGames").doc(gameId).update({
          cohouseIDs: cleanedCohouseIDs,
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
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from cohouseIDs)` : "")
        );
      }

      if (points.length < 4) {
        throw new HttpsError(
          "failed-precondition",
          `Need at least 4 cohouses to perform matching, but only ${points.length} remaining` +
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from cohouseIDs)` : "")
        );
      }

      if (points.length % 4 !== 0) {
        throw new HttpsError(
          "failed-precondition",
          `Number of participants (${points.length}) must be a multiple of 4. ` +
          `Current count leaves ${points.length % 4} cohouse(s) unmatched.` +
          (removedCount > 0 ? ` (${removedCount} orphaned cohouse(s) were removed from cohouseIDs)` : "")
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
