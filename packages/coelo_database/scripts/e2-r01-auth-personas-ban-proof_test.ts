import assert from "node:assert/strict";
import {
  PACKAGE,
  PackageError,
  type Plan,
  planPersonas,
  type Snapshot,
} from "./e2-r01-auth-personas.ts";
import {
  localBanProofReader,
  type LocalBanSqlExecutor,
  nominalBanSql,
  validateBanProof,
} from "./e2-r01-auth-personas-ban-proof.ts";

// Injected executor only: no Docker, SQL, Auth or network runs in this suite.
// SQL assertions inspect generated text; they are not PostgreSQL runtime proof.
const projectId = `coelo_safe_${"a".repeat(29)}`;
const containerId = "b".repeat(64);
const authUrl = "http://127.0.0.1:54321/auth/v1";
const correlation = "33333333-3333-4333-8333-333333333333";
const observedAt = "2026-09-08T20:00:00.123456Z";
type Request = Parameters<LocalBanSqlExecutor["readBan"]>[0];
function plan(): Plan {
  const operations = "11111111-1111-4111-8111-111111111111";
  const noCap = "22222222-2222-4222-8222-222222222222";
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
        id: operations,
        code: "operations",
        status: "active",
        maxScopeKind: "platform",
        permissions: ["platform.read", "institution.update"],
      },
      {
        id: noCap,
        code: "auditor",
        status: "active",
        maxScopeKind: "platform",
        permissions: ["platform.read", "audit.read"],
      },
    ],
  };
  return planPersonas(snapshot, { operations, noCap }, now);
}
function proof(
  p: Plan,
  authUserId = p.personas[0].authUserId,
  corr = correlation,
) {
  const persona = p.personas.find((item) => item.authUserId === authUserId)!;
  return {
    planId: p.id,
    authUserId,
    correlation: corr,
    email: persona.email,
    package: PACKAGE,
    persona: persona.persona,
    planMarker: p.id,
    bannedUntil: null as string | null,
    observedAt,
    isBanned: false,
  };
}
class Executor implements LocalBanSqlExecutor {
  environment = { kind: "local" as const, projectId, containerId };
  localAuthUrl: string | undefined = authUrl;
  calls: Request[] = [];
  response: ((request: Request) => unknown) | undefined;
  afterRead: (() => void) | undefined;
  failure: unknown;
  constructor(readonly p: Plan) {}
  envelope(rows: unknown[]) {
    return {
      environment: { ...this.environment },
      authUrl: this.localAuthUrl,
      completed: true,
      rows,
    };
  }
  readBan(request: Request): Promise<unknown> {
    this.calls.push(structuredClone(request));
    const response = this.response?.(request) ??
      this.envelope([proof(this.p, request.authUserId, request.correlation)]);
    this.afterRead?.();
    return this.failure === undefined
      ? Promise.resolve(response)
      : Promise.reject(this.failure);
  }
}
function packageFailure(operation: () => unknown) {
  assert.throws(
    operation,
    (error) =>
      error instanceof PackageError &&
      !error.message.includes("synthetic-private-secret"),
  );
}

Deno.test("ban proof validates each nominal persona and binds SQL to a fresh read correlation", async () => {
  const p = plan();
  const executor = new Executor(p);
  const reader = localBanProofReader(p, executor);
  assert.deepEqual(reader.environment, executor.environment);
  assert.equal(reader.authUrl, authUrl);
  for (const item of p.personas) {
    const result = await reader.read(item.authUserId);
    const call = executor.calls.at(-1)!;
    assert.match(
      call.correlation,
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    );
    assert.deepEqual(result, proof(p, item.authUserId, call.correlation));
    assert.equal(call.planId, p.id);
    assert.equal(call.sql, nominalBanSql(p, item.authUserId, call.correlation));
  }
  assert.equal(executor.calls.length, 5);
  assert.equal(new Set(executor.calls.map((r) => r.correlation)).size, 5);
});

Deno.test("ban proof rejects stale correlation from a prior read of the same persona", async () => {
  const p = plan();
  const executor = new Executor(p);
  const reader = localBanProofReader(p, executor);
  const first = await reader.read(p.personas[0].authUserId);
  executor.response = () => executor.envelope([first]);
  assert.equal(await reader.read(p.personas[0].authUserId), undefined);
  assert.equal(executor.calls.length, 2);
  assert.notEqual(executor.calls[0].correlation, executor.calls[1].correlation);
});

