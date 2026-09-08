import assert from "node:assert/strict";
import {
  PackageError,
  type Plan,
  planPersonas,
  type SecretReceipt,
  type Snapshot,
} from "./e2-r01-auth-personas.ts";
import {
  type SecretStoreInvoker,
  type SecretStoreRequest,
  windowsPersonaSecretStore,
} from "./e2-r01-auth-personas-secrets.ts";

// Offline protocol tests with an injected invoker. They do not execute
// PowerShell, inspect ACLs or prove encrypted durable storage on Windows.
const roleA = "11111111-1111-4111-8111-111111111111";
const roleB = "22222222-2222-4222-8222-222222222222";
const directory = "C:/Users/adrie/AppData/Local/CoeloSyntheticSecretTests";
const normalizedDirectory = directory.replaceAll("/", "\\");
const powerShellPath = "C:/Program Files/PowerShell/7/pwsh.exe";
function plan(): Plan {
  const now = new Date("2026-09-08T20:00:00Z");
  const snapshot: Snapshot = {
    capturedAt: now.toISOString(),
    projectRef: "abcdefghijklmnopqrst",
    activeOwners: 2,
    internalSchemaPresent: true,
    denialPermissionPresent: true,
    collidingEmails: [],
    collidingSlugs: [],
    collidingTypeCodes: [],
    roles: [
      {
        id: roleA,
        code: "operations",
        status: "active",
        maxScopeKind: "platform",
        permissions: ["platform.read", "institution.update"],
      },
      {
        id: roleB,
        code: "auditor",
        status: "active",
        maxScopeKind: "platform",
        permissions: ["platform.read", "audit.read"],
      },
    ],
  };
  return planPersonas(snapshot, { operations: roleA, noCap: roleB }, now);
}

Deno.test("secret-store protocol reads a missing nominal receipt through its injected invoker", async () => {
  const p = plan();
  const requests: SecretStoreRequest[] = [];
  const invoke: SecretStoreInvoker = (request) => {
    requests.push(structuredClone(request));
    return Promise.resolve({
      version: 1,
      ok: true,
      operation: "read",
      planId: p.id,
      authUserId: request.authUserId,
      receipt: null,
    });
  };
  const store = windowsPersonaSecretStore({
    plan: p,
    directory,
    powerShellPath,
  }, invoke);
  assert.equal(await store.read(p.personas[0].authUserId), null);
  assert.deepEqual(requests, [{
    version: 1,
    operation: "read",
    directory: normalizedDirectory,
    planId: p.id,
    authUserId: p.personas[0].authUserId,
  }]);
});

const syntheticPassword = "SYNTHETIC_ONLY_PASSWORD_1234567890_abcd";
function receipt(p: Plan): SecretReceipt {
  return {
    planId: p.id,
    authUserId: p.personas[0].authUserId,
    password: syntheticPassword,
    state: "reserved",
  };
}
function acknowledge(request: SecretStoreRequest) {
  return {
    version: 1,
    ok: true,
    operation: request.operation,
    planId: request.planId,
    authUserId: request.authUserId,
    ...(request.operation === "read" ? { receipt: null } : {}),
  };
}
class Invoker {
  requests: SecretStoreRequest[] = [];
  response: (request: SecretStoreRequest) => unknown = acknowledge;
  failure: Error | undefined;
  invoke: SecretStoreInvoker = (request) => {
    this.requests.push(structuredClone(request));
    if (this.failure) return Promise.reject(this.failure);
    return Promise.resolve(this.response(request));
  };
}
function storeFor(p: Plan, invoker: Invoker) {
  return windowsPersonaSecretStore(
    { plan: p, directory, powerShellPath },
    invoker.invoke,
  );
}
async function sanitizedFailure(operation: () => unknown | Promise<unknown>) {
  let caught: unknown;
  try {
    await operation();
  } catch (error) {
    caught = error;
  }
  assert(caught instanceof PackageError, "expected a sanitized PackageError");
  assert(!String(caught).includes(syntheticPassword));
  assert(!JSON.stringify(caught).includes(syntheticPassword));
  assert(!caught.stack?.includes(syntheticPassword));
  assert.equal(caught.cause, undefined);
}

Deno.test("secret-store protocol reserves once and marks created without a password in the acknowledgement", async () => {
  const p = plan();
  const invoker = new Invoker();
  const store = storeFor(p, invoker);
  const pending = receipt(p);
  assert.equal(await store.reserve(pending), undefined);
  assert.equal(await store.markCreated(pending.authUserId), undefined);
  assert.deepEqual(invoker.requests, [
    {
      version: 1,
      operation: "reserve",
      directory: normalizedDirectory,
      planId: p.id,
      authUserId: pending.authUserId,
      receipt: pending,
    },
    {
      version: 1,
      operation: "mark-created",
      directory: normalizedDirectory,
      planId: p.id,
      authUserId: pending.authUserId,
    },
  ]);
  assert(!JSON.stringify(invoker.requests[1]).includes(syntheticPassword));
});

