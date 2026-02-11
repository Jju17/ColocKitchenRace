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
          empty: docs.length === 0,
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
    {
      FieldValue: { serverTimestamp: jest.fn(() => "SERVER_TIMESTAMP"), delete: jest.fn(() => "FIELD_DELETE") },
      FieldPath: { documentId: jest.fn(() => "__doc_id__") },
    }
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
  getCohousesForMap,
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

  it("returns success false with message when cohouse has no users", async () => {
    firestoreSubcollections = { cohouses: { c1: { users: [] } } };

    const result = await callWith(
      sendNotificationToCohouse,
      { cohouseId: "c1", notification: { title: "Hi", body: "Msg" } }
    );

    expect(result.success).toBe(false);
    expect(result.totalUsers).toBe(0);
    expect(result.sent).toBe(0);
    expect(result.message).toMatch(/no users found/i);
  });

  it("returns success false with message when FCM delivery fails", async () => {
    firestoreSubcollections = {
      cohouses: { c1: { users: [{ userId: "u1" }] } },
    };
    firestoreData = {
      users: {
        u1: { id: "u1", fcmToken: "tok1" },
      },
    };

    mockSendEachForMulticast.mockResolvedValueOnce({
      successCount: 0,
      failureCount: 1,
      responses: [{ success: false, error: { code: "messaging/invalid-registration-token" } }],
    });

    const result = await callWith(
      sendNotificationToCohouse,
      { cohouseId: "c1", notification: { title: "Hi", body: "Msg" } }
    );

    expect(result.success).toBe(false);
    expect(result.sent).toBe(0);
    expect(result.failed).toBe(1);
    expect(result.message).toMatch(/delivery failure/i);
  });

  it("returns success false with message when users have no FCM tokens", async () => {
    firestoreSubcollections = {
      cohouses: { c1: { users: [{ userId: "u1" }, { userId: "u2" }] } },
    };
    firestoreData = {
      users: {
        u1: { id: "u1" },
        u2: { id: "u2" },
      },
    };

    const result = await callWith(
      sendNotificationToCohouse,
      { cohouseId: "c1", notification: { title: "Hi", body: "Msg" } }
    );

    expect(result.success).toBe(false);
    expect(result.totalUsers).toBe(2);
    expect(result.sent).toBe(0);
    expect(result.message).toMatch(/push notifications enabled/i);
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

  it("returns success false with message when no participants", async () => {
    firestoreData = { ckrGames: { e1: { participantsID: [] } } };

    const result = await callWith(
      sendNotificationToEdition,
      { editionId: "e1", notification: { title: "T", body: "B" } }
    );

    expect(result.success).toBe(false);
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
    firestoreData = {
      ckrGames: { g1: { participantsID: ["c1", "c2", "c3", "c4", "c5"] } },
      cohouses: {
        c1: { id: "c1", name: "A", latitude: 50.850, longitude: 4.350 },
        c2: { id: "c2", name: "B", latitude: 50.851, longitude: 4.351 },
        c3: { id: "c3", name: "C", latitude: 50.852, longitude: 4.352 },
        c4: { id: "c4", name: "D", latitude: 50.853, longitude: 4.353 },
        c5: { id: "c5", name: "E", latitude: 50.854, longitude: 4.354 },
      },
    };
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
    expect(result.removedOrphanedIds).toEqual([]);

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

  it("cleans up orphaned IDs and continues matching with remaining cohouses", async () => {
    // 6 participants in game, but c5 and c6 have been deleted from Firestore
    firestoreData = {
      ckrGames: { g3: { participantsID: ["c1", "c2", "c3", "c4", "c5", "c6"] } },
      cohouses: {
        c1: { id: "c1", name: "A", latitude: 50.850, longitude: 4.350 },
        c2: { id: "c2", name: "B", latitude: 50.851, longitude: 4.351 },
        c3: { id: "c3", name: "C", latitude: 50.852, longitude: 4.352 },
        c4: { id: "c4", name: "D", latitude: 50.853, longitude: 4.353 },
        // c5 and c6 are missing (deleted)
      },
    };

    const result = await callWith(matchCohouses, { gameId: "g3" });

    expect(result.success).toBe(true);
    expect(result.groupCount).toBe(1);
    expect(result.groups).toHaveLength(1);
    expect(result.groups[0].sort()).toEqual(["c1", "c2", "c3", "c4"]);
    expect(result.removedOrphanedIds.sort()).toEqual(["c5", "c6"]);

    // Verify participantsID was cleaned up and old matching was cleared
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        participantsID: ["c1", "c2", "c3", "c4"],
        matchedGroups: "FIELD_DELETE",
        matchedAt: "FIELD_DELETE",
      })
    );
  });

  it("cleans up orphaned IDs and throws when remaining count is not enough", async () => {
    // 5 participants, but c4 and c5 deleted → only 3 remain → less than 4
    firestoreData = {
      ckrGames: { g4: { participantsID: ["c1", "c2", "c3", "c4", "c5"] } },
      cohouses: {
        c1: { id: "c1", name: "A", latitude: 50.850, longitude: 4.350 },
        c2: { id: "c2", name: "B", latitude: 50.851, longitude: 4.351 },
        c3: { id: "c3", name: "C", latitude: 50.852, longitude: 4.352 },
        // c4 and c5 deleted
      },
    };

    await expect(
      callWith(matchCohouses, { gameId: "g4" })
    ).rejects.toThrow(/at least 4/i);

    // Verify participantsID was cleaned up and old matching was cleared
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        participantsID: ["c1", "c2", "c3"],
        matchedGroups: "FIELD_DELETE",
        matchedAt: "FIELD_DELETE",
      })
    );
  });

  it("cleans up orphaned IDs and throws when remaining count is not multiple of 4", async () => {
    // 9 participants, but c8 and c9 deleted → 7 remain → not multiple of 4
    firestoreData = {
      ckrGames: { g6: { participantsID: ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9"] } },
      cohouses: {
        c1: { id: "c1", name: "A", latitude: 50.850, longitude: 4.350 },
        c2: { id: "c2", name: "B", latitude: 50.851, longitude: 4.351 },
        c3: { id: "c3", name: "C", latitude: 50.852, longitude: 4.352 },
        c4: { id: "c4", name: "D", latitude: 50.853, longitude: 4.353 },
        c5: { id: "c5", name: "E", latitude: 50.854, longitude: 4.354 },
        c6: { id: "c6", name: "F", latitude: 50.855, longitude: 4.355 },
        c7: { id: "c7", name: "G", latitude: 50.856, longitude: 4.356 },
        // c8 and c9 deleted
      },
    };

    await expect(
      callWith(matchCohouses, { gameId: "g6" })
    ).rejects.toThrow(/multiple of 4/i);

    // Verify participantsID was cleaned up and old matching was cleared
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        participantsID: ["c1", "c2", "c3", "c4", "c5", "c6", "c7"],
        matchedGroups: "FIELD_DELETE",
        matchedAt: "FIELD_DELETE",
      })
    );
  });

  it("cleans up and throws when all cohouses are orphaned", async () => {
    firestoreData = {
      ckrGames: { g5: { participantsID: ["c1", "c2", "c3", "c4"] } },
      cohouses: {
        // All cohouses deleted from Firestore
      },
    };

    await expect(
      callWith(matchCohouses, { gameId: "g5" })
    ).rejects.toThrow(/no cohouses remaining/i);

    // Verify participantsID was cleaned to empty and old matching was cleared
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        participantsID: [],
        matchedGroups: "FIELD_DELETE",
        matchedAt: "FIELD_DELETE",
      })
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// getCohousesForMap
// ═══════════════════════════════════════════════════════════════════════════════

