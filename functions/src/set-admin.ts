/**
 * CLI script: set or remove the admin custom claim on a Firebase Auth user.
 *
 * Uses the Google Identity Toolkit REST API directly with the Firebase CLI
 * access token — no service account or gcloud needed.
 *
 * Usage:
 *   cd functions
 *   npm run set-admin -- --uid YOUR_AUTH_UID
 *   npm run set-admin -- --uid YOUR_AUTH_UID --revoke
 *
 * Options:
 *   --uid UID   The Firebase Auth UID of the user to promote/demote (required)
 *   --revoke    Remove admin instead of granting it
 *
 * Prerequisites:
 *   - Firebase CLI logged in (`firebase login`)
 */

import { readFileSync, existsSync } from "fs";
import { resolve } from "path";

// --- Resolve project ID from .firebaserc ---
function getProjectId(): string {
  try {
    const rc = JSON.parse(
      readFileSync(resolve(__dirname, "../../.firebaserc"), "utf-8")
    );
    const projects = rc.projects ?? {};
    return process.env.GCLOUD_PROJECT ?? Object.values<string>(projects)[0];
  } catch {
    throw new Error(
      "Could not read .firebaserc. Run this script from the functions/ directory."
    );
  }
}

// --- Refresh the access token using the Firebase CLI refresh token ---
async function getFreshAccessToken(): Promise<string> {
  const configPath = resolve(
    process.env.HOME ?? "~",
    ".config/configstore/firebase-tools.json"
  );

  if (!existsSync(configPath)) {
    throw new Error("Firebase CLI not logged in. Run `firebase login` first.");
  }

  const config = JSON.parse(readFileSync(configPath, "utf-8"));
  const refreshToken = config.tokens?.refresh_token;

  if (!refreshToken) {
    throw new Error("No refresh token found. Run `firebase login` first.");
  }

  // Firebase CLI's OAuth2 client credentials (public, embedded in the CLI itself)
  const clientId = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
  const clientSecret = "j9iVZfS8kkCEFUPaAeJV0sAi";

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });

  if (!res.ok) {
    throw new Error(`Failed to refresh token: ${res.status} ${await res.text()}`);
  }

  const data = await res.json() as { access_token: string };
  return data.access_token;
}

// --- Identity Toolkit REST API helpers ---
const API_BASE = "https://identitytoolkit.googleapis.com/v1";

interface IdentityToolkitUser {
  localId: string;
  email?: string;
  customAttributes?: string;
}

async function getUser(accessToken: string, projectId: string, uid: string): Promise<IdentityToolkitUser> {
  const res = await fetch(`${API_BASE}/projects/${projectId}/accounts:lookup`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ localId: [uid] }),
  });

  if (!res.ok) {
    throw new Error(`accounts:lookup failed: ${res.status} ${await res.text()}`);
  }

  const data = await res.json() as { users?: IdentityToolkitUser[] };
  if (!data.users?.length) {
    throw new Error(`User ${uid} not found`);
  }
  return data.users[0];
}

async function setCustomClaims(
  accessToken: string,
  projectId: string,
  uid: string,
  claims: Record<string, unknown>
): Promise<void> {
  const res = await fetch(`${API_BASE}/projects/${projectId}/accounts:update`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      localId: uid,
      customAttributes: JSON.stringify(claims),
    }),
  });

  if (!res.ok) {
    throw new Error(`accounts:update failed: ${res.status} ${await res.text()}`);
  }
}

async function updateFirestoreDoc(
  accessToken: string,
  projectId: string,
  uid: string,
  isAdmin: boolean
): Promise<boolean> {
  // Query Firestore for the user doc with matching authId
  const query = {
    structuredQuery: {
      from: [{ collectionId: "users" }],
      where: {
        fieldFilter: {
          field: { fieldPath: "authId" },
          op: "EQUAL",
          value: { stringValue: uid },
        },
      },
      limit: 1,
    },
  };

  const queryRes = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(query),
    }
  );

  if (!queryRes.ok) return false;

  const results = await queryRes.json() as Array<{ document?: { name?: string } }>;
  const docName = results[0]?.document?.name;
  if (!docName) return false;

  // Patch the isAdmin field
  const patchRes = await fetch(
    `https://firestore.googleapis.com/v1/${docName}?updateMask.fieldPaths=isAdmin`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        fields: { isAdmin: { booleanValue: isAdmin } },
      }),
    }
  );

  return patchRes.ok;
}

// --- Parse CLI args ---
const args = process.argv.slice(2);

function getArg(name: string): string | undefined {
  const index = args.indexOf(`--${name}`);
  if (index === -1) return undefined;
  return args[index + 1];
}

function hasFlag(name: string): boolean {
  return args.includes(`--${name}`);
}

const uid = getArg("uid");
const revoke = hasFlag("revoke");

if (!uid) {
  console.error("Usage: npm run set-admin -- --uid <AUTH_UID> [--revoke]");
  process.exit(1);
}

// --- Main ---
async function main() {
  const projectId = getProjectId();
  const isAdmin = !revoke;

  console.log(`Project: ${projectId}`);
  console.log(`Setting admin=${isAdmin} for UID: ${uid}\n`);

  // 1. Get a fresh access token
  const accessToken = await getFreshAccessToken();

  // 2. Set custom claims via Identity Toolkit REST API
  const claims = { admin: isAdmin };
  await setCustomClaims(accessToken, projectId, uid!, claims);
  console.log(`Auth custom claim set (admin: ${isAdmin})`);

  // 3. Try to sync Firestore
  const synced = await updateFirestoreDoc(accessToken, projectId, uid!, isAdmin);
  if (synced) {
    console.log(`Firestore user doc updated (isAdmin: ${isAdmin})`);
  } else {
    console.log("Firestore sync skipped (user doc not found or insufficient permissions)");
  }

  // 4. Confirm
  const user = await getUser(accessToken, projectId, uid!);
  const currentClaims = user.customAttributes
    ? JSON.parse(user.customAttributes)
    : {};
  console.log(`Auth custom claims: ${JSON.stringify(currentClaims)}`);
  console.log(
    `\nAdmin ${isAdmin ? "granted to" : "revoked from"} ${user.email ?? uid}`
  );
  console.log(
    "The user must sign out and sign back in for the change to take effect."
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Error:", err.message ?? err);
    process.exit(1);
  });