Deno.test("secret-store protocol reads reserved and created receipts with boundary-length passwords", async () => {
  const p = plan();
  for (const state of ["reserved", "created"] as const) {
    for (const length of [32, 256]) {
      const expected = { ...receipt(p), state, password: "x".repeat(length) };
      const invoker = new Invoker();
      invoker.response = (request) => ({
        ...acknowledge(request),
        receipt: expected,
      });
      const actual = await storeFor(p, invoker).read(expected.authUserId);
      assert.deepEqual(actual, expected);
      assert.equal(invoker.requests.length, 1);
    }
  }
});

Deno.test("secret-store protocol rejects non-nominal account IDs before any invocation", async () => {
  const p = plan();
  for (
    const id of [
      crypto.randomUUID(),
      "",
      "not-a-uuid",
      "../receipt",
      syntheticPassword,
    ]
  ) {
    const invoker = new Invoker();
    const store = storeFor(p, invoker);
    await sanitizedFailure(() => store.read(id));
    await sanitizedFailure(() => store.markCreated(id));
    await sanitizedFailure(() =>
      store.reserve({ ...receipt(p), authUserId: id })
    );
    assert.equal(invoker.requests.length, 0);
  }
  const invoker = new Invoker();
  const store = storeFor(p, invoker);
  for (const item of p.personas) {
    assert.equal(await store.read(item.authUserId), null);
  }
  assert.equal(invoker.requests.length, 5);
});

Deno.test("secret-store protocol validates complete context and local absolute Windows paths before invocation", async () => {
  const p = plan();
  const invalidPaths = [
    "relative/secrets",
    "C:relative",
    "/tmp/secrets",
    "\\\\server\\share\\secrets",
    "\\\\?\\C:\\secrets",
    "\\\\.\\C:\\secrets",
    "C:/secrets\nother",
    "C:/secrets\0other",
  ];
  for (const value of invalidPaths) {
    for (const field of ["directory", "powerShellPath"] as const) {
      const invoker = new Invoker();
      await sanitizedFailure(async () => {
        const store = windowsPersonaSecretStore({
          plan: p,
          directory,
          powerShellPath,
          [field]: value,
        }, invoker.invoke);
        await store.read(p.personas[0].authUserId);
      });
      assert.equal(invoker.requests.length, 0);
    }
  }
  const invalidPlan = structuredClone(p);
  invalidPlan.personas[0].institutionId = p.institutions[1].id;
  const invoker = new Invoker();
  await sanitizedFailure(async () => {
    const store = storeFor(invalidPlan, invoker);
    await store.read(p.personas[0].authUserId);
  });
  assert.equal(invoker.requests.length, 0);
});

Deno.test("secret-store protocol rejects tampered or non-reserved reservation receipts before invocation", async () => {
  const p = plan();
  const base = receipt(p);
  const invalid: unknown[] = [
    null,
    {},
    JSON.stringify(base),
    { ...base, planId: roleA },
    { ...base, state: "created" },
    { ...base, state: "unknown" },
    { ...base, extra: true },
    { ...base, password: true },
  ];
  for (
    const password of [
      "x".repeat(31),
      "x".repeat(257),
      "x".repeat(32) + "\n",
      "x".repeat(32) + "\r",
      "x".repeat(32) + "\0",
      "x".repeat(32) + "\t",
      "x".repeat(32) + "\x7f",
    ]
  ) invalid.push({ ...base, password });
  for (const value of invalid) {
    const invoker = new Invoker();
    await sanitizedFailure(() =>
      storeFor(p, invoker).reserve(value as SecretReceipt)
    );
    assert.equal(invoker.requests.length, 0);
  }
});

