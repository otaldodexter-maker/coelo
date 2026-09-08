// C01 I008: offline preparation; remote application belongs exclusively to C00.
// Auth creation uses the existing Supabase SDK. Private bindings require a
// separately reviewed PostgreSQL adapter: service_role has no table grants.
import type { SupabaseClient, User } from "@supabase/supabase-js";

export const PACKAGE = "C01-AUTH-PERSONAS-v1";
export const DENIED_PERMISSION = "institution.update";
export const PERSONAS = [
  "op-a",
  "op-b",
  "no-cap",
  "revoked",
  "global",
] as const;
type Persona = typeof PERSONAS[number];
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const emailFor = (persona: Persona) => `e2.r01.${persona}@example.invalid`;

export class PackageError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}
function requireValue(value: unknown, code: string): asserts value {
  if (!value) throw new PackageError(code);
}
async function guarded<T>(
  operation: () => Promise<T>,
  code: string,
): Promise<T> {
  try {
    return await operation();
  } catch (_) {
    throw new PackageError(code);
  }
}

export interface Role {
  id: string;
  code: string;
  status: string;
  maxScopeKind: string;
  // Effective catalog grants: active permission + active non-revoked role grant.
  permissions: string[];
}
export interface Snapshot {
  capturedAt: string;
  projectRef: string;
  activeOwners: number;
  internalSchemaPresent: boolean;
  denialPermissionPresent: boolean;
  roles: Role[];
  collidingEmails: string[];
  collidingSlugs: string[];
  collidingTypeCodes: string[];
}
export interface PlannedPersona {
  persona: Persona;
  email: string;
  authUserId: string;
  internalIdentityId: string | null;
  authLinkId: string | null;
  membershipId: string | null;
  roleId: string | null;
  institutionId: string | null;
}
export interface Plan {
  package: typeof PACKAGE;
  id: string;
  projectRef: string;
  snapshotAt: string;
  operationsRole: Role;
  noCapRole: Role;
  institutionType: { id: string; code: "e2-r01-synthetic" };
  institutions: { id: string; slug: "e2-r01-tenant-a" | "e2-r01-tenant-b" }[];
  personas: PlannedPersona[];
}

export function planPersonas(
  snapshot: Snapshot,
  roles: { operations: string; noCap: string },
  now = new Date(),
  newId: () => string = () => crypto.randomUUID(),
): Plan {
  const age = now.getTime() - Date.parse(snapshot.capturedAt);
  requireValue(
    Number.isFinite(age) && age >= 0 && age <= 15 * 60_000,
    "FRESH_C00_SNAPSHOT_REQUIRED",
  );
  requireValue(
    /^[a-z0-9]{20}$/.test(snapshot.projectRef),
    "PROJECT_REF_REQUIRED",
  );
  requireValue(snapshot.internalSchemaPresent, "INTERNAL_SCHEMA_REQUIRED");
  requireValue(
    snapshot.denialPermissionPresent,
    "DENIAL_PERMISSION_CATALOG_REQUIRED",
  );
  requireValue(snapshot.activeOwners >= 1, "EXISTING_OWNER_REQUIRED");
  requireValue(
    snapshot.collidingEmails.length === 0 &&
      snapshot.collidingSlugs.length === 0 &&
      snapshot.collidingTypeCodes.length === 0,
    "SYNTHETIC_NAMESPACE_COLLISION",
  );
  const select = (id: string): Role => {
    const matches = snapshot.roles.filter((role) => role.id === id);
    requireValue(matches.length === 1, "EXPLICIT_EXISTING_ROLE_REQUIRED");
    const role = matches[0];
    requireValue(
      role.code !== "owner" && role.status === "active" &&
        ["platform", "institution"].includes(role.maxScopeKind),
      "ROLE_NOT_ALLOWED",
    );
    return structuredClone(role);
  };
  const operationsRole = select(roles.operations);
  const noCapRole = select(roles.noCap);
  requireValue(operationsRole.id !== noCapRole.id, "DISTINCT_ROLES_REQUIRED");
  requireValue(
    operationsRole.permissions.includes("platform.read"),
    "OPERATIONS_READ_REQUIRED",
  );
  requireValue(
    noCapRole.permissions.includes("platform.read") &&
      !noCapRole.permissions.includes(DENIED_PERMISSION),
    "NO_CAP_ROLE_MUST_DENY_INSTITUTION_UPDATE",
  );
  const institutions: Plan["institutions"] = [
    { id: newId(), slug: "e2-r01-tenant-a" },
    { id: newId(), slug: "e2-r01-tenant-b" },
  ];
  const plan: Plan = {
    package: PACKAGE,
    id: newId(),
    projectRef: snapshot.projectRef,
    snapshotAt: snapshot.capturedAt,
    operationsRole,
    noCapRole,
    institutionType: { id: newId(), code: "e2-r01-synthetic" },
    institutions,
    personas: PERSONAS.map((persona) => ({
      persona,
      email: emailFor(persona),
      authUserId: newId(),
      internalIdentityId: persona === "global" ? null : newId(),
      authLinkId: persona === "global" ? null : newId(),
      membershipId: persona === "global" ? null : newId(),
      roleId: persona === "global"
        ? null
        : persona === "no-cap"
        ? noCapRole.id
        : operationsRole.id,
      institutionId: persona === "global"
        ? null
        : institutions[persona === "op-b" ? 1 : 0].id,
    })),
  };
  validatePlan(plan);
  return plan;
}

