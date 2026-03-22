import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, auth, REGION } from "./config";
import { parseRequest, requireAuth, setAdminClaimSchema } from "./schemas";

// ============================================
// Types
// ============================================

interface SetAdminClaimRequest {
  targetAuthUid: string;
  isAdmin?: boolean; // Legacy compat
  role?: "super_admin" | "edition_admin" | null;
}

// ============================================
// Cloud Functions
// ============================================

/**
 * Set or remove admin role on a Firebase Auth user.
 *
 * Supports two claim systems:
 * - Legacy: `{ admin: true }` (backward compat)
 * - New: `{ role: "super_admin" | "edition_admin" }`
 *
 * Only super admins can promote/demote others.
 * Bootstrap: first admin must have `isAdmin: true` in their Firestore user doc.
 */
export const setAdminClaim = onCall<SetAdminClaimRequest>(
  { region: REGION },
  async (request) => {
    requireAuth(request);
    const data = parseRequest(setAdminClaimSchema, request.data);
    const { targetAuthUid } = data;

    const callerUid = request.auth!.uid;
    const callerToken = request.auth!.token;
    const callerRole = callerToken.role as string | undefined;
    // Only super admins can manage roles — edition admins cannot promote/demote anyone
    const callerIsSuperAdmin = callerRole === "super_admin" || callerToken.admin === true;

    if (!callerIsSuperAdmin) {
      // Allow self-bootstrap only if the user's Firestore doc has isAdmin == true
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

      if (targetAuthUid !== callerUid) {
        throw new HttpsError(
          "permission-denied",
          "During bootstrap, you can only set your own admin claim."
        );
      }
    }

    // Determine the role to set
    const newRole = data.role !== undefined ? data.role : (data.isAdmin ? "super_admin" : null);

    try {
      const targetUser = await auth.getUser(targetAuthUid);
      const existingClaims = targetUser.customClaims || {};

      if (newRole) {
        await auth.setCustomUserClaims(targetAuthUid, {
          ...existingClaims,
          role: newRole,
          admin: true, // Legacy compat — keep `admin: true` so old rules still work during migration
        });
        console.log(`Role "${newRole}" set for Auth UID: ${targetAuthUid} (by: ${callerUid})`);
      } else {
        // Remove admin access
        const { role: _r, admin: _a, ...rest } = existingClaims;
        await auth.setCustomUserClaims(targetAuthUid, rest);
        console.log(`Admin access removed for Auth UID: ${targetAuthUid} (by: ${callerUid})`);
      }

      return {
        success: true,
        message: newRole
          ? `Role "${newRole}" granted to user ${targetAuthUid}`
          : `Admin access revoked from user ${targetAuthUid}`,
      };
    } catch (error) {
      console.error("Error setting admin claim:", error);
      throw new HttpsError("internal", "Failed to set admin claim");
    }
  }
);
