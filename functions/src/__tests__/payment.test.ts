/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Unit tests for the payment & registration flow:
 * - reserveAndCreatePayment (payment.ts)
 * - confirmRegistration (registration.ts)
 * - releaseExpiredReservation (cleanup.ts)
 *
 * Strategy: mock firebase-admin (Firestore, Auth) and Stripe at the module
 * level, then test the wrapped callable/task handlers directly.
 *
 * Firestore transactions are simulated by executing the callback immediately
 * with a mock transaction object that reads from / writes to `firestoreData`.
 */

// ── In-memory Firestore state ────────────────────────────────────────────────

let firestoreData: Record<string, Record<string, any>> = {};

/**
 * Tracks all writes that happened inside (or outside) transactions so that
 * assertions can verify what was persisted.
 */
const writtenDocs: Record<string, any> = {};
const deletedDocs: Set<string> = new Set();
const updatedFields: Record<string, any> = {};

// ── Mock helpers ─────────────────────────────────────────────────────────────

void updatedFields; // referenced below; keep the variable live

/**
 * Resolve a Firestore-like path ("ckrGames/g1" or "ckrGames/g1/registrations/c1")
 * from firestoreData.
 */
function resolveDoc(path: string): any {
  // path = "collection/docId" or "collection/docId/subcol/subDocId"
  const parts = path.split("/");
  if (parts.length === 2) {
    return firestoreData[parts[0]]?.[parts[1]] ?? null;
  }
  if (parts.length === 4) {
    // nested: look up "collection/docId/subcol" as a virtual collection key
    const key = `${parts[0]}/${parts[1]}/${parts[2]}`;
    return firestoreData[key]?.[parts[3]] ?? null;
  }
  return null;
}

function setDoc(path: string, data: any) {
  const parts = path.split("/");
  if (parts.length === 2) {
    if (!firestoreData[parts[0]]) firestoreData[parts[0]] = {};
    firestoreData[parts[0]][parts[1]] = data;
  } else if (parts.length === 4) {
    const key = `${parts[0]}/${parts[1]}/${parts[2]}`;
    if (!firestoreData[key]) firestoreData[key] = {};
    firestoreData[key][parts[3]] = data;
  }
  writtenDocs[path] = data;
}

function removeDoc(path: string) {
  const parts = path.split("/");
  if (parts.length === 2) {
    delete firestoreData[parts[0]]?.[parts[1]];
  } else if (parts.length === 4) {
    const key = `${parts[0]}/${parts[1]}/${parts[2]}`;
    delete firestoreData[key]?.[parts[3]];
  }
  deletedDocs.add(path);
}

/** Build a doc ref that reads from / writes to firestoreData. */
function makeDocRef(path: string): any {
  return {
    get: jest.fn().mockImplementation(async () => {
      const data = resolveDoc(path);
      const docId = path.split("/").pop()!;
      return { exists: data != null, data: () => data, id: docId, ref: makeDocRef(path) };
    }),
    set: jest.fn().mockImplementation(async (data: any) => {
      setDoc(path, data);
    }),
    update: jest.fn().mockImplementation(async (data: any) => {
      const existing = resolveDoc(path) || {};
      // Handle FieldValue.delete() — remove keys whose value is "FIELD_DELETE"
      const merged = { ...existing };
      for (const [k, v] of Object.entries(data)) {
        if (v === "FIELD_DELETE") {
          delete merged[k];
        } else {
          merged[k] = v;
        }
      }
      setDoc(path, merged);
    }),
    delete: jest.fn().mockImplementation(async () => {
      removeDoc(path);
    }),
    collection: jest.fn().mockImplementation((subName: string) => {
      const subPath = `${path}/${subName}`;
      return {
        doc: jest.fn().mockImplementation((subDocId: string) =>
          makeDocRef(`${subPath}/${subDocId}`)
        ),
        get: jest.fn().mockImplementation(async () => {
          const col = firestoreData[subPath] || {};
          const entries = Object.entries(col);
          return {
            empty: entries.length === 0,
            docs: entries.map(([id, d]) => ({
              data: () => d,
              id,
              ref: makeDocRef(`${subPath}/${id}`),
            })),
          };
        }),
        where: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
      };
    }),
    path,
  };
}

