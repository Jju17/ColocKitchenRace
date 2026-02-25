import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, auth, REGION } from "./config";
import { parseRequest, requireAuth, checkDuplicateSchema, validateAddressSchema, getCohousesForMapSchema } from "./schemas";
import { checkRateLimit } from "./rate-limiter";

// ============================================
// Nominatim geocoding cache (in-memory, per Cloud Function instance)
// ============================================

interface GeocodeCacheEntry {
  result: unknown;
  expiresAt: number;
}

const geocodeCache = new Map<string, GeocodeCacheEntry>();
const GEOCODE_CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes

// ============================================
// Types
// ============================================

interface CheckDuplicateRequest {
  name: string;
  street: string;
  city: string;
}

interface ValidateAddressRequest {
  street: string;
  city: string;
  postalCode: string;
  country: string;
}

interface GetCohousesForMapRequest {
  cohouseIds: string[];
}

interface CohouseMapData {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  userNames: string[];
}

// ============================================
// Cloud Functions
// ============================================

/**
 * Check if a cohouse with the same name or address already exists
 */
export const checkDuplicateCohouse = onCall<CheckDuplicateRequest>(
  { region: REGION },
  async (request) => {
    requireAuth(request);
    const { name, street, city } = parseRequest(checkDuplicateSchema, request.data);
    checkRateLimit(request.auth!.uid, "checkDuplicateCohouse", 10, 60_000);

    try {
      const nameLower = name.trim().toLowerCase();
      const streetLower = street.trim().toLowerCase();
      const cityLower = city.trim().toLowerCase();

      // Check by name
      const nameSnapshot = await db
        .collection("cohouses")
        .where("nameLower", "==", nameLower)
        .limit(1)
        .get();

      if (!nameSnapshot.empty) {
        return { isDuplicate: true, reason: "name" };
      }

      // Check by address (street + city)
      // Uses the lowercased PostalAddress stored as addressLower
      const addressSnapshot = await db
        .collection("cohouses")
        .where("addressLower.street", "==", streetLower)
        .where("addressLower.city", "==", cityLower)
        .limit(1)
        .get();

      if (!addressSnapshot.empty) {
        return { isDuplicate: true, reason: "address" };
      }

      return { isDuplicate: false };
    } catch (error) {
      console.error("Error checking duplicate cohouse:", error);
      throw new HttpsError("internal", "Failed to check for duplicates");
    }
  }
);

/**
 * Validate an address using Nominatim (OpenStreetMap) geocoding API
 */
export const validateAddress = onCall<ValidateAddressRequest>(
  { region: REGION },
  async (request) => {
    requireAuth(request);
    const { street, city, postalCode, country } = parseRequest(validateAddressSchema, request.data);
    checkRateLimit(request.auth!.uid, "validateAddress", 20, 60_000);

    try {
      const cacheKey = `${street}|${city}|${postalCode || ""}|${country || ""}`;
      const cached = geocodeCache.get(cacheKey);
      if (cached && cached.expiresAt > Date.now()) {
        return cached.result;
      }

      const params = new URLSearchParams({
        format: "json",
        street: street,
        city: city,
        postalcode: postalCode || "",
        country: country || "",
        limit: "1",
        addressdetails: "1",
      });

      const url = `https://nominatim.openstreetmap.org/search?${params.toString()}`;

      const response = await fetch(url, {
        headers: {
          "User-Agent": "ColocKitchenRace/1.0",
          "Accept": "application/json",
        },
      });

      if (!response.ok) {
        throw new Error(`Nominatim returned status ${response.status}`);
      }

      const results = await response.json() as Array<{
        display_name?: string;
        lat?: string;
        lon?: string;
        address?: {
          road?: string;
          house_number?: string;
          city?: string;
          town?: string;
          village?: string;
          postcode?: string;
          country?: string;
        };
      }>;

      if (!results || results.length === 0) {
        return { isValid: false };
      }

      const result = results[0];
      const addr = result.address || {};

      const normalizedCity = addr.city || addr.town || addr.village || null;
      const normalizedStreet = addr.road
        ? (addr.house_number ? `${addr.road} ${addr.house_number}` : addr.road)
        : null;

      const validResult = {
        isValid: true,
        normalizedStreet: normalizedStreet,
        normalizedCity: normalizedCity,
        normalizedPostalCode: addr.postcode || null,
        normalizedCountry: addr.country || null,
        latitude: result.lat ? parseFloat(result.lat) : null,
        longitude: result.lon ? parseFloat(result.lon) : null,
      };

      // Cache successful result
      geocodeCache.set(cacheKey, {
        result: validResult,
        expiresAt: Date.now() + GEOCODE_CACHE_TTL_MS,
      });

      return validResult;
    } catch (error) {
      console.error("Error validating address:", error);
      throw new HttpsError("internal", "Failed to validate address");
    }
  }
);

