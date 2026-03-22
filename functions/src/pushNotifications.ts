import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { getFunctions } from "firebase-admin/functions";
import { admin, db, messaging, REGION, getFCMTopicAllUsers } from "./config";
import { getFCMTokensForUsers, sendToTokens } from "./notifications";

// ============================================
// Types
// ============================================

interface GroupPlanningData {
  groupIndex: number;
  cohouseA: string;
  cohouseB: string;
  cohouseC: string;
  cohouseD: string;
}

interface GameReminderData {
  gameId: string;
}

interface EventReminderData {
  gameId: string;
}

// Max Cloud Tasks schedule: 30 days in seconds
const MAX_DELAY_SECONDS = 30 * 24 * 60 * 60;

// ============================================
// Helpers
// ============================================

function toDate(val: unknown): Date {
  if (val instanceof admin.firestore.Timestamp) {
    return val.toDate();
  }
  if (val instanceof Date) {
    return val;
  }
  return new Date(val as string);
}

/**
 * Schedule a Cloud Task at an absolute time.
 * Returns false if the time is in the past or too far in the future.
 */
export async function scheduleTaskAt(
  queueName: string,
  data: Record<string, string>,
  targetDate: Date
): Promise<boolean> {
  const delaySeconds = Math.floor(
    (targetDate.getTime() - Date.now()) / 1000
  );

  if (delaySeconds <= 0) {
    console.log(
      `Skipping ${queueName}: target time is in the past (${targetDate.toISOString()})`
    );
    return false;
  }

  if (delaySeconds > MAX_DELAY_SECONDS) {
    console.log(
      `Skipping ${queueName}: target time is more than 30 days away (${targetDate.toISOString()})`
    );
    return false;
  }

  const queue = getFunctions().taskQueue(queueName);
  await queue.enqueue(data, { scheduleDelaySeconds: delaySeconds });
  console.log(
    `Scheduled ${queueName} for ${targetDate.toISOString()} (in ${delaySeconds}s)`
  );
  return true;
}

async function getUserIdsFromCohouses(
  cohouseIDs: string[]
): Promise<string[]> {
  const allUserIds: string[] = [];

  for (const cohouseId of cohouseIDs) {
    const usersSnapshot = await db
      .collection("cohouses")
      .doc(cohouseId)
      .collection("users")
      .get();

    usersSnapshot.docs.forEach((doc) => {
      const userId = doc.data().userId as string | undefined;
      if (userId && !allUserIds.includes(userId)) {
        allUserIds.push(userId);
      }
    });
  }

  return allUserIds;
}

async function getUserIdsForCohouse(cohouseId: string): Promise<string[]> {
  const usersSnapshot = await db
    .collection("cohouses")
    .doc(cohouseId)
    .collection("users")
    .get();

  return usersSnapshot.docs
    .map((doc) => doc.data().userId as string)
    .filter((id) => !!id);
}

/**
 * Send personalized host/visitor reminders for apéro or dîner.
 *
 * Role schema:
 *   Apéro: A→B (A visits B, B hosts), C→D (C visits D, D hosts)
 *   Dîner: C→A (C visits A, A hosts), D→B (D visits B, B hosts)
 */