function makeCollection(name: string) {
  const filters: Array<{ field: string; op: string; value: any }> = [];

  const query: any = {
    doc: jest.fn().mockImplementation((id: string) => makeDocRef(`${name}/${id}`)),
    where: jest.fn().mockImplementation((field: string, op: string, value: any) => {
      filters.push({ field, op, value });
      return query;
    }),
    limit: jest.fn().mockReturnValue(null as any),
    get: jest.fn().mockImplementation(async () => {
      const allDocs = firestoreData[name] || {};
      let entries = Object.entries(allDocs);

      for (const f of filters) {
        if (f.op === "==") {
          entries = entries.filter(([, d]) => (d as any)[f.field] === f.value);
        } else if (f.op === "in") {
          entries = entries.filter(([, d]) =>
            (f.value as any[]).includes((d as any)[f.field])
          );
        }
      }

      return {
        empty: entries.length === 0,
        docs: entries.map(([id, data]) => ({
          data: () => data,
          id,
          ref: makeDocRef(`${name}/${id}`),
        })),
      };
    }),
  };

  query.limit.mockReturnValue(query);
  return query;
}

/**
 * Build a mock transaction that delegates reads/writes to firestoreData.
 * Transaction.get() returns the current state, and set/update/delete mutate
 * firestoreData directly (sufficient for unit-test purposes).
 */
function makeMockTransaction() {
  const tx: any = {
    get: jest.fn().mockImplementation(async (ref: any) => {
      const data = resolveDoc(ref.path);
      const docId = ref.path.split("/").pop()!;
      return { exists: data != null, data: () => data, id: docId, ref };
    }),
    set: jest.fn().mockImplementation((ref: any, data: any) => {
      setDoc(ref.path, data);
    }),
    update: jest.fn().mockImplementation((ref: any, data: any) => {
      const existing = resolveDoc(ref.path) || {};
      const merged = { ...existing };
      for (const [k, v] of Object.entries(data)) {
        if (v === "FIELD_DELETE") {
          delete merged[k];
        } else {
          merged[k] = v;
        }
      }
      setDoc(ref.path, merged);
    }),
    delete: jest.fn().mockImplementation((ref: any) => {
      removeDoc(ref.path);
    }),
  };
  return tx;
}

// ── Mock firebase-admin ──────────────────────────────────────────────────────

const mockGetUser = jest.fn();

jest.mock("firebase-admin", () => ({
  initializeApp: jest.fn(),
  firestore: Object.assign(
    jest.fn(() => ({
      collection: jest.fn().mockImplementation((name: string) => makeCollection(name)),
      runTransaction: jest.fn().mockImplementation(async (cb: any) => {
        const tx = makeMockTransaction();
        return cb(tx);
      }),
      batch: jest.fn().mockImplementation(() => ({
        delete: jest.fn(),
        commit: jest.fn().mockResolvedValue(undefined),
      })),
    })),
    {
      FieldValue: {
        serverTimestamp: jest.fn(() => "SERVER_TIMESTAMP"),
        delete: jest.fn(() => "FIELD_DELETE"),
        arrayUnion: jest.fn((...args: any[]) => args),
        arrayRemove: jest.fn((...args: any[]) => ({ __arrayRemove: args })),
        increment: jest.fn((n: number) => ({ __increment: n })),
      },
      FieldPath: { documentId: jest.fn(() => "__doc_id__") },
      Timestamp: {
        fromDate: (d: Date) => ({
          toDate: () => d,
          _seconds: Math.floor(d.getTime() / 1000),
          _nanoseconds: 0,
        }),
      },
    }
  ),
  messaging: jest.fn(() => ({
    sendEachForMulticast: jest.fn().mockResolvedValue({ successCount: 1 }),
    send: jest.fn().mockResolvedValue("mock-msg"),
  })),
  auth: jest.fn(() => ({
    getUser: mockGetUser,
  })),
}));

// ── Mock rate-limiter (bypass in tests) ───────────────────────────────────────

jest.mock("../rate-limiter", () => ({
  checkRateLimit: jest.fn(),
}));

// ── Mock firebase-admin/functions (Cloud Tasks) ──────────────────────────────

