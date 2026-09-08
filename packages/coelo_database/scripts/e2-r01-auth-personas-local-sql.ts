// I019: local disposable transport only. No remote PrivateSqlExecutor cast.
// C00 must grant a live local lease before using the default runtime.
import { win32 as path } from "node:path";
import {
  PackageError,
  PERSONAS,
  type Plan,
  privateRevokeSql,
  privateVerifySql,
  validatePlan,
} from "./e2-r01-auth-personas.ts";

export interface LocalSqlContext {
  readonly plan: Plan;
  readonly actor: { readonly authUserId: string; readonly sessionId: string };
  readonly local: {
    readonly projectRoot: string;
    readonly projectId: string;
    readonly containerId: string;
    readonly dockerPath: string;
    readonly dockerHost: string;
  };
}
export interface LocalSqlProcessRequest {
  readonly executable: string;
  readonly args: readonly string[];
  readonly stdin: string;
  readonly timeoutMs: number;
}
export interface LocalSqlProcessResult {
  readonly code: number;
  readonly stdout: string;
  readonly stderr: string;
}
export interface LocalSqlRuntime {
  readTextFile(path: string): Promise<string>;
  realPath(path: string): Promise<string>;
  run(request: LocalSqlProcessRequest): Promise<LocalSqlProcessResult>;
}
type State = "active" | "scenario-revoked" | "revoked";
const outputLimit = 128 * 1024;
const timeoutMs = 90_000;
// Request only identity fields, never container Env (which can contain secrets).
const inspectionFormat =
  '[{"Id":{{json .Id}},"Name":{{json .Name}},"State":{"Running":{{json .State.Running}}},"Config":{"Labels":{"com.supabase.cli.project":{{json (index .Config.Labels "com.supabase.cli.project")}}}}}]';

function requireValue(value: unknown): asserts value {
  if (!value) throw new PackageError("LOCAL_SQL_UNCONFIRMED");
}
function record(value: unknown): asserts value is Record<string, unknown> {
  requireValue(
    value !== null && typeof value === "object" && !Array.isArray(value),
  );
}
function exact(
  value: unknown,
  keys: readonly string[],
): asserts value is Record<string, unknown> {
  record(value);
  requireValue(
    Object.keys(value).length === keys.length &&
      keys.every((key) => Object.hasOwn(value, key)),
  );
}
function canonical(file: string): string {
  requireValue(
    typeof file === "string" && /^[A-Za-z]:[\\/]/.test(file) &&
      !/[\0\r\n]/.test(file),
  );
  return path.normalize(file).toLowerCase();
}

// JSON.parse alone silently accepts duplicate keys. Scan structural tokens,
// decoding key escapes, while JSON.parse remains responsible for JSON syntax.
function strictJson(text: string): unknown {
  const value: unknown = JSON.parse(text);
  const tokens = text.match(
    /"(?:[^"\\]|\\.)*"|[{}\[\]:,]|true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g,
  ) ?? [];
  const stack: Array<Set<string> | null> = [];
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (token === "{") stack.push(new Set());
    else if (token === "[") stack.push(null);
    else if (token === "}" || token === "]") stack.pop();
    else if (token.startsWith('"') && tokens[i + 1] === ":") {
      const keys = stack.at(-1);
      const key: string = JSON.parse(token);
      requireValue(keys && !keys.has(key));
      keys.add(key);
    }
  }
  return value;
}

function verifyPayload(value: unknown, planId: string, state: State) {
  exact(value, [
    "planId",
    "state",
    "verified",
    "revocationVerified",
    "personas",
  ]);
  requireValue(
    value.planId === planId && value.state === state &&
      typeof value.verified === "boolean" &&
      typeof value.revocationVerified === "boolean" &&
      Array.isArray(value.personas) &&
      value.personas.length === PERSONAS.length,
  );
  const seen = new Set<string>();
  const checks = value.personas.map((item: unknown) => {
    exact(item, [
      "persona",
      "revocation_target",
      "auth_owned",
      "no_people_link",
      "private_bindings",
    ]);
    requireValue(
      typeof item.persona === "string" && PERSONAS.some((p) =>
        p === item.persona
      ) && !seen.has(item.persona),
    );
    seen.add(item.persona);
    const terminal = state === "revoked" ||
      (state === "scenario-revoked" && item.persona === "revoked");
    requireValue(
      item.revocation_target === terminal &&
        [item.auth_owned, item.no_people_link, item.private_bindings].every((
          v,
        ) => typeof v === "boolean"),
    );
    return {
      terminal,
      valid: item.auth_owned && item.no_people_link && item.private_bindings,
    };
  });
  requireValue(
    seen.size === PERSONAS.length &&
      value.verified === checks.every((item) => item.valid) &&
      value.revocationVerified ===
        (state !== "active" &&
          checks.filter((item) => item.terminal).every((item) => item.valid)),
  );
  return value;
}