export function validatePlan(plan: Plan): void {
  requireValue(
    plan.package === PACKAGE && /^[a-z0-9]{20}$/.test(plan.projectRef),
    "INVALID_PLAN",
  );
  requireValue(
    plan.operationsRole.id !== plan.noCapRole.id &&
      plan.operationsRole.code !== "owner" && plan.noCapRole.code !== "owner" &&
      plan.operationsRole.status === "active" &&
      plan.noCapRole.status === "active" &&
      plan.operationsRole.permissions.includes("platform.read") &&
      plan.noCapRole.permissions.includes("platform.read") &&
      !plan.noCapRole.permissions.includes(DENIED_PERMISSION) &&
      [plan.operationsRole, plan.noCapRole].every((role) =>
        ["platform", "institution"].includes(role.maxScopeKind)
      ),
    "INVALID_PLAN_ROLES",
  );
  requireValue(
    plan.institutionType.code === "e2-r01-synthetic" &&
      plan.institutions.length === 2 &&
      plan.institutions[0].slug === "e2-r01-tenant-a" &&
      plan.institutions[1].slug === "e2-r01-tenant-b",
    "INVALID_PLAN_TENANTS",
  );
  requireValue(plan.personas.length === 5, "EXACTLY_FIVE_PERSONAS_REQUIRED");
  const allocated = [
    plan.id,
    plan.institutionType.id,
    ...plan.institutions.map((x) => x.id),
  ];
  for (const [index, item] of plan.personas.entries()) {
    requireValue(
      item.persona === PERSONAS[index] &&
        item.email === emailFor(PERSONAS[index]),
      "INVALID_PERSONA",
    );
    allocated.push(item.authUserId);
    if (item.persona === "global") {
      requireValue(
        item.internalIdentityId === null && item.authLinkId === null &&
          item.membershipId === null &&
          item.roleId === null && item.institutionId === null,
        "GLOBAL_MUST_HAVE_NO_INTERNAL_IDENTITY",
      );
    } else {
      requireValue(
        item.internalIdentityId && item.authLinkId && item.membershipId,
        "INTERNAL_BINDINGS_REQUIRED",
      );
      requireValue(
        item.institutionId ===
            plan.institutions[item.persona === "op-b" ? 1 : 0].id &&
          item.roleId ===
            (item.persona === "no-cap"
              ? plan.noCapRole.id
              : plan.operationsRole.id),
        "SCOPE_MISMATCH",
      );
      allocated.push(
        item.internalIdentityId,
        item.authLinkId,
        item.membershipId,
      );
    }
  }
  requireValue(
    allocated.every((id) => uuidPattern.test(id)) &&
      new Set(allocated).size === allocated.length &&
      uuidPattern.test(plan.operationsRole.id) &&
      uuidPattern.test(plan.noCapRole.id),
    "INVALID_OR_DUPLICATE_UUID",
  );
}

export interface AuthRecord {
  id: string;
  email: string;
  appMetadata: Record<string, unknown>;
}
export interface AuthAdapter {
  inspect(plan: Plan): Promise<AuthRecord[]>;
  create(
    input: {
      id: string;
      email: string;
      password: string;
      appMetadata: Record<string, unknown>;
    },
  ): Promise<AuthRecord>;
  setBanned(id: string, banned: boolean): Promise<void>;
}
export interface SecretReceipt {
  planId: string;
  authUserId: string;
  password: string;
  state: "reserved" | "created";
}
// Implementation belongs to the ignored, access-controlled secret store C00
// selects at application time. reserve must be durable/exclusive before Auth.
export interface SecretStore {
  read(id: string): Promise<SecretReceipt | null>;
  reserve(receipt: SecretReceipt): Promise<void>;
  markCreated(id: string): Promise<void>;
}
export interface PrivateBindingsAdapter {
  verifyActive(plan: Plan): Promise<boolean>;
  revokeOwned(plan: Plan, authUserIds: readonly string[]): Promise<void>;
  verifyRevoked(plan: Plan, authUserIds: readonly string[]): Promise<boolean>;
}
function metadata(plan: Plan, item: PlannedPersona) {
  return {
    coelo_e2_package: PACKAGE,
    coelo_e2_plan: plan.id,
    coelo_e2_persona: item.persona,
  };
}
function owned(record: AuthRecord, plan: Plan, item: PlannedPersona): boolean {
  return record.id === item.authUserId &&
    record.email.toLowerCase() === item.email &&
    Object.entries(metadata(plan, item)).every(([key, value]) =>
      record.appMetadata[key] === value
    );
}
function password(): string {
  return Array.from(
    crypto.getRandomValues(new Uint8Array(32)),
    (x) => x.toString(16).padStart(2, "0"),
  ).join("");
}
async function inspectOwned(
  plan: Plan,
  auth: AuthAdapter,
  secrets: SecretStore,
) {
  const found = await guarded(
    () => auth.inspect(plan),
    "AUTH_CATALOG_UNAVAILABLE",
  );
  const receipts = new Map<string, SecretReceipt | null>();
  for (const item of plan.personas) {
    const receipt = await guarded(
      () => secrets.read(item.authUserId),
      "SECRET_STORE_UNAVAILABLE",
    );
    if (receipt) {
      requireValue(
        receipt.planId === plan.id && receipt.authUserId === item.authUserId &&
          receipt.password.length >= 32,
        "SECRET_RECEIPT_MISMATCH",
      );
    }
    receipts.set(item.authUserId, receipt);
    const matches = found.filter((user) =>
      user.id === item.authUserId || user.email.toLowerCase() === item.email
    );
    requireValue(
      matches.length <= 1 &&
        matches.every((user) => owned(user, plan, item) && receipt !== null),
      "AUTH_COLLISION",
    );
    requireValue(
      receipt?.state !== "created" || matches.length === 1,
      "OWNED_ACCOUNT_DISAPPEARED",
    );
  }
  return { found, receipts };
}

