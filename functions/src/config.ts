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

export { admin };
