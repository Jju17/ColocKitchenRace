import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Region configuration for Europe (Belgium)
const REGION = "europe-west1";

// ============================================
// Types
// ============================================

interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface SendToCohouseRequest {
  cohouseId: string;
  notification: NotificationPayload;
}

interface SendToEditionRequest {
  editionId: string;
  notification: NotificationPayload;
}

interface SendToAllRequest {
  notification: NotificationPayload;
}

// ============================================
// Helper Functions
// ============================================

/**
 * Get FCM tokens for users by their IDs
 */
async function getFCMTokensForUsers(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];

  const tokens: string[] = [];

  // Firestore 'in' query supports max 30 items, so we batch
  const batches = [];
  for (let i = 0; i < userIds.length; i += 30) {
    batches.push(userIds.slice(i, i + 30));
  }

  for (const batch of batches) {
    const snapshot = await db
      .collection("users")
      .where("id", "in", batch)
      .get();

    snapshot.docs.forEach((doc) => {
      const fcmToken = doc.data().fcmToken;
      if (fcmToken) {
        tokens.push(fcmToken);
      }
    });
  }

  return tokens;
}

/**
 * Send notifications to multiple tokens
 * Handles token batching (FCM limit: 500 per request)
 */
async function sendToTokens(
  tokens: string[],
  notification: NotificationPayload
): Promise<{ success: number; failure: number }> {
  if (tokens.length === 0) {
    return { success: 0, failure: 0 };
  }

  let success = 0;
  let failure = 0;

  // FCM supports max 500 tokens per multicast
  const batches = [];
  for (let i = 0; i < tokens.length; i += 500) {
    batches.push(tokens.slice(i, i + 500));
  }

  for (const batch of batches) {
    const message: admin.messaging.MulticastMessage = {
      tokens: batch,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data,
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    success += response.successCount;
    failure += response.failureCount;

    // Clean up invalid tokens
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error?.code === "messaging/invalid-registration-token") {
        // Could delete invalid token from Firestore here
        console.log(`Invalid token: ${batch[idx]}`);
      }
    });
  }

  return { success, failure };
}

// ============================================
// Cloud Functions
// ============================================

/**
 * Send notification to all members of a cohouse
 *
 * Usage from admin app or Firebase console:
 * sendNotificationToCohouse({ cohouseId: "xxx", notification: { title: "...", body: "..." } })
 */
export const sendNotificationToCohouse = onCall<SendToCohouseRequest>(
  { region: REGION },
  async (request) => {
    // Verify caller is authenticated (optional: add admin check)
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { cohouseId, notification } = request.data;

    if (!cohouseId || !notification?.title || !notification?.body) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      // Get cohouse users
      const cohouseUsersSnapshot = await db
        .collection("cohouses")
        .doc(cohouseId)
        .collection("users")
        .get();

      // Extract user IDs (users who have linked their account)
      const userIds = cohouseUsersSnapshot.docs
        .map((doc) => doc.data().userId)
        .filter((id): id is string => !!id);

      // Get FCM tokens
      const tokens = await getFCMTokensForUsers(userIds);

      // Send notifications
      const result = await sendToTokens(tokens, notification);

      console.log(`Sent to cohouse ${cohouseId}: ${result.success} success, ${result.failure} failure`);

      return {
        success: true,
        sent: result.success,
        failed: result.failure,
        totalUsers: userIds.length,
      };
    } catch (error) {
      console.error("Error sending to cohouse:", error);
      throw new HttpsError("internal", "Failed to send notifications");
    }
  }
);

/**
 * Send notification to all participants of a CKR edition
 *
 * Usage:
 * sendNotificationToEdition({ editionId: "xxx", notification: { title: "...", body: "..." } })
 */
export const sendNotificationToEdition = onCall<SendToEditionRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { editionId, notification } = request.data;

    if (!editionId || !notification?.title || !notification?.body) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      // Get edition to find participating cohouses
      const editionDoc = await db.collection("ckrGames").doc(editionId).get();

      if (!editionDoc.exists) {
        throw new HttpsError("not-found", "Edition not found");
      }

      const participantsIds: string[] = editionDoc.data()?.participantsID || [];

      if (participantsIds.length === 0) {
        return {
          success: true,
          sent: 0,
          failed: 0,
          message: "No participants in this edition",
        };
      }

      // Collect all user IDs from all participating cohouses
      const allUserIds: string[] = [];

      for (const cohouseId of participantsIds) {
        const cohouseUsersSnapshot = await db
          .collection("cohouses")
          .doc(cohouseId)
          .collection("users")
          .get();

        cohouseUsersSnapshot.docs.forEach((doc) => {
          const userId = doc.data().userId;
          if (userId && !allUserIds.includes(userId)) {
            allUserIds.push(userId);
          }
        });
      }

      // Get FCM tokens
      const tokens = await getFCMTokensForUsers(allUserIds);

      // Send notifications
      const result = await sendToTokens(tokens, notification);

      console.log(`Sent to edition ${editionId}: ${result.success} success, ${result.failure} failure`);

      return {
        success: true,
        sent: result.success,
        failed: result.failure,
        totalCohouses: participantsIds.length,
        totalUsers: allUserIds.length,
      };
    } catch (error) {
      console.error("Error sending to edition:", error);
      throw new HttpsError("internal", "Failed to send notifications");
    }
  }
);

