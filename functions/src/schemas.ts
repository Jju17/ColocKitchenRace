/**
 * Zod validation schemas for all Cloud Function inputs.
 * Centralizes validation logic that was previously scattered across files.
 */
import { z } from "zod";
import { HttpsError } from "firebase-functions/v2/https";

// ── Parse helper ───────────────────────────────────────────────────────────

/**
 * Parse request data against a Zod schema.
 * Throws `HttpsError("invalid-argument")` with a descriptive message on failure.
 */
export function parseRequest<T>(schema: z.ZodType<T>, data: unknown): T {
  try {
    return schema.parse(data);
  } catch (e) {
    if (e instanceof z.ZodError) {
      const messages = e.issues
        .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
        .join(", ");
      throw new HttpsError("invalid-argument", `Invalid request: ${messages}`);
    }
    throw e;
  }
}

// ── Auth helpers ───────────────────────────────────────────────────────────

/** Throws if the caller is not authenticated. */
export function requireAuth(request: { auth?: { uid: string; token: Record<string, unknown> } }): void {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated");
  }
}

/** Throws if the caller is not an admin. */
export function requireAdmin(request: { auth?: { uid: string; token: Record<string, unknown> } }): void {
  requireAuth(request);
  if (!request.auth!.token.admin) {
    throw new HttpsError("permission-denied", "Admin access required");
  }
}

// ── Shared schemas ─────────────────────────────────────────────────────────

const notificationPayload = z.object({
  title: z.string().min(1, "Title is required"),
  body: z.string().min(1, "Body is required"),
  data: z.record(z.string(), z.string()).optional(),
});

// ── Payment & Registration ─────────────────────────────────────────────────

export const reserveAndCreatePaymentSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
  cohouseId: z.string().min(1, "cohouseId is required"),
  amountCents: z.number().positive("amountCents must be positive"),
  participantCount: z.number().int().positive("participantCount must be positive"),
  attendingUserIds: z.array(z.string().min(1)).min(1, "At least one attendee required"),
  averageAge: z.number().positive("averageAge must be positive"),
  cohouseType: z.string().min(1, "cohouseType is required"),
});

export const confirmRegistrationSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
  cohouseId: z.string().min(1, "cohouseId is required"),
  paymentIntentId: z.string().min(1, "paymentIntentId is required"),
});

export const cancelReservationSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
  cohouseId: z.string().min(1, "cohouseId is required"),
});

// ── Notifications ──────────────────────────────────────────────────────────

export const sendToCohouseSchema = z.object({
  cohouseId: z.string().min(1, "cohouseId is required"),
  notification: notificationPayload,
});

export const sendToEditionSchema = z.object({
  editionId: z.string().min(1, "editionId is required"),
  notification: notificationPayload,
});

export const sendToAllSchema = z.object({
  notification: notificationPayload,
});

// ── Planning ───────────────────────────────────────────────────────────────

export const updateEventSettingsSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
  aperoStartTime: z.string().min(1, "aperoStartTime is required"),
  aperoEndTime: z.string().min(1, "aperoEndTime is required"),
  dinerStartTime: z.string().min(1, "dinerStartTime is required"),
  dinerEndTime: z.string().min(1, "dinerEndTime is required"),
  partyStartTime: z.string().min(1, "partyStartTime is required"),
  partyEndTime: z.string().min(1, "partyEndTime is required"),
  partyAddress: z.string().min(1, "partyAddress is required"),
  partyName: z.string().min(1, "partyName is required"),
  partyNote: z.string().optional(),
});

export const gameIdSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
});

export const getMyPlanningSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
  cohouseId: z.string().min(1, "cohouseId is required"),
});

// ── Cohouse ────────────────────────────────────────────────────────────────

export const checkDuplicateSchema = z.object({
  name: z.string().min(1, "name is required"),
  street: z.string().min(1, "street is required"),
  city: z.string().min(1, "city is required"),
});

export const validateAddressSchema = z.object({
  street: z.string().min(1, "street is required"),
  city: z.string().min(1, "city is required"),
  postalCode: z.string().optional(),
  country: z.string().optional(),
});

// Scoped to authenticated users only — returns GPS coordinates for the
// requested cohouse IDs. Max 100 IDs per call to prevent abuse.
export const getCohousesForMapSchema = z.object({
  cohouseIds: z.array(z.string().min(1)).min(1, "At least one cohouseId required").max(100, "Maximum 100 cohouseIds per request"),
});

// ── Account ────────────────────────────────────────────────────────────────

export const deleteAccountSchema = z.object({
  userId: z.string().min(1, "userId is required"),
});

// ── Admin ──────────────────────────────────────────────────────────────────

export const setAdminClaimSchema = z.object({
  targetAuthUid: z.string().min(1, "targetAuthUid is required"),
  isAdmin: z.boolean(),
});

// ── Cleanup ────────────────────────────────────────────────────────────────

export const deleteCKRGameSchema = z.object({
  gameId: z.string().min(1, "gameId is required"),
});
