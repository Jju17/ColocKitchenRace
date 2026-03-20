import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db, messaging, REGION } from "./config";

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

/**
 * Automatically send a notification to all users when a new challenge is created
 *
 * Triggered when a new document is added to the "challenges" collection
 */
export const onChallengeCreated = onDocumentCreated(
  { document: "challenges/{challengeId}", region: REGION },
  async (event) => {
    const challengeData = event.data?.data();

    if (!challengeData) {
      console.log("No challenge data found");
      return;
    }

    const title = challengeData.title as string;
    const body = challengeData.body as string;

    if (!title) {
      console.log("Challenge missing title");
      return;
    }

    try {
      const message: admin.messaging.Message = {
        topic: "all_users",
        notification: {
          title: `🏆 Nouveau challenge : ${title}`,
          body: body
            ? body.length > 100
              ? body.substring(0, 100) + "..."
              : body
            : "Un nouveau challenge est disponible !",
        },
        data: {
          type: "challenge",
          challengeId: event.params.challengeId,
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
      console.log(
        `Challenge notification sent, messageId: ${messageId}, challengeId: ${event.params.challengeId}`
      );
    } catch (error) {
      console.error("Error sending challenge notification:", error);
    }
  }
);

/**
 * Scheduled function that checks for challenge start/end events every 5 minutes.
 *
 * Sends notifications when:
 * - A challenge has just started (startDate within the last 5 minutes)
 * - A challenge will end in ~30 minutes (endDate between now+25min and now+30min)
 *
 * Uses marker documents in challenges/{id}/notifications/{type} to prevent duplicates.
 */
export const checkChallengeSchedules = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Europe/Brussels",
    region: REGION,
  },
  async () => {
    const now = new Date();
    const fiveMinAgo = new Date(now.getTime() - 5 * 60 * 1000);
    // Widened from 5 minutes to 15 minutes to tolerate scheduler jitter.
    // The deduplication marker prevents double-sends.
    const twentyMinFromNow = new Date(now.getTime() + 20 * 60 * 1000);
    const thirtyFiveMinFromNow = new Date(now.getTime() + 35 * 60 * 1000);

    try {
      // 1. Check for challenges that just started
      const startedSnapshot = await db
        .collection("challenges")
        .where("startDate", ">=", fiveMinAgo)
        .where("startDate", "<=", now)
        .get();

      for (const doc of startedSnapshot.docs) {
        try {
          const challengeId = doc.id;
          const data = doc.data();
          const title = data.title as string;

          // Null-safe endDate: use fallback string if endDate is missing
          const endDateRaw = data.endDate as admin.firestore.Timestamp | undefined;
          const endDateStr = endDateRaw
            ? endDateRaw.toDate().toLocaleString("fr-BE", {
                day: "numeric",
                month: "short",
                hour: "2-digit",
                minute: "2-digit",
              })
            : "la date limite";

          // Deduplicate using transaction: create() fails if doc already exists
          const markerRef = db
            .collection("challenges")
            .doc(challengeId)
            .collection("notifications")
            .doc("started");

          let alreadySent = false;
          try {
            await db.runTransaction(async (transaction) => {
              const marker = await transaction.get(markerRef);
              if (marker.exists) {
                alreadySent = true;
                return;
              }
              transaction.create(markerRef, { sentAt: admin.firestore.FieldValue.serverTimestamp() });
            });
          } catch (error) {
            // create() throws if doc was created by a concurrent invocation
            console.log(`Marker already exists for challenge started: ${challengeId}, skipping`);
            continue;
          }
          if (alreadySent) continue;

          // Send notification
          const message: admin.messaging.Message = {
            topic: "all_users",
            notification: {
              title: `🟢 ${title} a commence !`,
              body: `Vous avez jusqu'au ${endDateStr} pour le completer.`,
            },
            data: {
              type: "challenge_started",
              challengeId: challengeId,
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

          await messaging.send(message);
          console.log(`Challenge started notification sent for: ${title} (${challengeId})`);
        } catch (docError) {
          console.error(`Error processing started challenge ${doc.id}:`, docError);
        }
      }

      // 2. Check for challenges ending in ~30 minutes
      const endingSoonSnapshot = await db
        .collection("challenges")
        .where("endDate", ">=", twentyMinFromNow)
        .where("endDate", "<=", thirtyFiveMinFromNow)
        .get();

      for (const doc of endingSoonSnapshot.docs) {
        try {
          const challengeId = doc.id;
          const data = doc.data();
          const title = data.title as string;

          // Deduplicate using transaction: create() fails if doc already exists
          const markerRef = db
            .collection("challenges")
            .doc(challengeId)
            .collection("notifications")
            .doc("ending_soon");

          let alreadySent = false;
          try {
            await db.runTransaction(async (transaction) => {
              const marker = await transaction.get(markerRef);
              if (marker.exists) {
                alreadySent = true;
                return;
              }
              transaction.create(markerRef, { sentAt: admin.firestore.FieldValue.serverTimestamp() });
            });
          } catch (error) {
            // create() throws if doc was created by a concurrent invocation
            console.log(`Marker already exists for challenge ending_soon: ${challengeId}, skipping`);
            continue;
          }
          if (alreadySent) continue;

          // Send notification
          const message: admin.messaging.Message = {
            topic: "all_users",
            notification: {
              title: `⏰ ${title} se termine dans 30 minutes !`,
              body: "Depecchez-vous de soumettre votre reponse !",
            },
            data: {
              type: "challenge_ending_soon",
              challengeId: challengeId,
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

          await messaging.send(message);
          console.log(`Challenge ending soon notification sent for: ${title} (${challengeId})`);
        } catch (docError) {
          console.error(`Error processing ending_soon challenge ${doc.id}:`, docError);
        }
      }
    } catch (error) {
      console.error("Error in checkChallengeSchedules:", error);
    }
  }
);
