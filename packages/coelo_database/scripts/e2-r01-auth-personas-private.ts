// C01 I013: offline adapter. C00 still owns the real PostgreSQL transport,
// environment authorization and SecretStore; this module creates none of them.
import {
  PackageError,
  PERSONAS,
  type Plan,
  type PrivateBindingsAdapter,
  privateRevokeSql,
  privateVerifySql,
  validatePlan,
} from "./e2-r01-auth-personas.ts";

export interface PrivateSqlRequest {
  readonly projectRef: string;
  readonly planId: string;
  readonly kind: "verify" | "revoke";
  readonly sql: string;
}

export interface PrivateSqlExecutor {
  // The future transport must bind this value to its actual connection, not
  // copy it from the request. This interface alone proves no remote environment.
  readonly projectRef: string;
  // Return {projectRef, completed:true, rows} only after the complete transaction
  // succeeds, including COMMIT. For verify, rows contains exactly the one parsed
  // JSON payload from privateVerifySql (not its SQL column wrapper or text).
  // For revoke, rows is empty: intermediate SELECT output is not a commit ack.
  // Extra result sets, server errors and uncertain completion must be rejected
  // by the transport, never normalized to an apparently successful response.
  execute(request: PrivateSqlRequest): Promise<unknown>;
}

export interface PrivateBindingsContext {
  readonly plan: Plan;
  readonly actor: { readonly authUserId: string; readonly sessionId: string };
}

type State = "active" | "scenario-revoked" | "revoked";
type Scope = "scenario" | "all";

function requireValue(value: unknown, code: string): asserts value {
  if (!value) throw new PackageError(code);
}

function exactObject(
  value: unknown,
  keys: readonly string[],
): asserts value is Record<string, unknown> {
  requireValue(
    value !== null && typeof value === "object" && !Array.isArray(value) &&
      Object.keys(value).length === keys.length &&
      keys.every((key) => Object.hasOwn(value, key)),
    "PRIVATE_RESULT_INVALID",
  );
}

