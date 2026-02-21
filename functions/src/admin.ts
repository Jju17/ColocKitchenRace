import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, auth, REGION } from "./config";

// ============================================
// Types
// ============================================

interface SetAdminClaimRequest {
  targetAuthUid: string;
  isAdmin: boolean;
}

// ============================================
// Cloud Functions
// ============================================

/**
 * Set or remove the "admin" custom claim on a Firebase Auth user.
 *
 * This is required for Firestore security rules to check admin status
 * via `request.auth.token.admin == true`.
 *
 * Can only be called by an existing admin. To bootstrap the very first admin,
 * use the CLI script:
 *   cd functions
 *   npm run set-admin -- --uid YOUR_AUTH_UID
 */
export const setAdminClaim = onCall<SetAdminClaimRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const callerUid = request.auth.uid;
    const { targetAuthUid, isAdmin } = request.data;

    if (!targetAuthUid || typeof isAdmin !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: targetAuthUid (string), isAdmin (boolean)"
      );
    }

    // Verify the caller is already an admin (or is the target — for bootstrap)
    const callerToken = request.auth.token;
    const callerIsAdmin = callerToken.admin === true;

    if (!callerIsAdmin) {
      // Allow self-bootstrap only if the user's Firestore doc has isAdmin == true
      // This enables the first admin to set their own custom claim
      const userSnapshot = await db
        .collection("users")
        .where("authId", "==", callerUid)
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        throw new HttpsError("permission-denied", "User not found");
      }

      const userData = userSnapshot.docs[0].data();
      if (userData.isAdmin !== true) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can set admin claims"
        );
      }

      // First-time bootstrap: caller has isAdmin in Firestore but not yet in Auth token
      // Only allow them to set their own claim
      if (targetAuthUid !== callerUid) {
        throw new HttpsError(
          "permission-denied",
          "During bootstrap, you can only set your own admin claim. " +
          "Call this function with your own Auth UID first, then you can promote others."
        );
      }
    }

    try {
      // Set the custom claim
      await auth.setCustomUserClaims(targetAuthUid, { admin: isAdmin });

      console.log(
        `Admin claim ${isAdmin ? "set" : "removed"} for Auth UID: ${targetAuthUid} (by: ${callerUid})`
      );

      return {
        success: true,
        message: `Admin claim ${isAdmin ? "granted to" : "revoked from"} user ${targetAuthUid}`,
      };
    } catch (error) {
      console.error("Error setting admin claim:", error);
      throw new HttpsError("internal", "Failed to set admin claim");
    }
  }
);
