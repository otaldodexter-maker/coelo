begin;

create extension if not exists pgtap with schema extensions;

select plan(60);

select has_column('public', 'invitations', 'target_kind', 'invite target kind is explicit');
select has_column('public', 'invitations', 'profile_id', 'invite profile is a foreign key');
select has_column('public', 'invitations', 'channels', 'invite channels are persisted');
select has_column('public', 'invitations', 'version', 'invite commands use optimistic concurrency');
select has_column('public', 'invitations', 'updated_at', 'invite changes are timestamped');
select has_column('public', 'invitations', 'validity_hours', 'resend preserves server-owned expiry policy');
select has_table('app_private', 'superadmin_invite_command_receipts', 'idempotency receipts are private');
select has_table('app_private', 'superadmin_invite_email_outbox', 'email delivery uses a private outbox');

select results_eq(
  $$select code from public.platform_permissions
    where code in ('platform.invites.manage', 'platform.invites.read') order by code$$,
  $$values ('platform.invites.manage'::text), ('platform.invites.read'::text)$$,
  'invite capabilities exist'
);
select ok(
  (select requires_mfa from public.platform_permissions where code = 'platform.invites.manage')
  and not (select requires_mfa from public.platform_permissions where code = 'platform.invites.read'),
  'manage requires MFA while read does not'
);
select ok(
  not exists (
    select 1
    from public.platform_permissions permission_record
    cross join public.platform_roles role_record
    where permission_record.code in ('platform.invites.manage', 'platform.invites.read')
      and role_record.code = 'owner'
      and not exists (
        select 1 from public.platform_role_permissions grant_record
        where grant_record.permission_id = permission_record.id
          and grant_record.role_id = role_record.id
          and grant_record.effect = 'allow'
          and grant_record.status = 'active'
          and grant_record.revoked_at is null
      )
  ),
  'owner receives both invite capabilities explicitly'
);

select has_function(
  'public', 'superadmin_invite_directory',
  array['text','text[]','text[]','uuid[]','uuid[]','uuid[]','uuid[]','timestamp with time zone','timestamp with time zone','integer','integer','text','boolean'],
  'directory filters and cursor pagination are server side'
);
select has_function('public', 'superadmin_invite_options', array['text','uuid','uuid','uuid','integer'], 'hierarchical options are server side');
select has_function('public', 'superadmin_invite_get', array['uuid'], 'detail is an authorized RPC');
select has_function('public', 'superadmin_invite_issue', array['uuid','uuid','uuid','uuid','uuid','uuid','text','text[]','integer'], 'issue is idempotent');
select has_function('public', 'superadmin_invite_resend', array['uuid','uuid','bigint'], 'resend is versioned and idempotent');
select has_function('public', 'superadmin_invite_revoke', array['uuid','uuid','bigint','text'], 'revoke is versioned and idempotent');

