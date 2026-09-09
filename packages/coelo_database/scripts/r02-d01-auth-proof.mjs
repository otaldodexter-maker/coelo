import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export const target = Object.freeze({
  package: 'D01-AUTH-PROOF-R02-v1',
  projectRef: 'evvbomzejfijozbtgvpt',
  apiOrigin: 'https://evvbomzejfijozbtgvpt.supabase.co',
  appOrigin: 'https://superadmin.coelo.me',
  redirect: 'https://superadmin.coelo.me/reset-password',
  roleId: '0da9b079-60db-406a-9721-d829a074b9cd',
  identityId: '71b183d9-5591-41e9-bfff-90460f2d2ab1',
  authLinkId: '7bd71321-05c0-412a-8ac7-3a38df859c6b',
  membershipId: 'bf7a4fbb-149d-4442-a221-bfef921383ee',
  authUserId: '8d7a34f8-6230-4f43-82c3-45743d62ab96',
});

// Read-only by construction: no session refresh, bootstrap RPC, mail or admin API.
export const qualificationSql = `begin read only;
select jsonb_build_object(
  'project_ref','${target.projectRef}',
  'context_rpc_present',to_regprocedure('public.superadmin_auth_bootstrap_context()') is not null,
  'internal_auth_links_present',to_regclass('app_private.superadmin_internal_auth_links') is not null,
  'internal_memberships_present',to_regclass('app_private.superadmin_internal_memberships') is not null,
  'auth_sessions_present',to_regclass('auth.sessions') is not null,
  'operations_role_ready',exists(select 1 from public.platform_roles where id='${target.roleId}'::uuid and code='operations' and status='active' and max_scope_kind='platform'),
  'reserved_ids_free',not exists(select 1 from auth.users where id='${target.authUserId}'::uuid) and not exists(select 1 from app_private.superadmin_internal_identities where id='${target.identityId}'::uuid) and not exists(select 1 from app_private.superadmin_internal_auth_links where id='${target.authLinkId}'::uuid) and not exists(select 1 from app_private.superadmin_internal_memberships where id='${target.membershipId}'::uuid),
  'package_owned_users',(select count(*) from auth.users where raw_app_meta_data->>'coelo_e2_package'='${target.package}'),
  'package_session_rows',(select count(*) from auth.sessions s join auth.users u on u.id=s.user_id where u.raw_app_meta_data->>'coelo_e2_package'='${target.package}')
) as qualification;
commit;`;

export function qualifyLocalConfig(toml) {
  const auth = toml.split(/^\[auth\]\s*$/m)[1]?.split(/^\[/m)[0];
  if (!auth) throw new Error('LOCAL_AUTH_SECTION_MISSING');
  const redirects = auth.match(/^additional_redirect_urls\s*=\s*\[([^\]]*)\]/m)?.[1];
  const allowed = [...(redirects ?? '').matchAll(/"([^"\r\n]*)"/g)].map((match) => match[1]);
  if (!allowed.includes(target.redirect)) throw new Error('LOCAL_REDIRECT_MISSING');
  return {
    mode: 'local-config-only', projectRef: target.projectRef,
    configuredProductionRedirect: true,
    productionConfigVerified: false, session: 'not-exercised', context: 'not-exercised',
  };
}

export async function qualifyPublicSettings({
  projectRef = target.projectRef, apiOrigin = target.apiOrigin,
  appOrigin = target.appOrigin, publishableKey, fetcher = fetch,
} = {}) {
  if (projectRef !== target.projectRef || apiOrigin !== target.apiOrigin || appOrigin !== target.appOrigin) {
    throw new Error('NOMINAL_TARGET_MISMATCH');
  }
  if (typeof publishableKey !== 'string' || !/^sb_publishable_[A-Za-z0-9_-]+$/.test(publishableKey)) {
    throw new Error('PUBLISHABLE_KEY_REQUIRED');
  }
  try {
    const response = await fetcher(`${target.apiOrigin}/auth/v1/settings`, {
      method: 'GET', redirect: 'error', credentials: 'omit',
      headers: { apikey: publishableKey }, signal: AbortSignal.timeout(10000),
    });
    if (response.status !== 200) throw new Error('SETTINGS_UNCONFIRMED');
    const data = await response.json();
    if (typeof data?.external?.email !== 'boolean' || typeof data?.disable_signup !== 'boolean') {
      throw new Error('SETTINGS_UNCONFIRMED');
    }
    return {
      mode: 'remote-readonly', projectRef: target.projectRef,
      emailProviderEnabled: data.external.email, signupDisabled: data.disable_signup,
      smtpDelivery: 'not-exercised', redirectAllowlist: 'not-exposed-by-public-settings',
      session: 'not-exercised', context: 'not-exercised',
    };
  } catch (_) {
    // Provider/network bodies may include credentials or PII. Never propagate them.
    throw new Error('SETTINGS_UNCONFIRMED');
  }
}

export async function main(args, env = process.env) {
  if (args.length !== 1) throw new Error('MODE_REQUIRED');
  if (args[0] === '--sql') return qualificationSql;
  if (args[0] === '--local') {
    const config = await readFile(new URL('../supabase/config.toml', import.meta.url), 'utf8');
    return JSON.stringify(qualifyLocalConfig(config));
  }
  if (args[0] === '--remote-readonly') {
    return JSON.stringify(await qualifyPublicSettings({ publishableKey: env.R02_D01_PUBLISHABLE_KEY }));
  }
  throw new Error('MODE_NOT_ALLOWED');
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  main(process.argv.slice(2)).then(console.log).catch((error) => {
    const safe = new Set(['MODE_REQUIRED', 'MODE_NOT_ALLOWED', 'LOCAL_AUTH_SECTION_MISSING',
      'LOCAL_REDIRECT_MISSING', 'PUBLISHABLE_KEY_REQUIRED', 'SETTINGS_UNCONFIRMED']);
    console.error(safe.has(error.message) ? error.message : 'QUALIFICATION_FAILED');
    process.exitCode = 1;
  });
}
