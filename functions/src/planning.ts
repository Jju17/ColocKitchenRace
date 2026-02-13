import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, REGION } from "./config";
import { getFCMTokensForUsers, sendToTokens } from "./notifications";

// ============================================
// Types
// ============================================

interface UpdateEventSettingsRequest {
  gameId: string;
  aperoStartTime: string;   // ISO 8601
  aperoEndTime: string;
  dinerStartTime: string;
  dinerEndTime: string;
  partyStartTime: string;
  partyEndTime: string;
  partyAddress: string;
  partyName: string;
  partyNote?: string;
}

interface ConfirmMatchingRequest {
  gameId: string;
}

interface RevealPlanningRequest {
  gameId: string;
}

interface GetMyPlanningRequest {
  gameId: string;
  cohouseId: string;
}

// ============================================
// Cloud Functions
// ============================================

/**
 * Save event settings (time slots + party info) on a CKR game.
 * Called by the admin before confirming the matching.
 */
export const updateEventSettings = onCall<UpdateEventSettingsRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const {
      gameId,
      aperoStartTime, aperoEndTime,
      dinerStartTime, dinerEndTime,
      partyStartTime, partyEndTime,
      partyAddress, partyName, partyNote,
    } = request.data;

    if (!gameId || !aperoStartTime || !aperoEndTime ||
        !dinerStartTime || !dinerEndTime ||
        !partyStartTime || !partyEndTime ||
        !partyAddress || !partyName) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const eventSettings = {
        aperoStartTime: new Date(aperoStartTime),
        aperoEndTime: new Date(aperoEndTime),
        dinerStartTime: new Date(dinerStartTime),
        dinerEndTime: new Date(dinerEndTime),
        partyStartTime: new Date(partyStartTime),
        partyEndTime: new Date(partyEndTime),
        partyAddress,
        partyName,
        ...(partyNote ? { partyNote } : {}),
      };

      await db.collection("ckrGames").doc(gameId).update({ eventSettings });

      console.log(`Event settings saved for game ${gameId}`);
      return { success: true };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error updating event settings:", error);
      throw new HttpsError("internal", "Failed to update event settings");
    }
  }
);

/**
 * Confirm the matching by assigning A/B/C/D roles within each group.
 *
 * For each matched group of 4:
 *   - Shuffles the cohouse IDs randomly
 *   - Assigns them as A, B, C, D
 *
 * Schema:
 *   Apero: A->B (A cooks at B), C->D (C cooks at D)
 *   Diner: C->A (C cooks at A), D->B (D cooks at B)
 *
 * Requires: matchedGroups and eventSettings to be set.
 */
export const confirmMatching = onCall<ConfirmMatchingRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId } = request.data;

    if (!gameId) {
      throw new HttpsError("invalid-argument", "Missing required field: gameId");
    }

    try {
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data()!;

      if (!gameData.matchedGroups || gameData.matchedGroups.length === 0) {
        throw new HttpsError("failed-precondition", "No matched groups found. Run matching first.");
      }

      if (!gameData.eventSettings) {
        throw new HttpsError("failed-precondition", "Event settings must be configured before confirming.");
      }

      const matchedGroups = gameData.matchedGroups as Array<{ cohouseIds: string[] }>;

      // Fisher-Yates shuffle
      function shuffle<T>(array: T[]): T[] {
        const arr = [...array];
        for (let i = arr.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [arr[i], arr[j]] = [arr[j], arr[i]];
        }
        return arr;
      }

      const groupPlannings = matchedGroups.map((group, index) => {
        const shuffled = shuffle(group.cohouseIds);
        return {
          id: `group-${index + 1}`,
          groupIndex: index + 1,
          cohouseA: shuffled[0],
          cohouseB: shuffled[1],
          cohouseC: shuffled[2],
          cohouseD: shuffled[3],
        };
      });

      await db.collection("ckrGames").doc(gameId).update({
        groupPlannings,
      });

      console.log(`Confirmed matching for game ${gameId}: ${groupPlannings.length} groups with roles assigned`);

      return {
        success: true,
        groupCount: groupPlannings.length,
        groupPlannings,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error confirming matching:", error);
      throw new HttpsError("internal", "Failed to confirm matching");
    }
  }
);

