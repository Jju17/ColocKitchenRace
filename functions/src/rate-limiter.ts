/**
 * Simple in-memory rate limiter for Cloud Functions.
 *
 * Tracks calls per user per function and rejects excess requests.
 * State is per-instance (Cloud Functions auto-scales), so this provides
 * best-effort protection rather than absolute guarantees.
 *
 * IMPORTANT LIMITATION: This rate limiter is in-memory and scoped to a single
 * Cloud Functions instance. Because Cloud Functions auto-scales across multiple
 * instances, each instance maintains its own independent rate limit state. This
 * means:
 *   - A user's requests may be routed to different instances, effectively
 *     multiplying their allowed rate by the number of active instances.
 *   - Instance cold starts reset all rate limit state.
 *   - Under high load (many instances), the rate limiter provides minimal
 *     protection as limits are not shared across instances.
 *
 * This is acceptable for basic abuse prevention (e.g., a single user hammering
 * a single instance), but it does NOT provide cross-instance guarantees.
 *
 * FUTURE IMPROVEMENT: For stricter rate limiting, replace this with a
 * Firestore-based approach using distributed counters or atomic increments
 * on a per-user document (e.g., /rateLimits/{userId}/{fnName}). This would
 * provide consistent limits across all instances at the cost of one Firestore
 * read+write per request. Alternatively, consider using Cloud Armor rate
 * limiting rules or Redis (via Memorystore) for sub-millisecond checks.
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