/**
 * Send notification to ALL users via topic
 *
 * This uses FCM topics - all users are automatically subscribed to "all_users" topic
 *
 * Usage:
 * sendNotificationToAll({ notification: { title: "...", body: "..." } })
 */
export const sendNotificationToAll = onCall<SendToAllRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { notification } = request.data;

    if (!notification?.title || !notification?.body) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      const message: admin.messaging.Message = {
        topic: "all_users",
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data,
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const messageId = await messaging.send(message);

      console.log(`Sent to all users via topic, messageId: ${messageId}`);

      return {
        success: true,
        messageId,
      };
    } catch (error) {
      console.error("Error sending to all:", error);
      throw new HttpsError("internal", "Failed to send notification");
    }
  }
);

// ============================================
// Cohouse Validation Functions
// ============================================

interface CheckDuplicateRequest {
  name: string;
  street: string;
  city: string;
}

/**
 * Check if a cohouse with the same name or address already exists
 */
export const checkDuplicateCohouse = onCall<CheckDuplicateRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { name, street, city } = request.data;

    if (!name || !street || !city) {
      throw new HttpsError("invalid-argument", "Missing required fields: name, street, city");
    }

    try {
      const nameLower = name.trim().toLowerCase();
      const streetLower = street.trim().toLowerCase();
      const cityLower = city.trim().toLowerCase();

      // Check by name
      const nameSnapshot = await db
        .collection("cohouses")
        .where("nameLower", "==", nameLower)
        .limit(1)
        .get();

      if (!nameSnapshot.empty) {
        return { isDuplicate: true, reason: "name" };
      }

      // Check by address (street + city)
      // Uses the lowercased PostalAddress stored as addressLower
      const addressSnapshot = await db
        .collection("cohouses")
        .where("addressLower.street", "==", streetLower)
        .where("addressLower.city", "==", cityLower)
        .limit(1)
        .get();

      if (!addressSnapshot.empty) {
        return { isDuplicate: true, reason: "address" };
      }

      return { isDuplicate: false };
    } catch (error) {
      console.error("Error checking duplicate cohouse:", error);
      throw new HttpsError("internal", "Failed to check for duplicates");
    }
  }
);

interface ValidateAddressRequest {
  street: string;
  city: string;
  postalCode: string;
  country: string;
}

/**
 * Validate an address using Nominatim (OpenStreetMap) geocoding API
 */
export const validateAddress = onCall<ValidateAddressRequest>(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { street, city, postalCode, country } = request.data;

    if (!street || !city) {
      throw new HttpsError("invalid-argument", "Missing required fields: street, city");
    }

    try {
      const params = new URLSearchParams({
        format: "json",
        street: street,
        city: city,
        postalcode: postalCode || "",
        country: country || "",
        limit: "1",
        addressdetails: "1",
      });

      const url = `https://nominatim.openstreetmap.org/search?${params.toString()}`;

      const response = await fetch(url, {
        headers: {
          "User-Agent": "ColocKitchenRace/1.0",
          "Accept": "application/json",
        },
      });

      if (!response.ok) {
        throw new Error(`Nominatim returned status ${response.status}`);
      }

      const results = await response.json() as Array<{
        display_name?: string;
        lat?: string;
        lon?: string;
        address?: {
          road?: string;
          house_number?: string;
          city?: string;
          town?: string;
          village?: string;
          postcode?: string;
          country?: string;
        };
      }>;

      if (!results || results.length === 0) {
        return { isValid: false };
      }

      const result = results[0];
      const addr = result.address || {};

      const normalizedCity = addr.city || addr.town || addr.village || null;
      const normalizedStreet = addr.road
        ? (addr.house_number ? `${addr.road} ${addr.house_number}` : addr.road)
        : null;

      return {
        isValid: true,
        normalizedStreet: normalizedStreet,
        normalizedCity: normalizedCity,
        normalizedPostalCode: addr.postcode || null,
        normalizedCountry: addr.country || null,
        latitude: result.lat ? parseFloat(result.lat) : null,
        longitude: result.lon ? parseFloat(result.lon) : null,
      };
    } catch (error) {
      console.error("Error validating address:", error);
      throw new HttpsError("internal", "Failed to validate address");
    }
  }
);