select ok(
  not has_table_privilege('anon', 'public.invitations', 'SELECT,INSERT,UPDATE,DELETE')
  and not has_table_privilege('authenticated', 'public.invitations', 'INSERT,UPDATE,DELETE'),
  'browser roles cannot mutate invitations directly'
);
select ok(
  not has_column_privilege('authenticated', 'public.invitations', 'token_hash', 'SELECT')
  and not has_column_privilege('authenticated', 'public.invitations', 'target_contact_hash', 'SELECT')
  and not has_column_privilege('authenticated', 'public.invitations', 'invited_by', 'SELECT'),
  'direct target read cannot expose token, contact or issuer identifiers'
);
select ok(
  has_column_privilege('authenticated', 'public.invitations', 'id', 'SELECT')
  and has_column_privilege('authenticated', 'public.invitations', 'invitation_state', 'SELECT')
  and has_column_privilege('authenticated', 'public.invitations', 'expires_at', 'SELECT'),
  'direct target read exposes only the minimal invitation lifecycle columns'
);
select ok(
  (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.invitations'::regclass)
  and (select count(*) = 1 from pg_policies where schemaname = 'public' and tablename = 'invitations')
  and exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'invitations'
      and policyname = 'invitations_self_read' and cmd = 'SELECT'
      and qual like '%target_person_id%'
      and qual not like '%invited_by%'
  ),
  'invitations keep one target-only direct-read policy with forced RLS'
);
select ok(
  not has_function_privilege('anon', 'public.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'app_private.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'app_private.superadmin_invite_resend(uuid,uuid,bigint)', 'EXECUTE')
  and not has_table_privilege('authenticated', 'app_private.superadmin_invite_read_model', 'SELECT'),
  'authenticated clients can reach only public invite gateways'
);
select ok(
  (
    select bool_and(procedure.prosecdef)
      and bool_and(procedure.proconfig @> array['search_path=""'])
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname like 'superadmin_invite_%'
  ) and exists (
    select 1 from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'app_private'
      and relation.relname = 'superadmin_invite_read_model'
      and relation.relkind = 'v'
      and relation.reloptions @> array['security_invoker=true']
  ),
  'public wrappers are minimal security definers with empty search_path because private implementations stay revoked'
);
select ok(
  (
    select bool_and(procedure.prosecdef)
      and bool_and(procedure.proconfig @> array['search_path=""'])
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'app_private'
      and procedure.proname in (
        'superadmin_invite_directory', 'superadmin_invite_options',
        'superadmin_invite_get', 'superadmin_invite_issue',
        'superadmin_invite_resend', 'superadmin_invite_revoke'
      )
  ),
  'private implementations are security definer with empty search_path'
);
select ok(
  pg_get_functiondef('app_private.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)'::regprocedure) like '%platform.invites.manage%'
  and pg_get_functiondef('app_private.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)'::regprocedure) like '%superadmin_invite_require%'
  and pg_get_functiondef('app_private.superadmin_invite_require(text,boolean)'::regprocedure) like '%has_mfa_aal2%'
  and pg_get_functiondef('app_private.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)'::regprocedure) like '%superadmin_invite_command_receipts%'
  and pg_get_functiondef('app_private.superadmin_invite_directory(text,text[],text[],uuid[],uuid[],uuid[],uuid[],timestamptz,timestamptz,integer,integer,text,boolean)'::regprocedure) like '%superadmin_invite_read_model%'
  and pg_get_functiondef('app_private.superadmin_invite_directory(text,text[],text[],uuid[],uuid[],uuid[],uuid[],timestamptz,timestamptz,integer,integer,text,boolean)'::regprocedure) not like '%superadmin_invite_json(page.id)%'
  and pg_get_functiondef('app_private.superadmin_invite_resend(uuid,uuid,bigint)'::regprocedure) like '%for update%'
  and pg_get_functiondef('app_private.superadmin_invite_revoke(uuid,uuid,bigint,text)'::regprocedure) like '%for update%',
  'commands reauthorize, require MFA, lock rows and use receipts'
);
select ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'public' and tablename = 'invitations'
      and indexname = 'invitations_directory_cursor_idx'
  ) and exists (
    select 1 from pg_indexes
    where schemaname = 'public' and tablename = 'invitations'
      and indexname = 'invitations_profile_idx'
  ),
  'directory and profile filters are indexed'
);