export async function provisionAuth(
  plan: Plan,
  adapters: { auth: AuthAdapter; secrets: SecretStore },
  options: { apply?: boolean } = {},
): Promise<{ state: string; authUserIds: string[] }> {
  validatePlan(plan);
  const authUserIds = plan.personas.map((item) => item.authUserId);
  if (!options.apply) return { state: "dry-run-no-effects", authUserIds };
  const { found, receipts } = await inspectOwned(
    plan,
    adapters.auth,
    adapters.secrets,
  );
  for (const item of plan.personas) {
    let receipt = receipts.get(item.authUserId);
    if (!receipt) {
      receipt = {
        planId: plan.id,
        authUserId: item.authUserId,
        password: password(),
        state: "reserved",
      };
      const reserved = receipt;
      await guarded(
        () => adapters.secrets.reserve(reserved),
        "SECRET_STORE_UNAVAILABLE",
      );
    }
    if (!found.some((user) => owned(user, plan, item))) {
      let created: AuthRecord;
      try {
        created = await adapters.auth.create({
          id: item.authUserId,
          email: item.email,
          password: receipt.password,
          appMetadata: metadata(plan, item),
        });
      } catch (_) {
        // A lost response may have created the account. Keep the write-ahead
        // receipt; retry inspects the exact ID, email and admin-only marker.
        throw new PackageError("AUTH_CREATE_AMBIGUOUS_RECONCILE_BEFORE_RETRY");
      }
      requireValue(
        owned(created, plan, item),
        "AUTH_RESPONSE_IDENTITY_MISMATCH",
      );
    }
    await guarded(
      () => adapters.secrets.markCreated(item.authUserId),
      "SECRET_RECEIPT_UNCONFIRMED",
    );
  }
  return {
    state:
      "owned-auth-accounts-reconciled-private-bindings-and-ban-verification-required",
    authUserIds,
  };
}

export async function activateAuth(
  plan: Plan,
  auth: AuthAdapter,
  secrets: SecretStore,
  bindings: PrivateBindingsAdapter,
  options: { apply?: boolean } = {},
): Promise<string> {
  validatePlan(plan);
  if (!options.apply) return "dry-run-no-effects";
  const { found } = await inspectOwned(plan, auth, secrets);
  requireValue(
    found.length === 5 &&
      await guarded(
        () => bindings.verifyActive(plan),
        "PRIVATE_VERIFICATION_UNAVAILABLE",
      ),
    "C00_PRIVATE_BINDINGS_VERIFICATION_REQUIRED",
  );
  for (const item of plan.personas) {
    await guarded(
      () => auth.setBanned(item.authUserId, false),
      "AUTH_ACTIVATION_UNCONFIRMED",
    );
  }
  return "activated-awaiting-normal-ui-verification";
}

export async function closePersonas(
  plan: Plan,
  auth: AuthAdapter,
  secrets: SecretStore,
  bindings: PrivateBindingsAdapter,
  options: { apply?: boolean } = {},
): Promise<string> {
  validatePlan(plan);
  if (!options.apply) return "dry-run-no-effects";
  const { found } = await inspectOwned(plan, auth, secrets);
  // Revoke the exact private links/memberships with version checks before
  // banning Auth. Preserve identities, tenants, receipt and audit history.
  const ids = plan.personas.map((item) => item.authUserId);
  await guarded(
    () => bindings.revokeOwned(plan, ids),
    "PRIVATE_REVOCATION_UNCONFIRMED",
  );
  requireValue(
    await guarded(
      () => bindings.verifyRevoked(plan, ids),
      "PRIVATE_VERIFICATION_UNAVAILABLE",
    ),
    "PRIVATE_REVOCATION_NOT_VERIFIED",
  );
  for (const item of plan.personas) {
    if (found.some((user) => owned(user, plan, item))) {
      await guarded(
        () => auth.setBanned(item.authUserId, true),
        "AUTH_BAN_UNCONFIRMED",
      );
    }
  }
  return "internal-access-revoked-auth-banned-session-cleanup-c00-required";
}