const mockEnqueue = jest.fn().mockResolvedValue(undefined);

jest.mock("firebase-admin/functions", () => ({
  getFunctions: jest.fn(() => ({
    taskQueue: jest.fn(() => ({
      enqueue: mockEnqueue,
    })),
  })),
}));

// ── Mock Stripe ──────────────────────────────────────────────────────────────

const mockStripeCustomersCreate = jest.fn();
const mockStripeEphemeralKeysCreate = jest.fn();
const mockStripePaymentIntentsCreate = jest.fn();
const mockStripePaymentIntentsRetrieve = jest.fn();
const mockStripeRefundsCreate = jest.fn();

// Set a dummy STRIPE_SECRET_KEY so getStripe() doesn't throw
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

const mockStripeInstance = {
  customers: { create: mockStripeCustomersCreate },
  ephemeralKeys: { create: mockStripeEphemeralKeysCreate },
  paymentIntents: {
    create: mockStripePaymentIntentsCreate,
    retrieve: mockStripePaymentIntentsRetrieve,
  },
  refunds: { create: mockStripeRefundsCreate },
};

// Stripe is imported as `import Stripe from "stripe"` and used as `new Stripe(...)`.
// ts-jest transpiles the default import to `stripe_1.default`, so we need
// __esModule + default to make the constructor available.
jest.mock("stripe", () => ({
  __esModule: true,
  default: jest.fn().mockImplementation(() => mockStripeInstance),
}));

// ── Import functions under test ──────────────────────────────────────────────

import * as functionsTest from "firebase-functions-test";
const testEnv = functionsTest();

import { reserveAndCreatePayment } from "../payment";
import { confirmRegistration } from "../registration";
import { releaseExpiredReservation } from "../cleanup";

// ── Helpers ──────────────────────────────────────────────────────────────────

function resetState() {
  firestoreData = {};
  Object.keys(writtenDocs).forEach((k) => delete writtenDocs[k]);
  deletedDocs.clear();
  Object.keys(updatedFields).forEach((k) => delete updatedFields[k]);
}

/** Call a callable function with standard auth. */
function callWith(fn: any, data: any) {
  const wrapped = testEnv.wrap(fn);
  return wrapped({ data, auth: { uid: "test-user", token: {} } } as any);
}

/** Call a task-dispatched function (no auth wrapper). */
function dispatchTask(fn: any, data: any) {
  const wrapped = testEnv.wrap(fn);
  return wrapped({ data } as any);
}

/**
 * Create a Firestore Timestamp-like object for a given date.
 */
function makeTimestamp(date: Date) {
  return {
    toDate: () => date,
    _seconds: Math.floor(date.getTime() / 1000),
    _nanoseconds: 0,
  };
}

/** Default valid request data for reserveAndCreatePayment. */
function makeReserveRequest(overrides: Record<string, any> = {}) {
  return {
    gameId: "game1",
    cohouseId: "cohouse1",
    amountCents: 1000, // 2 persons * 500 cents
    participantCount: 2,
    attendingUserIds: ["u1", "u2"],
    averageAge: 25,
    cohouseType: "coloc",
    ...overrides,
  };
}

/** Seed firestoreData with a valid game + cohouse for reservation. */
function seedGameAndCohouse(overrides: {
  game?: Record<string, any>;
  cohouse?: Record<string, any>;
} = {}) {
  const futureDeadline = new Date(Date.now() + 24 * 60 * 60 * 1000); // +24h

  firestoreData["ckrGames"] = {
    game1: {
      pricePerPersonCents: 500,
      registrationDeadline: makeTimestamp(futureDeadline),
      cohouseIDs: [],
      maxParticipants: 100,
      totalRegisteredParticipants: 0,
      ...overrides.game,
    },
  };

  firestoreData["cohouses"] = {
    doc_cohouse1: {
      id: "cohouse1",
      name: "Test Cohouse",
      stripeCustomerId: "cus_existing123",
      ...overrides.cohouse,
    },
  };
}

