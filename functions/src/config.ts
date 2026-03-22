import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import Stripe from "stripe";

admin.initializeApp();

export const db = admin.firestore();
export const messaging = admin.messaging();
export const auth = admin.auth();

// Region configuration for Europe (Belgium)
export const REGION = "europe-west1";

// Stripe lazy initialization (secret key from Firebase Functions Secrets)
// Set with: firebase functions:secrets:set STRIPE_SECRET_KEY
// Initialized lazily to avoid errors during deployment analysis
// when the secret is not yet available.
let _stripe: Stripe | null = null;
export function getStripe(): Stripe {
  if (!_stripe) {
    const key = process.env.STRIPE_SECRET_KEY;
    if (!key) {
      throw new HttpsError("internal", "Stripe secret key is not configured");
    }
    _stripe = new Stripe(key, { apiVersion: "2025-02-24.acacia" });
  }
  return _stripe;
}

// FCM topic — environment-aware to prevent cross-environment notifications
// Uses GCLOUD_PROJECT (set by Cloud Functions runtime) to avoid calling admin.app()
// at module load time, which fails in test environments.
function getProjectId(): string | undefined {
  try {
    return process.env.GCLOUD_PROJECT || admin.app().options.projectId;
  } catch {
    return undefined;
  }
}
export function getFCMTopicAllUsers(): string {
  return getProjectId() === "colocskitchenrace-prod" ? "all_users_prod" : "all_users_staging";
}

/** FCM topic for a specific edition (special editions only). */
export function getFCMTopicEdition(gameId: string): string {
  const suffix = getProjectId() === "colocskitchenrace-prod" ? "prod" : "staging";
  return `edition_${gameId}_${suffix}`;
}

export { admin };