// One process, concurrent pipe drains, bounded output and no shell or inherited
// Docker context. A killed Docker client may leave its exec finishing server-side:
// a timeout never authorizes a write retry or cleanup of another lease's process.
async function runProcess(
  request: LocalSqlProcessRequest,
): Promise<LocalSqlProcessResult> {
  const child = new Deno.Command(request.executable, {
    args: [...request.args],
    clearEnv: true,
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
  }).spawn();
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    try {
      child.kill("SIGKILL");
    } catch { /* already exited */ }
  }, request.timeoutMs);
  async function drain(stream: ReadableStream<Uint8Array>): Promise<string> {
    const reader = stream.getReader();
    const decoder = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
    let bytes = 0;
    let result = "";
    let invalid = false;
    try {
      while (true) {
        const item = await reader.read();
        if (item.done) break;
        bytes += item.value.length;
        if (bytes > outputLimit) invalid = true;
        if (!invalid) {
          try {
            result += decoder.decode(item.value, { stream: true });
          } catch {
            invalid = true;
          }
        }
      }
      requireValue(!invalid);
      return result + decoder.decode();
    } finally {
      reader.releaseLock();
    }
  }
  const write = async () => {
    const writer = child.stdin.getWriter();
    try {
      await writer.write(new TextEncoder().encode(request.stdin));
      await writer.close();
    } finally {
      writer.releaseLock();
    }
  };
  try {
    const result = await Promise.allSettled([
      child.status,
      drain(child.stdout),
      drain(child.stderr),
      write(),
    ]);
    requireValue(
      !timedOut && result.every((item) => item.status === "fulfilled"),
    );
    const status = result[0];
    const stdout = result[1];
    const stderr = result[2];
    requireValue(
      status.status === "fulfilled" && stdout.status === "fulfilled" &&
        stderr.status === "fulfilled",
    );
    return {
      code: status.value.code,
      stdout: stdout.value,
      stderr: stderr.value,
    };
  } finally {
    clearTimeout(timer);
  }
}
const defaultRuntime: LocalSqlRuntime = {
  readTextFile: (file) => Deno.readTextFile(file),
  realPath: (file) => Deno.realPath(file),
  run: runProcess,
};