insert into auth.users(id, aud, role, email, created_at, updated_at) values
  ('73000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'invite-owner@test.invalid', now(), now()),
  ('73000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'invite-denied@test.invalid', now(), now()),
  ('73000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'invite-target@test.invalid', now(), now());

insert into public.people(id, person_type, first_name, last_name, display_name, status) values
  ('73100000-0000-4000-8000-000000000001', 'adult', 'Invite', 'Owner', 'Invite Owner', 'active'),
  ('73100000-0000-4000-8000-000000000002', 'adult', 'Invite', 'Denied', 'Invite Denied', 'active'),
  ('73100000-0000-4000-8000-000000000003', 'adult', 'Invite', 'Target', 'Invite Target', 'active');

insert into public.person_auth_links(person_id, auth_user_id, status) values
  ('73100000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000001', 'active'),
  ('73100000-0000-4000-8000-000000000002', '73000000-0000-4000-8000-000000000002', 'active'),
  ('73100000-0000-4000-8000-000000000003', '73000000-0000-4000-8000-000000000003', 'active');

insert into public.platform_roles(id, code, name, status, is_system)
values ('73200000-0000-4000-8000-000000000002', 'invite_test_denied', 'Invite test denied', 'active', true);

insert into public.platform_memberships(person_id, role_id, status, scope_kind, mfa_required)
select '73100000-0000-4000-8000-000000000001', id, 'active', 'platform', true
from public.platform_roles where code = 'owner';
insert into public.platform_memberships(person_id, role_id, status, scope_kind, mfa_required)
values ('73100000-0000-4000-8000-000000000002', '73200000-0000-4000-8000-000000000002', 'active', 'platform', false);

insert into public.institutions(id, public_name, legal_name, slug, status) values
  ('73300000-0000-4000-8000-000000000001', 'Invite Institution A', 'Invite Institution A', 'invite-institution-a', 'active'),
  ('73300000-0000-4000-8000-000000000002', 'Invite Institution B', 'Invite Institution B', 'invite-institution-b', 'active');
insert into public.units(id, institution_id, name, slug, status, unit_type_id, unit_type_other_description, handle) values
  ('73400000-0000-4000-8000-000000000001', '73300000-0000-4000-8000-000000000001', 'Invite Unit A', 'invite-unit-a', 'active',
    (select id from public.unit_types where status = 'active' and lower(code) = 'other' order by code limit 1), 'Teste Convites', 'invite_unit_a'),
  ('73400000-0000-4000-8000-000000000002', '73300000-0000-4000-8000-000000000002', 'Invite Unit B', 'invite-unit-b', 'active',
    (select id from public.unit_types where status = 'active' and lower(code) = 'other' order by code limit 1), 'Teste Convites', 'invite_unit_b');
insert into public.groups(id, institution_id, unit_id, name, status) values
  ('73500000-0000-4000-8000-000000000001', '73300000-0000-4000-8000-000000000001', '73400000-0000-4000-8000-000000000001', 'Invite Group A', 'active'),
  ('73500000-0000-4000-8000-000000000002', '73300000-0000-4000-8000-000000000002', '73400000-0000-4000-8000-000000000002', 'Invite Group B', 'active');
insert into public.institution_roles(id, institution_id, code, name, status, max_scope_kind) values
  ('73600000-0000-4000-8000-000000000001', '73300000-0000-4000-8000-000000000001', 'invite_admin_a', 'Invite Admin A', 'active', 'institution'),
  ('73600000-0000-4000-8000-000000000002', '73300000-0000-4000-8000-000000000002', 'invite_admin_b', 'Invite Admin B', 'active', 'institution'),
  ('73600000-0000-4000-8000-000000000003', '73300000-0000-4000-8000-000000000001', 'invite_group_a', 'Invite Group A', 'active', 'group');
insert into public.institution_memberships(person_id, institution_id, role_code, status, scope_kind)
values ('73100000-0000-4000-8000-000000000003', '73300000-0000-4000-8000-000000000001', 'member', 'active', 'institution');

create temporary table invite_test_results(kind text primary key, result jsonb, token_hash text);
grant select, insert, update on invite_test_results to authenticated;

set local role anon;
select throws_ok(
  $$select public.superadmin_invite_directory('', '{}'::text[], '{}'::text[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], null, null, 25, 0, 'created_at', false)$$,
  '42501', null, 'anonymous callers cannot enumerate invites'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000002","aal":"aal2","role":"authenticated"}', true);
select throws_ok(
  $$select public.superadmin_invite_directory('', '{}'::text[], '{}'::text[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], null, null, 25, 0, 'created_at', false)$$,
  '42501', 'platform.invites.read required', 'authenticated actor without capability cannot read'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}', true);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000001', '73300000-0000-4000-8000-000000000001', null, null, '73600000-0000-4000-8000-000000000001', null, 'owner@example.com', array['link'], 48)$$,
  '42501', 'MFA AAL2 required', 'manage fails closed without AAL2'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}', true);
select throws_ok(
  $$select public.superadmin_invite_directory('', null, '{}'::text[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], null, null, 25, 0, 'created_at', false)$$,
  '22023', 'invalid invitation directory filters', 'null filter arrays fail closed'
);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000010', '73300000-0000-4000-8000-000000000001', null, null, '73600000-0000-4000-8000-000000000001', '73100000-0000-4000-8000-000000000003', 'both@example.com', array['link'], 48)$$,
  '22023', 'invalid invitation input', 'recipient target is an exclusive person-or-email choice'
);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000011', '73300000-0000-4000-8000-000000000001', null, null, '73600000-0000-4000-8000-000000000001', null, null, array['link'], 48)$$,
  '22023', 'invalid invitation input', 'recipient target cannot be omitted'
);
select ok(
  (
    select jsonb_array_length(payload->'scopes') = 1
      and payload->'scopes'->0 @> jsonb_build_object(
        'scope_kind','group','institution_id','73300000-0000-4000-8000-000000000001',
        'unit_id','73400000-0000-4000-8000-000000000001','group_id','73500000-0000-4000-8000-000000000001'
      )
      and exists (
        select 1 from jsonb_array_elements(payload->'profiles') profile
        where profile @> jsonb_build_object(
          'profile_id','73600000-0000-4000-8000-000000000001',
          'institution_id','73300000-0000-4000-8000-000000000001'
        ) and profile ?& array['label','unit_id','group_id']
      )
      and exists (
        select 1 from jsonb_array_elements(payload->'recipients') recipient
        where recipient @> jsonb_build_object('person_id','73100000-0000-4000-8000-000000000003')
          and recipient ?& array['label','masked_email']
      )
    from (select public.superadmin_invite_options(
      '', '73300000-0000-4000-8000-000000000001',
      '73400000-0000-4000-8000-000000000001', null, 25
    ) payload) options_result
  ),
  'options return adapter-shaped scopes, applicable profiles and searchable people for the selected hierarchy'
);
select ok(
  not exists (
    select 1 from jsonb_array_elements(public.superadmin_invite_options(
      '', '73300000-0000-4000-8000-000000000001',
      '73400000-0000-4000-8000-000000000001', null, 25
    )->'profiles') profile
    where profile->>'profile_id' = '73600000-0000-4000-8000-000000000003'
  ) and exists (
    select 1 from jsonb_array_elements(public.superadmin_invite_options(
      '', '73300000-0000-4000-8000-000000000001',
      '73400000-0000-4000-8000-000000000001', '73500000-0000-4000-8000-000000000001', 25
    )->'profiles') profile
    where profile->>'profile_id' = '73600000-0000-4000-8000-000000000003'
  ),
  'profile options respect the selected hierarchy and profile maximum scope'
);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000014', '73300000-0000-4000-8000-000000000001', null, null, '73600000-0000-4000-8000-000000000003', null, 'wrong-scope@example.com', array['link'], 48)$$,
  '22023', 'invalid invitation profile', 'profile cannot be issued above its maximum scope'
);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000002', '73300000-0000-4000-8000-000000000001', '73400000-0000-4000-8000-000000000002', null, '73600000-0000-4000-8000-000000000001', null, 'cross-unit@example.com', array['link'], 48)$$,
  '22023', 'invalid invitation hierarchy', 'cross-tenant unit is rejected'
);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000003', '73300000-0000-4000-8000-000000000001', '73400000-0000-4000-8000-000000000001', '73500000-0000-4000-8000-000000000002', '73600000-0000-4000-8000-000000000001', null, 'cross-group@example.com', array['link'], 48)$$,
  '22023', 'invalid invitation hierarchy', 'cross-tenant child scope is rejected'
);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000004', '73300000-0000-4000-8000-000000000001', null, null, '73600000-0000-4000-8000-000000000002', null, 'cross-profile@example.com', array['link'], 48)$$,
  '22023', 'invalid invitation profile', 'profile from another tenant is rejected'
);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000005', '73300000-0000-4000-8000-000000000001', null, null, '73600000-0000-4000-8000-000000000001', null, 'sms@example.com', array['sms'], 48)$$,
  '22023', 'invalid invitation channels', 'SMS is rejected by the backend'
);
insert into invite_test_results(kind, result)
select 'issued', public.superadmin_invite_issue(
  '73700000-0000-4000-8000-000000000006',
  '73300000-0000-4000-8000-000000000001',
  '73400000-0000-4000-8000-000000000001',
  '73500000-0000-4000-8000-000000000001',
  '73600000-0000-4000-8000-000000000001',
  null, 'delivery@example.com', array['email','link'], 48
);
insert into invite_test_results(kind, result)
select 'person_issued', public.superadmin_invite_issue(
  '73700000-0000-4000-8000-000000000013',
  '73300000-0000-4000-8000-000000000001',
  null, null, '73600000-0000-4000-8000-000000000001',
  '73100000-0000-4000-8000-000000000003', null, array['link'], 48
);
insert into invite_test_results(kind, result)
select 'email_only', public.superadmin_invite_issue(
  '73700000-0000-4000-8000-000000000014',
  '73300000-0000-4000-8000-000000000001',
  null, null, '73600000-0000-4000-8000-000000000001',
  null, 'only-email@example.com', array['email'], 48
);
reset role;