// ============================================
// Cohouse Matching Algorithm
// ============================================

interface MatchCohousesRequest {
  gameId: string;
}

interface CohousePoint {
  id: string;
  latitude: number;
  longitude: number;
}

/**
 * Euclidean distance between two GPS points.
 * Uses a simple equirectangular approximation (valid for short distances like within Belgium).
 * Returns distance in km.
 */
function euclideanDistanceKm(
  lat1: number, lon1: number,
  lat2: number, lon2: number
): number {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const avgLat = (lat1 + lat2) / 2 * Math.PI / 180;
  const dx = dLon * Math.cos(avgLat) * R;
  const dy = dLat * R;
  return Math.sqrt(dx * dx + dy * dy);
}

/**
 * Compute cubic distance matrix for all pairs.
 * Key format: "i,j" where i < j (sorted indices).
 */
function computeCubicDistances(points: CohousePoint[]): Map<string, number> {
  const distances = new Map<string, number>();
  for (let i = 0; i < points.length; i++) {
    for (let j = i + 1; j < points.length; j++) {
      const d = euclideanDistanceKm(
        points[i].latitude, points[i].longitude,
        points[j].latitude, points[j].longitude
      );
      distances.set(`${i},${j}`, d * d * d); // cubic
    }
  }
  return distances;
}

/**
 * Get cubic distance between two point indices.
 */
function getCubicDist(dCubic: Map<string, number>, i: number, j: number): number {
  const key = i < j ? `${i},${j}` : `${j},${i}`;
  return dCubic.get(key) ?? Infinity;
}

/**
 * Greedy Minimum Weight Perfect Matching.
 * Sorts all edges by weight, greedily picks the lightest edge
 * whose both endpoints are still unmatched.
 * Returns pairs of node indices.
 */
function greedyMinWeightMatching(
  nodeCount: number,
  edges: Array<{ u: number; v: number; weight: number }>
): Array<[number, number]> {
  // Sort edges by weight ascending
  edges.sort((a, b) => a.weight - b.weight);

  const matched = new Set<number>();
  const pairs: Array<[number, number]> = [];

  for (const edge of edges) {
    if (matched.has(edge.u) || matched.has(edge.v)) continue;
    pairs.push([edge.u, edge.v]);
    matched.add(edge.u);
    matched.add(edge.v);
    if (pairs.length * 2 >= nodeCount) break;
  }

  return pairs;
}

/**
 * Double Perfect Matching Heuristic — adapted from coloc_matcher.py
 *
 * Phase 1: Match individual cohouses into optimal pairs via greedy MWPM.
 * Phase 2: Match pairs into groups of 4 via a second greedy MWPM.
 *
 * @param points - Array of cohouse points with GPS coordinates
 * @param dCubic - Precomputed cubic distance matrix
 * @returns Array of groups, each group is an array of 4 cohouse IDs
 */