// JSON plans with reordered object keys remain equivalent; array order and all
// catalog/identity/scope values remain part of the nominal plan binding.
function fingerprint(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(fingerprint).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${
      Object.entries(value).sort(([a], [b]) => a.localeCompare(b))
        .map(([key, item]) => `${JSON.stringify(key)}:${fingerprint(item)}`)
        .join(",")
    }}`;
  }
  requireValue(
    value === null || typeof value === "string" || typeof value === "boolean" ||
      (typeof value === "number" && Number.isFinite(value)),
    "PRIVATE_PLAN_MISMATCH",
  );
  return JSON.stringify(value);
}

function verification(
  value: unknown,
  planId: string,
  state: State,
): { verified: boolean; revocationVerified: boolean } {
  exactObject(value, [
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
    "PRIVATE_RESULT_INVALID",
  );
  const seen = new Set<string>();
  const checks = value.personas.map((item: unknown) => {
    exactObject(item, [
      "persona",
      "revocation_target",
      "auth_owned",
      "no_people_link",
      "private_bindings",
    ]);
    requireValue(
      typeof item.persona === "string" &&
        PERSONAS.some((persona) => persona === item.persona) &&
        !seen.has(item.persona) &&
        [
          item.revocation_target,
          item.auth_owned,
          item.no_people_link,
          item.private_bindings,
        ].every((flag) => typeof flag === "boolean"),
      "PRIVATE_RESULT_INVALID",
    );
    seen.add(item.persona);
    const terminal = state === "revoked" ||
      (state === "scenario-revoked" && item.persona === "revoked");
    requireValue(item.revocation_target === terminal, "PRIVATE_RESULT_INVALID");
    return {
      terminal,
      valid: item.auth_owned && item.no_people_link && item.private_bindings,
    };
  });
  requireValue(seen.size === PERSONAS.length, "PRIVATE_RESULT_INVALID");
  const verified = checks.every((item) => item.valid);
  const revocationVerified = state !== "active" &&
    checks.filter((item) => item.terminal).every((item) => item.valid);
  requireValue(
    value.verified === verified &&
      value.revocationVerified === revocationVerified,
    "PRIVATE_RESULT_INVALID",
  );
  return { verified, revocationVerified };
}

export function privateBindingsAdapter(
  context: PrivateBindingsContext,
  executor: PrivateSqlExecutor,
): PrivateBindingsAdapter {
  let nominal: Plan;
  let actor: { authUserId: string; sessionId: string };
  let nominalFingerprint: string;
  try {
    nominal = structuredClone(context.plan);
    actor = structuredClone(context.actor);
    validatePlan(nominal);
    // Reuse the canonical builder's actor UUID validation without executing it.
    privateRevokeSql(nominal, actor, "scenario");
    nominalFingerprint = fingerprint(nominal);
  } catch (_) {
    throw new PackageError("INVALID_PRIVATE_CONTEXT");
  }

  function assertEnvironment() {
    requireValue(
      executor.projectRef === nominal.projectRef,
      "PRIVATE_ENVIRONMENT_MISMATCH",
    );
  }
  assertEnvironment();

  function assertPlan(plan: Plan) {
    try {
      validatePlan(plan);
      requireValue(
        fingerprint(plan) === nominalFingerprint,
        "PRIVATE_PLAN_MISMATCH",
      );
    } catch (_) {
      throw new PackageError("PRIVATE_PLAN_MISMATCH");
    }
  }

  function targetScope(plan: Plan, ids: readonly string[]): Scope {
    assertPlan(plan);
    requireValue(
      Array.isArray(ids) && new Set(ids).size === ids.length,
      "PRIVATE_REVOCATION_TARGETS_INVALID",
    );
    const revoked = nominal.personas.find((item) =>
      item.persona === "revoked"
    )!;
    if (ids.length === 1 && ids[0] === revoked.authUserId) return "scenario";
    requireValue(
      ids.length === PERSONAS.length &&
        nominal.personas.every((item) => ids.includes(item.authUserId)),
      "PRIVATE_REVOCATION_TARGETS_INVALID",
    );
    return "all";
  }

  async function run(plan: Plan, kind: "verify" | "revoke", sql: string) {
    assertPlan(plan);
    assertEnvironment();
    let result: unknown;
    try {
      // Deliberately one attempt: a lost response is not permission to retry a
      // write. The caller must reconcile through a separate explicit read.
      result = await executor.execute(Object.freeze({
        projectRef: nominal.projectRef,
        planId: nominal.id,
        kind,
        sql,
      }));
    } catch (_) {
      throw new PackageError("PRIVATE_EXECUTION_UNCONFIRMED");
    }
    // Callers act on their plan after awaiting this result; reject a plan or
    // connection changed during the await before allowing that next step.
    assertPlan(plan);
    assertEnvironment();
    exactObject(result, ["projectRef", "completed", "rows"]);
    requireValue(
      result.projectRef === nominal.projectRef,
      "PRIVATE_ENVIRONMENT_MISMATCH",
    );
    requireValue(result.completed === true, "PRIVATE_EXECUTION_UNCONFIRMED");
    requireValue(Array.isArray(result.rows), "PRIVATE_RESULT_INVALID");
    return result.rows;
  }

  return {
    async verifyActive(plan) {
      const rows = await run(
        plan,
        "verify",
        privateVerifySql(nominal, "active"),
      );
      requireValue(rows.length === 1, "PRIVATE_RESULT_INVALID");
      const proof = verification(rows[0], nominal.id, "active");
      assertPlan(plan);
      assertEnvironment();
      return proof.verified;
    },
    async revokeOwned(plan, ids) {
      const scope = targetScope(plan, ids);
      const rows = await run(
        plan,
        "revoke",
        privateRevokeSql(nominal, actor, scope),
      );
      requireValue(
        targetScope(plan, ids) === scope,
        "PRIVATE_REVOCATION_TARGETS_INVALID",
      );
      requireValue(rows.length === 0, "PRIVATE_RESULT_INVALID");
      assertEnvironment();
    },
    async verifyRevoked(plan, ids) {
      const scope = targetScope(plan, ids);
      const state = scope === "scenario" ? "scenario-revoked" : "revoked";
      const rows = await run(plan, "verify", privateVerifySql(nominal, state));
      requireValue(
        targetScope(plan, ids) === scope,
        "PRIVATE_REVOCATION_TARGETS_INVALID",
      );
      requireValue(rows.length === 1, "PRIVATE_RESULT_INVALID");
      const proof = verification(rows[0], nominal.id, state);
      assertEnvironment();
      return proof.revocationVerified;
    },
  };
}