/**
 * Reveal the planning to all participants.
 * Sets isRevealed=true and sends a push notification.
 */
export const revealPlanning = onCall<RevealPlanningRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId } = request.data;

    if (!gameId) {
      throw new HttpsError("invalid-argument", "Missing required field: gameId");
    }

    try {
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data()!;

      if (!gameData.groupPlannings || gameData.groupPlannings.length === 0) {
        throw new HttpsError("failed-precondition", "Matching must be confirmed before revealing.");
      }

      await db.collection("ckrGames").doc(gameId).update({
        isRevealed: true,
        revealedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Send push notification to all registered cohouses
      const cohouseIDs: string[] = gameData.cohouseIDs || [];
      if (cohouseIDs.length > 0) {
        const allUserIds: string[] = [];

        for (const cohouseId of cohouseIDs) {
          const cohouseSnapshot = await db
            .collection("cohouses")
            .where("id", "==", cohouseId)
            .limit(1)
            .get();

          if (cohouseSnapshot.empty) continue;

          const usersSnapshot = await db
            .collection("cohouses")
            .doc(cohouseSnapshot.docs[0].id)
            .collection("users")
            .get();

          usersSnapshot.docs.forEach((doc) => {
            const userId = doc.data().userId;
            if (userId && !allUserIds.includes(userId)) {
              allUserIds.push(userId);
            }
          });
        }

        const tokens = await getFCMTokensForUsers(allUserIds);
        if (tokens.length > 0) {
          await sendToTokens(tokens, {
            title: "🎉 Votre planning CKR est disponible !",
            body: "Découvrez chez qui vous allez cuisiner ce soir !",
          });
        }
      }

      console.log(`Planning revealed for game ${gameId}`);
      return { success: true };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error revealing planning:", error);
      throw new HttpsError("internal", "Failed to reveal planning");
    }
  }
);

/**
 * Get the personalized CKR evening planning for a specific cohouse.
 *
 * Returns apero, diner, and party info including:
 * - Where to go (address), host/visitor role
 * - Contact phones (host cohouse admin)
 * - Total people count and dietary summary
 */
