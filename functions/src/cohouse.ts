import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, REGION } from "./config";

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
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { name, street, city } = request.data;

    if (!name || !street || !city) {
      throw new HttpsError("invalid-argument", "Missing required fields: name, street, city");
    }

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
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { street, city, postalCode, country } = request.data;

    if (!street || !city) {
      throw new HttpsError("invalid-argument", "Missing required fields: street, city");
    }

    try {
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

      return {
        isValid: true,
        normalizedStreet: normalizedStreet,
        normalizedCity: normalizedCity,
        normalizedPostalCode: addr.postcode || null,
        normalizedCountry: addr.country || null,
        latitude: result.lat ? parseFloat(result.lat) : null,
        longitude: result.lon ? parseFloat(result.lon) : null,
      };
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
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { cohouseIds } = request.data;

    if (!cohouseIds || !Array.isArray(cohouseIds) || cohouseIds.length === 0) {
      throw new HttpsError("invalid-argument", "Missing required field: cohouseIds (non-empty array)");
    }

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
