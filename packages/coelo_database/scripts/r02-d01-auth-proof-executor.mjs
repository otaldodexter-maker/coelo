import { pathToFileURL } from 'node:url';
import { target } from './r02-d01-auth-proof.mjs';

export const plan = Object.freeze({
  ...target,
  planId: '52edcfbe-adec-4614-b9a5-a10bc543379d',
  persona: 'auth-proof',
});
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const fail = (code) => { throw new Error(code); };
const literal = (value) => `'${value.replaceAll("'", "''")}'`;
const metadata = Object.freeze({coelo_e2_package: plan.package, coelo_e2_plan: plan.planId, coelo_e2_persona: plan.persona});

export function preview(action = 'provision') {
  if (!['provision', 'cleanup'].includes(action)) fail('ACTION_NOT_ALLOWED');
  return {...plan, action, mode: 'offline-no-network', mailbox: 'owner-input-required',
    mutations: action === 'provision'
      ? ['create-exact-auth-id-banned-no-email', 'insert-three-private-rows-and-audit', 'unban-owned-auth-id']
      : ['ban-owned-auth-id', 'revoke-owned-link-membership-and-audit', 'delete-only-owned-auth-sessions-with-refresh-token-cascade'],
    deletes: action === 'cleanup' ? 'only-owned-auth-session-rows' : 0, sendEmail: false};
}

export function validateInputs(action, input) {
  preview(action);
  if (input.projectRef !== plan.projectRef || input.apiOrigin !== plan.apiOrigin) fail('TARGET_MISMATCH');
  if (input.approval !== `${plan.package}:${plan.planId}:${action}`) fail('NOMINAL_APPROVAL_REQUIRED');
  if (typeof input.mailbox !== 'string' || input.mailbox !== input.mailbox.toLowerCase() ||
      !/^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/.test(input.mailbox) || input.mailbox.length > 254 ||
      /\.(invalid|test|example)$/.test(input.mailbox)) fail('CONTROLLED_MAILBOX_REQUIRED');
  if (!/^sb_secret_[A-Za-z0-9_-]+$/.test(input.secretKey ?? '') ||
      typeof input.managementToken !== 'string' || !/^[A-Za-z0-9._~-]{20,}$/.test(input.managementToken)) fail('SECRET_STORE_INPUT_REQUIRED');
  if (action === 'provision' && (typeof input.password !== 'string' || input.password.length < 32 || input.password.length > 128)) fail('SYNTHETIC_PASSWORD_REQUIRED');
  return sessionClaims(input.actorToken);
}

function sessionClaims(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error();
    const claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (!uuid.test(claims.sub) || !uuid.test(claims.session_id) || claims.iss !== `${plan.apiOrigin}/auth/v1` ||
        claims.role !== 'authenticated' || !['aal1', 'aal2'].includes(claims.aal) ||
        !Number.isFinite(claims.exp) || claims.exp <= Date.now() / 1000) throw new Error();
    return {sub: claims.sub, session_id: claims.session_id, aal: claims.aal, role: 'authenticated'};
  } catch (_) { fail('LIVE_SESSION_REQUIRED'); }
}

function ownershipSql(mailbox) {
  return `u.id='${plan.authUserId}'::uuid and lower(u.email)=${literal(mailbox)}
    and u.email_confirmed_at is not null
    and u.raw_app_meta_data->>'coelo_e2_package'='${plan.package}'
    and u.raw_app_meta_data->>'coelo_e2_plan'='${plan.planId}'
    and u.raw_app_meta_data->>'coelo_e2_persona'='${plan.persona}'`;
}

function exactBindings(state) {
  const version = state === 'active' ? 1 : 2;
  return `exists(select 1 from app_private.superadmin_internal_identities i
    join app_private.superadmin_internal_auth_links l on l.internal_identity_id=i.id
    join app_private.superadmin_internal_memberships m on m.internal_identity_id=i.id
    where i.id='${plan.identityId}'::uuid and i.created_by_internal_identity_id is not null
      and l.id='${plan.authLinkId}'::uuid and l.auth_user_id='${plan.authUserId}'::uuid
      and m.id='${plan.membershipId}'::uuid and m.platform_role_id='${plan.roleId}'::uuid
      and m.scope_kind='platform' and m.scope_institution_id is null
      and l.status='${state}' and m.status='${state}' and l.version=${version} and m.version=${version}
      and not exists(select 1 from app_private.superadmin_internal_auth_links x where (x.internal_identity_id=i.id or x.auth_user_id=l.auth_user_id) and x.id<>l.id)
      and not exists(select 1 from app_private.superadmin_internal_memberships x where x.internal_identity_id=i.id and x.id<>m.id))`;
}
const absentBindings = `not exists(select 1 from app_private.superadmin_internal_identities where id='${plan.identityId}'::uuid)
  and not exists(select 1 from app_private.superadmin_internal_auth_links where id='${plan.authLinkId}'::uuid or auth_user_id='${plan.authUserId}'::uuid or internal_identity_id='${plan.identityId}'::uuid)
  and not exists(select 1 from app_private.superadmin_internal_memberships where id='${plan.membershipId}'::uuid or internal_identity_id='${plan.identityId}'::uuid)`;
