/**
 * Cloud Functions for multi-edition support (Phase 2).
 *
 * - createSpecialEdition: Edition admin creates a draft special edition
 * - saveDraftEdition: Autosave draft fields
 * - publishEdition: Publish a draft edition (transition draft → published)
 * - joinEditionByCode: User joins a special edition via 6-char code
 * - leaveEdition: User leaves a special edition (if not registered)
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, admin, REGION, getFCMTopicEdition } from "./config";
import {
  parseRequest,
  requireAuth,
  requireAdmin,
  requireEditionOwner,
} from "./schemas";
import { z } from "zod";
import { randomUUID, randomBytes } from "crypto";
import { scheduleTaskAt } from "./pushNotifications";

// ── Schemas ───────────────────────────────────────────────────────────

const createSpecialEditionSchema = z.object({
  title: z.string().min(1, "Title is required"),
  description: z.string().optional(),
  maxParticipants: z.number().int().positive().optional(),
  pricePerPersonCents: z.number().int().min(0).optional(),
  nextGameDate: z.string().optional(),
  registrationDeadline: z.string().optional(),
});

const saveDraftEditionSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
  fields: z.record(z.string(), z.unknown()),
});

const publishEditionSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
});

const joinEditionByCodeSchema = z.object({
  joinCode: z.string().length(6, "Code must be exactly 6 characters").regex(/^[A-Z2-9]+$/i, "Invalid code format"),
});

const leaveEditionSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
});

// ── Helpers ───────────────────────────────────────────────────────────

/** Generate a unique 6-character alphanumeric code. */
async function generateUniqueJoinCode(): Promise<string> {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // No I/O/0/1 to avoid confusion
  const maxAttempts = 10;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const bytes = randomBytes(6);
    let code = "";
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(bytes[i] % chars.length);
    }

    // Check uniqueness
    const existing = await db
      .collection("ckrGames")
      .where("joinCode", "==", code)
      .limit(1)
      .get();

    if (existing.empty) return code;
  }

  throw new HttpsError("internal", "Failed to generate unique join code after multiple attempts");
}

// ── Cloud Functions ──────────────────────────────────────────────────

/**
 * Create a new special edition (draft).
 *
 * Called by edition admins to start the creation flow.
 * Returns the gameId and joinCode for the new edition.
 */
export const createSpecialEdition = onCall(
  { region: REGION },
  async (request) => {
    requireAdmin(request);
    const data = parseRequest(createSpecialEditionSchema, request.data);
    const callerUid = request.auth!.uid;

    const joinCode = await generateUniqueJoinCode();
    const now = new Date();

    const gameId = randomUUID().toUpperCase();
    const gameRef = db.collection("ckrGames").doc(gameId);
    const gameData: Record<string, unknown> = {
      id: gameId,
      editionType: "special",
      status: "draft",
      title: data.title,
      editionDescription: data.description || null,
      joinCode,
      createdByAuthUid: callerUid,
      lastSavedAt: now,
      publishedTimestamp: null,

      // Defaults — can be overridden via saveDraftEdition
      editionNumber: 1,
      maxParticipants: data.maxParticipants || 100,
      pricePerPersonCents: data.pricePerPersonCents || 500,
      startCKRCountdown: data.nextGameDate ? new Date(data.nextGameDate) : now,
      nextGameDate: data.nextGameDate ? new Date(data.nextGameDate) : now,
      registrationDeadline: data.registrationDeadline
        ? new Date(data.registrationDeadline)
        : now,

      // Initialize empty arrays/fields
      cohouseIDs: [],
      totalRegisteredParticipants: 0,
      matchedGroups: null,
      matchedAt: null,
      eventSettings: null,
      groupPlannings: null,
      isRevealed: false,
      revealedAt: null,
    };

    await gameRef.set(gameData);

    console.log(
      `Special edition created: ${gameRef.id} (code: ${joinCode}) by ${callerUid}`
    );

    return {
      success: true,
      gameId: gameRef.id,
      joinCode,
    };
  }
);