select ok(
  (select result->'invite'->>'status' = 'pending'
      and result->>'link' like 'https://app.coelo.me/convites/%'
      and result->'invite' ?& array[
        'invite_id','status','channels','scope_kind','institution_id','unit_id','group_id','scope_label',
        'profile_id','profile_label','target_person_id','recipient_label','recipient_masked',
        'issuer_person_id','issuer_label','email_delivery_status','management_version',
        'created_at','expires_at','accepted_at','revoked_at','timeline'
      ]
    from invite_test_results where kind = 'issued'),
  'authorized AAL2 issue returns the one-time link'
);
select ok(
  (select result->'link' = 'null'::jsonb
     from invite_test_results where kind = 'email_only'),
  'email-only issue does not expose the clear invitation token'
);
select ok(
  (select (select count(*) from jsonb_object_keys(result)) = 3
      and result ?& array['invite','link','replayed']
      and result->'invite'->>'scope_label' = 'Invite Institution A / Invite Unit A / Invite Group A'
      and result->'invite'->>'profile_label' = 'Invite Admin A'
      and result->'invite'->>'recipient_masked' = 'd***@example.com'
      and result->'invite'->>'email_delivery_status' = 'queued'
      and (result->'invite'->>'management_version')::bigint = 1
    from invite_test_results where kind = 'issued'),
  'command JSON matches the productive Flutter adapter contract exactly'
);
update invite_test_results result_record
set token_hash = invitation.token_hash
from public.invitations invitation
where result_record.kind = 'issued' and invitation.id = (result_record.result->'invite'->>'invite_id')::uuid;
select ok(
  exists (
    select 1 from app_private.superadmin_invite_email_outbox outbox
    join public.invitations invitation on invitation.id = outbox.invitation_id
    join invite_test_results result_record on (result_record.result->'invite'->>'invite_id')::uuid = outbox.invitation_id
    where result_record.kind = 'issued' and outbox.state = 'pending'
      and outbox.destination_hash ~ '^[0-9a-f]{64}$'
      and outbox.masked_destination = 'd***@example.com'
      and outbox.token_hash_snapshot = invitation.token_hash
  ),
  'email channel creates a pending hash-only outbox item'
);
select ok(
  not exists (
    select 1 from information_schema.columns
    where table_schema = 'app_private' and table_name = 'superadmin_invite_email_outbox'
      and column_name in ('token','raw_token','destination','email')
  ) and not exists (
    select 1 from app_private.superadmin_invite_email_outbox outbox
    join invite_test_results result_record on result_record.kind = 'issued'
    where to_jsonb(outbox)::text like '%' || regexp_replace(result_record.result->>'link', '^.*/', '') || '%'
  ),
  'clear token and clear destination never persist in invitation or outbox storage'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', jsonb_build_object('sub','73000000-0000-4000-8000-000000000001','aal','aal2','role','authenticated')::text, true);
select is(
  (select count(*)::bigint from public.invitations
    where id = (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued')),
  0::bigint,
  'issuer cannot bypass the capability-checked RPC with direct table SELECT'
);
select is(
  (public.superadmin_invite_directory(
    '%'' OR true --', '{}'::text[], '{}'::text[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[],
    null, null, 25, 0, 'created_at', false
  )->>'total_count')::bigint,
  0::bigint,
  'search is parameterized and SQL-injection text is treated as text'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000003', true);
select set_config('request.jwt.claims', jsonb_build_object('sub','73000000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text, true);
select is(
  (select count(*)::bigint from public.invitations
    where id = (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'person_issued')),
  1::bigint,
  'target person can read exactly their own invitation through the target-only RLS policy'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}', true);
insert into invite_test_results(kind, result)
select 'issue_replay', public.superadmin_invite_issue(
  '73700000-0000-4000-8000-000000000006',
  '73300000-0000-4000-8000-000000000001',
  '73400000-0000-4000-8000-000000000001',
  '73500000-0000-4000-8000-000000000001',
  '73600000-0000-4000-8000-000000000001',
  null, 'delivery@example.com', array['email','link'], 48
);
select throws_ok(
  $$select public.superadmin_invite_issue('73700000-0000-4000-8000-000000000006', '73300000-0000-4000-8000-000000000001', null, null, '73600000-0000-4000-8000-000000000001', null, 'different@example.com', array['link'], 48)$$,
  '22023', 'idempotency key conflict', 'same request id with a different payload is rejected'
);
reset role;
select ok(
  (select (result->>'replayed')::boolean and result->'link' = 'null'::jsonb from invite_test_results where kind = 'issue_replay'),
  'issue replay returns no clear link'
);

update public.invitations
set expires_at = now() - interval '1 minute'
where id = (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued');

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}', true);
insert into invite_test_results(kind, result)
select 'resent', public.superadmin_invite_resend(
  (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued'),
  '73700000-0000-4000-8000-000000000007', 1
);
insert into invite_test_results(kind, result)
select 'resend_replay', public.superadmin_invite_resend(
  (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued'),
  '73700000-0000-4000-8000-000000000007', 1
);
reset role;
select ok(
  (select invitation.token_hash <> result_record.token_hash and invitation.version = 2
     from public.invitations invitation
     join invite_test_results result_record on invitation.id = (result_record.result->'invite'->>'invite_id')::uuid
    where result_record.kind = 'issued'),
  'expired resend rotates the old token hash and increments the version'
);
select ok(
  (select invitation.send_count = 1 and invitation.last_sent_at is not null
     from public.invitations invitation
     join invite_test_results result_record
       on invitation.id = (result_record.result->'invite'->>'invite_id')::uuid
    where result_record.kind = 'issued'),
  'send count records the first resend attempt and its timestamp'
);
select ok(
  (select (result->>'replayed')::boolean and result->'link' = 'null'::jsonb
    from invite_test_results where kind = 'resend_replay'),
  'resend replay returns the stored receipt without a clear link'
);
select ok(
  (select count(*) = 1 and bool_and(state = 'pending')
    from app_private.superadmin_invite_email_outbox
    where invitation_id = (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued')
      and token_hash_snapshot = (select token_hash from public.invitations
        where id = (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued'))),
  'resend leaves exactly one pending outbox item for the rotated token'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}', true);
select throws_ok(
  format(
    'select public.superadmin_invite_revoke(%L::uuid,%L::uuid,1,%L)',
    (select result->'invite'->>'invite_id' from invite_test_results where kind = 'issued'),
    '73700000-0000-4000-8000-000000000012',
    'Solicitacao administrativa validada.'
  ),
  '40001', 'invitation version conflict', 'stale expected version fails closed'
);
insert into invite_test_results(kind, result)
select 'revoked', public.superadmin_invite_revoke(
  (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued'),
  '73700000-0000-4000-8000-000000000008', 2, 'Solicitação administrativa validada.'
);
select throws_ok(
  format(
    'select public.superadmin_invite_resend(%L::uuid,%L::uuid,3)',
    (select result->'invite'->>'invite_id' from invite_test_results where kind = 'issued'),
    '73700000-0000-4000-8000-000000000009'
  ),
  '22023', 'invitation cannot be resent', 'revoked invite cannot be resent'
);
reset role;
select is(
  (select invitation_state::text from public.invitations where id = (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued')),
  'revoked', 'revoke performs the allowed pending-to-revoked transition'
);
select ok(
  not exists (
    select 1 from app_private.superadmin_invite_email_outbox
    where invitation_id = (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued')
      and state = 'pending'
  ),
  'revocation cancels every pending email delivery for the invite'
);
select ok(
  (select count(*) = 3
      and count(*) filter (where action_code = 'invite.issue') = 1
      and count(*) filter (where action_code = 'invite.resend') = 1
      and count(*) filter (where action_code = 'invite.revoke') = 1
      and bool_and(mfa_aal = 'aal2')
      and bool_and(actor_person_id = '73100000-0000-4000-8000-000000000001')
    from audit.audit_logs
    where object_type = 'invitation'
      and object_id = (select (result->'invite'->>'invite_id')::uuid from invite_test_results where kind = 'issued')),
  'issue, resend and revoke are audited with the recalculated actor and AAL2 evidence'
);

update public.platform_memberships
set status = 'revoked', revoked_at = now()
where person_id = '73100000-0000-4000-8000-000000000001'
  and role_id = (select id from public.platform_roles where code = 'owner');
set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', jsonb_build_object('sub','73000000-0000-4000-8000-000000000001','aal','aal2','role','authenticated')::text, true);
select throws_ok(
  format(
    'select public.superadmin_invite_get(%L::uuid)',
    (select result->'invite'->>'invite_id' from invite_test_results where kind = 'issued')
  ),
  '42501', 'platform.invites.read required', 'revoked capability cannot read an existing invite'
);
select throws_ok(
  $$select public.superadmin_invite_get('73900000-0000-4000-8000-000000000099')$$,
  '42501', 'platform.invites.read required', 'unknown and existing IDs have the same unauthorized response'
);
reset role;

select * from finish();
rollback;
