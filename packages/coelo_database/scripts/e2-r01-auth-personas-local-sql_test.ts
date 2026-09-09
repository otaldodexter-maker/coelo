import assert from "node:assert/strict";
import { win32 } from "node:path";
import {
  PACKAGE,
  PackageError,
  type Plan,
  planPersonas,
  privateRevokeSql,
  privateVerifySql,
  type Snapshot,
} from "./e2-r01-auth-personas.ts";
import {
  localPersonaSqlExecutor,
  type LocalSqlContext,
  type LocalSqlProcessRequest,
  type LocalSqlProcessResult,
  type LocalSqlRuntime,
} from "./e2-r01-auth-personas-local-sql.ts";
import { nominalBanSql } from "./e2-r01-auth-personas-ban-proof.ts";

// Controlled runtime contract only. No Docker, database or network is exercised.
// Canonical psql output fixtures express the protocol, not an observed runtime
// transaction or proof that an installed psql actually emitted these messages.
const projectId = `coelo_safe_${"a".repeat(29)}`;
const containerId = "b".repeat(64);
const actor = {
  authUserId: "33333333-3333-4333-8333-333333333333",
  sessionId: "44444444-4444-4444-8444-444444444444",
};
type State = "active" | "scenario-revoked" | "revoked";
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
function context() {
  return {
    plan: plan(),
    actor: { ...actor },
    local: {
      projectRoot: `C:\\Temp\\${projectId}`,
      projectId,
      containerId,
      dockerPath:
        "C:\\Program Files\\Docker\\Docker\\resources\\bin\\docker.exe",
      dockerHost: "npipe:////./pipe/dockerDesktopLinuxEngine",
    },
  };
}
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
function verifyOutput(
  p: Plan,
  state: State,
  proof: unknown = payload(p, state),
) {
  return `BEGIN\n${JSON.stringify(proof)}\nCOMMIT\n`;
}
function revokeOutput() {
  return `BEGIN\nSET\nSET\n\n${
    JSON.stringify({
      sub: actor.authUserId,
      session_id: actor.sessionId,
      aal: "aal1",
      role: "authenticated",
    })
  }\nDO\nCOMMIT\n`;
}
function key(path: string) {
  return win32.normalize(path).toLowerCase();
}
class Runtime implements LocalSqlRuntime {
  calls: LocalSqlProcessRequest[] = [];
  files = new Map<string, string>();
  paths = new Map<string, string>();
  output: { code: number; stdout: string; stderr: string };
  inspect: unknown;
  failure: unknown;
  afterSql: (() => void) | undefined;
  deferred: Promise<LocalSqlProcessResult> | undefined;
  constructor(c: LocalSqlContext) {
    this.files.set(
      key(win32.join(c.local.projectRoot, ".coelo-safe-replay")),
      c.local.projectId,
    );
    this.files.set(
      key(win32.join(c.local.projectRoot, "supabase", "config.toml")),
      `# synthetic fixture\nproject_id = "${c.local.projectId}"\n[db]\nport = 54322\n`,
    );
    this.inspect = [{
      Id: c.local.containerId,
      Name: `/supabase_db_${c.local.projectId}`,
      State: { Running: true },
      Config: { Labels: { "com.supabase.cli.project": c.local.projectId } },
    }];
    this.output = {
      code: 0,
      stdout: verifyOutput(c.plan, "active"),
      stderr: "",
    };
  }
  readTextFile(path: string): Promise<string> {
    const value = this.files.get(key(path));
    return value === undefined
      ? Promise.reject(new Error("synthetic-private-secret missing file"))
      : Promise.resolve(value);
  }
  realPath(path: string): Promise<string> {
    return Promise.resolve(this.paths.get(key(path)) ?? win32.normalize(path));
  }
  run(request: LocalSqlProcessRequest): Promise<LocalSqlProcessResult> {
    this.calls.push(structuredClone(request));
    if (request.args.includes("inspect")) {
      return Promise.resolve({
        code: 0,
        stdout: JSON.stringify(this.inspect),
        stderr: "",
      });
    }
    this.afterSql?.();
    if (this.failure !== undefined) return Promise.reject(this.failure);
    return this.deferred ?? Promise.resolve(this.output);
  }
  get sqlCalls() {
    return this.calls.filter((call) => !call.args.includes("inspect"));
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
function request(p: Plan, state: State = "active") {
  return {
    planId: p.id,
    kind: "verify" as const,
    sql: privateVerifySql(p, state),
  };
}

Deno.test("local SQL verifies three nominal states bound to one immutable local container", async () => {
  const c = context();
  const runtime = new Runtime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const environment = { kind: "local", projectId, containerId };
  assert.deepEqual(executor.environment, environment);
  assert(!Object.hasOwn(executor, "projectRef"));
  assert.deepEqual(runtime.calls[0], {
    executable: c.local.dockerPath,
    args: [
      "--host",
      c.local.dockerHost,
      "inspect",
      "--type",
      "container",
      "--format",
      '[{"Id":{{json .Id}},"Name":{{json .Name}},"State":{"Running":{{json .State.Running}}},"Config":{"Labels":{"com.supabase.cli.project":{{json (index .Config.Labels "com.supabase.cli.project")}}}}}]',
      containerId,
    ],
    stdin: "",
    timeoutMs: 90000,
  });
  assert(!runtime.calls[0].args.some((argument) => argument.includes(".Env")));
  for (const state of ["active", "scenario-revoked", "revoked"] as const) {
    runtime.output.stdout = verifyOutput(c.plan, state);
    assert.deepEqual(await executor.execute(request(c.plan, state)), {
      environment,
      completed: true,
      rows: [payload(c.plan, state)],
    });
  }
  assert.equal(runtime.calls.length, 4);
  for (const call of runtime.sqlCalls) {
    assert.equal(call.executable, c.local.dockerPath);
    assert.deepEqual(call.args.slice(0, 4), [
      "--host",
      c.local.dockerHost,
      "exec",
      "-i",
    ]);
    for (
      const argument of [
        containerId,
        "/var/run/postgresql",
        "5432",
        "PGOPTIONS=-c statement_timeout=60000",
        "PGSERVICE=",
        "PGHOSTADDR=",
        "PGSERVICEFILE=/dev/null",
        "ON_ERROR_STOP=1",
        "-X",
        "-A",
        "-t",
      ]
    ) assert(call.args.includes(argument), argument);
    assert(!call.args.includes(call.stdin), "SQL must use stdin, never argv");
    assert.equal(call.timeoutMs, 90000);
    assert.deepEqual(Object.keys(call).sort(), [
      "args",
      "executable",
      "stdin",
      "timeoutMs",
    ]);
  }
});

Deno.test("local SQL confirms both nominal revokes only after the complete command sequence", async () => {
  const c = context();
  const runtime = new Runtime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  runtime.output.stdout = revokeOutput();
  for (const scope of ["scenario", "all"] as const) {
    const sql = privateRevokeSql(c.plan, actor, scope);
    assert.deepEqual(
      await executor.execute({ planId: c.plan.id, kind: "revoke", sql }),
      { environment: executor.environment, completed: true, rows: [] },
    );
    assert.equal(runtime.sqlCalls.at(-1)?.stdin, sql);
  }
  assert.equal(runtime.calls.length, 3);
});

Deno.test("local factory rejects unsafe or foreign identity before any process", async () => {
  const cases: ((c: ReturnType<typeof context>) => void)[] = [
    (c) => {
      c.local.projectId = "production";
    },
    (c) => {
      c.local.projectRoot = "relative";
    },
    (c) => {
      c.local.projectRoot = "C:\\Temp\\different";
    },
    (c) => {
      c.local.projectRoot = `\\\\server\\share\\${projectId}`;
    },
    (c) => {
      c.local.dockerPath = "docker.exe";
    },
    (c) => {
      c.local.containerId = "b".repeat(12);
    },
    (c) => {
      c.local.dockerHost = "tcp://127.0.0.1:2375";
    },
    (c) => {
      c.local.dockerHost = "ssh://synthetic-private-secret";
    },
    (c) => {
      c.local.dockerHost = "unix:///var/run/docker.sock";
    },
  ];
  for (const mutate of cases) {
    const c = context();
    const runtime = new Runtime(c);
    mutate(c);
    await sanitizedFailure(() => localPersonaSqlExecutor(c, runtime));
    assert.equal(runtime.calls.length, 0);
  }
});

Deno.test("local factory requires exact marker, unique top-level project id and resolved paths", async () => {
  const validConfig = `project_id = "${projectId}"\n`;
  for (
    const text of [
      "",
      'project_id = "other"\n',
      validConfig + validConfig,
      validConfig + `"project_id" = "${projectId}"\n`,
      `[db]\n${validConfig}`,
      `project_id = '${projectId}'\n`,
    ]
  ) {
    const c = context();
    const runtime = new Runtime(c);
    runtime.files.set(
      key(win32.join(c.local.projectRoot, "supabase", "config.toml")),
      text,
    );
    await sanitizedFailure(() => localPersonaSqlExecutor(c, runtime));
    assert.equal(runtime.calls.length, 0);
  }
  for (const pathKind of ["marker", "root", "config", "docker"] as const) {
    const c = context();
    const runtime = new Runtime(c);
    const paths = {
      marker: win32.join(c.local.projectRoot, ".coelo-safe-replay"),
      root: c.local.projectRoot,
      config: win32.join(c.local.projectRoot, "supabase", "config.toml"),
      docker: c.local.dockerPath,
    };
    runtime.paths.set(
      key(paths[pathKind]),
      "C:\\foreign\\synthetic-private-secret",
    );
    await sanitizedFailure(() => localPersonaSqlExecutor(c, runtime));
    assert.equal(runtime.calls.length, 0);
  }
  const c = context();
  const runtime = new Runtime(c);
  runtime.files.set(
    key(win32.join(c.local.projectRoot, ".coelo-safe-replay")),
    projectId + "\n",
  );
  await sanitizedFailure(() => localPersonaSqlExecutor(c, runtime));
  assert.equal(runtime.calls.length, 0);
});

Deno.test("local factory rejects foreign, stopped, ambiguous and unlabelled inspected containers", async () => {
  for (
    const mutate of [
      (r: Record<string, unknown>) => {
        r.Id = "c".repeat(64);
      },
      (r: Record<string, unknown>) => {
        r.Name = "/supabase_db_other";
      },
      (r: Record<string, unknown>) => {
        r.State = { Running: false };
      },
      (r: Record<string, unknown>) => {
        r.State = { Running: "true" };
      },
      (r: Record<string, unknown>) => {
        r.Config = { Labels: {} };
      },
      (r: Record<string, unknown>) => {
        r.Config = { Labels: { "com.supabase.cli.project": "other" } };
      },
    ]
  ) {
    const c = context();
    const runtime = new Runtime(c);
    mutate((runtime.inspect as Record<string, unknown>[])[0]);
    await sanitizedFailure(() => localPersonaSqlExecutor(c, runtime));
    assert.equal(runtime.calls.length, 1);
  }
  for (const shape of [[], [{}, {}], {}, null]) {
    const c = context();
    const runtime = new Runtime(c);
    runtime.inspect = shape;
    await sanitizedFailure(() => localPersonaSqlExecutor(c, runtime));
    assert.equal(runtime.calls.length, 1);
  }
});

Deno.test("local SQL refuses changed plan, unsupported operations and noncanonical SQL before exec", async () => {
  const c = context();
  const runtime = new Runtime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const valid = request(c.plan);
  const changed = structuredClone(c.plan);
  changed.personas[0].authUserId = "55555555-5555-4555-8555-555555555555";
  for (
    const invalid of [
      { ...valid, planId: "other" },
      { ...valid, sql: valid.sql + "select 1;" },
      { ...valid, kind: "revoke" },
      { ...valid, kind: "provision" },
      { ...valid, sql: privateVerifySql(changed, "active") },
      { ...valid, sql: valid.sql.replace("begin read only;", "begin;") },
    ]
  ) {
    await sanitizedFailure(() =>
      executor.execute(invalid as Parameters<typeof executor.execute>[0])
    );
  }
  assert.equal(runtime.sqlCalls.length, 0);
});

Deno.test("local SQL rejects incomplete, extra, malformed and mismatched verification output", async () => {
  const c = context();
  const runtime = new Runtime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const valid = verifyOutput(c.plan, "active");
  const proof = payload(c.plan, "active");
  const invalid = [
    "\ufeff" + valid,
    "",
    valid.replace("COMMIT\n", ""),
    valid.replace("COMMIT", "ROLLBACK"),
    valid.slice(0, -1),
    valid + "extra\n",
    valid.replace("BEGIN\n", "BEGIN\nSET\n"),
    `BEGIN\n${JSON.stringify(proof, null, 2)}\nCOMMIT\n`,
    verifyOutput(c.plan, "revoked"),
    verifyOutput(c.plan, "active", { ...proof, verified: "true" }),
    verifyOutput(c.plan, "active", { ...proof, extra: true }),
    verifyOutput(c.plan, "active", {
      ...proof,
      personas: proof.personas.slice(0, 4),
    }),
    verifyOutput(c.plan, "active", {
      ...proof,
      personas: [...proof.personas.slice(0, 4), proof.personas[0]],
    }),
    verifyOutput(c.plan, "active", { ...proof, verified: false }),
    valid.replace('"planId":', '"planId":"other","planId":'),
    valid.replace('"planId":', '"pl\\u0061nId":"other","planId":'),
  ];
  for (const stdout of invalid) {
    runtime.output.stdout = stdout;
    await sanitizedFailure(() => executor.execute(request(c.plan)));
  }
  assert.equal(
    runtime.sqlCalls.length,
    invalid.length,
    "one subprocess each, no retry",
  );
});

Deno.test("local SQL preserves negative and target-only proofs without claiming full verification", async () => {
  const c = context();
  const runtime = new Runtime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  for (const state of ["active", "scenario-revoked"] as const) {
    const proof = payload(c.plan, state);
    proof.personas[0].private_bindings = false;
    proof.verified = false;
    runtime.output.stdout = verifyOutput(c.plan, state, proof);
    assert.deepEqual((await executor.execute(request(c.plan, state))).rows, [
      proof,
    ]);
  }
});

Deno.test("local SQL rejects incomplete revoke, foreign claims and extra output without retry", async () => {
  const c = context();
  const runtime = new Runtime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const valid = revokeOutput();
  const invalid = [
    "",
    valid.replace("COMMIT\n", ""),
    valid.replace("DO\n", ""),
    valid.slice(0, -1),
    valid.replace("SET\nSET\n\n", "SET\nSET\n"),
    valid.replace("SET\nSET\n\n", "SET\nSET\n\n\n"),
    valid + "SELECT 1\n",
    valid.replace(actor.sessionId, "55555555-5555-4555-8555-555555555555"),
    valid.replace('"aal":"aal1"', '"aal":"aal1","extra":true'),
  ];
  for (const stdout of invalid) {
    runtime.output.stdout = stdout;
    await sanitizedFailure(() =>
      executor.execute({
        planId: c.plan.id,
        kind: "revoke",
        sql: privateRevokeSql(c.plan, actor, "all"),
      })
    );
  }
  assert.equal(runtime.sqlCalls.length, invalid.length);
});

Deno.test("local SQL sanitizes timeout, thrown and late process errors without repeating a write", async () => {
  for (
    const failure of [
      new Error("synthetic-private-secret timeout"),
      "synthetic-private-secret",
      null,
      undefined,
    ]
  ) {
    const c = context();
    const runtime = new Runtime(c);
    const executor = await localPersonaSqlExecutor(c, runtime);
    runtime.output = {
      code: failure === null ? 1 : 0,
      stdout: revokeOutput(),
      stderr: "synthetic-private-secret late error",
    };
    if (failure !== null) runtime.failure = failure;
    await sanitizedFailure(() =>
      executor.execute({
        planId: c.plan.id,
        kind: "revoke",
        sql: privateRevokeSql(c.plan, actor, "all"),
      })
    );
    assert.equal(runtime.sqlCalls.length, 1);
  }
});

Deno.test("local SQL rechecks marker, config and resolved paths before and after executing", async () => {
  for (const phase of ["before", "during"] as const) {
    for (const target of ["marker", "config", "root", "docker"] as const) {
      const c = context();
      const runtime = new Runtime(c);
      const executor = await localPersonaSqlExecutor(c, runtime);
      const change = () => {
        if (target === "marker") {
          runtime.files.set(
            key(win32.join(c.local.projectRoot, ".coelo-safe-replay")),
            "other",
          );
        }
        if (target === "config") {
          runtime.files.set(
            key(win32.join(c.local.projectRoot, "supabase", "config.toml")),
            `project_id = "${projectId}"\n# changed after factory\n`,
          );
        }
        if (target === "root") {
          runtime.paths.set(key(c.local.projectRoot), "C:\\foreign");
        }
        if (target === "docker") {
          runtime.paths.set(key(c.local.dockerPath), "C:\\foreign\\docker.exe");
        }
      };
      if (phase === "before") change();
      else runtime.afterSql = change;
      await sanitizedFailure(() => executor.execute(request(c.plan)));
      assert.equal(runtime.sqlCalls.length, phase === "before" ? 0 : 1);
    }
  }
});

Deno.test("local SQL freezes nominal inputs and never relabels local results as a remote project", async () => {
  const c = context();
  const original = structuredClone(c);
  const runtime = new Runtime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  c.actor.authUserId = "55555555-5555-4555-8555-555555555555";
  c.local.containerId = "c".repeat(64);
  c.plan.personas[0].authUserId = "55555555-5555-4555-8555-555555555555";
  const result = await executor.execute(request(original.plan));
  assert.deepEqual(result.environment, {
    kind: "local",
    projectId,
    containerId,
  });
  assert(!Object.hasOwn(result, "projectRef"));
  assert(runtime.sqlCalls[0].args.includes(containerId));
  assert(!runtime.sqlCalls[0].args.includes(c.local.containerId));
});

Deno.test("local SQL refuses request identity or SQL changed while the subprocess is pending", async () => {
  for (const field of ["planId", "kind", "sql"] as const) {
    const c = context();
    const runtime = new Runtime(c);
    const executor = await localPersonaSqlExecutor(c, runtime);
    const input: Parameters<typeof executor.execute>[0] = request(c.plan);
    runtime.afterSql = () => {
      Object.assign(input, {
        [field]: field === "kind"
          ? "revoke"
          : "synthetic-private-secret changed",
      });
    };
    await sanitizedFailure(() => executor.execute(input));
    assert.equal(runtime.sqlCalls.length, 1);
  }
});

Deno.test("local SQL prevents overlapping executions and permits a later explicit request after failure", async () => {
  const c = context();
  const runtime = new Runtime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const released = Promise.withResolvers<LocalSqlProcessResult>();
  const entered = Promise.withResolvers<void>();
  runtime.deferred = released.promise;
  runtime.afterSql = () => entered.resolve();
  const pending = executor.execute(request(c.plan));
  const pendingFailure = sanitizedFailure(() => pending);
  await entered.promise;
  await sanitizedFailure(() => executor.execute(request(c.plan)));
  assert.equal(runtime.sqlCalls.length, 1);
  released.reject(new Error("synthetic-private-secret response lost"));
  await pendingFailure;
  runtime.deferred = undefined;
  runtime.afterSql = undefined;
  assert.equal((await executor.execute(request(c.plan))).completed, true);
  assert.equal(
    runtime.sqlCalls.length,
    2,
    "explicit new call, never an automatic retry",
  );
});

const correlation = "66666666-6666-4666-8666-666666666666";
const nextCorrelation = "77777777-7777-4777-8777-777777777777";
const apiConfig =
  "[api]\nenabled = true\nport = 54321\n[api.tls]\nenabled = false\n";
function banRuntime(c: LocalSqlContext, api = apiConfig) {
  const runtime = new Runtime(c);
  const configPath = key(
    win32.join(c.local.projectRoot, "supabase", "config.toml"),
  );
  runtime.files.set(configPath, runtime.files.get(configPath)! + api);
  runtime.output.stdout = banOutput(banPayload(c.plan));
  return runtime;
}
function banPayload(p: Plan, index = 0, requestCorrelation = correlation) {
  const persona = p.personas[index];
  return {
    planId: p.id,
    authUserId: persona.authUserId,
    correlation: requestCorrelation,
    email: persona.email,
    package: PACKAGE,
    persona: persona.persona,
    planMarker: p.id,
    bannedUntil: "2026-09-08T23:00:00.123457Z" as string | null,
    observedAt: "2026-09-08T23:00:00.123456Z",
    isBanned: true,
  };
}
function banOutput(proof: unknown) {
  return `BEGIN\n${JSON.stringify(proof)}\nCOMMIT\n`;
}
function banRequest(p: Plan, index = 0, requestCorrelation = correlation) {
  const authUserId = p.personas[index].authUserId;
  return {
    planId: p.id,
    authUserId,
    correlation: requestCorrelation,
    sql: nominalBanSql(p, authUserId, requestCorrelation),
  };
}

Deno.test("local ban returns one bound proof for each nominal AuthID using the configured local Auth URL", async () => {
  const c = context();
  const runtime = banRuntime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const authUrl = "http://127.0.0.1:54321/auth/v1";
  assert.equal(executor.localAuthUrl, authUrl);
  for (let index = 0; index < c.plan.personas.length; index++) {
    const proof = banPayload(c.plan, index);
    if (index % 2 === 1) {
      proof.bannedUntil = null;
      proof.isBanned = false;
    }
    runtime.output.stdout = banOutput(proof);
    const input = banRequest(c.plan, index);
    const result = await executor.readBan(input);
    assert.deepEqual(result, {
      environment: { kind: "local", projectId, containerId },
      authUrl,
      completed: true,
      rows: [proof],
    });
    assert(!Object.hasOwn(result, "projectRef"));
    assert.equal(runtime.sqlCalls.at(-1)?.stdin, input.sql);
    assert(runtime.sqlCalls.at(-1)?.args.includes("PGHOSTADDR="));
    assert(!runtime.sqlCalls.at(-1)?.args.includes(input.sql));
  }
  assert.equal(runtime.sqlCalls.length, 5);
});

Deno.test("local ban requires an unambiguous enabled HTTP API while old verification does not", async () => {
  for (
    const config of [
      "",
      apiConfig.replace("enabled = true", "enabled = false"),
      apiConfig.replace("port = 54321\n", ""),
      apiConfig.replace("port = 54321", "port = 0"),
      apiConfig.replace("port = 54321", "port = 65536"),
      apiConfig.replace("port = 54321", 'port = "54321"'),
      apiConfig.replace("port = 54321", "port = 54321\nport = 54322"),
      apiConfig.replace("enabled = false", "enabled = true"),
      apiConfig.replace("[api.tls]\nenabled = false\n", ""),
    ]
  ) {
    const c = context();
    const runtime = banRuntime(c, config);
    const executor = await localPersonaSqlExecutor(c, runtime);
    assert.equal(executor.localAuthUrl, undefined);
    await sanitizedFailure(() => executor.readBan(banRequest(c.plan)));
    assert.equal(runtime.sqlCalls.length, 0);
    runtime.output.stdout = verifyOutput(c.plan, "active");
    assert.equal((await executor.execute(request(c.plan))).completed, true);
    assert.equal(runtime.sqlCalls.length, 1);
  }
});

Deno.test("local ban rejects foreign IDs, correlations and noncanonical SQL before execution", async () => {
  const c = context();
  const runtime = banRuntime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const valid = banRequest(c.plan);
  const wrongId = "88888888-8888-4888-8888-888888888888";
  for (
    const input of [
      { ...valid, planId: wrongId },
      { ...valid, authUserId: wrongId },
      { ...valid, authUserId: c.plan.personas[1].authUserId },
      { ...valid, correlation: "not-a-uuid" },
      { ...valid, correlation: nextCorrelation },
      { ...valid, sql: valid.sql + "select 1;" },
      { ...valid, sql: privateVerifySql(c.plan, "active") },
      { ...valid, sql: valid.sql.replace("begin read only;", "begin;") },
      { ...valid, extra: true },
    ]
  ) {
    await sanitizedFailure(() => executor.readBan(input));
  }
  await sanitizedFailure(() =>
    executor.execute({
      planId: c.plan.id,
      kind: "verify",
      sql: valid.sql,
    })
  );
  assert.equal(runtime.sqlCalls.length, 0);
});

Deno.test("local ban requires exactly one complete proof and rejects framing, duplicate keys and process errors", async () => {
  const c = context();
  const runtime = banRuntime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const proof = banPayload(c.plan);
  const valid = banOutput(proof);
  const invalid = [
    "BEGIN\nCOMMIT\n",
    "BEGIN\n\nCOMMIT\n",
    `BEGIN\n${JSON.stringify(proof)}\n${JSON.stringify(proof)}\nCOMMIT\n`,
    valid.replace("COMMIT\n", ""),
    valid.replace("COMMIT", "ROLLBACK"),
    valid + "extra\n",
    valid.slice(0, -1),
    "\ufeff" + valid,
    `BEGIN\n${JSON.stringify(proof, null, 2)}\nCOMMIT\n`,
    valid.replace('"correlation":', '"correlation":"other","correlation":'),
    valid.replace(
      '"correlation":',
      '"correlat\\u0069on":"other","correlation":',
    ),
  ];
  for (const stdout of invalid) {
    runtime.output.stdout = stdout;
    await sanitizedFailure(() => executor.readBan(banRequest(c.plan)));
  }
  assert.equal(runtime.sqlCalls.length, invalid.length);
  runtime.output.stdout = valid;
  for (
    const output of [
      { code: 1, stdout: valid, stderr: "" },
      { code: 0, stdout: valid, stderr: "synthetic-private-secret late error" },
    ]
  ) {
    runtime.output = output;
    await sanitizedFailure(() => executor.readBan(banRequest(c.plan)));
  }
  assert.equal(runtime.sqlCalls.length, invalid.length + 2);
});

Deno.test("local ban validates identity, explicit null and microsecond boolean consistency in the transport", async () => {
  const c = context();
  const runtime = banRuntime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const proof = banPayload(c.plan);
  const omitted: Record<string, unknown> = { ...proof };
  delete omitted.bannedUntil;
  for (
    const invalid of [
      { ...proof, planId: nextCorrelation },
      { ...proof, authUserId: c.plan.personas[1].authUserId },
      { ...proof, correlation: nextCorrelation },
      { ...proof, email: c.plan.personas[1].email },
      { ...proof, package: "other" },
      { ...proof, persona: "op-b" },
      { ...proof, planMarker: nextCorrelation },
      { ...proof, isBanned: "true" },
      { ...proof, isBanned: false },
      { ...proof, bannedUntil: null },
      { ...proof, bannedUntil: proof.observedAt },
      { ...proof, observedAt: "2026-09-08T23:00:00.123456+00:00" },
      { ...proof, observedAt: "2026-02-30T23:00:00.123456Z" },
      { ...proof, extra: true },
      omitted,
      null,
      [proof],
    ]
  ) {
    runtime.output.stdout = banOutput(invalid);
    await sanitizedFailure(() => executor.readBan(banRequest(c.plan)));
  }
  for (
    const bannedUntil of [null, proof.observedAt, "2026-09-08T23:00:00.123455Z"]
  ) {
    const valid = { ...proof, bannedUntil, isBanned: false };
    runtime.output.stdout = banOutput(valid);
    assert.deepEqual((await executor.readBan(banRequest(c.plan))).rows, [
      valid,
    ]);
  }
});

Deno.test("local ban rechecks local identity and API config before and after its subprocess", async () => {
  for (const phase of ["before", "during"] as const) {
    for (const target of ["config", "marker", "root"] as const) {
      const c = context();
      const runtime = banRuntime(c);
      const executor = await localPersonaSqlExecutor(c, runtime);
      const change = () => {
        if (target === "config") {
          const configPath = key(
            win32.join(c.local.projectRoot, "supabase", "config.toml"),
          );
          runtime.files.set(
            configPath,
            runtime.files.get(configPath)!.replace("54321", "54323"),
          );
        } else if (target === "marker") {
          runtime.files.set(
            key(win32.join(c.local.projectRoot, ".coelo-safe-replay")),
            "other",
          );
        } else {
          runtime.paths.set(key(c.local.projectRoot), "C:\\foreign");
        }
      };
      if (phase === "before") change();
      else runtime.afterSql = change;
      await sanitizedFailure(() => executor.readBan(banRequest(c.plan)));
      assert.equal(runtime.sqlCalls.length, phase === "before" ? 0 : 1);
    }
  }
});

Deno.test("local ban refuses request identity or SQL changed while its subprocess is pending", async () => {
  for (const field of ["planId", "authUserId", "correlation", "sql"] as const) {
    const c = context();
    const runtime = banRuntime(c);
    const executor = await localPersonaSqlExecutor(c, runtime);
    const input = banRequest(c.plan);
    runtime.afterSql = () => {
      input[field] = "synthetic-private-secret changed";
    };
    await sanitizedFailure(() => executor.readBan(input));
    assert.equal(runtime.sqlCalls.length, 1);
  }
});

Deno.test("local ban shares the execution lock and allows only an explicit fresh reconciliation after response loss", async () => {
  const c = context();
  const runtime = banRuntime(c);
  const executor = await localPersonaSqlExecutor(c, runtime);
  const released = Promise.withResolvers<LocalSqlProcessResult>();
  const entered = Promise.withResolvers<void>();
  runtime.deferred = released.promise;
  runtime.afterSql = () => entered.resolve();
  const pending = executor.readBan(banRequest(c.plan));
  const failed = sanitizedFailure(() => pending);
  await entered.promise;
  await sanitizedFailure(() =>
    executor.readBan(banRequest(c.plan, 0, nextCorrelation))
  );
  await sanitizedFailure(() => executor.execute(request(c.plan)));
  assert.equal(runtime.sqlCalls.length, 1);
  released.reject(new Error("synthetic-private-secret response lost"));
  await failed;
  runtime.deferred = undefined;
  runtime.afterSql = undefined;
  const proof = banPayload(c.plan, 0, nextCorrelation);
  runtime.output.stdout = banOutput(proof);
  assert.deepEqual(
    (await executor.readBan(banRequest(c.plan, 0, nextCorrelation))).rows,
    [proof],
  );
  assert.equal(runtime.sqlCalls.length, 2);
});
