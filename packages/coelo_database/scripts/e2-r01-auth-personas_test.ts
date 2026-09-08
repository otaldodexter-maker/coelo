import assert from "node:assert/strict";
import { createClient } from "@supabase/supabase-js";
import {
  activateAuth,
  type AuthAdapter,
  type AuthRecord,
  catalogSnapshotSql,
  closePersonas,
  effects,
  PACKAGE,
  type Plan,
  planPersonas,
  type PrivateBindingsAdapter,
  privateProvisionSql,
  privateRevokeSql,
  privateVerifySql,
  provisionAuth,
  revokeScenario,
  sdkAuthAdapter,
  type SecretReceipt,
  type SecretStore,
  type Snapshot,
  validatePlan,
} from "./e2-r01-auth-personas.ts";

const now = new Date("2026-09-08T20:00:00Z");
const roleA = "11111111-1111-4111-8111-111111111111";
const roleB = "22222222-2222-4222-8222-222222222222";
function snapshot(): Snapshot {
  return {
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
}
const plan = () =>
  planPersonas(snapshot(), { operations: roleA, noCap: roleB }, now);
class Harness implements AuthAdapter, SecretStore, PrivateBindingsAdapter {
  calls: string[] = [];
  users: AuthRecord[] = [];
  banned = new Map<string, boolean>();
  secrets = new Map<string, SecretReceipt>();
  loseCreateResponse = false;
  failSecretWrite = false;
  failPrivateRevoke = false;
  bindingsActive = true;
  bindingsRevoked = false;
  revokedIds: readonly string[] = [];
  inspect(_plan: Plan) {
    this.calls.push("inspect");
    return Promise.resolve(structuredClone(this.users));
  }
  create(input: Parameters<AuthAdapter["create"]>[0]) {
    this.calls.push(`create:${input.id}`);
    const record = {
      id: input.id,
      email: input.email,
      appMetadata: input.appMetadata,
    };
    this.users.push(record);
    this.banned.set(input.id, true);
    if (this.loseCreateResponse) {
      this.loseCreateResponse = false;
      throw new Error("synthetic private transport detail");
    }
    return Promise.resolve(record);
  }
  setBanned(id: string, banned: boolean) {
    this.calls.push(`${banned ? "ban" : "activate"}:${id}`);
    this.banned.set(id, banned);
    return Promise.resolve();
  }
  read(id: string) {
    this.calls.push(`read:${id}`);
    return Promise.resolve(this.secrets.get(id) ?? null);
  }
  reserve(receipt: SecretReceipt) {
    this.calls.push(`reserve:${receipt.authUserId}`);
    if (this.failSecretWrite) throw new Error("synthetic disk failure");
    assert(!this.secrets.has(receipt.authUserId));
    this.secrets.set(receipt.authUserId, structuredClone(receipt));
    return Promise.resolve();
  }
  markCreated(id: string) {
    this.calls.push(`receipt:${id}`);
    this.secrets.get(id)!.state = "created";
    return Promise.resolve();
  }
  verifyActive(_plan: Plan) {
    this.calls.push("verify-active");
    return Promise.resolve(this.bindingsActive);
  }
  revokeOwned(_plan: Plan, ids: readonly string[]) {
    this.calls.push("revoke-private");
    if (this.failPrivateRevoke) throw new Error("synthetic version conflict");
    this.bindingsRevoked = true;
    this.revokedIds = [...ids];
    return Promise.resolve();
  }
  verifyRevoked(_plan: Plan, _ids: readonly string[]) {
    this.calls.push("verify-revoked");
    return Promise.resolve(this.bindingsRevoked);
  }
}

// Controlled adapter contract, not a PostgreSQL implementation: activation
// requires a live capability catalog; terminal proof inspects nominal bindings.
class LifecycleHarness extends Harness {
  roleActive = true;
  catalogAvailable = true;
  revocationAudits = 0;
  verifiedRevokedIds: readonly string[] = [];
  lifecycle = new Map<string, { status: string; version: number }>();
  constructor(p: Plan) {
    super();
    for (const item of p.personas) {
      if (item.internalIdentityId) {
        this.lifecycle.set(item.authUserId, { status: "active", version: 1 });
      }
    }
  }
  override verifyActive(_plan: Plan) {
    this.calls.push("verify-active");
    return Promise.resolve(
      this.roleActive && this.catalogAvailable &&
        [...this.lifecycle.values()].every((value) =>
          value.status === "active" && value.version === 1
        ),
    );
  }
  override revokeOwned(p: Plan, ids: readonly string[]) {
    this.calls.push("revoke-private");
    this.revokedIds = [...ids];
    for (const id of ids) {
      const item = p.personas.find((candidate) => candidate.authUserId === id);
      assert(item, "only nominal package accounts may be revoked");
      if (item.persona === "global") continue;
      const current = this.lifecycle.get(id)!;
      if (current.status === "revoked" && current.version === 2) continue;
      assert.deepEqual(current, { status: "active", version: 1 });
      this.lifecycle.set(id, { status: "revoked", version: 2 });
      this.revocationAudits++;
    }
    return Promise.resolve();
  }
  override verifyRevoked(p: Plan, ids: readonly string[]) {
    this.calls.push("verify-revoked");
    this.verifiedRevokedIds = [...ids];
    return Promise.resolve(ids.every((id) => {
      const item = p.personas.find((candidate) => candidate.authUserId === id);
      if (!item) return false;
      if (item.persona === "global") return !this.lifecycle.has(id);
      const current = this.lifecycle.get(id);
      return current?.status === "revoked" && current.version === 2;
    }));
  }
}

Deno.test("controlled adapter: inactive role blocks activation but cannot block terminal cleanup and its retry", async () => {
  const p = plan();
  const h = new LifecycleHarness(p);
  await provisionAuth(p, { auth: h, secrets: h }, { apply: true });
  await activateAuth(p, h, h, h, { apply: true });
  h.roleActive = false;
  h.catalogAvailable = false;
  await assert.rejects(
    activateAuth(p, h, h, h, { apply: true }),
    /PRIVATE_BINDINGS_VERIFICATION/,
  );
  h.calls = [];
  const outcome = await closePersonas(p, h, h, h, { apply: true });
  assert.equal(
    outcome,
    "internal-access-revoked-auth-banned-session-cleanup-c00-required",
  );
  assert.deepEqual(
    [...h.lifecycle.values()],
    Array(4).fill({ status: "revoked", version: 2 }),
  );
  assert.deepEqual([...h.banned.values()], Array(5).fill(true));
  assert.equal(h.revocationAudits, 4);
  assert(
    h.calls.indexOf("verify-revoked") <
      h.calls.findIndex((call) => call.startsWith("ban:")),
  );
  h.calls = [];
  assert.equal(await closePersonas(p, h, h, h, { apply: true }), outcome);
  assert.equal(h.revocationAudits, 4);
  assert.deepEqual([...h.banned.values()], Array(5).fill(true));
  assert(!h.calls.some((call) => /^(create|activate|reserve):/.test(call)));
});

Deno.test("controlled adapter: scenario cleanup proves only the target despite unrelated catalog and lifecycle drift", async () => {
  const p = plan();
  const h = new LifecycleHarness(p);
  await provisionAuth(p, { auth: h, secrets: h }, { apply: true });
  await activateAuth(p, h, h, h, { apply: true });
  h.roleActive = false;
  h.catalogAvailable = false;
  h.lifecycle.set(p.personas[0].authUserId, {
    status: "suspended",
    version: 3,
  });
  h.calls = [];
  const outcome = await revokeScenario(p, h, h, h, { apply: true });
  assert.equal(
    outcome,
    "revoked-persona-only-awaiting-ui-and-session-verification",
  );
  assert.deepEqual(h.verifiedRevokedIds, [p.personas[3].authUserId]);
  assert.deepEqual(h.revokedIds, [p.personas[3].authUserId]);
  assert.deepEqual(h.calls.filter((call) => call.startsWith("ban:")), [
    `ban:${p.personas[3].authUserId}`,
  ]);
  assert.deepEqual(h.lifecycle.get(p.personas[0].authUserId), {
    status: "suspended",
    version: 3,
  });
  assert.deepEqual([...h.banned.values()], [false, false, false, true, false]);
  await revokeScenario(p, h, h, h, { apply: true });
  assert.equal(h.revocationAudits, 1);
});

Deno.test("SQL artifact separates terminal revocation proof from full active scenario verification", () => {
  const p = plan();
  // Static contract inspection only: actual SQL predicates still need C00's
  // authorized database replay, including role and permission drift fixtures.
  for (const state of ["active", "scenario-revoked", "revoked"] as const) {
    const sql = privateVerifySql(p, state);
    const payload = sql.match(/jsonb_array_elements\('([^']+)'::jsonb\)/)?.[1];
    assert(payload);
    const rows: { persona: string; status: string; version: number }[] = JSON
      .parse(payload);
    const targets = rows.filter((row) => row.status === "revoked");
    assert.equal(
      targets.length,
      state === "active" ? 0 : state === "revoked" ? 5 : 1,
    );
    if (state === "scenario-revoked") {
      assert.equal(targets[0].persona, "revoked");
    }
    assert(targets.every((row) => row.version === 2));
    assert.match(
      sql,
      /count\(\*\)=5 and bool_and\(auth_owned and no_people_link and private_bindings\)/,
    );
    assert(sql.includes(`'revocationVerified',${state !== "active"}`));
    assert(
      sql.includes(
        `count(*) filter(where revocation_target)=${
          state === "revoked" ? 5 : 1
        }`,
      ),
    );
    assert.match(
      sql,
      /bool_and\(auth_owned and no_people_link and private_bindings\) filter\(where revocation_target\)/,
    );
    const activeCatalog = sql.slice(
      sql.indexOf("and (item->>'status'='revoked' or ("),
      sql.indexOf(
        "and not exists(select 1 from app_private.superadmin_internal_auth_links other",
      ),
    );
    assert(activeCatalog.startsWith("and (item->>'status'='revoked' or ("));
    assert(activeCatalog.includes("r.status='active'"));
    assert(activeCatalog.includes("i.status='active'"));
    assert(
      activeCatalog.includes(
        "p.code='institution.update' and p.status='active'",
      ),
    );
    assert(
      activeCatalog.includes("p.code='platform.read' and p.status='active'"),
    );
  }
});

Deno.test("revocation scenario targets only revoked and never the other four accounts", async () => {
  const p = plan();
  const h = new Harness();
  await provisionAuth(p, { auth: h, secrets: h }, { apply: true });
  h.calls = [];
  await revokeScenario(p, h, h, h, { apply: true });
  assert.deepEqual(h.revokedIds, [p.personas[3].authUserId]);
  assert.deepEqual(h.calls.filter((x) => x.startsWith("ban:")), [
    `ban:${p.personas[3].authUserId}`,
  ]);
});

Deno.test("private SQL refuses injected identifiers and contains no Auth user writes", () => {
  const p = plan();
  assert.throws(
    () =>
      privateProvisionSql(p, {
        authUserId: "';drop table auth.users;",
        sessionId: roleA,
      }),
    /EXISTING_ACTOR_SESSION/,
  );
  const sql = privateProvisionSql(p, { authUserId: roleA, sessionId: roleB });
  assert(!/insert\s+into\s+auth\.users/i.test(sql));
  assert(!/insert\s+into\s+public\.people/i.test(sql));
  assert(!/\bgrant\b/i.test(sql));
  assert(sql.includes("is not true"));
  assert(sql.includes("Existing active Owner session required"));
  const revoke = privateRevokeSql(
    p,
    { authUserId: roleA, sessionId: roleB },
    "scenario",
  );
  assert(revoke.includes(p.personas[3].membershipId!));
  assert(!revoke.includes(p.personas[0].membershipId!));
  assert(!/\bdelete\s+from/i.test(revoke));
  assert(catalogSnapshotSql(p.projectRef).includes("begin read only"));
});

// These assertions inspect review artifacts only. They do not execute SQL or
// certify PostgreSQL authorization, lifecycle constraints or isolation.
Deno.test("revocation SQL artifact binds the selected Auth ID to its nominal email and persona", () => {
  const p = plan();
  const sql = privateRevokeSql(
    p,
    { authUserId: roleA, sessionId: roleB },
    "scenario",
  );
  const payload = sql.match(/jsonb_array_elements\('([^']+)'::jsonb\)/)?.[1];
  assert(payload, "revocation artifact must declare its nominal targets");
  const rows = JSON.parse(payload);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].auth_id, p.personas[3].authUserId);
  assert.equal(rows[0].email, p.personas[3].email);
  assert.equal(rows[0].persona, "revoked");
  assert.match(sql, /lower\(u\.email\)\s*=\s*item->>'email'/);
  assert.match(sql, /coelo_e2_persona'\s*=\s*item->>'persona'/);
});