Deno.test("ban proof comparison preserves PostgreSQL microseconds and calendar boundaries", () => {
  const p = plan();
  const base = proof(p);
  for (
    const [bannedUntil, at, isBanned] of [
      [null, observedAt, false],
      ["2026-09-08T20:00:00.123455Z", observedAt, false],
      [observedAt, observedAt, false],
      ["2026-09-08T20:00:00.123457Z", observedAt, true],
      ["2026-09-09T00:00:00.000000Z", "2026-09-08T23:59:59.999999Z", true],
      ["2028-02-29T00:00:00.000000Z", "2028-02-28T23:59:59.999999Z", true],
      ["2000-02-29T00:00:00.000000Z", "2000-03-01T00:00:00.000000Z", false],
    ] as const
  ) {
    const value = { ...base, bannedUntil, observedAt: at, isBanned };
    assert.deepEqual(
      validateBanProof(value, p, base.authUserId, correlation),
      value,
    );
    packageFailure(() =>
      validateBanProof(
        { ...value, isBanned: !isBanned },
        p,
        base.authUserId,
        correlation,
      )
    );
  }
});

Deno.test("ban proof requires exact UTC six-microsecond timestamps with valid calendar fields", () => {
  const p = plan();
  const base = proof(p);
  const invalid = [
    "",
    "infinity",
    "-infinity",
    "2026-09-08T20:00:00Z",
    "2026-09-08T20:00:00.123Z",
    "2026-09-08T20:00:00.1234567Z",
    "2026-09-08T20:00:00.123456+00:00",
    "2026-02-29T20:00:00.123456Z",
    "2100-02-29T20:00:00.123456Z",
    "2026-04-31T20:00:00.123456Z",
    "2026-00-08T20:00:00.123456Z",
    "2026-09-08T24:00:00.123456Z",
    "2026-09-08T20:60:00.123456Z",
    "2026-09-08T20:00:60.123456Z",
  ];
  for (const timestamp of invalid) {
    packageFailure(() =>
      validateBanProof(
        { ...base, observedAt: timestamp },
        p,
        base.authUserId,
        correlation,
      )
    );
    packageFailure(() =>
      validateBanProof(
        { ...base, bannedUntil: timestamp },
        p,
        base.authUserId,
        correlation,
      )
    );
  }
});

Deno.test("ban proof enforces exact ownership, real booleans and explicit nullable ban state", () => {
  const p = plan();
  const base = proof(p);
  for (
    const field of [
      "planId",
      "authUserId",
      "correlation",
      "email",
      "package",
      "persona",
      "planMarker",
    ]
  ) {
    packageFailure(() =>
      validateBanProof(
        { ...base, [field]: "synthetic-private-secret" },
        p,
        base.authUserId,
        correlation,
      )
    );
  }
  for (
    const altered of [
      { ...base, isBanned: "false" },
      { ...base, bannedUntil: undefined },
      { ...base, extra: true },
      { ...base, observedAt: null },
      { ...base, bannedUntil: 0 },
      { ...base, persona: p.personas[1].persona },
    ]
  ) {
    packageFailure(() =>
      validateBanProof(altered, p, base.authUserId, correlation)
    );
  }
  const missing: Record<string, unknown> = { ...base };
  delete missing.bannedUntil;
  packageFailure(() =>
    validateBanProof(missing, p, base.authUserId, correlation)
  );
});

Deno.test("ban proof does not use the local wall clock to classify a server observation", () => {
  const p = plan();
  const base = proof(p);
  const original = Date.now;
  try {
    for (const clock of [0, 8_000_000_000_000_000]) {
      Date.now = () => clock;
      const value = {
        ...base,
        bannedUntil: "2026-09-08T20:00:00.123457Z",
        isBanned: true,
      };
      assert.deepEqual(
        validateBanProof(value, p, base.authUserId, correlation),
        value,
      );
      assert.deepEqual(
        validateBanProof(base, p, base.authUserId, correlation),
        base,
      );
    }
  } finally {
    Date.now = original;
  }
});