/**
 * Autosave draft edition fields.
 *
 * Called by the admin app during the creation flow to persist progress.
 * Only works on drafts owned by the caller.
 */
export const saveDraftEdition = onCall(
  { region: REGION },
  async (request) => {
    const { gameId, fields } = parseRequest(saveDraftEditionSchema, request.data);
    await requireEditionOwner(request, gameId, db);

    const gameRef = db.doc(`ckrGames/${gameId}`);
    const gameDoc = await gameRef.get();
    const gameData = gameDoc.data()!;

    if (gameData.status !== "draft") {
      throw new HttpsError("failed-precondition", "Can only autosave draft editions");
    }

    // Whitelist of fields that can be updated via autosave
    const allowedFields = [
      "title", "editionDescription", "maxParticipants", "pricePerPersonCents",
      "nextGameDate", "registrationDeadline", "startCKRCountdown",
      "eventSettings", "editionNumber",
    ];

    const sanitized: Record<string, unknown> = {};
    for (const key of allowedFields) {
      if (key in fields) {
        sanitized[key] = fields[key];
      }
    }
    sanitized.lastSavedAt = new Date();

    await gameRef.update(sanitized);

    return { success: true };
  }
);

/**
 * Publish a draft edition.
 *
 * Transitions status from "draft" to "published".
 * After this, users can discover it via joinCode.
 */
export const publishEdition = onCall(
  { region: REGION },
  async (request) => {
    const { gameId } = parseRequest(publishEditionSchema, request.data);
    await requireEditionOwner(request, gameId, db);
    const callerUid = request.auth!.uid;

    const gameRef = db.doc(`ckrGames/${gameId}`);
    const gameDoc = await gameRef.get();
    const gameData = gameDoc.data()!;

    if (gameData.status !== "draft") {
      throw new HttpsError("failed-precondition", "Edition is already published");
    }

    // Validate required fields before publishing
    if (!gameData.title) {
      throw new HttpsError("failed-precondition", "Title is required to publish");
    }
    if (!gameData.nextGameDate) {
      throw new HttpsError("failed-precondition", "Game date is required to publish");
    }
    if (!gameData.registrationDeadline) {
      throw new HttpsError("failed-precondition", "Registration deadline is required to publish");
    }

    await gameRef.update({
      status: "published",
      publishedTimestamp: new Date(),
    });

    // Schedule game-start reminders (24h + 1h before)
    const nextGameDate = gameData.nextGameDate?.toDate?.()
      ?? new Date(gameData.nextGameDate as string);

    const reminder24h = new Date(nextGameDate.getTime() - 24 * 60 * 60 * 1000);
    const reminder1h = new Date(nextGameDate.getTime() - 1 * 60 * 60 * 1000);

    try {
      await scheduleTaskAt("sendGameReminder24h", { gameId }, reminder24h);
    } catch (error) {
      console.warn("Failed to schedule 24h game reminder:", error);
    }
    try {
      await scheduleTaskAt("sendGameReminder1h", { gameId }, reminder1h);
    } catch (error) {
      console.warn("Failed to schedule 1h game reminder:", error);
    }

    console.log(`Edition ${gameId} published by ${callerUid}`);

    return {
      success: true,
      joinCode: gameData.joinCode,
    };
  }
);

/**
 * Join a special edition by its 6-character code.
 *
 * Sets activeEditionId on the user's doc and subscribes to the edition FCM topic.
 */