Deno.test("provision SQL artifact refuses an existing identity without its complete nominal bindings", () => {
  const sql = privateProvisionSql(plan(), {
    authUserId: roleA,
    sessionId: roleB,
  });
  const collisionGuard = sql.slice(
    sql.indexOf(
      "if exists(select 1 from app_private.superadmin_internal_identities",
    ),
    sql.indexOf(
      "raise exception 'Internal identity collision or lifecycle drift'",
    ),
  );
  assert.match(collisionGuard, /not exists\s*\(/);
  assert.match(collisionGuard, /superadmin_internal_auth_links/);
  assert.match(collisionGuard, /superadmin_internal_memberships/);
  assert.match(collisionGuard, /l\.id\s*=\s*\(item->>'link_id'\)::uuid/);
  assert.match(collisionGuard, /m\.id\s*=\s*\(item->>'membership_id'\)::uuid/);
  assert.match(collisionGuard, /l\.status\s*=\s*'active'/);
  assert.match(collisionGuard, /m\.status\s*=\s*'active'/);
  assert.match(collisionGuard, /l\.version\s*=\s*1/);
  assert.match(collisionGuard, /m\.version\s*=\s*1/);
});

Deno.test("provision and verification SQL artifacts require the denied capability to exist and be active", () => {
  const p = plan();
  const sqls = [
    privateProvisionSql(p, { authUserId: roleA, sessionId: roleB }),
    privateVerifySql(p, "active"),
  ];
  for (const sql of sqls) {
    assert.match(
      sql,
      /exists\s*\(select 1 from public\.platform_permissions(?:\s+\w+)?\s+where (?:\w+\.)?code\s*=\s*'institution\.update'\s+and (?:\w+\.)?status\s*=\s*'active'\)/,
    );
  }
});

Deno.test("default dry-run has no network, secret or private-binding effects", async () => {
  const p = plan();
  const h = new Harness();
  assert.equal(
    (await provisionAuth(p, { auth: h, secrets: h })).state,
    "dry-run-no-effects",
  );
  assert.equal(await activateAuth(p, h, h, h), "dry-run-no-effects");
  assert.equal(await closePersonas(p, h, h, h), "dry-run-no-effects");
  assert.deepEqual(h.calls, []);
  assert.equal(effects(p).auth.count, 5);
  assert.equal(p.personas.filter((x) => x.internalIdentityId).length, 4);
  assert.equal(p.personas[4].membershipId, null);
  assert.notEqual(p.personas[0].institutionId, p.personas[1].institutionId);
});

for (
  const collision of [
    "collidingEmails",
    "collidingSlugs",
    "collidingTypeCodes",
  ] as const
) {
  Deno.test(`planner refuses existing ${collision} without adopting them`, () => {
    const s = snapshot();
    s[collision] = ["synthetic collision"];
    assert.throws(
      () => planPersonas(s, { operations: roleA, noCap: roleB }, now),
      /SYNTHETIC_NAMESPACE_COLLISION/,
    );
  });
}
Deno.test("planner refuses stale catalog, absent schema and Owner role", () => {
  const s = snapshot();
  assert.throws(
    () =>
      planPersonas(
        s,
        { operations: roleA, noCap: roleB },
        new Date(now.getTime() + 16 * 60_000),
      ),
    /FRESH_C00/,
  );
  s.internalSchemaPresent = false;
  assert.throws(
    () => planPersonas(s, { operations: roleA, noCap: roleB }, now),
    /INTERNAL_SCHEMA/,
  );
  s.internalSchemaPresent = true;
  s.roles[0].code = "owner";
  assert.throws(
    () => planPersonas(s, { operations: roleA, noCap: roleB }, now),
    /ROLE_NOT_ALLOWED/,
  );
});
Deno.test("role names never grant capabilities and no-cap must really deny the target", () => {
  const s = snapshot();
  s.roles[0].permissions = [];
  assert.throws(
    () => planPersonas(s, { operations: roleA, noCap: roleB }, now),
    /OPERATIONS_READ_REQUIRED/,
  );
  s.roles[0].permissions = ["platform.read"];
  s.roles[1].permissions.push("institution.update");
  assert.throws(
    () => planPersonas(s, { operations: roleA, noCap: roleB }, now),
    /NO_CAP_ROLE/,
  );
});
Deno.test("tampered tenant, global identity, UUID and recipient fail before effects", async () => {
  for (
    const mutate of [
      (p: Plan) => {
        p.personas[0].institutionId = p.institutions[1].id;
      },
      (p: Plan) => {
        p.personas[4].internalIdentityId = p.personas[0].internalIdentityId;
      },
      (p: Plan) => {
        p.personas[0].authUserId = p.personas[1].authUserId;
      },
      (p: Plan) => {
        p.personas[0].email = "real-user@example.com";
      },
    ]
  ) {
    const p = plan();
    const h = new Harness();
    mutate(p);
    await assert.rejects(
      provisionAuth(p, { auth: h, secrets: h }, { apply: true }),
    );
    assert.deepEqual(h.calls, []);
  }
});
Deno.test("an existing namespace account is never adopted even with copied metadata", async () => {
  const p = plan();
  const h = new Harness();
  const item = p.personas[4];
  h.users.push({
    id: item.authUserId,
    email: item.email,
    appMetadata: {
      coelo_e2_package: PACKAGE,
      coelo_e2_plan: p.id,
      coelo_e2_persona: item.persona,
    },
  });
  await assert.rejects(
    provisionAuth(p, { auth: h, secrets: h }, { apply: true }),
    /AUTH_COLLISION/,
  );
  assert.equal(
    h.calls.filter((x) => x.startsWith("create:") || x.startsWith("reserve:"))
      .length,
    0,
  );
});
Deno.test("lost create response resumes from durable receipt without rotating password or duplicating user", async () => {
  const p = plan();
  const h = new Harness();
  h.loseCreateResponse = true;
  await assert.rejects(
    provisionAuth(p, { auth: h, secrets: h }, { apply: true }),
    /AUTH_CREATE_AMBIGUOUS/,
  );
  const reserved = structuredClone(h.secrets.get(p.personas[0].authUserId)!);
  assert.equal(reserved.state, "reserved");
  const outcome = await provisionAuth(p, { auth: h, secrets: h }, {
    apply: true,
  });
  assert.equal(h.users.length, 5);
  assert.equal(h.secrets.get(reserved.authUserId)!.password, reserved.password);
  assert.equal(h.calls.filter((x) => x.startsWith("create:")).length, 5);
  assert(!JSON.stringify(outcome).includes(reserved.password));
  assert.equal(
    outcome.state,
    "owned-auth-accounts-reconciled-private-bindings-and-ban-verification-required",
  );
});
Deno.test("secret-store failure happens before the first Auth mutation", async () => {
  const p = plan();
  const h = new Harness();
  h.failSecretWrite = true;
  await assert.rejects(
    provisionAuth(p, { auth: h, secrets: h }, { apply: true }),
  );
  assert.equal(h.users.length, 0);
});
Deno.test("replaying an applied Auth plan has no create, password change or activation", async () => {
  const p = plan();
  const h = new Harness();
  await provisionAuth(p, { auth: h, secrets: h }, { apply: true });
  h.calls = [];
  await provisionAuth(p, { auth: h, secrets: h }, { apply: true });
  assert(
    !h.calls.some((x) =>
      x.startsWith("create:") || x.startsWith("activate:") ||
      x.startsWith("reserve:")
    ),
  );
});
Deno.test("activation requires complete owned accounts and current private-binding proof", async () => {
  const p = plan();
  const h = new Harness();
  await provisionAuth(p, { auth: h, secrets: h }, { apply: true });
  h.calls = [];
  h.bindingsActive = false;
  await assert.rejects(
    activateAuth(p, h, h, h, { apply: true }),
    /PRIVATE_BINDINGS_VERIFICATION/,
  );
  assert(!h.calls.some((x) => x.startsWith("activate:")));
  h.bindingsActive = true;
  await activateAuth(p, h, h, h, { apply: true });
  assert.equal(h.calls.filter((x) => x.startsWith("activate:")).length, 5);
});
Deno.test("replay after activation preserves account states and never claims an unverified ban", async () => {
  const p = plan();
  const h = new Harness();
  await provisionAuth(p, { auth: h, secrets: h }, { apply: true });
  await activateAuth(p, h, h, h, { apply: true });
  assert.deepEqual([...h.banned.values()], Array(5).fill(false));
  h.calls = [];
  const outcome = await provisionAuth(p, { auth: h, secrets: h }, {
    apply: true,
  });
  assert.equal(
    outcome.state,
    "owned-auth-accounts-reconciled-private-bindings-and-ban-verification-required",
  );
  assert(!h.calls.some((call) => /^(create|activate|ban|reserve):/.test(call)));
  assert.deepEqual([...h.banned.values()], Array(5).fill(false));
  assert.equal(h.users.length, 5);
});
Deno.test("cleanup revokes private access first, preserves records and stops on version conflict", async () => {
  const p = plan();
  const h = new Harness();
  await provisionAuth(p, { auth: h, secrets: h }, { apply: true });
  h.calls = [];
  h.failPrivateRevoke = true;
  await assert.rejects(closePersonas(p, h, h, h, { apply: true }));
  assert(!h.calls.some((x) => x.startsWith("ban:")));
  h.calls = [];
  h.failPrivateRevoke = false;
  assert.equal(
    await closePersonas(p, h, h, h, { apply: true }),
    "internal-access-revoked-auth-banned-session-cleanup-c00-required",
  );
  assert(
    h.calls.indexOf("verify-revoked") <
      h.calls.findIndex((x) => x.startsWith("ban:")),
  );
  assert.equal(h.users.length, 5);
  assert.equal(h.secrets.size, 5);
});
Deno.test("SDK adapter uses Admin API with banned creation and never sends user authorization metadata", async () => {
  const requests: {
    method: string;
    path: string;
    body: Record<string, unknown>;
  }[] = [];
  const p = plan();
  const item = p.personas[0];
  const client = createClient(
    `https://${p.projectRef}.supabase.co`,
    "synthetic-service-key",
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
      global: {
        fetch: (input, init) => {
          const body = JSON.parse(String(init?.body ?? "{}"));
          requests.push({
            method: init?.method ?? "GET",
            path: new URL(String(input)).pathname,
            body,
          });
          return Promise.resolve(
            new Response(
              JSON.stringify({
                id: item.authUserId,
                email: item.email,
                app_metadata: body.app_metadata ?? {},
                user_metadata: {},
                aud: "authenticated",
                created_at: now.toISOString(),
              }),
              { status: 200, headers: { "content-type": "application/json" } },
            ),
          );
        },
      },
    },
  );
  const adapter = sdkAuthAdapter(client);
  await adapter.create({
    id: item.authUserId,
    email: item.email,
    password: "synthetic-only-never-production",
    appMetadata: { coelo_e2_package: PACKAGE },
  });
  await adapter.setBanned(item.authUserId, false);
  assert.equal(requests[0].path, "/auth/v1/admin/users");
  assert.equal(requests[0].body.ban_duration, "876000h");
  assert.equal(requests[0].body.email_confirm, true);
  assert.equal(requests[0].body.user_metadata, undefined);
  assert.equal(requests[1].path, `/auth/v1/admin/users/${item.authUserId}`);
  assert.equal(requests[1].body.ban_duration, "none");
  validatePlan(p);
});