Deno.test("secret-store protocol rejects malformed envelopes, extra fields and mismatched echoed identities", async () => {
  const p = plan();
  for (const operation of ["read", "reserve", "mark-created"] as const) {
    for (
      const malformed of [
        "null",
        "string",
        "array",
        "missing-version",
        "wrong-version",
        "string-ok",
        "false-ok",
        "operation",
        "plan",
        "account",
        "extra",
        "receipt-shape",
      ]
    ) {
      const invoker = new Invoker();
      invoker.response = (request) => {
        const valid: Record<string, unknown> = acknowledge(request);
        switch (malformed) {
          case "null":
            return null;
          case "string":
            return JSON.stringify(valid);
          case "array":
            return [valid];
          case "missing-version":
            delete valid.version;
            break;
          case "wrong-version":
            valid.version = "1";
            break;
          case "string-ok":
            valid.ok = "true";
            break;
          case "false-ok":
            valid.ok = false;
            break;
          case "operation":
            valid.operation = request.operation === "read" ? "reserve" : "read";
            break;
          case "plan":
            valid.planId = roleA;
            break;
          case "account":
            valid.authUserId = p.personas[1].authUserId;
            break;
          case "extra":
            valid.extra = syntheticPassword;
            break;
          case "receipt-shape":
            if (operation === "read") delete valid.receipt;
            else valid.receipt = null;
            break;
        }
        return valid;
      };
      const store = storeFor(p, invoker);
      await sanitizedFailure(() =>
        operation === "read"
          ? store.read(p.personas[0].authUserId)
          : operation === "reserve"
          ? store.reserve(receipt(p))
          : store.markCreated(p.personas[0].authUserId)
      );
      assert.equal(invoker.requests.length, 1);
    }
  }
});

Deno.test("secret-store protocol rejects read receipts with mismatched plan account state or password", async () => {
  const p = plan();
  const base = receipt(p);
  for (
    const invalid of [
      { ...base, planId: roleA },
      { ...base, authUserId: p.personas[1].authUserId },
      { ...base, state: "revoked" },
      { ...base, password: "short" },
      { ...base, password: "x".repeat(257) },
      { ...base, password: "x".repeat(32) + "\0" },
      { ...base, extra: syntheticPassword },
      JSON.stringify(base),
      {},
      [],
    ]
  ) {
    const invoker = new Invoker();
    invoker.response = (request) => ({
      ...acknowledge(request),
      receipt: invalid,
    });
    await sanitizedFailure(() => storeFor(p, invoker).read(base.authUserId));
    assert.equal(invoker.requests.length, 1);
  }
});

Deno.test("secret-store protocol snapshots caller context and keeps all subsequent requests nominal", async () => {
  const p = plan();
  const original = structuredClone(p);
  const context = { plan: p, directory, powerShellPath };
  const invoker = new Invoker();
  const store = windowsPersonaSecretStore(context, invoker.invoke);
  p.id = crypto.randomUUID();
  p.personas[0].authUserId = crypto.randomUUID();
  context.directory = "D:/another-secret-location";
  context.powerShellPath = "D:/another-executable.exe";
  assert.equal(await store.read(original.personas[0].authUserId), null);
  assert.equal(invoker.requests[0].planId, original.id);
  assert.equal(invoker.requests[0].directory, normalizedDirectory);
  await sanitizedFailure(() => store.read(p.personas[0].authUserId));
  assert.equal(invoker.requests.length, 1);
});

Deno.test("secret-store protocol preserves the nominal reservation but rejects caller mutation and requires explicit reconciliation", async () => {
  const p = plan();
  const pendingReceipt = receipt(p);
  const original = structuredClone(pendingReceipt);
  let requestSeen!: SecretStoreRequest;
  const operations: string[] = [];
  let release!: (value: unknown) => void;
  const deferred = new Promise<unknown>((resolve) => release = resolve);
  const store = windowsPersonaSecretStore({
    plan: p,
    directory,
    powerShellPath,
  }, (request) => {
    operations.push(request.operation);
    if (request.operation === "read") {
      return Promise.resolve({ ...acknowledge(request), receipt: original });
    }
    requestSeen = request;
    return deferred;
  });
  const pending = store.reserve(pendingReceipt);
  pendingReceipt.planId = crypto.randomUUID();
  pendingReceipt.password = "changed-after-invocation";
  assert.deepEqual(requestSeen.receipt, original);
  release(acknowledge(requestSeen));
  await sanitizedFailure(() => pending);
  assert.deepEqual(await store.read(original.authUserId), original);
  assert.deepEqual(operations, ["reserve", "read"]);
});

Deno.test("secret-store protocol sanitizes ambiguous helper errors and never retries a read reserve or mark", async () => {
  const p = plan();
  for (const operation of ["read", "reserve", "mark-created"] as const) {
    const invoker = new Invoker();
    invoker.failure = new Error(
      `synthetic helper lost response ${syntheticPassword}`,
    );
    const store = storeFor(p, invoker);
    await sanitizedFailure(() =>
      operation === "read"
        ? store.read(p.personas[0].authUserId)
        : operation === "reserve"
        ? store.reserve(receipt(p))
        : store.markCreated(p.personas[0].authUserId)
    );
    assert.equal(invoker.requests.length, 1);
    assert.equal(invoker.requests[0].operation, operation);
  }
});