async function sendStepReminders(
  gameId: string,
  groupPlannings: GroupPlanningData[],
  step: "apero" | "diner"
): Promise<void> {
  // Batch-fetch all cohouse names
  const allCohouseIds = new Set<string>();
  for (const group of groupPlannings) {
    allCohouseIds.add(group.cohouseA);
    allCohouseIds.add(group.cohouseB);
    allCohouseIds.add(group.cohouseC);
    allCohouseIds.add(group.cohouseD);
  }

  const cohouseNames: Record<string, string> = {};
  const idArray = Array.from(allCohouseIds);
  for (let i = 0; i < idArray.length; i += 30) {
    const batch = idArray.slice(i, i + 30);
    const snapshot = await db
      .collection("cohouses")
      .where("id", "in", batch)
      .get();

    snapshot.docs.forEach((doc) => {
      const data = doc.data();
      cohouseNames[data.id as string] = (data.name as string) || "une coloc";
    });
  }

  const stepLabel = step === "apero" ? "l'apéro" : "le dîner";
  const stepTitle = step === "apero" ? "L'apéro" : "Le dîner";
  const stepGreeting = step === "apero" ? "Bon apéro !" : "Bon appétit !";

  // Collect all host/visitor pairs across all groups
  const allPairs: Array<{
    hostCohouseId: string;
    visitorCohouseId: string;
  }> = [];

  for (const group of groupPlannings) {
    if (step === "apero") {
      allPairs.push(
        { hostCohouseId: group.cohouseB, visitorCohouseId: group.cohouseA },
        { hostCohouseId: group.cohouseD, visitorCohouseId: group.cohouseC },
      );
    } else {
      allPairs.push(
        { hostCohouseId: group.cohouseA, visitorCohouseId: group.cohouseC },
        { hostCohouseId: group.cohouseB, visitorCohouseId: group.cohouseD },
      );
    }
  }

  // Fetch all user IDs in parallel across all pairs
  const allCohouseIdsForUsers = new Set<string>();
  for (const pair of allPairs) {
    allCohouseIdsForUsers.add(pair.hostCohouseId);
    allCohouseIdsForUsers.add(pair.visitorCohouseId);
  }

  const userIdsByCohouseEntries = await Promise.all(
    Array.from(allCohouseIdsForUsers).map(async (cohouseId) => {
      const userIds = await getUserIdsForCohouse(cohouseId);
      return [cohouseId, userIds] as const;
    })
  );
  const userIdsByCohouse = new Map(userIdsByCohouseEntries);

  // Fetch FCM tokens per cohouse in parallel
  const tokensByCohouse = new Map<string, string[]>();
  await Promise.all(
    Array.from(userIdsByCohouse.entries()).map(async ([cohouseId, userIds]) => {
      const tokens = await getFCMTokensForUsers(userIds);
      tokensByCohouse.set(cohouseId, tokens);
    })
  );

  // Send all notifications in parallel
  await Promise.all(
    allPairs.map(async (pair) => {
      const hostName = cohouseNames[pair.hostCohouseId] || "une coloc";
      const visitorName = cohouseNames[pair.visitorCohouseId] || "une coloc";

      const hostTokens = tokensByCohouse.get(pair.hostCohouseId) || [];
      const visitorTokens = tokensByCohouse.get(pair.visitorCohouseId) || [];

      const promises: Promise<unknown>[] = [];

      if (hostTokens.length > 0) {
        promises.push(
          sendToTokens(hostTokens, {
            title: `${stepTitle} commence dans 15 min !`,
            body: `Vous recevez ${visitorName} chez vous. ${stepGreeting}`,
            data: { type: `${step}_reminder`, gameId, role: "host" },
          })
        );
      }

      if (visitorTokens.length > 0) {
        promises.push(
          sendToTokens(visitorTokens, {
            title: `${stepTitle} commence dans 15 min !`,
            body: `Direction chez ${hostName} pour ${stepLabel} !`,
            data: { type: `${step}_reminder`, gameId, role: "visitor" },
          })
        );
      }

      await Promise.all(promises);
    })
  );

  console.log(
    `${step} reminders sent for game ${gameId} (${groupPlannings.length} groups)`
  );
}

// ============================================
// Firestore Trigger
// ============================================

/**
 * Notify all users when a new CKR game is created (registrations open).
 * Also schedules game-start reminder tasks (24h + 1h before).
 */