const roleReady = `exists(select 1 from public.platform_roles r where r.id='${plan.roleId}'::uuid and r.code='operations' and r.status='active' and r.max_scope_kind='platform'
  and exists(select 1 from public.platform_role_permissions g join public.platform_permissions p on p.id=g.permission_id where g.role_id=r.id and g.effect='allow' and g.status='active' and g.revoked_at is null and p.code='platform.read' and p.status='active'))`;

export function stateSql(mailbox) {
  return `select jsonb_build_object('planId','${plan.planId}',
    'auth_exists',exists(select 1 from auth.users where id='${plan.authUserId}'::uuid),
    'owned',exists(select 1 from auth.users u where ${ownershipSql(mailbox)}),
    'mailbox_collisions',(select count(*) from auth.users where lower(email)=${literal(mailbox)} and id<>'${plan.authUserId}'::uuid),
    'banned',exists(select 1 from auth.users u where ${ownershipSql(mailbox)} and u.banned_until>statement_timestamp()),
    'sessions',(select count(*) from auth.sessions where user_id='${plan.authUserId}'::uuid),
    'no_global_link',not exists(select 1 from public.person_auth_links where auth_user_id='${plan.authUserId}'::uuid),
    'role_ready',${roleReady},
    'bindings',case when ${absentBindings} then 'absent' when ${exactBindings('active')} then 'active' when ${exactBindings('revoked')} then 'revoked' else 'drift' end
  ) as receipt;`;
}

// Adapted from the existing e2-r01-auth-personas private transaction contract.
// No shared helper is changed: R01 requires five institution-scoped personas.
export function mutationSql(action, mailbox, actor) {
  preview(action);
  if (!uuid.test(actor.sub) || !uuid.test(actor.session_id) || !['aal1', 'aal2'].includes(actor.aal)) fail('LIVE_SESSION_REQUIRED');
  const claims = {sub: actor.sub, session_id: actor.session_id, aal: actor.aal, role: 'authenticated'};
  const provision = `
  if not (${roleReady}) or not (${absentBindings}) then raise exception 'NOMINAL_BINDINGS_OR_ROLE_DRIFT'; end if;
  if not exists(select 1 from auth.users u where ${ownershipSql(mailbox)} and u.banned_until>statement_timestamp()) then raise exception 'OWNED_BANNED_USER_REQUIRED'; end if;
  insert into app_private.superadmin_internal_identities(id,created_by_internal_identity_id) values('${plan.identityId}',ctx.internal_identity_id);
  insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,changed_by_internal_identity_id)
    values('${plan.authLinkId}','${plan.identityId}','${plan.authUserId}',ctx.internal_identity_id);
  insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,changed_by_internal_identity_id)
    values('${plan.membershipId}','${plan.identityId}','${plan.roleId}','platform',null,ctx.internal_identity_id);`;
  const cleanup = `
  if not (${absentBindings}) and not (${exactBindings('active')}) and not (${exactBindings('revoked')}) then raise exception 'NOMINAL_BINDINGS_DRIFT'; end if;
  if ${exactBindings('active')} then
    update app_private.superadmin_internal_memberships set status='revoked',revoked_at=clock_timestamp(),version=version+1,changed_by_internal_identity_id=ctx.internal_identity_id where id='${plan.membershipId}' and version=1;
    update app_private.superadmin_internal_auth_links set status='revoked',revoked_at=clock_timestamp(),version=version+1,changed_by_internal_identity_id=ctx.internal_identity_id where id='${plan.authLinkId}' and version=1;
  end if;
  -- Terminal provider-session revocation does not require a live synthetic JWT.
  -- Verified production FKs cascade only to auth.refresh_tokens/auth.mfa_amr_claims.
  delete from auth.sessions s using auth.users u where s.user_id=u.id and ${ownershipSql(mailbox)};`;
  return `begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
select pg_advisory_xact_lock(hashtextextended('${plan.package}:${plan.planId}',0));
select set_config('request.jwt.claims',${literal(JSON.stringify(claims))},true);
do $d01$
declare ctx app_private.superadmin_internal_context;
begin
  if current_user<>'postgres' then raise exception 'POSTGRES_EXECUTOR_REQUIRED'; end if;
  select * into ctx from app_private.require_superadmin_internal_context('platform.read');
  if ctx.platform_role_code is distinct from 'owner' or ctx.scope_kind is distinct from 'platform'
    or ctx.auth_user_id is distinct from '${actor.sub}'::uuid or ctx.session_id is distinct from '${actor.session_id}'::uuid then raise exception 'LIVE_OWNER_REQUIRED'; end if;
  perform 1 from auth.users u where ${ownershipSql(mailbox)} for update;
  if not found then raise exception 'NOMINAL_AUTH_OWNERSHIP_REQUIRED'; end if;
  if exists(select 1 from public.person_auth_links where auth_user_id='${plan.authUserId}'::uuid) then raise exception 'CROSS_REALM_DENIED'; end if;
  perform 1 from app_private.superadmin_internal_auth_links where id='${plan.authLinkId}'::uuid for update;
  perform 1 from app_private.superadmin_internal_memberships where id='${plan.membershipId}'::uuid for update;
${action === 'provision' ? provision : cleanup}
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.read',ctx.aal,'e2.r02.auth.${action}','success','${plan.package}','${plan.planId}',null,'superadmin_internal_identity','${plan.identityId}');
end
$d01$;
commit;
${stateSql(mailbox)}`;
}

