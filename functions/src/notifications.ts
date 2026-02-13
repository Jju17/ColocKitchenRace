import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, messaging, REGION } from "./config";

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

interface NotificationHistoryEntry {
  target: "all" | "cohouse" | "edition";
  targetId?: string;
  title: string;
  body: string;
  sent: number;
  failed: number;
  message?: string;
  sentBy: string;
  sentAt: FirebaseFirestore.FieldValue;
}

// ============================================
// Shared Helpers (exported for use by planning.ts)
// ============================================

/**
 * Get FCM tokens for users by their IDs
 */
export async function getFCMTokensForUsers(userIds: string[]): Promise<string[]> {
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
      .where(admin.firestore.FieldPath.documentId(), "in", batch)
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
export async function sendToTokens(
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
// Notification History
// ============================================

/**
 * Save a notification to the history collection for audit/tracking
 */
async function saveNotificationHistory(entry: NotificationHistoryEntry): Promise<void> {
  try {
    await db.collection("notificationHistory").add(entry);
  } catch (error) {
    // Don't fail the notification if history save fails
    console.error("Failed to save notification history:", error);
  }
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

      console.log(`Sent to cohouse ${cohouseId}: ${result.success} success, ${result.failure} failure (${userIds.length} users, ${tokens.length} tokens)`);

      const noUsers = cohouseUsersSnapshot.empty;
      const noTokens = tokens.length === 0;
      const message = noUsers
        ? "No users found in this cohouse"
        : noTokens
          ? `${userIds.length} user(s) found but none have push notifications enabled`
          : result.failure > 0
            ? `${result.failure} delivery failure(s) out of ${tokens.length} token(s)`
            : undefined;

      await saveNotificationHistory({
        target: "cohouse",
        targetId: cohouseId,
        title: notification.title,
        body: notification.body,
        sent: result.success,
        failed: result.failure,
        ...(message && { message }),
        sentBy: request.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: !noUsers && !noTokens && result.failure === 0,
        sent: result.success,
        failed: result.failure,
        totalUsers: userIds.length,
        message: message ?? null,
      };
    } catch (error) {
      console.error("Error sending to cohouse:", error);
      throw new HttpsError("internal", `Failed to send notifications: ${error}`);
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

      const cohouseIDs: string[] = editionDoc.data()?.cohouseIDs || [];

      if (cohouseIDs.length === 0) {
        const message = "No participants in this edition";
        await saveNotificationHistory({
          target: "edition",
          targetId: editionId,
          title: notification.title,
          body: notification.body,
          sent: 0,
          failed: 0,
          message,
          sentBy: request.auth.uid,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: false, sent: 0, failed: 0, message };
      }

      // Collect all user IDs from all participating cohouses
      const allUserIds: string[] = [];

      for (const cohouseId of cohouseIDs) {
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

      const noTokens = tokens.length === 0;
      const message = noTokens
        ? `${allUserIds.length} user(s) found but none have push notifications enabled`
        : result.failure > 0
          ? `${result.failure} delivery failure(s) out of ${tokens.length} token(s)`
          : undefined;

      await saveNotificationHistory({
        target: "edition",
        targetId: editionId,
        title: notification.title,
        body: notification.body,
        sent: result.success,
        failed: result.failure,
        ...(message && { message }),
        sentBy: request.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: !noTokens && result.failure === 0,
        sent: result.success,
        failed: result.failure,
        totalCohouses: cohouseIDs.length,
        totalUsers: allUserIds.length,
        message: message ?? null,
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

      await saveNotificationHistory({
        target: "all",
        title: notification.title,
        body: notification.body,
        sent: 0,  // Topic-based, exact count unknown
        failed: 0,
        sentBy: request.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

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