/** Seed Stripe mocks with default success responses. */
function seedStripeMocks() {
  mockStripeCustomersCreate.mockResolvedValue({
    id: "cus_new123",
  });

  mockStripeEphemeralKeysCreate.mockResolvedValue({
    secret: "ek_test_secret",
  });

  mockStripePaymentIntentsCreate.mockResolvedValue({
    id: "pi_test123",
    client_secret: "pi_test123_secret_abc",
  });

  mockStripePaymentIntentsRetrieve.mockResolvedValue({
    id: "pi_test123",
    status: "succeeded",
    metadata: { gameId: "game1", cohouseId: "cohouse1" },
  });

  mockStripeRefundsCreate.mockResolvedValue({ id: "re_test123" });
}

// ── Setup / teardown ─────────────────────────────────────────────────────────

beforeEach(() => {
  jest.clearAllMocks();
  resetState();

  // Default: non-demo user
  mockGetUser.mockResolvedValue({ email: "normal@example.com" });

  seedStripeMocks();
});

afterAll(() => testEnv.cleanup());

// ═══════════════════════════════════════════════════════════════════════════════
// reserveAndCreatePayment
// ═══════════════════════════════════════════════════════════════════════════════

describe("reserveAndCreatePayment", () => {
  // ── Validation ─────────────────────────────────────────────────────────────

  it("throws invalid-argument when required fields are missing", async () => {
    await expect(
      callWith(reserveAndCreatePayment, { gameId: "", cohouseId: "" })
    ).rejects.toThrow(/invalid-argument|invalid request|required/i);
  });

  it("throws invalid-argument when participantCount does not match attendingUserIds length", async () => {
    seedGameAndCohouse();

    await expect(
      callWith(reserveAndCreatePayment, makeReserveRequest({
        participantCount: 3,
        attendingUserIds: ["u1", "u2"], // length 2 != participantCount 3
      }))
    ).rejects.toThrow(/participantCount.*does not match/i);
  });

  // ── Happy path ─────────────────────────────────────────────────────────────

  it("reserves a spot, creates Stripe PaymentIntent, and schedules cleanup task", async () => {
    seedGameAndCohouse();

    const result = await callWith(reserveAndCreatePayment, makeReserveRequest());

    // Returns Stripe data
    expect(result.clientSecret).toBe("pi_test123_secret_abc");
    expect(result.customerId).toBe("cus_existing123");
    expect(result.ephemeralKeySecret).toBe("ek_test_secret");
    expect(result.paymentIntentId).toBe("pi_test123");
    expect(result.remainingSpots).toBeDefined();

    // Stripe PaymentIntent was created with correct amount
    expect(mockStripePaymentIntentsCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        amount: 1000,
        currency: "eur",
        customer: "cus_existing123",
      })
    );

    // Cloud Task was scheduled for cleanup
    expect(mockEnqueue).toHaveBeenCalledWith(
      { gameId: "game1", cohouseId: "cohouse1" },
      { scheduleDelaySeconds: 900 } // 15 min
    );

    // Registration doc was written (check writtenDocs)
    const regDoc = writtenDocs["ckrGames/game1/registrations/cohouse1"];
    expect(regDoc).toBeDefined();
    expect(regDoc.status).toBe("pending");
    expect(regDoc.cohouseId).toBe("cohouse1");
    expect(regDoc.attendingUserIds).toEqual(["u1", "u2"]);
  });

  it("calculates remaining spots correctly", async () => {
    seedGameAndCohouse({
      game: {
        maxParticipants: 10,
        totalRegisteredParticipants: 6,
      },
    });

    const result = await callWith(reserveAndCreatePayment, makeReserveRequest());

    // 10 - (6 + 2) = 2 remaining
    expect(result.remainingSpots).toBe(2);
  });

  it("creates a new Stripe customer when cohouse has none", async () => {
    seedGameAndCohouse({
      cohouse: { stripeCustomerId: undefined },
    });

    mockStripeCustomersCreate.mockResolvedValue({ id: "cus_new456" });

    const result = await callWith(reserveAndCreatePayment, makeReserveRequest());

    // Should have created a new customer
    expect(mockStripeCustomersCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Test Cohouse",
        metadata: expect.objectContaining({ cohouseId: "cohouse1" }),
      })
    );

    expect(result.customerId).toBe("cus_new456");
  });

  // ── Capacity full ──────────────────────────────────────────────────────────

  it("throws failed-precondition when capacity is full", async () => {
    seedGameAndCohouse({
      game: {
        maxParticipants: 10,
        totalRegisteredParticipants: 9, // Only 1 spot left, requesting 2
      },
    });

    await expect(
      callWith(reserveAndCreatePayment, makeReserveRequest())
    ).rejects.toThrow(/maximum number of participants/i);
  });

  it("throws failed-precondition when exactly at capacity", async () => {
    seedGameAndCohouse({
      game: {
        maxParticipants: 10,
        totalRegisteredParticipants: 10,
      },
    });

    await expect(
      callWith(reserveAndCreatePayment, makeReserveRequest())
    ).rejects.toThrow(/maximum number of participants/i);
  });

  // ── Deadline passed ────────────────────────────────────────────────────────

  it("throws failed-precondition when registration deadline has passed", async () => {
    const pastDeadline = new Date(Date.now() - 60 * 1000); // 1 minute ago
    seedGameAndCohouse({
      game: { registrationDeadline: makeTimestamp(pastDeadline) },
    });

    await expect(
      callWith(reserveAndCreatePayment, makeReserveRequest())
    ).rejects.toThrow(/deadline has passed/i);
  });

  // ── Duplicate registration ─────────────────────────────────────────────────

  it("throws already-exists when cohouse is already registered", async () => {
    seedGameAndCohouse({
      game: { cohouseIDs: ["cohouse1"] }, // already in the list
    });

    await expect(
      callWith(reserveAndCreatePayment, makeReserveRequest())
    ).rejects.toThrow(/already registered/i);
  });

  // ── Amount mismatch ────────────────────────────────────────────────────────

  it("throws invalid-argument when amount does not match price * count", async () => {
    seedGameAndCohouse();

    await expect(
      callWith(reserveAndCreatePayment, makeReserveRequest({
        amountCents: 9999, // should be 500 * 2 = 1000
      }))
    ).rejects.toThrow(/amount mismatch/i);
  });

  // ── Game not found ─────────────────────────────────────────────────────────

  it("throws not-found when game does not exist", async () => {
    // Seed cohouse but no game
    firestoreData["cohouses"] = {
      doc_cohouse1: {
        id: "cohouse1",
        name: "Test Cohouse",
        stripeCustomerId: "cus_existing123",
      },
    };

    await expect(
      callWith(reserveAndCreatePayment, makeReserveRequest())
    ).rejects.toThrow(/not found/i);
  });

  // ── Stripe failure → rollback ──────────────────────────────────────────────

  it("rolls back reservation when Stripe PaymentIntent creation fails", async () => {
    seedGameAndCohouse();

    mockStripePaymentIntentsCreate.mockRejectedValue(new Error("Stripe is down"));

    await expect(
      callWith(reserveAndCreatePayment, makeReserveRequest())
    ).rejects.toThrow(/failed to create payment/i);
  });

  // ── Demo mode ──────────────────────────────────────────────────────────────

  it("bypasses Firestore validation for demo user", async () => {
    mockGetUser.mockResolvedValue({ email: "test_apple@colocskitchenrace.be" });

    // No game or cohouse data seeded — demo mode should skip validation
    const result = await callWith(reserveAndCreatePayment, makeReserveRequest());

    expect(result.clientSecret).toBeDefined();
    expect(result.customerId).toBeDefined();
    expect(result.paymentIntentId).toBeDefined();

    // Stripe customer was created with demo metadata
    expect(mockStripeCustomersCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Demo Cohouse",
        metadata: expect.objectContaining({ demo: "true" }),
      })
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// confirmRegistration
// ═══════════════════════════════════════════════════════════════════════════════

describe("confirmRegistration", () => {
  const confirmRequest = {
    gameId: "game1",
    cohouseId: "cohouse1",
    paymentIntentId: "pi_test123",
  };

  // ── Validation ─────────────────────────────────────────────────────────────

  it("throws invalid-argument when required fields are missing", async () => {
    await expect(
      callWith(confirmRegistration, { gameId: "", cohouseId: "", paymentIntentId: "" })
    ).rejects.toThrow(/invalid-argument|invalid request|required/i);
  });

  // ── Happy path ─────────────────────────────────────────────────────────────

  it("transitions registration from pending to confirmed", async () => {
    const reservedUntil = new Date(Date.now() + 10 * 60 * 1000); // 10 min from now

    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "pending",
        paymentIntentId: "pi_test123",
        reservedUntil: makeTimestamp(reservedUntil),
        reservedAt: "SERVER_TIMESTAMP",
        reservedBy: "test-user",
        cohouseId: "cohouse1",
        attendingUserIds: ["u1", "u2"],
      },
    };

    const result = await callWith(confirmRegistration, confirmRequest);

    expect(result.success).toBe(true);

    // Stripe payment was verified
    expect(mockStripePaymentIntentsRetrieve).toHaveBeenCalledWith("pi_test123");

    // Registration was updated to confirmed
    const updated = resolveDoc("ckrGames/game1/registrations/cohouse1");
    expect(updated).toBeDefined();
    expect(updated.status).toBe("confirmed");
    // Reservation fields should be removed
    expect(updated.reservedUntil).toBeUndefined();
    expect(updated.reservedAt).toBeUndefined();
    expect(updated.reservedBy).toBeUndefined();
  });

  // ── Expired TTL ────────────────────────────────────────────────────────────

  it("rejects when reservation TTL has expired", async () => {
    const expiredTime = new Date(Date.now() - 60 * 1000); // 1 min ago

    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "pending",
        paymentIntentId: "pi_test123",
        reservedUntil: makeTimestamp(expiredTime),
        reservedAt: "SERVER_TIMESTAMP",
        reservedBy: "test-user",
      },
    };

    await expect(
      callWith(confirmRegistration, confirmRequest)
    ).rejects.toThrow(/reservation has expired/i);
  });

  // ── Already confirmed (idempotent) ─────────────────────────────────────────

  it("returns success when registration is already confirmed (idempotent)", async () => {
    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "confirmed",
        paymentIntentId: "pi_test123",
        confirmedAt: "SERVER_TIMESTAMP",
      },
    };

    const result = await callWith(confirmRegistration, confirmRequest);

    expect(result.success).toBe(true);

    // No refund should have been issued
    expect(mockStripeRefundsCreate).not.toHaveBeenCalled();
  });

  // ── Registration not found ─────────────────────────────────────────────────

  it("throws not-found when registration does not exist", async () => {
    // No registration data seeded
    await expect(
      callWith(confirmRegistration, confirmRequest)
    ).rejects.toThrow(/not found/i);
  });

  // ── Payment not succeeded ──────────────────────────────────────────────────

  it("throws failed-precondition when Stripe payment has not succeeded", async () => {
    const reservedUntil = new Date(Date.now() + 10 * 60 * 1000);

    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "pending",
        paymentIntentId: "pi_test123",
        reservedUntil: makeTimestamp(reservedUntil),
      },
    };

    mockStripePaymentIntentsRetrieve.mockResolvedValue({
      id: "pi_test123",
      status: "requires_payment_method", // not succeeded
      metadata: { gameId: "game1", cohouseId: "cohouse1" },
    });

    await expect(
      callWith(confirmRegistration, confirmRequest)
    ).rejects.toThrow(/payment not completed/i);
  });

  // ── Payment metadata mismatch ──────────────────────────────────────────────

  it("throws invalid-argument when Stripe payment metadata does not match", async () => {
    const reservedUntil = new Date(Date.now() + 10 * 60 * 1000);

    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "pending",
        paymentIntentId: "pi_test123",
        reservedUntil: makeTimestamp(reservedUntil),
      },
    };

    mockStripePaymentIntentsRetrieve.mockResolvedValue({
      id: "pi_test123",
      status: "succeeded",
      metadata: { gameId: "wrong-game", cohouseId: "wrong-cohouse" },
    });

    await expect(
      callWith(confirmRegistration, confirmRequest)
    ).rejects.toThrow(/payment does not match/i);
  });

  // ── PaymentIntent ID mismatch ──────────────────────────────────────────────

  it("throws invalid-argument when paymentIntentId does not match stored one", async () => {
    const reservedUntil = new Date(Date.now() + 10 * 60 * 1000);

    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "pending",
        paymentIntentId: "pi_different_id", // stored ID is different
        reservedUntil: makeTimestamp(reservedUntil),
      },
    };

    await expect(
      callWith(confirmRegistration, confirmRequest)
    ).rejects.toThrow(/does not match the reservation/i);
  });

  // ── Demo mode ──────────────────────────────────────────────────────────────

  it("returns success directly for demo user without Stripe verification", async () => {
    mockGetUser.mockResolvedValue({ email: "test_apple@colocskitchenrace.be" });

    // No registration data needed for demo mode
    const result = await callWith(confirmRegistration, confirmRequest);

    expect(result.success).toBe(true);

    // Stripe should NOT have been called
    expect(mockStripePaymentIntentsRetrieve).not.toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// releaseExpiredReservation
// ═══════════════════════════════════════════════════════════════════════════════

describe("releaseExpiredReservation", () => {
  // ── Pending → released ─────────────────────────────────────────────────────

  it("deletes a pending registration and frees spots on the game", async () => {
    firestoreData["ckrGames"] = {
      game1: {
        cohouseIDs: ["cohouse1", "other"],
        totalRegisteredParticipants: 5,
      },
    };

    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "pending",
        cohouseId: "cohouse1",
        attendingUserIds: ["u1", "u2"],
      },
    };

    await dispatchTask(releaseExpiredReservation, {
      gameId: "game1",
      cohouseId: "cohouse1",
    });

    // Registration should be deleted
    expect(deletedDocs.has("ckrGames/game1/registrations/cohouse1")).toBe(true);

    // Game doc should have been updated to free spots
    const gamePath = "ckrGames/game1";
    const gameData = resolveDoc(gamePath);
    // The transaction.update was called with arrayRemove and increment
    // Since our mock applies these literally, verify the written data contains them
    expect(gameData.cohouseIDs).toEqual(
      expect.objectContaining({ __arrayRemove: ["cohouse1"] })
    );
    expect(gameData.totalRegisteredParticipants).toEqual(
      expect.objectContaining({ __increment: -2 })
    );
  });

  // ── Confirmed → no-op ─────────────────────────────────────────────────────

  it("does nothing when registration is already confirmed", async () => {
    firestoreData["ckrGames"] = {
      game1: {
        cohouseIDs: ["cohouse1"],
        totalRegisteredParticipants: 5,
      },
    };

    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "confirmed",
        cohouseId: "cohouse1",
        attendingUserIds: ["u1", "u2"],
      },
    };

    await dispatchTask(releaseExpiredReservation, {
      gameId: "game1",
      cohouseId: "cohouse1",
    });

    // Registration should NOT be deleted
    expect(deletedDocs.has("ckrGames/game1/registrations/cohouse1")).toBe(false);

    // Game doc should not have changed
    const gameData = resolveDoc("ckrGames/game1");
    expect(gameData.totalRegisteredParticipants).toBe(5);
  });

  // ── Already deleted → no-op ────────────────────────────────────────────────

  it("does nothing when registration has already been deleted", async () => {
    firestoreData["ckrGames"] = {
      game1: {
        cohouseIDs: [],
        totalRegisteredParticipants: 0,
      },
    };

    // No registration doc at all
    await dispatchTask(releaseExpiredReservation, {
      gameId: "game1",
      cohouseId: "cohouse1",
    });

    // No deletions or updates
    expect(deletedDocs.size).toBe(0);
  });

  // ── Game deleted → delete orphaned registration ────────────────────────────

  it("deletes orphaned registration when game no longer exists", async () => {
    // No game doc, but orphaned registration exists
    firestoreData["ckrGames/game1/registrations"] = {
      cohouse1: {
        status: "pending",
        cohouseId: "cohouse1",
        attendingUserIds: ["u1"],
      },
    };

    await dispatchTask(releaseExpiredReservation, {
      gameId: "game1",
      cohouseId: "cohouse1",
    });

    // Orphaned registration should be deleted
    expect(deletedDocs.has("ckrGames/game1/registrations/cohouse1")).toBe(true);
  });

  // ── Missing data → graceful return ─────────────────────────────────────────

  it("returns silently when gameId or cohouseId is missing", async () => {
    // Should not throw
    await dispatchTask(releaseExpiredReservation, {
      gameId: "",
      cohouseId: "",
    });

    expect(deletedDocs.size).toBe(0);
  });
});