export async function revokeScenario(
  plan: Plan,
  auth: AuthAdapter,
  secrets: SecretStore,
  bindings: PrivateBindingsAdapter,
  options: { apply?: boolean } = {},
): Promise<string> {
  validatePlan(plan);
  if (!options.apply) return "dry-run-no-effects";
  const { found } = await inspectOwned(plan, auth, secrets);
  const target = plan.personas.find((item) => item.persona === "revoked")!;
  requireValue(
    found.some((user) => owned(user, plan, target)),
    "REVOCATION_PERSONA_NOT_PROVISIONED",
  );
  await guarded(
    () => bindings.revokeOwned(plan, [target.authUserId]),
    "PRIVATE_REVOCATION_UNCONFIRMED",
  );
  requireValue(
    await guarded(
      () => bindings.verifyRevoked(plan, [target.authUserId]),
      "PRIVATE_VERIFICATION_UNAVAILABLE",
    ),
    "PRIVATE_REVOCATION_NOT_VERIFIED",
  );
  await guarded(
    () => auth.setBanned(target.authUserId, true),
    "AUTH_BAN_UNCONFIRMED",
  );
  return "revoked-persona-only-awaiting-ui-and-session-verification";
}

export function sdkAuthAdapter(
  client: Pick<SupabaseClient, "auth">,
): AuthAdapter {
  const record = (user: User): AuthRecord => ({
    id: user.id,
    email: user.email ?? "",
    appMetadata: user.app_metadata,
  });
  return {
    async inspect(plan) {
      const found: AuthRecord[] = [];
      for (let page = 1; page <= 1000; page++) {
        const { data, error } = await client.auth.admin.listUsers({
          page,
          perPage: 100,
        });
        if (error) throw new PackageError("AUTH_CATALOG_UNAVAILABLE");
        found.push(
          ...data.users.filter((user) =>
            plan.personas.some((item) =>
              user.id === item.authUserId ||
              user.email?.toLowerCase() === item.email
            )
          ).map(record),
        );
        if (data.users.length < 100) return found;
      }
      throw new PackageError("AUTH_CATALOG_LIMIT_REQUIRES_REVIEW");
    },
    async create(input) {
      const { data, error } = await client.auth.admin.createUser({
        id: input.id,
        email: input.email,
        password: input.password,
        email_confirm: true,
        ban_duration: "876000h",
        app_metadata: input.appMetadata,
      });
      if (error || !data.user) {
        throw new PackageError("AUTH_CREATE_UNCONFIRMED");
      }
      return record(data.user);
    },
    async setBanned(id, banned) {
      const { data, error } = await client.auth.admin.updateUserById(id, {
        ban_duration: banned ? "876000h" : "none",
      });
      if (error || data.user?.id !== id) {
        throw new PackageError("AUTH_STATUS_UNCONFIRMED");
      }
    },
  };
}

export function effects(plan: Plan) {
  validatePlan(plan);
  return {
    package: PACKAGE,
    planId: plan.id,
    state: "review-required-no-remote-authorization",
    auth: {
      count: 5,
      initialState: "banned",
      emailConfirmed: true,
      sendEmail: false,
    },
    private: {
      identities: 4,
      authLinks: 4,
      memberships: 4,
      scopeKind: "institution",
      initialVersion: 1,
    },
    institutions: plan.institutions,
    institutionType: plan.institutionType,
    roles: {
      operations: plan.operationsRole.id,
      noCap: plan.noCapRole.id,
      createOrChangeRoles: false,
    },
    people: { create: 0, link: 0 },
    negatives: [
      "op-a denies tenant-b",
      "op-b denies tenant-a",
      "no-cap bootstraps but denies institution.update",
      "revoked starts active; C00 revokes exact membership/auth-link version",
      "global has no internal identity",
    ],
    blockers: [
      "C00 fresh privileged catalog and transactional private-binding adapter",
      "C00 ignored access-controlled secret store",
      "C00/Owner nominal application and UI window",
    ],
    cleanup: [
      "revoke owned internal links/memberships with version+1 and timestamp",
      "ban only owned Auth accounts",
      "C00 revoke owned sessions through approved Auth operation",
      "preserve tenants/identities/Auth records/audit/receipts; never delete real data",
    ],
  };
}

