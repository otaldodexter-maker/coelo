// I020: nominal, read-only local Auth observation. Never a JWT revocation proof.
import {
  PACKAGE,
  PackageError,
  type Plan,
  validatePlan,
} from "./e2-r01-auth-personas.ts";

export interface LocalBanEnvironment {
  readonly kind: "local";
  readonly projectId: string;
  readonly containerId: string;
}
export interface LocalBanProof {
  readonly planId: string;
  readonly authUserId: string;
  readonly correlation: string;
  readonly email: string;
  readonly package: string;
  readonly persona: string;
  readonly planMarker: string;
  readonly bannedUntil: string | null;
  readonly observedAt: string;
  readonly isBanned: boolean;
}
export interface LocalBanSqlRequest {
  readonly planId: string;
  readonly authUserId: string;
  readonly correlation: string;
  readonly sql: string;
}
export interface LocalBanSqlExecutor {
  readonly environment: LocalBanEnvironment;
  readonly localAuthUrl: string | undefined;
  readBan(request: LocalBanSqlRequest): Promise<unknown>;
}
export interface LocalBanProofReader {
  readonly environment: LocalBanEnvironment;
  readonly authUrl: string;
  read(authUserId: string): Promise<LocalBanProof | undefined>;
}
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
function requireValue(value: unknown): asserts value {
  if (!value) throw new PackageError("LOCAL_BAN_PROOF_UNCONFIRMED");
}
function exact(
  value: unknown,
  keys: readonly string[],
): asserts value is Record<string, unknown> {
  requireValue(
    value !== null && typeof value === "object" && !Array.isArray(value),
  );
  requireValue(
    Object.keys(value).length === keys.length &&
      keys.every((key) => Object.hasOwn(value, key)),
  );
}
function target(plan: Plan, authUserId: string, correlation: string) {
  validatePlan(plan);
  requireValue(
    typeof authUserId === "string" && uuid.test(authUserId) &&
      typeof correlation === "string" && uuid.test(correlation),
  );
  const persona = plan.personas.find((item) => item.authUserId === authUserId);
  requireValue(persona);
  return persona;
}
const literal = (value: string) => `'${value.replaceAll("'", "''")}'`;

export function nominalBanSql(
  plan: Plan,
  authUserId: string,
  correlation: string,
): string {
  try {
    const persona = target(plan, authUserId, correlation);
    return `-- C00 local readonly observation. Qualify nullable timestamptz before use.
begin read only;
select jsonb_build_object(
  'planId',${literal(plan.id)}, 'authUserId',u.id::text,
  'correlation',${literal(correlation)}, 'email',lower(u.email),
  'package',u.raw_app_meta_data->>'coelo_e2_package',
  'persona',u.raw_app_meta_data->>'coelo_e2_persona',
  'planMarker',u.raw_app_meta_data->>'coelo_e2_plan',
  'bannedUntil',case when u.banned_until is null then null else
    to_char(u.banned_until at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') end,
  'observedAt',to_char(statement_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'isBanned',u.banned_until is not null and u.banned_until > statement_timestamp())
from auth.users u
where u.id=${literal(authUserId)}::uuid and lower(u.email)=${
      literal(persona.email)
    }
  and u.raw_app_meta_data->>'coelo_e2_package'=${literal(PACKAGE)}
  and u.raw_app_meta_data->>'coelo_e2_plan'=${literal(plan.id)}
  and u.raw_app_meta_data->>'coelo_e2_persona'=${literal(persona.persona)}
  and (u.banned_until is null or isfinite(u.banned_until));
commit;
`;
  } catch (_) {
    throw new PackageError("LOCAL_BAN_REQUEST_INVALID");
  }
}