export const onCKRGameCreated = onDocumentCreated(
  { document: "ckrGames/{gameId}", region: REGION },
  async (event) => {
    const gameData = event.data?.data();
    if (!gameData) {
      console.log("No game data found");
      return;
    }

    const gameId = event.params.gameId;

    // Skip draft editions — notifications are sent when the edition is published
    if (gameData.status === "draft") {
      console.log(`Skipping notifications for draft game ${gameId}`);
      return;
    }

    // 1. Send "registration open" notification to all users
    const editionNumber = gameData.editionNumber as number | undefined;
    const body = editionNumber
      ? `L'édition #${editionNumber} de la CKR est disponible. Inscrivez votre coloc !`
      : "Une nouvelle édition de la CKR est disponible. Inscrivez votre coloc !";

    try {
      const message: admin.messaging.Message = {
        topic: getFCMTopicAllUsers(),
        notification: {
          title: "🎉 Les inscriptions sont ouvertes !",
          body,
        },
        data: {
          type: "registration_open",
          gameId,
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
        `Registration open notification sent, messageId: ${messageId}, gameId: ${gameId}`
      );
    } catch (error) {
      console.error("Error sending registration open notification:", error);
    }

    // 2. Schedule game-start reminders
    const nextGameDate = toDate(gameData.nextGameDate);

    const reminder24h = new Date(nextGameDate.getTime() - 24 * 60 * 60 * 1000);
    const reminder1h = new Date(nextGameDate.getTime() - 1 * 60 * 60 * 1000);

    try {
      await scheduleTaskAt("sendGameReminder24h", { gameId }, reminder24h);
    } catch (error) {
      console.warn("Failed to schedule 24h game reminder (non-critical):", error);
    }

    try {
      await scheduleTaskAt("sendGameReminder1h", { gameId }, reminder1h);
    } catch (error) {
      console.warn("Failed to schedule 1h game reminder (non-critical):", error);
    }
  }
);

// ============================================
// Cloud Task Handlers
// ============================================

/**
 * Send "La CKR, c'est demain !" notification to all registered users.
 * Scheduled by onCKRGameCreated to fire 24h before nextGameDate.
 */
export const sendGameReminder24h = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 10 },
  },
  async (req) => {
    const { gameId } = req.data as GameReminderData;
    if (!gameId) {
      console.error("sendGameReminder24h: missing gameId");
      return;
    }

    const gameDoc = await db.collection("ckrGames").doc(gameId).get();
    if (!gameDoc.exists) return;

    const gameData = gameDoc.data()!;
    const cohouseIDs: string[] = gameData.cohouseIDs || [];
    if (cohouseIDs.length === 0) return;

    const userIds = await getUserIdsFromCohouses(cohouseIDs);
    const tokens = await getFCMTokensForUsers(userIds);

    if (tokens.length > 0) {
      await sendToTokens(tokens, {
        title: "🔥 La CKR, c'est demain !",
        body: "Préparez-vous pour une soirée de folie demain soir !",
        data: { type: "game_starting_24h", gameId },
      });
    }

    console.log(`Game 24h reminder sent for ${gameId} (${tokens.length} tokens)`);
  }
);

/**
 * Send "La CKR, c'est dans 1 heure !" notification to all registered users.
 * Scheduled by onCKRGameCreated to fire 1h before nextGameDate.
 */
export const sendGameReminder1h = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 10 },
  },
  async (req) => {
    const { gameId } = req.data as GameReminderData;
    if (!gameId) {
      console.error("sendGameReminder1h: missing gameId");
      return;
    }

    const gameDoc = await db.collection("ckrGames").doc(gameId).get();
    if (!gameDoc.exists) return;

    const gameData = gameDoc.data()!;
    const cohouseIDs: string[] = gameData.cohouseIDs || [];
    if (cohouseIDs.length === 0) return;

    const userIds = await getUserIdsFromCohouses(cohouseIDs);
    const tokens = await getFCMTokensForUsers(userIds);

    if (tokens.length > 0) {
      await sendToTokens(tokens, {
        title: "🔥 La CKR, c'est dans 1 heure !",
        body: "La soirée commence bientôt. Soyez prêts !",
        data: { type: "game_starting_1h", gameId },
      });
    }

    console.log(`Game 1h reminder sent for ${gameId} (${tokens.length} tokens)`);
  }
);

/**
 * Send personalized apéro reminders (host/visitor) to each cohouse.
 * Scheduled by revealPlanning to fire 15 min before aperoStartTime.
 */