// C00 must execute the exported SQL as postgres with an EXISTING valid Owner
// Auth session. It is never executed by this script or by service_role.
export function privateProvisionSql(
  plan: Plan,
  actor: { authUserId: string; sessionId: string },
): string {
  validatePlan(plan);
  requireValue(
    uuidPattern.test(actor.authUserId) && uuidPattern.test(actor.sessionId),
    "EXISTING_ACTOR_SESSION_REQUIRED",
  );
  const rows = plan.personas.map((item) => ({
    persona: item.persona,
    email: item.email,
    auth_id: item.authUserId,
    identity_id: item.internalIdentityId,
    link_id: item.authLinkId,
    membership_id: item.membershipId,
    role_id: item.roleId,
    institution_id: item.institutionId,
  }));
  // All interpolated fields are validated UUIDs or fixed package strings.
  const payload = JSON.stringify(rows).replaceAll("'", "''");
  return `-- C01 I008 candidate; REVIEW ONLY until C00/Owner authorizes this exact plan.
-- No Auth user creation, People, grants, role changes or session fabrication.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
select pg_advisory_xact_lock(hashtextextended('coelo.e2.r01.personas',0));
select set_config('request.jwt.claims',jsonb_build_object('sub','${actor.authUserId}',
  'session_id','${actor.sessionId}','aal','aal1','role','authenticated')::text,true);
do $c01$
declare
  ctx app_private.superadmin_internal_context;
  item jsonb;
  inserted_id uuid;
begin
  if current_user <> 'postgres' then raise exception 'C00 postgres execution required'; end if;
  select * into ctx from app_private.require_superadmin_internal_context('platform.read');
  if ctx.platform_role_code is distinct from 'owner' or ctx.scope_kind is distinct from 'platform'
    or ctx.auth_user_id is distinct from '${actor.authUserId}'::uuid or ctx.session_id is distinct from '${actor.sessionId}'::uuid then
    raise exception 'Existing active Owner session required';
  end if;
  if not exists(select 1 from public.platform_roles r where r.id='${plan.operationsRole.id}'
      and r.status='active' and r.code <> 'owner' and r.max_scope_kind in ('platform','institution'))
    or not exists(select 1 from public.platform_roles r where r.id='${plan.noCapRole.id}'
      and r.status='active' and r.code <> 'owner' and r.max_scope_kind in ('platform','institution')) then
    raise exception 'Role status or scope drift';
  end if;
  if not exists(select 1 from public.platform_permissions p
      where p.code='institution.update' and p.status='active')
    or (select count(distinct g.role_id) from public.platform_role_permissions g
      join public.platform_permissions p on p.id=g.permission_id and p.code='platform.read' and p.status='active'
      where g.role_id in ('${plan.operationsRole.id}','${plan.noCapRole.id}') and g.effect='allow'
        and g.status='active' and g.revoked_at is null) <> 2
    or exists(select 1 from public.platform_role_permissions g
      join public.platform_permissions p on p.id=g.permission_id and p.code='institution.update' and p.status='active'
      where g.role_id='${plan.noCapRole.id}' and g.effect='allow' and g.status='active' and g.revoked_at is null) then
    raise exception 'Effective permission drift';
  end if;
  -- All Auth records must have been created by SDK with this plan marker.
  for item in select value from jsonb_array_elements('${payload}'::jsonb) loop
    if not exists(select 1 from auth.users u where u.id=(item->>'auth_id')::uuid
      and lower(u.email)=item->>'email' and u.email_confirmed_at is not null
      and u.raw_app_meta_data->>'coelo_e2_package'='${PACKAGE}'
      and u.raw_app_meta_data->>'coelo_e2_plan'='${plan.id}'
      and u.raw_app_meta_data->>'coelo_e2_persona'=item->>'persona') then
      raise exception 'Owned Auth account missing or changed';
    end if;
    if exists(select 1 from public.person_auth_links l where l.auth_user_id=(item->>'auth_id')::uuid) then
      raise exception 'Unexpected global person linkage';
    end if;
    if item->>'persona'='global' then
      if exists(select 1 from app_private.superadmin_internal_auth_links l where l.auth_user_id=(item->>'auth_id')::uuid) then
        raise exception 'Global negative has internal linkage';
      end if;
    else
      -- This package creates all three rows atomically. A replay must find the
      -- complete exact trio; a pre-existing orphan is not owned by this plan.
      if exists(select 1 from app_private.superadmin_internal_identities i where i.id=(item->>'identity_id')::uuid
        and (i.created_by_internal_identity_id is distinct from ctx.internal_identity_id
          or not exists(select 1 from app_private.superadmin_internal_auth_links l
            join app_private.superadmin_internal_memberships m on m.internal_identity_id=l.internal_identity_id
            where l.id=(item->>'link_id')::uuid and l.auth_user_id=(item->>'auth_id')::uuid
              and l.internal_identity_id=i.id and l.status='active' and l.version=1
              and m.id=(item->>'membership_id')::uuid and m.platform_role_id=(item->>'role_id')::uuid
              and m.scope_kind='institution' and m.scope_institution_id=(item->>'institution_id')::uuid
              and m.status='active' and m.version=1)))
        or exists(select 1 from app_private.superadmin_internal_auth_links l
          where (l.id=(item->>'link_id')::uuid or l.auth_user_id=(item->>'auth_id')::uuid
            or l.internal_identity_id=(item->>'identity_id')::uuid)
          and (l.id=(item->>'link_id')::uuid and l.auth_user_id=(item->>'auth_id')::uuid
            and l.internal_identity_id=(item->>'identity_id')::uuid and l.status='active' and l.version=1) is not true)
        or exists(select 1 from app_private.superadmin_internal_memberships m
          where (m.id=(item->>'membership_id')::uuid or m.internal_identity_id=(item->>'identity_id')::uuid)
          and (m.id=(item->>'membership_id')::uuid and m.internal_identity_id=(item->>'identity_id')::uuid
            and m.platform_role_id=(item->>'role_id')::uuid and m.scope_kind='institution'
            and m.scope_institution_id=(item->>'institution_id')::uuid and m.status='active' and m.version=1) is not true) then
        raise exception 'Internal identity collision or lifecycle drift';
      end if;
    end if;
  end loop;
  if exists(select 1 from public.institution_types t
    where (t.id='${plan.institutionType.id}' or lower(t.code)='e2-r01-synthetic' or lower(t.name)='e2 r01 synthetic')
      and (t.id='${plan.institutionType.id}' and t.code='e2-r01-synthetic' and t.name='E2 R01 Synthetic'
        and t.description='${PACKAGE}:${plan.id}' and t.status='active') is not true) then
    raise exception 'Institution type collision';
  end if;
  insert into public.institution_types(id,code,name,description,status)
    values('${plan.institutionType.id}','e2-r01-synthetic','E2 R01 Synthetic','${PACKAGE}:${plan.id}','active')
    on conflict(id) do nothing returning id into inserted_id;
  if inserted_id is not null then
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
      ctx.internal_membership_id,ctx.session_id,'platform.read',ctx.aal,'e2.r01.personas.provision','success',
      '${PACKAGE}','${plan.id}',null,'institution_type',inserted_id);
  end if;
${
    plan.institutions.map((institution) =>
      `  if exists(select 1 from public.institutions i
    where (i.id='${institution.id}' or i.slug='${institution.slug}')
      and (i.id='${institution.id}' and i.slug='${institution.slug}' and i.public_name='${institution.slug}'
        and i.institution_type_id='${plan.institutionType.id}' and i.status='active' and i.deleted_at is null
        and i.management_version=1 and i.created_by is null and i.primary_contact_person_id is null) is not true) then
    raise exception 'Institution collision or drift';
  end if;
  insert into public.institutions(id,public_name,slug,institution_type_id,status)
    values('${institution.id}','${institution.slug}','${institution.slug}','${plan.institutionType.id}','active')
    on conflict(id) do nothing returning id into inserted_id;
  if inserted_id is not null then
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
      ctx.internal_membership_id,ctx.session_id,'platform.read',ctx.aal,'e2.r01.personas.provision','success',
      '${PACKAGE}','${plan.id}',inserted_id,'institution',inserted_id);
  end if;`
    ).join("\n")
  }
  for item in select value from jsonb_array_elements('${payload}'::jsonb) where value->>'persona'<>'global' loop
    insert into app_private.superadmin_internal_identities(id,created_by_internal_identity_id)
      values((item->>'identity_id')::uuid,ctx.internal_identity_id) on conflict(id) do nothing;
    insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,changed_by_internal_identity_id)
      values((item->>'link_id')::uuid,(item->>'identity_id')::uuid,(item->>'auth_id')::uuid,ctx.internal_identity_id)
      on conflict(id) do nothing;
    insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,
        scope_kind,scope_institution_id,changed_by_internal_identity_id)
      values((item->>'membership_id')::uuid,(item->>'identity_id')::uuid,(item->>'role_id')::uuid,
        'institution',(item->>'institution_id')::uuid,ctx.internal_identity_id)
      on conflict(id) do nothing returning id into inserted_id;
    if inserted_id is not null then
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,ctx.session_id,'platform.read',ctx.aal,'e2.r01.personas.provision','success',
        '${PACKAGE}','${plan.id}',(item->>'institution_id')::uuid,'superadmin_internal_membership',inserted_id);
    end if;
  end loop;
end
$c01$;
commit;
`;
}

