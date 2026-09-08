import assert from "node:assert/strict";
import { win32 } from "node:path";
import {
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