describe("getCohousesForMap", () => {
  it("throws invalid-argument when cohouseIds missing", async () => {
    await expect(
      callWith(getCohousesForMap, { cohouseIds: [] })
    ).rejects.toThrow(/invalid-argument|missing/i);
  });

  it("returns cohouse data with user names", async () => {
    firestoreData = {
      cohouses: {
        c1: { id: "c1", name: "Les Fous", latitude: 50.850, longitude: 4.350 },
        c2: { id: "c2", name: "Zone 88", latitude: 50.852, longitude: 4.352 },
      },
    };
    firestoreSubcollections = {
      cohouses: {
        c1: { users: [{ firstName: "Alice", lastName: "Dupont" }, { firstName: "Bob", lastName: "Martin" }] },
        c2: { users: [{ firstName: "Charlie", lastName: "Leclerc" }] },
      },
    };

    const result = await callWith(getCohousesForMap, { cohouseIds: ["c1", "c2"] });

    expect(result.success).toBe(true);
    expect(result.cohouses).toHaveLength(2);

    const c1 = result.cohouses.find((c: any) => c.id === "c1");
    expect(c1).toBeDefined();
    expect(c1.name).toBe("Les Fous");
    expect(c1.latitude).toBe(50.850);
    expect(c1.longitude).toBe(4.350);
    expect(c1.userNames).toEqual(["Alice Dupont", "Bob Martin"]);

    const c2 = result.cohouses.find((c: any) => c.id === "c2");
    expect(c2).toBeDefined();
    expect(c2.name).toBe("Zone 88");
    expect(c2.userNames).toEqual(["Charlie Leclerc"]);
  });

  it("skips cohouses without GPS coordinates", async () => {
    firestoreData = {
      cohouses: {
        c1: { id: "c1", name: "Has GPS", latitude: 50.850, longitude: 4.350 },
        c2: { id: "c2", name: "No GPS" },
      },
    };
    firestoreSubcollections = {
      cohouses: {
        c1: { users: [] },
        c2: { users: [] },
      },
    };

    const result = await callWith(getCohousesForMap, { cohouseIds: ["c1", "c2"] });

    expect(result.success).toBe(true);
    expect(result.cohouses).toHaveLength(1);
    expect(result.cohouses[0].id).toBe("c1");
  });
});