export function catalogSnapshotSql(projectRef: string): string {
  requireValue(/^[a-z0-9]{20}$/.test(projectRef), "PROJECT_REF_REQUIRED");
  return `-- C00 read-only export. Connection/project binding is verified by C00.
begin read only;
select jsonb_build_object(
  'capturedAt',clock_timestamp(),'projectRef','${projectRef}',
  'activeOwners',(select count(*) from app_private.superadmin_internal_memberships m
    join public.platform_roles r on r.id=m.platform_role_id and r.code='owner' and r.status='active'
    where m.status='active' and m.scope_kind='platform' and exists(
      select 1 from app_private.superadmin_internal_auth_links l
      where l.internal_identity_id=m.internal_identity_id and l.status='active')),
  'internalSchemaPresent',to_regclass('app_private.superadmin_internal_identities') is not null
    and to_regclass('app_private.superadmin_internal_auth_links') is not null
    and to_regclass('app_private.superadmin_internal_memberships') is not null
    and to_regprocedure('public.superadmin_auth_bootstrap_context()') is not null
    and to_regprocedure('public.superadmin_auth_resolve_institution_context(uuid)') is not null,
  'denialPermissionPresent',exists(select 1 from public.platform_permissions where code='institution.update' and status='active'),
  'roles',(select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'code',r.code,'status',r.status,
    'maxScopeKind',r.max_scope_kind,'permissions',(select coalesce(jsonb_agg(p.code order by p.code),'[]'::jsonb)
      from public.platform_role_permissions g join public.platform_permissions p on p.id=g.permission_id
      where g.role_id=r.id and g.effect='allow' and g.status='active' and g.revoked_at is null and p.status='active'))
    order by r.code),'[]'::jsonb) from public.platform_roles r),
  'collidingEmails',(select coalesce(jsonb_agg(email),'[]'::jsonb) from auth.users where lower(email) in (
    'e2.r01.op-a@example.invalid','e2.r01.op-b@example.invalid','e2.r01.no-cap@example.invalid',
    'e2.r01.revoked@example.invalid','e2.r01.global@example.invalid')),
  'collidingSlugs',(select coalesce(jsonb_agg(slug),'[]'::jsonb) from public.institutions where slug in ('e2-r01-tenant-a','e2-r01-tenant-b')),
  'collidingTypeCodes',(select coalesce(jsonb_agg(code),'[]'::jsonb) from public.institution_types
    where lower(code)='e2-r01-synthetic' or lower(name)='e2 r01 synthetic')
);
commit;
`;
}