export const sendAperoReminder = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 10 },
  },
  async (req) => {
    const { gameId } = req.data as EventReminderData;
    if (!gameId) {
      console.error("sendAperoReminder: missing gameId");
      return;
    }

    const gameDoc = await db.collection("ckrGames").doc(gameId).get();
    if (!gameDoc.exists) return;

    const gameData = gameDoc.data()!;
    const groupPlannings = gameData.groupPlannings as GroupPlanningData[] | undefined;
    if (!groupPlannings || groupPlannings.length === 0) return;

    await sendStepReminders(gameId, groupPlannings, "apero");
  }
);

/**
 * Send personalized dîner reminders (host/visitor) to each cohouse.
 * Scheduled by revealPlanning to fire 15 min before dinerStartTime.
 */
export const sendDinerReminder = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 10 },
  },
  async (req) => {
    const { gameId } = req.data as EventReminderData;
    if (!gameId) {
      console.error("sendDinerReminder: missing gameId");
      return;
    }

    const gameDoc = await db.collection("ckrGames").doc(gameId).get();
    if (!gameDoc.exists) return;

    const gameData = gameDoc.data()!;
    const groupPlannings = gameData.groupPlannings as GroupPlanningData[] | undefined;
    if (!groupPlannings || groupPlannings.length === 0) return;

    await sendStepReminders(gameId, groupPlannings, "diner");
  }
);

/**
 * Send party reminder to all registered users.
 * Scheduled by revealPlanning to fire 15 min before partyStartTime.
 */
export const sendPartyReminder = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 10 },
  },
  async (req) => {
    const { gameId } = req.data as EventReminderData;
    if (!gameId) {
      console.error("sendPartyReminder: missing gameId");
      return;
    }

    const gameDoc = await db.collection("ckrGames").doc(gameId).get();
    if (!gameDoc.exists) return;

    const gameData = gameDoc.data()!;
    const cohouseIDs: string[] = gameData.cohouseIDs || [];
    if (cohouseIDs.length === 0) return;

    const partyName = gameData.eventSettings?.partyName as string || "la party";

    const userIds = await getUserIdsFromCohouses(cohouseIDs);
    const tokens = await getFCMTokensForUsers(userIds);

    if (tokens.length > 0) {
      await sendToTokens(tokens, {
        title: "🎉 La party commence dans 15 min !",
        body: `Direction ${partyName} pour la suite de la soirée !`,
        data: { type: "party_reminder", gameId },
      });
    }

    console.log(`Party reminder sent for ${gameId} (${tokens.length} tokens)`);
  }
);

// ============================================
// Exported scheduling helper
// ============================================

/**
 * Schedule event step reminder tasks (apéro, dîner, party) 15 min before each.
 * Called from revealPlanning in planning.ts.
 */
export async function scheduleEventReminders(
  gameId: string,
  eventSettings: {
    aperoStartTime: unknown;
    dinerStartTime: unknown;
    partyStartTime: unknown;
  }
): Promise<void> {
  const aperoStart = toDate(eventSettings.aperoStartTime);
  const dinerStart = toDate(eventSettings.dinerStartTime);
  const partyStart = toDate(eventSettings.partyStartTime);

  const fifteenMin = 15 * 60 * 1000;

  const aperoReminder = new Date(aperoStart.getTime() - fifteenMin);
  const dinerReminder = new Date(dinerStart.getTime() - fifteenMin);
  const partyReminder = new Date(partyStart.getTime() - fifteenMin);

  try {
    await scheduleTaskAt("sendAperoReminder", { gameId }, aperoReminder);
  } catch (error) {
    console.warn("Failed to schedule apéro reminder (non-critical):", error);
  }

  try {
    await scheduleTaskAt("sendDinerReminder", { gameId }, dinerReminder);
  } catch (error) {
    console.warn("Failed to schedule dîner reminder (non-critical):", error);
  }

  try {
    await scheduleTaskAt("sendPartyReminder", { gameId }, partyReminder);
  } catch (error) {
    console.warn("Failed to schedule party reminder (non-critical):", error);
  }
}