function doubleMatchingHeuristic(
  points: CohousePoint[],
  dCubic: Map<string, number>
): string[][] {
  const N = points.length;

  // --- Phase 1: Match individual points into optimal pairs ---
  const edges1: Array<{ u: number; v: number; weight: number }> = [];
  for (let i = 0; i < N; i++) {
    for (let j = i + 1; j < N; j++) {
      edges1.push({ u: i, v: j, weight: getCubicDist(dCubic, i, j) });
    }
  }

  const pairs = greedyMinWeightMatching(N, edges1);
  console.log(`Phase 1: Found ${pairs.length} optimal pairs.`);

  // --- Phase 2: Match the pairs into optimal groups of 4 ---
  const numPairs = pairs.length;
  const edges2: Array<{ u: number; v: number; weight: number }> = [];

  for (let idx1 = 0; idx1 < numPairs; idx1++) {
    for (let idx2 = idx1 + 1; idx2 < numPairs; idx2++) {
      const pair1 = pairs[idx1];
      const pair2 = pairs[idx2];

      // Cost = max of 4 cross-distances (conservative estimate)
      const cost = Math.max(
        getCubicDist(dCubic, pair1[0], pair2[0]),
        getCubicDist(dCubic, pair1[0], pair2[1]),
        getCubicDist(dCubic, pair1[1], pair2[0]),
        getCubicDist(dCubic, pair1[1], pair2[1])
      );

      edges2.push({ u: idx1, v: idx2, weight: cost });
    }
  }

  const matchedPairs = greedyMinWeightMatching(numPairs, edges2);
  console.log(`Phase 2: Matched pairs into ${matchedPairs.length} groups of 4.`);

  // Reconstruct final groups using cohouse IDs
  const groups: string[][] = [];
  for (const [pairIdx1, pairIdx2] of matchedPairs) {
    const group = [
      points[pairs[pairIdx1][0]].id,
      points[pairs[pairIdx1][1]].id,
      points[pairs[pairIdx2][0]].id,
      points[pairs[pairIdx2][1]].id,
    ];
    groups.push(group);
  }

  return groups;
}

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
      const participantsIds: string[] = gameData?.participantsID || [];

      if (participantsIds.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "No cohouses registered for this game"
        );
      }

      if (participantsIds.length % 4 !== 0) {
        throw new HttpsError(
          "failed-precondition",
          `Number of participants (${participantsIds.length}) must be a multiple of 4. ` +
          `Current count leaves ${participantsIds.length % 4} cohouse(s) unmatched.`
        );
      }

      if (participantsIds.length < 4) {
        throw new HttpsError(
          "failed-precondition",
          "Need at least 4 cohouses to perform matching"
        );
      }

      // 2. Fetch GPS coordinates for all participating cohouses
      const points: CohousePoint[] = [];
      const missingCoords: string[] = [];

      // Batch Firestore reads (max 30 per 'in' query)
      const batches = [];
      for (let i = 0; i < participantsIds.length; i += 30) {
        batches.push(participantsIds.slice(i, i + 30));
      }

      for (const batch of batches) {
        const snapshot = await db
          .collection("cohouses")
          .where("id", "in", batch)
          .get();

        snapshot.docs.forEach((doc) => {
          const data = doc.data();
          const id = data.id as string;
          const lat = data.latitude as number | undefined;
          const lon = data.longitude as number | undefined;

          if (lat != null && lon != null) {
            points.push({ id, latitude: lat, longitude: lon });
          } else {
            missingCoords.push(data.name || id);
          }
        });
      }

      if (missingCoords.length > 0) {
        throw new HttpsError(
          "failed-precondition",
          `The following cohouses are missing GPS coordinates: ${missingCoords.join(", ")}. ` +
          "All cohouses must have valid coordinates for matching."
        );
      }

      if (points.length !== participantsIds.length) {
        const found = points.map((p) => p.id);
        const missing = participantsIds.filter((id) => !found.includes(id));
        throw new HttpsError(
          "not-found",
          `Could not find cohouse documents for IDs: ${missing.join(", ")}`
        );
      }

      console.log(`Starting matching for ${points.length} cohouses...`);

      // 3. Compute cubic distance matrix
      const dCubic = computeCubicDistances(points);

      // 4. Run double matching heuristic
      const groups = doubleMatchingHeuristic(points, dCubic);

      console.log(`Matching complete: ${groups.length} groups of 4 created.`);

      // 5. Store results back in Firestore on the game document
      await db.collection("ckrGames").doc(gameId).update({
        matchedGroups: groups,
        matchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        groupCount: groups.length,
        groups: groups,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error matching cohouses:", error);
      throw new HttpsError("internal", "Failed to match cohouses");
    }
  }
);

// ============================================
// Firestore Triggers
// ============================================

/**
 * Automatically send a notification to all users when a new news is created
 *
 * Triggered when a new document is added to the "news" collection
 */
export const onNewsCreated = onDocumentCreated(
  { document: "news/{newsId}", region: REGION },
  async (event) => {
    const newsData = event.data?.data();

    if (!newsData) {
      console.log("No news data found");
      return;
    }

    const title = newsData.title as string;
    const body = newsData.body as string;

    if (!title || !body) {
      console.log("News missing title or body");
      return;
    }

    try {
      const message: admin.messaging.Message = {
        topic: "all_users",
        notification: {
          title: `📰 ${title}`,
          body: body.length > 100 ? body.substring(0, 100) + "..." : body,
        },
        data: {
          type: "news",
          newsId: event.params.newsId,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const messageId = await messaging.send(message);
      console.log(`News notification sent, messageId: ${messageId}, newsId: ${event.params.newsId}`);
    } catch (error) {
      console.error("Error sending news notification:", error);
    }
  }
);
