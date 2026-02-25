/**
 * Simple in-memory rate limiter for Cloud Functions.
 *
 * Tracks calls per user per function and rejects excess requests.
 * State is per-instance (Cloud Functions auto-scales), so this provides
 * best-effort protection rather than absolute guarantees.
 *
 * For production-grade rate limiting, consider Cloud Armor or
 * Firestore-based tracking with distributed counters.
 */
import { HttpsError } from "firebase-functions/v2/https";

interface RateLimitEntry {
  timestamps: number[];
}

const store = new Map<string, RateLimitEntry>();

// Clean up stale entries every 10 minutes to prevent memory growth
const CLEANUP_INTERVAL_MS = 10 * 60 * 1000;
let lastCleanup = Date.now();

function cleanupStaleEntries(windowMs: number): void {
  const now = Date.now();
  if (now - lastCleanup < CLEANUP_INTERVAL_MS) return;
  lastCleanup = now;

  for (const [key, entry] of store.entries()) {
    entry.timestamps = entry.timestamps.filter((t) => now - t < windowMs);
    if (entry.timestamps.length === 0) {
      store.delete(key);
    }
  }
}

/**
 * Check and enforce a per-user rate limit for a given function.
 *
 * @param userId   - The authenticated user's UID
 * @param fnName   - Function name (used as namespace)
 * @param maxCalls - Maximum calls allowed in the window
 * @param windowMs - Time window in milliseconds
 *
 * @throws HttpsError("resource-exhausted") if limit exceeded
 */
export function checkRateLimit(
  userId: string,
  fnName: string,
  maxCalls: number,
  windowMs: number
): void {
  const key = `${fnName}:${userId}`;
  const now = Date.now();

  cleanupStaleEntries(windowMs);

  const entry = store.get(key) || { timestamps: [] };
  entry.timestamps = entry.timestamps.filter((t) => now - t < windowMs);

  if (entry.timestamps.length >= maxCalls) {
    throw new HttpsError(
      "resource-exhausted",
      "Trop de requêtes. Veuillez réessayer dans quelques minutes."
    );
  }

  entry.timestamps.push(now);
  store.set(key, entry);
}