export const getMyPlanning = onCall<GetMyPlanningRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { gameId, cohouseId } = request.data;

    if (!gameId || !cohouseId) {
      throw new HttpsError("invalid-argument", "Missing required fields: gameId, cohouseId");
    }

    try {
      const gameDoc = await db.collection("ckrGames").doc(gameId).get();
      if (!gameDoc.exists) {
        throw new HttpsError("not-found", "CKR Game not found");
      }

      const gameData = gameDoc.data()!;

      if (!gameData.isRevealed) {
        throw new HttpsError("failed-precondition", "Planning has not been revealed yet");
      }

      if (!gameData.groupPlannings || !gameData.eventSettings) {
        throw new HttpsError("failed-precondition", "Planning data is incomplete");
      }

      const eventSettings = gameData.eventSettings;
      const groupPlannings = gameData.groupPlannings as Array<{
        groupIndex: number;
        cohouseA: string;
        cohouseB: string;
        cohouseC: string;
        cohouseD: string;
      }>;

      // Find the group containing this cohouse
      const myGroup = groupPlannings.find(
        (g) => g.cohouseA === cohouseId || g.cohouseB === cohouseId ||
               g.cohouseC === cohouseId || g.cohouseD === cohouseId
      );

      if (!myGroup) {
        throw new HttpsError("not-found", "Your cohouse is not in any group");
      }

      // Determine our role (A/B/C/D)
      let myRole: "A" | "B" | "C" | "D";
      if (myGroup.cohouseA === cohouseId) myRole = "A";
      else if (myGroup.cohouseB === cohouseId) myRole = "B";
      else if (myGroup.cohouseC === cohouseId) myRole = "C";
      else myRole = "D";

      // Derive apero and diner assignments based on the schema:
      // Apero: A->B, C->D  |  Diner: C->A, D->B
      let aperoPartnerCohouseId: string;
      let aperoRole: "host" | "visitor";
      let dinerPartnerCohouseId: string;
      let dinerRole: "host" | "visitor";

      switch (myRole) {
        case "A": // Goes to B for apero, hosts C for diner
          aperoPartnerCohouseId = myGroup.cohouseB;
          aperoRole = "visitor";
          dinerPartnerCohouseId = myGroup.cohouseC;
          dinerRole = "host";
          break;
        case "B": // Hosts A for apero, hosts D for diner
          aperoPartnerCohouseId = myGroup.cohouseA;
          aperoRole = "host";
          dinerPartnerCohouseId = myGroup.cohouseD;
          dinerRole = "host";
          break;
        case "C": // Goes to D for apero, goes to A for diner
          aperoPartnerCohouseId = myGroup.cohouseD;
          aperoRole = "visitor";
          dinerPartnerCohouseId = myGroup.cohouseA;
          dinerRole = "visitor";
          break;
        case "D": // Hosts C for apero, goes to B for diner
          aperoPartnerCohouseId = myGroup.cohouseC;
          aperoRole = "host";
          dinerPartnerCohouseId = myGroup.cohouseB;
          dinerRole = "visitor";
          break;
      }

      // Helper: fetch cohouse data (name, address, admin phone)
      async function getCohouseInfo(cId: string) {
        const snapshot = await db
          .collection("cohouses")
          .where("id", "==", cId)
          .limit(1)
          .get();

        if (snapshot.empty) {
          return { name: "Unknown", address: "", phone: null, docId: "" };
        }

        const doc = snapshot.docs[0];
        const data = doc.data();
        const address = data.address || {};
        const fullAddress = [address.street, address.postalCode, address.city]
          .filter(Boolean)
          .join(", ");

        // Get admin user's phone
        const usersSnapshot = await db
          .collection("cohouses")
          .doc(doc.id)
          .collection("users")
          .where("isAdmin", "==", true)
          .limit(1)
          .get();

        let phone: string | null = null;
        if (!usersSnapshot.empty) {
          const adminUserId = usersSnapshot.docs[0].data().userId;
          if (adminUserId) {
            const userSnapshot = await db
              .collection("users")
              .where("id", "==", adminUserId)
              .limit(1)
              .get();
            if (!userSnapshot.empty) {
              phone = userSnapshot.docs[0].data().phoneNumber || null;
            }
          }
        }

        return {
          name: (data.name as string) || "Unknown",
          address: fullAddress,
          phone,
          docId: doc.id,
        };
      }

      // Helper: get attending user IDs from registration
      async function getAttendingUserIds(cId: string): Promise<string[]> {
        const regDoc = await db
          .collection("ckrGames")
          .doc(gameId)
          .collection("registrations")
          .doc(cId)
          .get();

        if (!regDoc.exists) return [];
        return (regDoc.data()?.attendingUserIds as string[]) || [];
      }

      // Helper: fetch dietary preferences for a list of user IDs
      async function getDietarySummary(userIds: string[]): Promise<Record<string, number>> {
        const summary: Record<string, number> = {};
        if (userIds.length === 0) return summary;

        // Batch fetch users (max 30 per 'in' query)
        const batches = [];
        for (let i = 0; i < userIds.length; i += 30) {
          batches.push(userIds.slice(i, i + 30));
        }

        for (const batch of batches) {
          const snapshot = await db
            .collection("users")
            .where("id", "in", batch)
            .get();

          for (const doc of snapshot.docs) {
            const prefs = doc.data().dietaryPreferences as string[] | undefined;
            if (prefs && Array.isArray(prefs)) {
              for (const pref of prefs) {
                const displayName = dietaryDisplayName(pref);
                summary[displayName] = (summary[displayName] || 0) + 1;
              }
            }
          }
        }

        return summary;
      }

      function dietaryDisplayName(raw: string): string {
        switch (raw) {
          case "vegetarian": return "Vegetarien";
          case "vegan": return "Vegan";
          case "gluten_free": return "Sans gluten";
          case "lactose_free": return "Sans lactose";
          case "nut_free": return "Sans noix";
          default: return raw;
        }
      }

      // Fetch all data in parallel
      const [myInfo, aperoPartnerInfo, dinerPartnerInfo] = await Promise.all([
        getCohouseInfo(cohouseId),
        getCohouseInfo(aperoPartnerCohouseId),
        getCohouseInfo(dinerPartnerCohouseId),
      ]);

      const [myUserIds, aperoPartnerUserIds, dinerPartnerUserIds] = await Promise.all([
        getAttendingUserIds(cohouseId),
        getAttendingUserIds(aperoPartnerCohouseId),
        getAttendingUserIds(dinerPartnerCohouseId),
      ]);

      // Apero: both our cohouse + partner are present
      const aperoAllUserIds = [...myUserIds, ...aperoPartnerUserIds];
      const aperoDietarySummary = await getDietarySummary(aperoAllUserIds);

      // Diner: both our cohouse + partner are present
      const dinerAllUserIds = [...myUserIds, ...dinerPartnerUserIds];
      const dinerDietarySummary = await getDietarySummary(dinerAllUserIds);

      // Determine addresses and contacts based on role
      const aperoAddress = aperoRole === "host" ? myInfo.address : aperoPartnerInfo.address;
      const aperoHostPhone = aperoRole === "host" ? myInfo.phone : aperoPartnerInfo.phone;
      const aperoVisitorPhone = aperoRole === "host" ? aperoPartnerInfo.phone : myInfo.phone;

      const dinerAddress = dinerRole === "host" ? myInfo.address : dinerPartnerInfo.address;
      const dinerHostPhone = dinerRole === "host" ? myInfo.phone : dinerPartnerInfo.phone;
      const dinerVisitorPhone = dinerRole === "host" ? dinerPartnerInfo.phone : myInfo.phone;

      // Convert Firestore Timestamps to ISO strings
      function toISO(val: unknown): string {
        if (val instanceof admin.firestore.Timestamp) {
          return val.toDate().toISOString();
        }
        if (val instanceof Date) {
          return val.toISOString();
        }
        return String(val);
      }

      return {
        success: true,
        planning: {
          apero: {
            role: aperoRole,
            cohouseName: aperoPartnerInfo.name,
            address: aperoAddress,
            hostPhone: aperoHostPhone,
            visitorPhone: aperoVisitorPhone,
            totalPeople: aperoAllUserIds.length,
            dietarySummary: aperoDietarySummary,
            startTime: toISO(eventSettings.aperoStartTime),
            endTime: toISO(eventSettings.aperoEndTime),
          },
          diner: {
            role: dinerRole,
            cohouseName: dinerPartnerInfo.name,
            address: dinerAddress,
            hostPhone: dinerHostPhone,
            visitorPhone: dinerVisitorPhone,
            totalPeople: dinerAllUserIds.length,
            dietarySummary: dinerDietarySummary,
            startTime: toISO(eventSettings.dinerStartTime),
            endTime: toISO(eventSettings.dinerEndTime),
          },
          party: {
            name: eventSettings.partyName,
            address: eventSettings.partyAddress,
            startTime: toISO(eventSettings.partyStartTime),
            endTime: toISO(eventSettings.partyEndTime),
            note: eventSettings.partyNote || null,
          },
        },
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error getting planning:", error);
      throw new HttpsError("internal", "Failed to get planning");
    }
  }
);