export function privateRevokeSql(
  plan: Plan,
  actor: { authUserId: string; sessionId: string },
  scope: "scenario" | "all",
): string {
  validatePlan(plan);
  requireValue(
    uuidPattern.test(actor.authUserId) && uuidPattern.test(actor.sessionId),
    "EXISTING_ACTOR_SESSION_REQUIRED",
  );
  requireValue(
    scope === "scenario" || scope === "all",
    "REVOCATION_SCOPE_REQUIRED",
  );
  const rows = plan.personas.filter((item) =>
    item.persona !== "global" &&
    (scope === "all" || item.persona === "revoked")
  ).map((item) => ({
    persona: item.persona,
    email: item.email,
    auth_id: item.authUserId,
    identity_id: item.internalIdentityId,
    link_id: item.authLinkId,
    membership_id: item.membershipId,
    role_id: item.roleId,
    institution_id: item.institutionId,
  }));
  return `-- C00 REVIEW ONLY. Terminal revocation; preserves all history.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
select pg_advisory_xact_lock(hashtextextended('coelo.e2.r01.personas',0));
select set_config('request.jwt.claims',jsonb_build_object('sub','${actor.authUserId}',
  'session_id','${actor.sessionId}','aal','aal1','role','authenticated')::text,true);
do $c01$
declare ctx app_private.superadmin_internal_context; item jsonb; changed_id uuid;
begin
  if current_user <> 'postgres' then raise exception 'C00 postgres execution required'; end if;
  select * into ctx from app_private.require_superadmin_internal_context('platform.read');
  if ctx.platform_role_code is distinct from 'owner' or ctx.scope_kind is distinct from 'platform'
    or ctx.auth_user_id is distinct from '${actor.authUserId}'::uuid or ctx.session_id is distinct from '${actor.sessionId}'::uuid then
    raise exception 'Existing Owner required'; end if;
  for item in select value from jsonb_array_elements('${
    JSON.stringify(rows)
  }'::jsonb) loop
    perform 1 from app_private.superadmin_internal_memberships where id=(item->>'membership_id')::uuid for update;
    perform 1 from app_private.superadmin_internal_auth_links where id=(item->>'link_id')::uuid for update;
    if not exists(select 1 from app_private.superadmin_internal_memberships m
      join app_private.superadmin_internal_auth_links l on l.id=(item->>'link_id')::uuid
        and l.internal_identity_id=m.internal_identity_id
      join auth.users u on u.id=l.auth_user_id
      where m.id=(item->>'membership_id')::uuid and m.internal_identity_id=(item->>'identity_id')::uuid
        and m.platform_role_id=(item->>'role_id')::uuid and m.scope_kind='institution'
        and m.scope_institution_id=(item->>'institution_id')::uuid and l.auth_user_id=(item->>'auth_id')::uuid
        and lower(u.email)=item->>'email' and u.raw_app_meta_data->>'coelo_e2_persona'=item->>'persona'
        and u.raw_app_meta_data->>'coelo_e2_package'='${PACKAGE}' and u.raw_app_meta_data->>'coelo_e2_plan'='${plan.id}'
        and ((m.status='active' and m.version=1 and l.status='active' and l.version=1)
          or (m.status='revoked' and m.version=2 and l.status='revoked' and l.version=2))) then
      raise exception 'Owned resource or expected lifecycle version mismatch';
    end if;
    update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),
      suspended_at=null,version=version+1,changed_by_internal_identity_id=ctx.internal_identity_id
      where id=(item->>'membership_id')::uuid and status='active' and version=1 returning id into changed_id;
    update app_private.superadmin_internal_auth_links set status='revoked',revoked_at=now(),
      suspended_at=null,version=version+1,changed_by_internal_identity_id=ctx.internal_identity_id
      where id=(item->>'link_id')::uuid and status='active' and version=1;
    if changed_id is not null then
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,ctx.session_id,'platform.read',ctx.aal,'e2.r01.personas.revoke','success',
        '${PACKAGE}','${plan.id}',(item->>'institution_id')::uuid,'superadmin_internal_membership',changed_id);
    end if;
  end loop;
end
$c01$;
commit;
-- Auth ban and actual session revocation are separate C00 steps, not implied by this SQL.
`;
}