function receipt(data) {
  const value = Array.isArray(data) && data.length === 1 ? data[0]?.receipt : undefined;
  if (!value || value.planId !== plan.planId ||
      !['absent', 'active', 'revoked', 'drift'].includes(value.bindings) ||
      !['auth_exists','owned','banned','no_global_link','role_ready'].every((key) => typeof value[key] === 'boolean') ||
      !Number.isSafeInteger(value.sessions) || value.sessions < 0 || !Number.isSafeInteger(value.mailbox_collisions) || value.mailbox_collisions < 0) fail('STATE_UNCONFIRMED');
  return value;
}
function ownedUser(data, mailbox) {
  const user = data?.user ?? data;
  if (user?.id !== plan.authUserId || user?.email?.toLowerCase() !== mailbox ||
      !Object.entries(metadata).every(([key,value]) => user.app_metadata?.[key] === value)) fail('AUTH_OWNERSHIP_UNCONFIRMED');
  return user;
}

export async function execute(action, input, fetcher = fetch) {
  const actor = validateInputs(action, input);
  if (actor.sub === plan.authUserId) fail('OWNER_AND_SYNTHETIC_MUST_DIFFER');
  async function request(url, method, headers, body, code, absent = false) {
    try {
      const response = await fetcher(url, {method, headers, body: body === undefined ? undefined : JSON.stringify(body),
        credentials: 'omit', redirect: 'error', signal: AbortSignal.timeout(40000)});
      if (absent && response.status === 404) return null;
      if (![200,201,204].includes(response.status)) throw new Error();
      return response.status === 204 ? null : await response.json();
    } catch (_) { fail(code); } // No automatic retry or compensating mutation.
  }
  const apiHeaders = {apikey: input.secretKey, 'Content-Type':'application/json'};
  const auth = (path, method = 'GET', body, token, code = 'AUTH_OPERATION_UNCONFIRMED') => request(
    `${plan.apiOrigin}/auth/v1${path}`, method,
    token ? {...apiHeaders, Authorization:`Bearer ${token}`} : apiHeaders, body, code);
  const sqlRequest = (sql, code = 'SQL_OPERATION_UNCONFIRMED') => request(
    `https://api.supabase.com/v1/projects/${plan.projectRef}/database/query`, 'POST',
    {Authorization:`Bearer ${input.managementToken}`, 'Content-Type':'application/json'}, {query:sql}, code);
  const query = async (sql, code) => receipt(await sqlRequest(sql,code));
  const readState = () => query(`begin read only;\n${stateSql(input.mailbox)}\ncommit;`);
  const actorUser = await auth('/user', 'GET', undefined, input.actorToken, 'ACTOR_UNCONFIRMED');
  if ((actorUser?.user ?? actorUser)?.id !== actor.sub) fail('ACTOR_UNCONFIRMED');
  const actorProof = await sqlRequest(`begin read only;
select set_config('request.jwt.claims',${literal(JSON.stringify(actor))},true);
select jsonb_build_object('authorized',ctx.platform_role_code='owner' and ctx.scope_kind='platform'
  and ctx.auth_user_id='${actor.sub}'::uuid and ctx.session_id='${actor.session_id}'::uuid) as actor
from app_private.require_superadmin_internal_context('platform.read') ctx;
commit;`,'OWNER_CONTEXT_UNCONFIRMED');
  if (!Array.isArray(actorProof) || actorProof.length!==1 || actorProof[0]?.actor?.authorized!==true) fail('LIVE_OWNER_REQUIRED');
  let current = await readState();
  if (current.mailbox_collisions || !current.no_global_link || current.bindings === 'drift' || (current.auth_exists && !current.owned)) fail('NOMINAL_OWNERSHIP_OR_COLLISION');
  if (action === 'provision') {
    if (!current.role_ready || current.bindings === 'revoked') fail('PROVISION_STATE_DENIED');
    if (!current.auth_exists) {
      if (current.bindings !== 'absent') fail('PROVISION_STATE_DENIED');
      const created = await auth('/admin/users', 'POST', {id:plan.authUserId, email:input.mailbox, password:input.password,
        email_confirm:true, ban_duration:'876000h', app_metadata:metadata}, undefined, 'AUTH_CREATE_UNCONFIRMED');
      ownedUser(created, input.mailbox);
      current = await readState();
    }
    ownedUser(await auth(`/admin/users/${plan.authUserId}`), input.mailbox);
    if (!current.owned || !current.no_global_link) fail('AUTH_OWNERSHIP_UNCONFIRMED');
    if (current.bindings === 'absent') {
      if (!current.banned || current.sessions !== 0) fail('OWNED_BANNED_USER_REQUIRED');
      current = await query(mutationSql('provision',input.mailbox,actor), 'BINDINGS_COMMIT_UNCONFIRMED');
    }
    if (current.bindings !== 'active' || !current.owned || current.banned && current.sessions !== 0) fail('BINDINGS_UNCONFIRMED');
    if (current.banned) {
      ownedUser(await auth(`/admin/users/${plan.authUserId}`), input.mailbox);
      ownedUser(await auth(`/admin/users/${plan.authUserId}`, 'PUT', {ban_duration:'none'}, undefined, 'AUTH_UNBAN_UNCONFIRMED'), input.mailbox);
    }
    current = await readState();
    if (!current.owned || current.banned || current.bindings !== 'active' || !current.role_ready || !current.no_global_link) fail('PROVISION_UNCONFIRMED');
  } else {
    if (!current.auth_exists) {
      if (current.bindings !== 'absent' || current.sessions !== 0) fail('CLEANUP_STATE_DENIED');
      return {package:plan.package,planId:plan.planId,action,status:'nothing-created',sendEmail:false};
    }
    ownedUser(await auth(`/admin/users/${plan.authUserId}`), input.mailbox);
    if (!(current.banned && current.sessions===0 && ['absent','revoked'].includes(current.bindings))) {
      try {
        ownedUser(await auth(`/admin/users/${plan.authUserId}`,'PUT',{ban_duration:'876000h'},undefined,'AUTH_BAN_UNCONFIRMED'),input.mailbox);
      } catch (_) {
        // A lost ban response must not prevent terminal access/session revocation.
        // Do not retry the ban. The final authoritative read decides its outcome.
      }
      current = await query(mutationSql('cleanup',input.mailbox,actor),'REVOCATION_COMMIT_UNCONFIRMED');
    }
    current = await readState();
    if (!current.owned || !current.banned || current.sessions !== 0 || !['absent','revoked'].includes(current.bindings) || !current.no_global_link) fail('CLEANUP_UNCONFIRMED');
  }
  return {package:plan.package,planId:plan.planId,action,status:'confirmed',bindings:current.bindings,
    banned:current.banned,sessionRows:current.sessions,sendEmail:false};
}

export async function main(args, env = process.env, fetcher = fetch) {
  if (args.length === 0) return preview();
  if (args.length === 1) return preview(args[0]);
  if (args.length !== 2 || args[0] !== '--execute') fail('ARGUMENTS_NOT_ALLOWED');
  return execute(args[1], {
    projectRef:env.R02_D01_PROJECT_REF,apiOrigin:env.R02_D01_API_ORIGIN,
    approval:env.R02_D01_APPROVAL,mailbox:env.R02_D01_MAILBOX,
    secretKey:env.R02_D01_SUPABASE_SECRET_KEY,managementToken:env.R02_D01_MANAGEMENT_TOKEN,
    actorToken:env.R02_D01_ACTOR_ACCESS_TOKEN,password:env.R02_D01_SYNTHETIC_PASSWORD,
  },fetcher);
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  main(process.argv.slice(2)).then((value)=>console.log(JSON.stringify(value))).catch((error)=>{
    console.error(/^[A-Z][A-Z_]{2,80}$/.test(error?.message ?? '') ? error.message : 'EXECUTION_UNCONFIRMED');
    process.exitCode=1;
  });
}
