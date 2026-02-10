/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Unit tests for all Cloud Functions.
 *
 * Strategy: mock firebase-admin (Firestore + Messaging) at the module level,
 * then test the wrapped callable handlers directly.
 *
 * The `firebase-functions-test` wrapper enriches the request object and does
 * NOT faithfully propagate `auth: undefined`, so we call the handler directly
 * for auth tests, and use the wrapper for everything else.
 */

// ── Mock firebase-admin before any imports ─────────────────────────────────────

let firestoreData: Record<string, Record<string, any>> = {};
let firestoreSubcollections: Record<string, Record<string, Record<string, any[]>>> = {};

const mockUpdate = jest.fn().mockResolvedValue(undefined);

function makeDocRef(collection: string, docId: string) {
  return {
    get: jest.fn().mockImplementation(async () => {
      const data = firestoreData[collection]?.[docId];
      return { exists: !!data, data: () => data, id: docId };
    }),
    set: jest.fn().mockResolvedValue(undefined),
    update: mockUpdate,
    collection: jest.fn().mockImplementation((subName: string) => ({
      get: jest.fn().mockImplementation(async () => {
        const docs = firestoreSubcollections[collection]?.[docId]?.[subName] || [];
        return {
          docs: docs.map((d: any, i: number) => ({ data: () => d, id: `sub_${i}` })),
        };
      }),
    })),
  };
}

function makeCollection(name: string) {
  return {
    doc: jest.fn().mockImplementation((id: string) => makeDocRef(name, id)),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn().mockImplementation(async () => {
      const docs = firestoreData[name] || {};
      return {
        empty: Object.keys(docs).length === 0,
        docs: Object.entries(docs).map(([id, data]) => ({ data: () => data, id })),
      };
    }),
  };
}

const mockSendEachForMulticast = jest.fn().mockResolvedValue({
  successCount: 1,
  failureCount: 0,
  responses: [{ success: true }],
});

const mockSend = jest.fn().mockResolvedValue("mock-message-id");

jest.mock("firebase-admin", () => ({
  initializeApp: jest.fn(),
  firestore: Object.assign(
    jest.fn(() => ({
      collection: jest.fn().mockImplementation((name: string) => makeCollection(name)),
    })),
    { FieldValue: { serverTimestamp: jest.fn(() => "SERVER_TIMESTAMP") } }
  ),
  messaging: jest.fn(() => ({
    sendEachForMulticast: mockSendEachForMulticast,
    send: mockSend,
  })),
}));

// ── Import functions ────────────────────────────────────────────────────────────

import * as functionsTest from "firebase-functions-test";
const testEnv = functionsTest();

import {
  sendNotificationToCohouse,
  sendNotificationToEdition,
  sendNotificationToAll,
  checkDuplicateCohouse,
  validateAddress,
  matchCohouses,
} from "../index";

// ── Helpers ─────────────────────────────────────────────────────────────────────

function resetFirestore() {
  firestoreData = {};
  firestoreSubcollections = {};
}

/** Helper: call wrapped function with auth. */
function callWith(fn: any, data: any) {
  const wrapped = testEnv.wrap(fn);
  // testEnv.wrap for callable v2 expects { data, auth? }
  return wrapped({ data, auth: { uid: "test-user" } } as any);
}

// ── Setup / teardown ────────────────────────────────────────────────────────────

beforeEach(() => {
  jest.clearAllMocks();
  resetFirestore();
});

afterAll(() => testEnv.cleanup());

// ═══════════════════════════════════════════════════════════════════════════════
// sendNotificationToCohouse
// ═══════════════════════════════════════════════════════════════════════════════