export async function localPersonaSqlExecutor(
  context: LocalSqlContext,
  runtime: LocalSqlRuntime = defaultRuntime,
) {
  try {
    const nominal = structuredClone(context);
    validatePlan(nominal.plan);
    const { local, actor, plan } = nominal;
    requireValue(
      /^coelo_safe_[0-9a-f]{29}$/.test(local.projectId) &&
        /^[0-9a-f]{64}$/.test(local.containerId),
    );
    requireValue(
      canonical(local.projectRoot) ===
          canonical(path.join(local.projectRoot, ".")) &&
        path.basename(local.projectRoot) === local.projectId,
    );
    canonical(local.dockerPath);
    requireValue(
      [
        "npipe:////./pipe/dockerDesktopLinuxEngine",
        "npipe:////./pipe/docker_engine",
      ].includes(local.dockerHost),
    );
    const markerPath = `${local.projectRoot}/.coelo-safe-replay`;
    const configPath = `${local.projectRoot}/supabase/config.toml`;
    const environment = Object.freeze({
      kind: "local" as const,
      projectId: local.projectId,
      containerId: local.containerId,
    });
    const verifyQueries = new Map<string, State>();
    for (const state of ["active", "scenario-revoked", "revoked"] as const) {
      verifyQueries.set(privateVerifySql(plan, state), state);
    }
    const revokeQueries = new Set([
      privateRevokeSql(plan, actor, "scenario"),
      privateRevokeSql(plan, actor, "all"),
    ]);
    let fixedConfig: string | undefined;
    const assertIdentity = async () => {
      const files = [
        local.projectRoot,
        markerPath,
        configPath,
        local.dockerPath,
      ];
      const resolved = await Promise.all(
        files.map((file) => runtime.realPath(file)),
      );
      requireValue(
        files.every((file, i) => canonical(file) === canonical(resolved[i])),
      );
      const [marker, config] = await Promise.all([
        runtime.readTextFile(markerPath),
        runtime.readTextFile(configPath),
      ]);
      requireValue(marker === local.projectId && config.length < outputLimit);
      const beforeTable = config.split(/^\s*\[/m)[0];
      const declarations = config.match(
        /^[\t ]*(?:project_id|"project_id"|'project_id')\s*=.*$/gm,
      ) ?? [];
      const expected = new RegExp(
        `^\\s*project_id\\s*=\\s*"${local.projectId}"\\s*(?:#.*)?$`,
        "m",
      );
      requireValue(declarations.length === 1 && expected.test(beforeTable));
      if (fixedConfig === undefined) fixedConfig = config;
      else requireValue(config === fixedConfig);
    };
    const successful = (result: LocalSqlProcessResult) => {
      exact(result, ["code", "stdout", "stderr"]);
      requireValue(
        result.code === 0 && result.stderr === "" &&
          typeof result.stdout === "string" &&
          result.stdout.length <= outputLimit,
      );
    };
    await assertIdentity();
    const inspection = await runtime.run({
      executable: local.dockerPath,
      args: [
        "--host",
        local.dockerHost,
        "inspect",
        "--type",
        "container",
        "--format",
        inspectionFormat,
        local.containerId,
      ],
      stdin: "",
      timeoutMs,
    });
    successful(inspection);
    const inspected = strictJson(inspection.stdout);
    requireValue(Array.isArray(inspected) && inspected.length === 1);
    const container: unknown = inspected[0];
    record(container);
    record(container.State);
    record(container.Config);
    record(container.Config.Labels);
    requireValue(
      container.Id === local.containerId &&
        container.Name === `/supabase_db_${local.projectId}` &&
        container.State.Running === true &&
        container.Config.Labels["com.supabase.cli.project"] === local.projectId,
    );
    await assertIdentity();
    let executing = false;
    return Object.freeze({
      environment,
      async execute(
        request: {
          readonly planId: string;
          readonly kind: "verify" | "revoke";
          readonly sql: string;
        },
      ) {
        let acquired = false;
        try {
          exact(request, ["planId", "kind", "sql"]);
          requireValue(
            request.planId === plan.id && typeof request.sql === "string",
          );
          const { sql, kind } = request;
          const state = verifyQueries.get(sql);
          requireValue(
            (kind === "verify" && state !== undefined) ||
              (kind === "revoke" && revokeQueries.has(sql)),
          );
          requireValue(!executing);
          executing = true;
          acquired = true;
          await assertIdentity();
          const output = await runtime.run({
            executable: local.dockerPath,
            args: [
              "--host",
              local.dockerHost,
              "exec",
              "-i",
              "--env",
              "PGOPTIONS=-c statement_timeout=60000",
              "--env",
              "PGHOSTADDR=",
              "--env",
              "PGSERVICE=",
              "--env",
              "PGSERVICEFILE=/dev/null",
              "--env",
              "PGPASSFILE=/dev/null",
              "--env",
              "PGCLIENTENCODING=UTF8",
              local.containerId,
              "psql",
              "-X",
              "-A",
              "-t",
              "--host",
              "/var/run/postgresql",
              "--port",
              "5432",
              "--username",
              "postgres",
              "--dbname",
              "postgres",
              "--set",
              "ON_ERROR_STOP=1",
            ],
            stdin: sql,
            timeoutMs,
          });
          successful(output);
          await assertIdentity();
          requireValue(
            request.planId === plan.id && request.kind === kind &&
              request.sql === sql,
          );
          // Preserve the void lock row; never trim/filter unknown output away.
          const lines = output.stdout.replaceAll("\r\n", "\n").split("\n");
          let rows: unknown[];
          if (kind === "verify") {
            requireValue(
              lines.length === 4 && lines[0] === "BEGIN" &&
                lines[2] === "COMMIT" && lines[3] === "",
            );
            rows = [verifyPayload(strictJson(lines[1]), plan.id, state!)];
          } else {
            requireValue(
              lines.length === 8 && lines[0] === "BEGIN" &&
                lines[1] === "SET" && lines[2] === "SET" &&
                lines[3] === "" && lines[5] === "DO" && lines[6] === "COMMIT" &&
                lines[7] === "",
            );
            const claims = strictJson(lines[4]);
            exact(claims, ["aal", "sub", "role", "session_id"]);
            requireValue(
              claims.aal === "aal1" && claims.role === "authenticated" &&
                claims.sub === actor.authUserId &&
                claims.session_id === actor.sessionId,
            );
            rows = [];
          }
          return { environment, completed: true as const, rows };
        } catch (_) {
          throw new PackageError("LOCAL_SQL_UNCONFIRMED");
        } finally {
          if (acquired) executing = false;
        }
      },
    });
  } catch (_) {
    throw new PackageError("LOCAL_SQL_CONTEXT_INVALID");
  }
}