export function privateVerifySql(
  plan: Plan,
  state: "active" | "scenario-revoked" | "revoked",
): string {
  validatePlan(plan);
  requireValue(
    ["active", "scenario-revoked", "revoked"].includes(state),
    "VERIFICATION_STATE_REQUIRED",
  );
  const rows = plan.personas.map((item) => ({
    persona: item.persona,
    email: item.email,
    auth_id: item.authUserId,
    identity_id: item.internalIdentityId,
    link_id: item.authLinkId,
    membership_id: item.membershipId,
    role_id: item.roleId,
    institution_id: item.institutionId,
    status: state === "revoked" ||
        (state === "scenario-revoked" && item.persona === "revoked")
      ? "revoked"
      : "active",
    version: state === "revoked" ||
        (state === "scenario-revoked" && item.persona === "revoked")
      ? 2
      : 1,
  }));
  return `-- C00 read-only verification. No credentials or session tokens in output.
begin read only;
with target as (select value item from jsonb_array_elements('${
    JSON.stringify(rows)
  }'::jsonb)),
checks as (select item->>'persona' persona,
  exists(select 1 from auth.users u where u.id=(item->>'auth_id')::uuid and lower(u.email)=item->>'email'
    and u.email_confirmed_at is not null and u.raw_app_meta_data->>'coelo_e2_package'='${PACKAGE}'
    and u.raw_app_meta_data->>'coelo_e2_plan'='${plan.id}'
    and u.raw_app_meta_data->>'coelo_e2_persona'=item->>'persona') auth_owned,
  not exists(select 1 from public.person_auth_links p where p.auth_user_id=(item->>'auth_id')::uuid) no_people_link,
  case when item->>'persona'='global' then not exists(
    select 1 from app_private.superadmin_internal_auth_links l where l.auth_user_id=(item->>'auth_id')::uuid)
  else exists(select 1 from app_private.superadmin_internal_memberships m
    join app_private.superadmin_internal_auth_links l on l.internal_identity_id=m.internal_identity_id
    join public.platform_roles r on r.id=m.platform_role_id
    join public.institutions i on i.id=m.scope_institution_id
    where m.id=(item->>'membership_id')::uuid and l.id=(item->>'link_id')::uuid
      and m.internal_identity_id=(item->>'identity_id')::uuid and l.auth_user_id=(item->>'auth_id')::uuid
      and m.platform_role_id=(item->>'role_id')::uuid and m.scope_kind='institution'
      and m.scope_institution_id=(item->>'institution_id')::uuid and i.status='active' and i.deleted_at is null
      and m.status::text=item->>'status' and l.status::text=item->>'status'
      and m.version=(item->>'version')::bigint and l.version=(item->>'version')::bigint
      and r.status='active' and r.code<>'owner' and r.max_scope_kind in ('platform','institution')
      and exists(select 1 from public.platform_role_permissions g join public.platform_permissions p on p.id=g.permission_id
        where g.role_id=r.id and p.code='platform.read' and p.status='active' and g.status='active'
          and g.effect='allow' and g.revoked_at is null)
      and (item->>'persona'<>'no-cap' or not exists(select 1 from public.platform_role_permissions g
        join public.platform_permissions p on p.id=g.permission_id where g.role_id=r.id
          and p.code='institution.update' and p.status='active' and g.status='active' and g.effect='allow' and g.revoked_at is null))
      and not exists(select 1 from app_private.superadmin_internal_auth_links other
        where other.internal_identity_id=m.internal_identity_id and other.id<>l.id)
      and not exists(select 1 from app_private.superadmin_internal_memberships other
        where other.internal_identity_id=m.internal_identity_id and other.id<>m.id)) end private_bindings
  from target)
select jsonb_build_object('planId','${plan.id}','state','${state}','verified',
  count(*)=5 and bool_and(auth_owned and no_people_link and private_bindings)
    and exists(select 1 from public.platform_permissions p where p.code='institution.update' and p.status='active'),
  'personas',jsonb_agg(to_jsonb(checks) order by persona)) from checks;
commit;
`;
}

// No CLI network client or environment/secret reading. This command consumes
// only a C00 catalog snapshot and writes a reviewable plan to stdout.
if (import.meta.main) {
  try {
    const [command, snapshotPath, operations, noCap, scope] = Deno.args;
    if (command === "snapshot-sql" && Deno.args.length === 2) {
      console.log(catalogSnapshotSql(snapshotPath));
    } else if (command === "verify-sql" && Deno.args.length === 3) {
      const input = JSON.parse(await Deno.readTextFile(snapshotPath));
      console.log(
        privateVerifySql(
          input.plan ?? input,
          operations as "active" | "scenario-revoked" | "revoked",
        ),
      );
    } else if (
      (command === "provision-sql" && Deno.args.length === 4) ||
      (command === "revoke-sql" && Deno.args.length === 5)
    ) {
      const input = JSON.parse(await Deno.readTextFile(snapshotPath));
      const plan: Plan = input.plan ?? input;
      console.log(
        command === "provision-sql"
          ? privateProvisionSql(plan, {
            authUserId: operations,
            sessionId: noCap,
          })
          : privateRevokeSql(
            plan,
            { authUserId: operations, sessionId: noCap },
            scope as "scenario" | "all",
          ),
      );
    } else {
      requireValue(
        command === "plan" && snapshotPath && operations && noCap &&
          Deno.args.length === 4,
        "USAGE_plan_SNAPSHOT_JSON_OPERATIONS_ROLE_UUID_NO_CAP_ROLE_UUID",
      );
      const plan = planPersonas(
        JSON.parse(await Deno.readTextFile(snapshotPath)),
        { operations, noCap },
      );
      console.log(JSON.stringify({ plan, effects: effects(plan) }, null, 2));
    }
  } catch (error) {
    console.error(
      error instanceof PackageError ? error.code : "INVALID_PLAN_INPUT",
    );
    Deno.exitCode = 1;
  }
}