describe("sendNotificationToCohouse", () => {
  it("throws invalid-argument when fields missing", async () => {
    await expect(
      callWith(sendNotificationToCohouse, { cohouseId: "", notification: { title: "", body: "" } })
    ).rejects.toThrow(/invalid-argument|missing/i);
  });

  it("sends notifications to cohouse users and returns success", async () => {
    firestoreSubcollections = {
      cohouses: { c1: { users: [{ userId: "u1" }, { userId: "u2" }] } },
    };
    firestoreData = {
      users: {
        u1: { id: "u1", fcmToken: "tok1" },
        u2: { id: "u2", fcmToken: "tok2" },
      },
    };

    const result = await callWith(
      sendNotificationToCohouse,
      { cohouseId: "c1", notification: { title: "Hi", body: "Msg" } }
    );

    expect(result.success).toBe(true);
    expect(result.totalUsers).toBe(2);
  });

  it("handles cohouse with no users gracefully", async () => {
    firestoreSubcollections = { cohouses: { c1: { users: [] } } };

    const result = await callWith(
      sendNotificationToCohouse,
      { cohouseId: "c1", notification: { title: "Hi", body: "Msg" } }
    );

    expect(result.success).toBe(true);
    expect(result.totalUsers).toBe(0);
    expect(result.sent).toBe(0);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// sendNotificationToEdition
// ═══════════════════════════════════════════════════════════════════════════════

describe("sendNotificationToEdition", () => {
  it("throws invalid-argument when fields missing", async () => {
    await expect(
      callWith(sendNotificationToEdition, { editionId: "", notification: { title: "", body: "" } })
    ).rejects.toThrow(/invalid-argument|missing/i);
  });

  it("returns success with 0 sent when no participants", async () => {
    firestoreData = { ckrGames: { e1: { participantsID: [] } } };

    const result = await callWith(
      sendNotificationToEdition,
      { editionId: "e1", notification: { title: "T", body: "B" } }
    );

    expect(result.success).toBe(true);
    expect(result.sent).toBe(0);
    expect(result.message).toMatch(/no participants/i);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// sendNotificationToAll
// ═══════════════════════════════════════════════════════════════════════════════

describe("sendNotificationToAll", () => {
  it("throws invalid-argument when fields missing", async () => {
    await expect(
      callWith(sendNotificationToAll, { notification: { title: "", body: "" } })
    ).rejects.toThrow(/invalid-argument|missing/i);
  });

  it("sends to all_users topic and returns messageId", async () => {
    const result = await callWith(
      sendNotificationToAll,
      { notification: { title: "News", body: "Body" } }
    );

    expect(result.success).toBe(true);
    expect(result.messageId).toBe("mock-message-id");
    expect(mockSend).toHaveBeenCalledTimes(1);
    expect(mockSend).toHaveBeenCalledWith(
      expect.objectContaining({
        topic: "all_users",
        notification: { title: "News", body: "Body" },
      })
    );
  });

  it("forwards optional data payload", async () => {
    await callWith(
      sendNotificationToAll,
      { notification: { title: "T", body: "B", data: { key: "val" } } }
    );

    expect(mockSend).toHaveBeenCalledWith(
      expect.objectContaining({ data: { key: "val" } })
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// checkDuplicateCohouse
// ═══════════════════════════════════════════════════════════════════════════════

describe("checkDuplicateCohouse", () => {
  it("throws invalid-argument when fields missing", async () => {
    await expect(
      callWith(checkDuplicateCohouse, { name: "", street: "", city: "" })
    ).rejects.toThrow(/invalid-argument|missing/i);
  });

  it("returns isDuplicate: false when no match in Firestore", async () => {
    const result = await callWith(
      checkDuplicateCohouse,
      { name: "Brand New", street: "Rue Neuve 1", city: "Bruxelles" }
    );
    expect(result.isDuplicate).toBe(false);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// validateAddress
// ═══════════════════════════════════════════════════════════════════════════════

describe("validateAddress", () => {
  it("throws invalid-argument when street or city missing", async () => {
    await expect(
      callWith(validateAddress, { street: "", city: "", postalCode: "", country: "" })
    ).rejects.toThrow(/invalid-argument|missing/i);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// matchCohouses
// ═══════════════════════════════════════════════════════════════════════════════

describe("matchCohouses", () => {
  it("throws invalid-argument when gameId missing", async () => {
    await expect(
      callWith(matchCohouses, { gameId: "" })
    ).rejects.toThrow(/invalid-argument|missing/i);
  });

  it("throws not-found when game does not exist", async () => {
    await expect(
      callWith(matchCohouses, { gameId: "nope" })
    ).rejects.toThrow(/not.found/i);
  });

  it("throws failed-precondition when no participants", async () => {
    firestoreData = { ckrGames: { g1: { participantsID: [] } } };
    await expect(
      callWith(matchCohouses, { gameId: "g1" })
    ).rejects.toThrow(/no cohouses/i);
  });

  it("throws failed-precondition when count is not multiple of 4", async () => {
    firestoreData = { ckrGames: { g1: { participantsID: ["a", "b", "c"] } } };
    await expect(
      callWith(matchCohouses, { gameId: "g1" })
    ).rejects.toThrow(/multiple of 4/i);
  });

  it("matches 4 cohouses, stores results, returns groups", async () => {
    firestoreData = {
      ckrGames: { g1: { participantsID: ["c1", "c2", "c3", "c4"] } },
      cohouses: {
        c1: { id: "c1", name: "A", latitude: 50.850, longitude: 4.350 },
        c2: { id: "c2", name: "B", latitude: 50.851, longitude: 4.351 },
        c3: { id: "c3", name: "C", latitude: 50.852, longitude: 4.352 },
        c4: { id: "c4", name: "D", latitude: 50.853, longitude: 4.353 },
      },
    };

    const result = await callWith(matchCohouses, { gameId: "g1" });

    expect(result.success).toBe(true);
    expect(result.groupCount).toBe(1);
    expect(result.groups).toHaveLength(1);
    expect(result.groups[0].sort()).toEqual(["c1", "c2", "c3", "c4"]);

    // Verify Firestore was updated with wrapped groups
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        matchedGroups: [{ cohouseIds: expect.arrayContaining(["c1", "c2", "c3", "c4"]) }],
        matchedAt: "SERVER_TIMESTAMP",
      })
    );
  });

  it("matches 8 cohouses into 2 groups", async () => {
    firestoreData = {
      ckrGames: { g2: { participantsID: ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8"] } },
      cohouses: {
        c1: { id: "c1", name: "A1", latitude: 50.827, longitude: 4.372 },
        c2: { id: "c2", name: "A2", latitude: 50.828, longitude: 4.373 },
        c3: { id: "c3", name: "A3", latitude: 50.829, longitude: 4.374 },
        c4: { id: "c4", name: "A4", latitude: 50.830, longitude: 4.375 },
        c5: { id: "c5", name: "B1", latitude: 50.858, longitude: 4.368 },
        c6: { id: "c6", name: "B2", latitude: 50.859, longitude: 4.369 },
        c7: { id: "c7", name: "B3", latitude: 50.860, longitude: 4.370 },
        c8: { id: "c8", name: "B4", latitude: 50.861, longitude: 4.371 },
      },
    };

    const result = await callWith(matchCohouses, { gameId: "g2" });

    expect(result.success).toBe(true);
    expect(result.groupCount).toBe(2);
    expect(result.groups).toHaveLength(2);

    // All 8 IDs present
    const allIds = result.groups.flat().sort();
    expect(allIds).toEqual(["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8"]);
  });
});