/**
 * Batch-fetch lightweight cohouse data for map display.
 *
 * Returns name, GPS coordinates, and member names for each cohouse ID.
 * This avoids N individual Firestore calls from the client.
 */
export const getCohousesForMap = onCall<GetCohousesForMapRequest>(
  { region: REGION },
  async (request) => {
    requireAuth(request);
    const { cohouseIds } = parseRequest(getCohousesForMapSchema, request.data);

    try {
      const results: CohouseMapData[] = [];

      // Fetch cohouse docs in batches of 30 (Firestore 'in' limit)
      const batches = [];
      for (let i = 0; i < cohouseIds.length; i += 30) {
        batches.push(cohouseIds.slice(i, i + 30));
      }

      for (const batch of batches) {
        const snapshot = await db
          .collection("cohouses")
          .where("id", "in", batch)
          .get();

        // For each cohouse doc, also fetch its users subcollection
        for (const doc of snapshot.docs) {
          const data = doc.data();
          const id = data.id as string;
          const name = (data.name as string) || "Unknown";
          const latitude = data.latitude as number | undefined;
          const longitude = data.longitude as number | undefined;

          if (latitude == null || longitude == null) continue;

          // Fetch users subcollection
          const usersSnapshot = await db
            .collection("cohouses")
            .doc(doc.id)
            .collection("users")
            .get();

          const userNames = usersSnapshot.docs
            .map((userDoc) => {
              const userData = userDoc.data();
              const first = (userData.firstName as string) || "";
              const last = (userData.lastName as string) || "";
              return `${first} ${last}`.trim();
            })
            .filter((name) => name.length > 0);

          results.push({ id, name, latitude, longitude, userNames });
        }
      }

      return { success: true, cohouses: results };
    } catch (error) {
      console.error("Error fetching cohouses for map:", error);
      throw new HttpsError("internal", "Failed to fetch cohouse data");
    }
  }
);

/**
 * Set the "cohouseId" custom claim on the caller's Auth token.
 *
 * Reads the caller's Firestore user doc (matched by authId) to get their
 * current cohouseId, then sets it as a custom claim. This is used by
 * Firestore security rules to validate cohouse membership via
 * `request.auth.token.cohouseId`.
 *
 * Should be called after joining, creating, or leaving a cohouse.
 * The client must force a token refresh after calling this.
 */
export const setCohouseClaim = onCall(
  { region: REGION },
  async (request) => {
    requireAuth(request);

    const callerUid = request.auth!.uid;

    try {
      // Look up the user's Firestore doc by authId
      const userSnapshot = await db
        .collection("users")
        .where("authId", "==", callerUid)
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        throw new HttpsError("not-found", "User document not found");
      }

      const userData = userSnapshot.docs[0].data();
      const cohouseId = (userData.cohouseId as string) || null;

      // Preserve existing custom claims (e.g. admin) and set cohouseId
      const currentUser = await auth.getUser(callerUid);
      const existingClaims = currentUser.customClaims || {};
      await auth.setCustomUserClaims(callerUid, { ...existingClaims, cohouseId });

      console.log(
        `Cohouse claim set to "${cohouseId ?? "null"}" for Auth UID: ${callerUid}`
      );

      return { success: true, cohouseId };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Error setting cohouse claim:", error);
      throw new HttpsError("internal", "Failed to set cohouse claim");
    }
  }
);