export const joinEditionByCode = onCall(
  { region: REGION },
  async (request) => {
    requireAuth(request);
    const { joinCode } = parseRequest(joinEditionByCodeSchema, request.data);
    const callerUid = request.auth!.uid;

    // Find the edition by code
    const gamesSnapshot = await db
      .collection("ckrGames")
      .where("joinCode", "==", joinCode.toUpperCase())
      .where("status", "==", "published")
      .limit(1)
      .get();

    if (gamesSnapshot.empty) {
      throw new HttpsError("not-found", "No edition found with this code");
    }

    const gameDoc = gamesSnapshot.docs[0];
    const gameData = gameDoc.data();
    const gameId = gameDoc.id;

    // Validate registration is still possible
    const deadline = gameData.registrationDeadline?.toDate?.() ?? gameData.registrationDeadline;
    if (deadline && new Date() > new Date(deadline)) {
      throw new HttpsError("failed-precondition", "Registration deadline has passed for this edition");
    }
    const totalRegistered = (gameData.totalRegisteredParticipants as number) || 0;
    const maxParticipants = (gameData.maxParticipants as number) || 100;
    if (totalRegistered >= maxParticipants) {
      throw new HttpsError("failed-precondition", "This edition is full");
    }

    // Find the caller's user doc
    const userSnapshot = await db
      .collection("users")
      .where("authId", "==", callerUid)
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      throw new HttpsError("not-found", "User profile not found");
    }

    const userDocRef = userSnapshot.docs[0].ref;

    // Atomically check + set activeEditionId in a transaction
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userDocRef);
      if (!userDoc.exists) {
        throw new HttpsError("not-found", "User profile not found");
      }
      const userData = userDoc.data()!;

      if (userData.activeEditionId === gameId) {
        return; // Already in this edition — no-op
      }

      if (userData.activeEditionId) {
        throw new HttpsError(
          "failed-precondition",
          "You are already in a special edition. Leave it first before joining another."
        );
      }

      transaction.update(userDocRef, { activeEditionId: gameId });
    });

    const userData = (await userDocRef.get()).data()!;

    // Subscribe to edition FCM topic
    const fcmToken = userData.fcmToken as string | undefined;
    if (fcmToken) {
      try {
        await admin.messaging().subscribeToTopic([fcmToken], getFCMTopicEdition(gameId));
      } catch (e) {
        console.warn(`Failed to subscribe ${callerUid} to edition topic:`, e);
      }
    }

    console.log(`User ${callerUid} joined edition ${gameId} (code: ${joinCode})`);

    return {
      success: true,
      gameId,
      title: gameData.title,
      editionType: gameData.editionType,
    };
  }
);

/**
 * Leave a special edition.
 *
 * Only allowed if the user is NOT registered (no confirmed registration).
 * Resets activeEditionId to null.
 */
export const leaveEdition = onCall(
  { region: REGION },
  async (request) => {
    requireAuth(request);
    const { gameId } = parseRequest(leaveEditionSchema, request.data);
    const callerUid = request.auth!.uid;

    // Find the caller's user doc
    const userSnapshot = await db
      .collection("users")
      .where("authId", "==", callerUid)
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      throw new HttpsError("not-found", "User profile not found");
    }

    const userDoc = userSnapshot.docs[0];
    const userData = userDoc.data();

    if (userData.activeEditionId !== gameId) {
      throw new HttpsError("failed-precondition", "You are not in this edition");
    }

    // Check if any registration exists for this edition that includes the user
    const regsSnapshot = await db
      .collection("ckrGames")
      .doc(gameId)
      .collection("registrations")
      .where("status", "==", "confirmed")
      .get();

    const userId = userDoc.id;
    const userCohouseId = userData.cohouseId as string | undefined;
    const hasActiveRegistration = regsSnapshot.docs.some((reg) => {
      const regData = reg.data();
      // Check by cohouseId match or by attendingUserIds containing the user
      if (userCohouseId && reg.id === userCohouseId) return true;
      const attendingIds = (regData.attendingUserIds as string[]) || [];
      return attendingIds.includes(userId);
    });

    if (hasActiveRegistration) {
      throw new HttpsError(
        "failed-precondition",
        "Cannot leave an edition you are registered for. Contact the organizer."
      );
    }

    // Clear activeEditionId
    await userDoc.ref.update({ activeEditionId: null });

    // Unsubscribe from edition FCM topic
    const fcmToken = userData.fcmToken as string | undefined;
    if (fcmToken) {
      try {
        await admin.messaging().unsubscribeFromTopic([fcmToken], getFCMTopicEdition(gameId));
      } catch (e) {
        console.warn(`Failed to unsubscribe ${callerUid} from edition topic:`, e);
      }
    }

    console.log(`User ${callerUid} left edition ${gameId}`);

    return { success: true };
  }
);
