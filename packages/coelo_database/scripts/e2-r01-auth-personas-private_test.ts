import assert from "node:assert/strict";
import {
  PackageError,
  type Plan,
  planPersonas,
  type Snapshot,
} from "./e2-r01-auth-personas.ts";
import {
  privateBindingsAdapter,
  type PrivateSqlExecutor,
} from "./e2-r01-auth-personas-private.ts";

// Controlled executor contract only. These tests neither connect to PostgreSQL
// nor prove that a future transport committed or enforced generated SQL.
const now = new Date("2026-09-08T20:00:00Z");
const roleA = "11111111-1111-4111-8111-111111111111";
const roleB = "22222222-2222-4222-8222-222222222222";
const actor = {
  authUserId: "33333333-3333-4333-8333-333333333333",
  sessionId: "44444444-4444-4444-8444-444444444444",
};
function plan(): Plan {
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
type State = "active" | "scenario-revoked" | "revoked";
function payload(p: Plan, state: State) {
  return {
    planId: p.id,
    state,
    verified: true,
    revocationVerified: state !== "active",
    personas: p.personas.map((item) => ({
      persona: item.persona,
      revocation_target: state === "revoked" ||
        (state === "scenario-revoked" && item.persona === "revoked"),
      auth_owned: true,
      no_people_link: true,
      private_bindings: true,
    })),
  };
}
function envelope(p: Plan, rows: unknown[]) {
  return { projectRef: p.projectRef, completed: true, rows };
}
type Request = Parameters<PrivateSqlExecutor["execute"]>[0];
class Executor implements PrivateSqlExecutor {
  requests: Request[] = [];
  projectRef: string;
  response: unknown;
  afterExecute: (() => void) | undefined;
  failure: Error | undefined;
  constructor(
    p: Plan,
    response: unknown = envelope(p, [payload(p, "active")]),
  ) {
    this.projectRef = p.projectRef;
    this.response = response;
  }
  execute(request: Request): Promise<unknown> {
    this.requests.push(structuredClone(request));
    this.afterExecute?.();
    if (this.failure) return Promise.reject(this.failure);
    return Promise.resolve(this.response);
  }
}
async function sanitizedFailure(operation: () => unknown | Promise<unknown>) {
  let caught: unknown;
  try {
    await operation();
  } catch (error) {
    caught = error;
  }
  assert(
    caught instanceof PackageError,
    "failure must be a sanitized PackageError",
  );
  assert(!caught.message.includes("synthetic-private-secret"));
}

Deno.test("private adapter verifies active state using a nominal read-only executor request", async () => {
  const p = plan();
  const executor = new Executor(p);
  const adapter = privateBindingsAdapter({ plan: p, actor }, executor);
  assert.equal(await adapter.verifyActive(p), true);
  assert.equal(executor.requests.length, 1);
  const request = executor.requests[0];
  assert.equal(request.projectRef, p.projectRef);
  assert.equal(request.planId, p.id);
  assert.equal(request.kind, "verify");
  assert(request.sql.includes("begin read only;"));
  assert(request.sql.includes(p.id));
  assert(
    !/\b(insert|update|delete)\s+(into|from|app_private\.)/i.test(request.sql),
  );
});

Deno.test("private adapter reports a valid negative active proof without inventing success", async () => {
  const p = plan();
  const proof = payload(p, "active");
  proof.personas[0].private_bindings = false;
  proof.verified = false;
  const executor = new Executor(p, envelope(p, [proof]));
  assert.equal(
    await privateBindingsAdapter({ plan: p, actor }, executor).verifyActive(p),
    false,
  );
});

Deno.test("private adapter proves only the revoked target while unrelated scenario rows may fail", async () => {
  const p = plan();
  const proof = payload(p, "scenario-revoked");
  proof.personas[0].private_bindings = false;
  proof.verified = false;
  const executor = new Executor(p, envelope(p, [proof]));
  assert.equal(
    await privateBindingsAdapter({ plan: p, actor }, executor).verifyRevoked(
      p,
      [p.personas[3].authUserId],
    ),
    true,
  );
  const sql = executor.requests[0].sql;
  assert(sql.includes("scenario-revoked"));
});

Deno.test("private adapter rejects an unverified terminal target despite unrelated valid rows", async () => {
  const p = plan();
  const proof = payload(p, "scenario-revoked");
  proof.personas[3].auth_owned = false;
  proof.verified = false;
  proof.revocationVerified = false;
  const executor = new Executor(p, envelope(p, [proof]));
  assert.equal(
    await privateBindingsAdapter({ plan: p, actor }, executor).verifyRevoked(
      p,
      [p.personas[3].authUserId],
    ),
    false,
  );
});

Deno.test("private adapter cross-checks terminal and full aggregates against their distinct row sets", async () => {
  const p = plan();
  for (
    const mismatch of [
      "unproved-target",
      "false-target-aggregate",
      "unproved-full-scenario",
      "wrong-target-persona",
    ]
  ) {
    const proof = payload(p, "scenario-revoked");
    if (mismatch === "unproved-target") {
      proof.personas[3].private_bindings = false;
      proof.verified = false;
    }
    if (mismatch === "false-target-aggregate") proof.revocationVerified = false;
    if (mismatch === "unproved-full-scenario") {
      proof.personas[0].private_bindings = false;
    }
    if (mismatch === "wrong-target-persona") {
      proof.personas[3].revocation_target = false;
      proof.personas[0].revocation_target = true;
    }
    const executor = new Executor(p, envelope(p, [proof]));
    await sanitizedFailure(() =>
      privateBindingsAdapter({ plan: p, actor }, executor).verifyRevoked(p, [
        p.personas[3].authUserId,
      ])
    );
  }
});

Deno.test("private adapter binds executor and normalized response to the exact project before and after execution", async () => {
  const p = plan();
  const otherProject = "bbbbbbbbbbbbbbbbbbbb";
  const wrongInitial = new Executor(p);
  wrongInitial.projectRef = otherProject;
  await sanitizedFailure(async () => {
    const adapter = privateBindingsAdapter({ plan: p, actor }, wrongInitial);
    await adapter.verifyActive(p);
  });
  assert.equal(wrongInitial.requests.length, 0);
  for (const timing of ["before-call", "after-call", "response"] as const) {
    const executor = new Executor(p);
    const adapter = privateBindingsAdapter({ plan: p, actor }, executor);
    if (timing === "before-call") executor.projectRef = otherProject;
    if (timing === "after-call") {
      executor.afterExecute = () => executor.projectRef = otherProject;
    }
    if (timing === "response") {
      executor.response = {
        ...envelope(p, [payload(p, "active")]),
        projectRef: otherProject,
      };
    }
    await sanitizedFailure(() => adapter.verifyActive(p));
    assert.equal(executor.requests.length, timing === "before-call" ? 0 : 1);
  }
});

Deno.test("private adapter rejects divergent plan contents even when their nominal plan ID is unchanged", async () => {
  const p = plan();
  const executor = new Executor(p);
  const adapter = privateBindingsAdapter({ plan: p, actor }, executor);
  for (
    const mutate of [
      (copy: Plan) => copy.personas[0].authUserId = crypto.randomUUID(),
      (copy: Plan) => copy.personas[0].institutionId = copy.institutions[1].id,
      (copy: Plan) => copy.operationsRole.permissions.push("audit.read"),
      (copy: Plan) => copy.projectRef = "bbbbbbbbbbbbbbbbbbbb",
    ]
  ) {
    const copy = structuredClone(p);
    mutate(copy);
    await sanitizedFailure(() => adapter.verifyActive(copy));
    await sanitizedFailure(() =>
      adapter.verifyRevoked(copy, [p.personas[3].authUserId])
    );
    await sanitizedFailure(() =>
      adapter.revokeOwned(copy, [p.personas[3].authUserId])
    );
  }
  assert.equal(executor.requests.length, 0);
});

Deno.test("private adapter snapshots context so subsequent caller mutations cannot redirect an operation", async () => {
  const p = plan();
  const original = structuredClone(p);
  const suppliedActor = { ...actor };
  const executor = new Executor(p, envelope(p, []));
  const adapter = privateBindingsAdapter(
    { plan: p, actor: suppliedActor },
    executor,
  );
  p.personas[3].authUserId = crypto.randomUUID();
  suppliedActor.authUserId = crypto.randomUUID();
  suppliedActor.sessionId = crypto.randomUUID();
  await adapter.revokeOwned(original, [original.personas[3].authUserId]);
  assert(executor.requests[0].sql.includes(actor.authUserId));
  assert(executor.requests[0].sql.includes(actor.sessionId));
  assert(!executor.requests[0].sql.includes(suppliedActor.authUserId));
});

Deno.test("private adapter revalidates a caller plan changed during the executor await before reporting a result", async () => {
  for (const operation of ["active", "terminal", "revoke"] as const) {
    const p = plan();
    const targetId = p.personas[3].authUserId;
    const response = envelope(
      p,
      operation === "revoke"
        ? []
        : [payload(p, operation === "active" ? "active" : "scenario-revoked")],
    );
    const executor = new Executor(p, response);
    const adapter = privateBindingsAdapter({ plan: p, actor }, executor);
    executor.afterExecute = () =>
      p.personas[0].authUserId = crypto.randomUUID();
    await sanitizedFailure(() =>
      operation === "active"
        ? adapter.verifyActive(p)
        : operation === "terminal"
        ? adapter.verifyRevoked(p, [targetId])
        : adapter.revokeOwned(p, [targetId])
    );
    assert.equal(executor.requests.length, 1);
    assert.equal(
      executor.requests[0].kind,
      operation === "revoke" ? "revoke" : "verify",
    );
  }
});

Deno.test("private adapter rejects an invalid nominal actor before executing SQL", async () => {
  const p = plan();
  for (
    const invalidActor of [
      { ...actor, authUserId: "synthetic-private-secret" },
      { ...actor, sessionId: "';select secret;" },
    ]
  ) {
    const executor = new Executor(p);
    await sanitizedFailure(async () => {
      const adapter = privateBindingsAdapter(
        { plan: p, actor: invalidActor },
        executor,
      );
      await adapter.revokeOwned(p, [p.personas[3].authUserId]);
    });
    assert.equal(executor.requests.length, 0);
  }
});

Deno.test("private adapter rejects malformed normalized envelopes and non-boolean proof fields", async () => {
  const p = plan();
  const base = envelope(p, [payload(p, "active")]);
  const invalid: unknown[] = [
    null,
    [],
    "synthetic-private-secret",
    JSON.stringify(base),
    {},
    { ...base, completed: false },
    { ...base, completed: "true" },
    { ...base, rows: [] },
    { ...base, rows: [...base.rows, ...base.rows] },
    { ...base, rows: [JSON.stringify(base.rows[0])] },
    { ...base, extra: "synthetic-private-secret" },
  ];
  for (const value of ["true", "false", 1, 0, null]) {
    for (const field of ["verified", "revocationVerified"] as const) {
      invalid.push(envelope(p, [{ ...payload(p, "active"), [field]: value }]));
    }
    for (
      const field of [
        "revocation_target",
        "auth_owned",
        "no_people_link",
        "private_bindings",
      ] as const
    ) {
      const proof = payload(p, "active");
      invalid.push(
        envelope(p, [{
          ...proof,
          personas: proof.personas.map((item, i) =>
            i === 0 ? { ...item, [field]: value } : item
          ),
        }]),
      );
    }
  }
  for (const response of invalid) {
    const executor = new Executor(p, response);
    await sanitizedFailure(() =>
      privateBindingsAdapter({ plan: p, actor }, executor).verifyActive(p)
    );
    assert.equal(executor.requests.length, 1);
  }
});

Deno.test("private adapter rejects mismatched proof identity, persona sets, target flags and aggregate claims", async () => {
  const p = plan();
  const invalid = [
    { ...payload(p, "active"), planId: roleA },
    { ...payload(p, "active"), state: "revoked" },
    { ...payload(p, "active"), extra: true },
    { ...payload(p, "active"), verified: false },
    { ...payload(p, "active"), revocationVerified: true },
  ];
  for (
    const kind of [
      "missing",
      "duplicate",
      "unknown",
      "extra-field",
      "wrong-target",
      "wrong-aggregate",
    ]
  ) {
    const proof = payload(p, "active");
    if (kind === "missing") proof.personas.pop();
    if (kind === "duplicate") proof.personas[0] = { ...proof.personas[1] };
    if (kind === "unknown") {
      proof.personas[0].persona =
        "unknown" as typeof proof.personas[0]["persona"];
    }
    if (kind === "extra-field") {
      Object.assign(proof.personas[0], { extra: true });
    }
    if (kind === "wrong-target") proof.personas[0].revocation_target = true;
    if (kind === "wrong-aggregate") proof.personas[0].private_bindings = false;
    invalid.push(proof);
  }
  for (const proof of invalid) {
    const executor = new Executor(p, envelope(p, [proof]));
    await sanitizedFailure(() =>
      privateBindingsAdapter({ plan: p, actor }, executor).verifyActive(p)
    );
  }
  for (
    const missing of [
      "planId",
      "state",
      "verified",
      "revocationVerified",
      "personas",
    ]
  ) {
    const proof: Record<string, unknown> = { ...payload(p, "active") };
    delete proof[missing];
    const executor = new Executor(p, envelope(p, [proof]));
    await sanitizedFailure(() =>
      privateBindingsAdapter({ plan: p, actor }, executor).verifyActive(p)
    );
  }
});

Deno.test("private adapter permits only the single revoked persona or the exact five-account set", async () => {
  const p = plan();
  const all = p.personas.map((item) => item.authUserId);
  for (
    const ids of [
      [],
      all.slice(0, 4),
      [all[0]],
      [all[3], all[3]],
      [...all.slice(0, 4), all[0]],
      [...all, crypto.randomUUID()],
      [crypto.randomUUID()],
    ]
  ) {
    const executor = new Executor(p);
    const adapter = privateBindingsAdapter({ plan: p, actor }, executor);
    await sanitizedFailure(() => adapter.verifyRevoked(p, ids));
    await sanitizedFailure(() => adapter.revokeOwned(p, ids));
    assert.equal(executor.requests.length, 0);
  }
  const executor = new Executor(p, envelope(p, [payload(p, "revoked")]));
  assert.equal(
    await privateBindingsAdapter({ plan: p, actor }, executor).verifyRevoked(
      p,
      [...all].reverse(),
    ),
    true,
  );
});

Deno.test("private adapter emits exact scenario or all-scope revocation SQL and requires a committed empty acknowledgement", async () => {
  const p = plan();
  for (const scope of ["scenario", "all"]) {
    const ids = scope === "scenario"
      ? [p.personas[3].authUserId]
      : p.personas.map((item) => item.authUserId).reverse();
    const executor = new Executor(p, envelope(p, []));
    await privateBindingsAdapter({ plan: p, actor }, executor).revokeOwned(
      p,
      ids,
    );
    const request = executor.requests[0];
    assert.equal(request.kind, "revoke");
    assert.equal(request.projectRef, p.projectRef);
    assert.equal(request.planId, p.id);
    assert(request.sql.includes("commit;"));
    assert(request.sql.includes(p.personas[3].membershipId!));
    assert.equal(
      request.sql.includes(p.personas[0].membershipId!),
      scope === "all",
    );
    assert(!/\bdelete\s+from/i.test(request.sql));
  }
  for (
    const response of [
      [],
      null,
      { ...envelope(p, []), completed: false },
      envelope(p, [{ set_config: "synthetic-private-secret" }]),
      { ...envelope(p, []), extra: true },
    ]
  ) {
    const executor = new Executor(p, response);
    await sanitizedFailure(() =>
      privateBindingsAdapter({ plan: p, actor }, executor).revokeOwned(p, [
        p.personas[3].authUserId,
      ])
    );
    assert.equal(executor.requests.length, 1);
  }
});

Deno.test("private adapter never retries an ambiguous revoke and sanitizes transport errors", async () => {
  const p = plan();
  const executor = new Executor(p);
  executor.failure = new Error(
    "synthetic-private-secret lost response after COMMIT",
  );
  await sanitizedFailure(() =>
    privateBindingsAdapter({ plan: p, actor }, executor).revokeOwned(p, [
      p.personas[3].authUserId,
    ])
  );
  assert.equal(executor.requests.length, 1);
  assert.equal(executor.requests[0].kind, "revoke");
});

Deno.test("private adapter closes the microtask gap between executor validation and public method completion", async () => {
  for (const operation of ["active", "terminal", "revoke"] as const) {
    for (const changed of ["plan", "environment"] as const) {
      const p = plan();
      const targetId = p.personas[3].authUserId;
      const response = envelope(
        p,
        operation === "revoke" ? [] : [
          payload(p, operation === "active" ? "active" : "scenario-revoked"),
        ],
      );
      let release!: (value: unknown) => void;
      const deferred = new Promise<unknown>((resolve) => release = resolve);
      const executor = new Executor(p, response);
      executor.execute = (request: Request) => {
        executor.requests.push(structuredClone(request));
        return deferred;
      };
      const adapter = privateBindingsAdapter({ plan: p, actor }, executor);
      const pending = operation === "active"
        ? adapter.verifyActive(p)
        : operation === "terminal"
        ? adapter.verifyRevoked(p, [targetId])
        : adapter.revokeOwned(p, [targetId]);
      release(response);
      queueMicrotask(() => {
        if (changed === "plan") p.personas[0].authUserId = crypto.randomUUID();
        else executor.projectRef = "bbbbbbbbbbbbbbbbbbbb";
      });
      await sanitizedFailure(() => pending);
      assert.equal(executor.requests.length, 1);
    }
  }
});

Deno.test("private adapter rejects sparse persona arrays instead of accepting empty aggregate checks", async () => {
  for (const state of ["active", "revoked"] as const) {
    const p = plan();
    const proof = payload(p, state);
    proof.personas = new Array(5);
    const executor = new Executor(p, envelope(p, [proof]));
    const adapter = privateBindingsAdapter({ plan: p, actor }, executor);
    await sanitizedFailure(() =>
      state === "active"
        ? adapter.verifyActive(p)
        : adapter.verifyRevoked(p, p.personas.map((item) => item.authUserId))
    );
    assert.equal(executor.requests.length, 1);
  }
});
