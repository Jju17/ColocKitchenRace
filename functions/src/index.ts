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