function timestamp(value: unknown): asserts value is string {
  requireValue(
    typeof value === "string" &&
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/.test(value) &&
      !value.startsWith("0000"),
  );
  const date = new Date(value.slice(0, 19) + "Z");
  requireValue(
    Number.isFinite(date.getTime()) &&
      date.toISOString().slice(0, 19) === value.slice(0, 19),
  );
}
export function validateBanProof(
  value: unknown,
  plan: Plan,
  authUserId: string,
  correlation: string,
): LocalBanProof {
  try {
    const persona = target(plan, authUserId, correlation);
    exact(value, [
      "planId",
      "authUserId",
      "correlation",
      "email",
      "package",
      "persona",
      "planMarker",
      "bannedUntil",
      "observedAt",
      "isBanned",
    ]);
    requireValue(
      value.planId === plan.id && value.authUserId === authUserId &&
        value.correlation === correlation &&
        value.email === persona.email && value.package === PACKAGE &&
        value.persona === persona.persona && value.planMarker === plan.id &&
        typeof value.isBanned === "boolean",
    );
    timestamp(value.observedAt);
    if (value.bannedUntil !== null) timestamp(value.bannedUntil);
    // Both strings are canonical UTC with six microseconds: lexical comparison
    // preserves precision. Client wall time does not determine server ban state.
    requireValue(
      value.isBanned ===
        (value.bannedUntil !== null && value.bannedUntil > value.observedAt),
    );
    return Object.freeze({
      planId: plan.id,
      authUserId,
      correlation,
      email: persona.email,
      package: PACKAGE,
      persona: persona.persona,
      planMarker: plan.id,
      bannedUntil: value.bannedUntil,
      observedAt: value.observedAt,
      isBanned: value.isBanned,
    });
  } catch (_) {
    throw new PackageError("LOCAL_BAN_PROOF_UNCONFIRMED");
  }
}

export function localBanProofReader(
  plan: Plan,
  executor: LocalBanSqlExecutor,
): LocalBanProofReader {
  try {
    const nominal = structuredClone(plan);
    validatePlan(nominal);
    const sourceEnvironment = executor.environment;
    exact(sourceEnvironment, ["kind", "projectId", "containerId"]);
    requireValue(
      sourceEnvironment.kind === "local" &&
        /^coelo_safe_[0-9a-f]{29}$/.test(sourceEnvironment.projectId) &&
        /^[0-9a-f]{64}$/.test(sourceEnvironment.containerId),
    );
    const environment = Object.freeze({ ...sourceEnvironment });
    const authUrl = executor.localAuthUrl;
    requireValue(
      typeof authUrl === "string" &&
        /^http:\/\/127\.0\.0\.1:[1-9]\d{0,4}\/auth\/v1$/.test(authUrl),
    );
    const port = Number(authUrl.split(":")[2].split("/")[0]);
    requireValue(port <= 65535);
    const read = executor.readBan;
    requireValue(typeof read === "function");
    const bound = () => {
      requireValue(
        executor.environment === sourceEnvironment &&
          executor.localAuthUrl === authUrl && executor.readBan === read,
      );
      exact(sourceEnvironment, ["kind", "projectId", "containerId"]);
      requireValue(
        sourceEnvironment.kind === environment.kind &&
          sourceEnvironment.projectId === environment.projectId &&
          sourceEnvironment.containerId === environment.containerId,
      );
    };
    return Object.freeze({
      environment,
      authUrl,
      async read(authUserId: string) {
        try {
          bound();
          const correlation = crypto.randomUUID();
          const sql = nominalBanSql(nominal, authUserId, correlation);
          const response = await read.call(
            executor,
            Object.freeze({ planId: nominal.id, authUserId, correlation, sql }),
          );
          bound();
          exact(response, ["environment", "authUrl", "completed", "rows"]);
          exact(response.environment, ["kind", "projectId", "containerId"]);
          requireValue(
            response.environment.kind === environment.kind &&
              response.environment.projectId === environment.projectId &&
              response.environment.containerId === environment.containerId &&
              response.authUrl === authUrl && response.completed === true &&
              Array.isArray(response.rows) && response.rows.length === 1,
          );
          return validateBanProof(
            response.rows[0],
            nominal,
            authUserId,
            correlation,
          );
        } catch (_) {
          return undefined;
        }
      },
    });
  } catch (_) {
    throw new PackageError("LOCAL_BAN_CONTEXT_INVALID");
  }
}