Deno.test("ban proof reader rejects malformed or wrong-environment acknowledgements", async () => {
  const p = plan();
  const executor = new Executor(p);
  const reader = localBanProofReader(p, executor);
  const factories: ((r: Request) => unknown)[] = [
    () => executor.envelope([]),
    (r) =>
      executor.envelope([
        proof(p, r.authUserId, r.correlation),
        proof(p, r.authUserId, r.correlation),
      ]),
    (r) => ({
      ...executor.envelope([proof(p, r.authUserId, r.correlation)]),
      completed: "true",
    }),
    (r) => ({
      ...executor.envelope([proof(p, r.authUserId, r.correlation)]),
      extra: true,
    }),
    (r) => ({
      ...executor.envelope([proof(p, r.authUserId, r.correlation)]),
      authUrl: "https://synthetic-private-secret.example",
    }),
    (r) => ({
      ...executor.envelope([proof(p, r.authUserId, r.correlation)]),
      environment: { kind: "local", projectId, containerId: "c".repeat(64) },
    }),
    (r) => ({
      ...executor.envelope([proof(p, r.authUserId, r.correlation)]),
      environment: { kind: "remote", projectId, containerId },
    }),
    () => "synthetic-private-secret",
  ];
  for (const make of factories) {
    executor.response = make;
    assert.equal(await reader.read(p.personas[0].authUserId), undefined);
  }
  assert.equal(executor.calls.length, factories.length);
});

Deno.test("ban proof reader rejects invalid proof and sanitizes a timeout without retry", async () => {
  const p = plan();
  const executor = new Executor(p);
  const reader = localBanProofReader(p, executor);
  executor.response = (r) =>
    executor.envelope([{
      ...proof(p, r.authUserId, r.correlation),
      isBanned: "false",
    }]);
  assert.equal(await reader.read(p.personas[0].authUserId), undefined);
  executor.failure = new Error("synthetic-private-secret timeout");
  assert.equal(await reader.read(p.personas[0].authUserId), undefined);
  assert.equal(executor.calls.length, 2);
});

Deno.test("ban proof generator rejects unknown IDs and malformed correlations before any SQL read", async () => {
  const p = plan();
  const executor = new Executor(p);
  const reader = localBanProofReader(p, executor);
  for (
    const id of [
      "",
      "55555555-5555-4555-8555-555555555555",
      "synthetic-private-secret'; select 1;--",
    ]
  ) {
    packageFailure(() => nominalBanSql(p, id, correlation));
    assert.equal(await reader.read(id), undefined);
  }
  for (const corr of ["", "synthetic-private-secret'", "123"]) {
    packageFailure(() => nominalBanSql(p, p.personas[0].authUserId, corr));
  }
  assert.equal(executor.calls.length, 0);
  const sql = nominalBanSql(p, p.personas[0].authUserId, correlation);
  for (
    const value of [
      p.personas[0].authUserId,
      p.personas[0].email,
      p.personas[0].persona,
      PACKAGE,
      p.id,
      correlation,
      "statement_timestamp()",
      "banned_until",
    ]
  ) assert(sql.includes(value), value);
  assert(!/\b(insert|update|delete)\s+(into|from|app_private\.)/i.test(sql));
});

Deno.test("ban proof factory rejects remote auth endpoints and malformed local context", () => {
  const p = plan();
  for (
    const url of [
      undefined,
      "",
      "https://remote.example",
      "http://127.0.0.1.evil.example:54321",
      "http://user:synthetic-private-secret@127.0.0.1:54321",
    ]
  ) {
    const executor = new Executor(p);
    executor.localAuthUrl = url;
    packageFailure(() => localBanProofReader(p, executor));
    assert.equal(executor.calls.length, 0);
  }
  const executor = new Executor(p);
  executor.environment.projectId = "production";
  packageFailure(() => localBanProofReader(p, executor));
});

Deno.test("ban proof reader snapshots its plan and rejects executor identity changes during reads", async () => {
  const p = plan();
  const original = structuredClone(p);
  const executor = new Executor(original);
  const reader = localBanProofReader(p, executor);
  p.personas[0].email = "synthetic-private-secret@example.invalid";
  p.personas[0].authUserId = "55555555-5555-4555-8555-555555555555";
  assert.equal(
    (await reader.read(original.personas[0].authUserId))?.email,
    original.personas[0].email,
  );
  for (const field of ["environment", "authUrl"] as const) {
    const isolated = new Executor(original);
    const scoped = localBanProofReader(original, isolated);
    isolated.afterRead = () => {
      if (field === "environment") {
        isolated.environment.containerId = "c".repeat(64);
      } else isolated.localAuthUrl = "http://127.0.0.1:54322";
    };
    assert.equal(await scoped.read(original.personas[0].authUserId), undefined);
    assert.equal(isolated.calls.length, 1);
  }
});
