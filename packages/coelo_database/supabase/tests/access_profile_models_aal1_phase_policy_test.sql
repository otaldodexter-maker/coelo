-- R01 C01 I005. Disposable coordinated replay only; never run in production.
-- Base: ModelReadAuthorizationGreen + the reserved AAL1 phase policy candidate.
-- Without the candidate, AAL1 success assertions are expected RED, not certified.
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

select is(pg_get_function_arguments(
  'app_private.access_profile_require_model_action(text,text,boolean)'::regprocedure),
  'p_domain text, p_action text, p_require_mfa boolean DEFAULT true',
  'compatible helper signature and default remain unchanged');
select ok((select proowner='postgres'::regrole and prosecdef and provolatile='s'
    and proconfig=array['search_path=""']::text[]
    from pg_proc where oid=
      'app_private.access_profile_require_model_action(text,text,boolean)'::regprocedure)
  and not exists(select 1 from (values('anon'),('authenticated'),('service_role')) r(name)
    where has_function_privilege(r.name,
      'app_private.access_profile_require_model_action(text,text,boolean)','EXECUTE')),
  'helper keeps stable definer metadata and has no client execution grant');
select is((select count(*) from public.platform_permissions
  where code in('platform.role_models.create','platform.role_models.update')
    and requires_mfa and status='active'),2::bigint,
  'MFA metadata is preserved for the formal gate');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('ca110000-0000-4000-8000-000000000001','authenticated','authenticated',
    'c01-model-aal1-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('ca110000-0000-4000-8000-000000000002','authenticated','authenticated',
    'c01-model-aal1-global@invalid.test',now(),now(),now(),'{}','{}'),
  ('ca110000-0000-4000-8000-000000000003','authenticated','authenticated',
    'c01-model-aal1-auditor@invalid.test',now(),now(),now(),'{}','{}'),
  ('ca110000-0000-4000-8000-000000000004','authenticated','authenticated',
    'c01-model-aal1-reserve@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('ca120000-0000-4000-8000-000000000001','ca110000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('ca120000-0000-4000-8000-000000000002','ca110000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('ca120000-0000-4000-8000-000000000003','ca110000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('ca130000-0000-4000-8000-000000000001'),
  ('ca130000-0000-4000-8000-000000000003'),
  ('ca130000-0000-4000-8000-000000000004');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('ca140000-0000-4000-8000-000000000001','ca130000-0000-4000-8000-000000000001','ca110000-0000-4000-8000-000000000001'),
  ('ca140000-0000-4000-8000-000000000003','ca130000-0000-4000-8000-000000000003','ca110000-0000-4000-8000-000000000003'),
  ('ca140000-0000-4000-8000-000000000004','ca130000-0000-4000-8000-000000000004','ca110000-0000-4000-8000-000000000004');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind)
select 'ca150000-0000-4000-8000-000000000001',
  'ca130000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';
-- A second local Owner keeps lifecycle fixtures legal without disabling guards.
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind)
select 'ca150000-0000-4000-8000-000000000004',
  'ca130000-0000-4000-8000-000000000004',id,'platform'
from public.platform_roles where code='owner';
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind)
select 'ca150000-0000-4000-8000-000000000003',
  'ca130000-0000-4000-8000-000000000003',id,'platform'
from public.platform_roles where code='auditor';
-- Deliberately allow the capability to isolate the independent Owner rule.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active'
from public.platform_roles r,public.platform_permissions p
where r.code='auditor' and p.code='platform.role_models.create'
on conflict(role_id,permission_id) do update
set effect='allow',status='active',revoked_at=null;

-- Independent source fixtures keep duplicate/update diagnostics meaningful
-- even when create is denied by the old secondary AAL2 gate.
insert into public.access_profile_templates(id,domain,code,name,max_scope_kind,is_system,status) values
  ('ca160000-0000-4000-8000-000000000001','platform','c01_aal1_source','C01 source','platform',false,'active'),
  ('ca160000-0000-4000-8000-000000000002','institution','c01_aal1_institution','C01 institution source','institution',false,'active');
insert into public.access_profile_template_platform_permissions(template_id,permission_id,effect)
select 'ca160000-0000-4000-8000-000000000001',id,'allow'
from public.platform_permissions where code='platform.read';

create temporary table c01_aal1_results(key text primary key,result jsonb not null);
grant select,insert on c01_aal1_results to authenticated;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','ca110000-0000-4000-8000-000000000001',
  'session_id','ca120000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.c01_aal1_rpc_actor',current_user,true);
insert into c01_aal1_results values('create',public.superadmin_access_profile_model_create(
  'ca170000-0000-4000-8000-000000000001',
  '{"domain":"platform","name":"C01 AAL1 created","max_scope_kind":"platform","capabilities":[{"code":"platform.read","effect":"allow"}],"reason":"C01 policy regression"}'));
insert into c01_aal1_results values('update',public.superadmin_access_profile_model_update(
  'ca170000-0000-4000-8000-000000000002',
  '{"id":"ca160000-0000-4000-8000-000000000001","name":"C01 source edited","expected_version":1,"capabilities":[{"code":"platform.read","effect":"allow"}],"reason":"C01 policy regression"}'));
insert into c01_aal1_results values('duplicate',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000003',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","name":"C01 AAL1 copy","reason":"C01 policy regression"}'));
insert into c01_aal1_results values('replay',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000003',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","name":"C01 AAL1 copy","reason":"C01 policy regression"}'));
insert into c01_aal1_results values('reused',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000003',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","name":"Different draft","reason":"C01 policy regression"}'));
insert into c01_aal1_results values('unknown',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000004',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000099","reason":"C01 policy regression"}'));
insert into c01_aal1_results values('reload',public.superadmin_access_profile_model_detail(
  (select (result#>>'{data,model_id}')::uuid from c01_aal1_results where key='duplicate')));
reset role;

select is(current_setting('test.c01_aal1_rpc_actor'),'authenticated','commands run as authenticated');
select is((select result->>'ok' from c01_aal1_results where key='create'),'true','Owner AAL1 creates without People');
select is((select result#>>'{data,model,name}' from c01_aal1_results where key='update'),
  'C01 source edited','Owner AAL1 edits an existing model');
select is((select result->>'ok' from c01_aal1_results where key='duplicate'),'true','Owner AAL1 duplicates');
select ok((select (result#>>'{data,model_id}')::uuid <> 'ca160000-0000-4000-8000-000000000001'::uuid
  from c01_aal1_results where key='duplicate'),'copy has a distinct identity');
select is((select result#>>'{data,model,status}' from c01_aal1_results where key='duplicate'),
  'inactive','copy starts inactive');
select is((select result#>'{data,model,capabilities}' from c01_aal1_results where key='duplicate'),
  '[{"code":"platform.read","effect":"allow"}]'::jsonb,'copy preserves source capabilities');
select ok(not exists(select 1 from public.platform_roles where source_template_id=
    (select (result#>>'{data,model_id}')::uuid from c01_aal1_results where key='duplicate'))
  and not exists(select 1 from public.institution_roles where source_template_id=
    (select (result#>>'{data,model_id}')::uuid from c01_aal1_results where key='duplicate'))
  and not exists(select 1 from public.guardian_context_permissions where source_template_id=
    (select (result#>>'{data,model_id}')::uuid from c01_aal1_results where key='duplicate')),
  'duplication creates no concrete profile or assignment');
select is((select result#>>'{data,model_id}' from c01_aal1_results where key='replay'),
  (select result#>>'{data,model_id}' from c01_aal1_results where key='duplicate'),
  'identical request reuses the original copy');
select is((select result#>>'{data,replayed}' from c01_aal1_results where key='replay'),'true','replay is explicit');
select is((select result#>>'{error,code}' from c01_aal1_results where key='reused'),
  'SAI_INVALID_ARGUMENT','changed draft cannot reuse the idempotency key');
select is((select result#>>'{error,code}' from c01_aal1_results where key='unknown'),
  'SAI_PERMISSION_DENIED','unknown source ID receives a sanitized denial');
select is((select count(*) from app_private.access_profile_model_command_receipts
  where actor_internal_identity_id='ca130000-0000-4000-8000-000000000001'),3::bigint,
  'create edit and duplicate each persist one receipt');
select is((select count(*) from audit.audit_logs
  where actor_internal_identity_id='ca130000-0000-4000-8000-000000000001'
    and permission_code in('platform.role_models.create','platform.role_models.update')
    and outcome='success'),3::bigint,'replay appends no duplicate successful command audit');
select is((select result#>>'{data,id}' from c01_aal1_results where key='reload'),
  (select result#>>'{data,model_id}' from c01_aal1_results where key='duplicate'),
  'a new authorized read reloads the persisted copy');

-- Domain denial does not become authorization merely because AAL1 is accepted.
update public.platform_role_permissions g set effect='deny'
from public.platform_roles r,public.platform_permissions p
where g.role_id=r.id and g.permission_id=p.id
  and r.code='owner' and p.code='institution.role_models.create';
set local role authenticated;
insert into c01_aal1_results values('domain-denied',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000005',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000002","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='domain-denied'),
  'SAI_PERMISSION_DENIED','a source in a denied domain cannot be duplicated');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','ca110000-0000-4000-8000-000000000003',
  'session_id','ca120000-0000-4000-8000-000000000003',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into c01_aal1_results values('non-owner',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000006',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='non-owner'),
  'SAI_PERMISSION_DENIED','a non-Owner with the capability still cannot duplicate');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','ca110000-0000-4000-8000-000000000002',
  'session_id','ca120000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into c01_aal1_results values('global',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000007',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='global'),
  'SAI_INTERNAL_CONTEXT_DENIED','an Auth account without internal identity is denied');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','ca110000-0000-4000-8000-000000000001',
  'session_id','ca120000-0000-4000-8000-000000000099',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into c01_aal1_results values('invalid-session',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000008',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='invalid-session'),
  'SAI_SESSION_INVALID','a forged session ID cannot authorize a command');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','ca110000-0000-4000-8000-000000000001',
  'session_id','ca120000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
update auth.sessions set not_after=now()-interval '1 second'
where id='ca120000-0000-4000-8000-000000000001';
set local role authenticated;
insert into c01_aal1_results values('expired-session',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000003',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","name":"C01 AAL1 copy","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='expired-session'),
  'SAI_SESSION_INVALID','receipt replay reauthorizes an expired session');
update auth.sessions set not_after=now()+interval '1 hour'
where id='ca120000-0000-4000-8000-000000000001';

update public.platform_role_permissions g set effect='deny'
from public.platform_roles r,public.platform_permissions p
where g.role_id=r.id and g.permission_id=p.id
  and r.code='owner' and p.code='platform.role_models.create';
set local role authenticated;
insert into c01_aal1_results values('revoked-capability',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000003',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","name":"C01 AAL1 copy","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='revoked-capability'),
  'SAI_PERMISSION_DENIED','receipt replay reauthorizes the current capability');
update public.platform_role_permissions g set effect='allow'
from public.platform_roles r,public.platform_permissions p
where g.role_id=r.id and g.permission_id=p.id
  and r.code='owner' and p.code='platform.role_models.create';

update app_private.superadmin_internal_memberships set status='suspended',suspended_at=now(),version=version+1
where id='ca150000-0000-4000-8000-000000000001';
set local role authenticated;
insert into c01_aal1_results values('suspended',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000003',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","name":"C01 AAL1 copy","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='suspended'),
  'SAI_MEMBERSHIP_SUSPENDED','receipt replay reauthorizes a suspended membership');
update app_private.superadmin_internal_memberships set status='active',suspended_at=null,version=version+1
where id='ca150000-0000-4000-8000-000000000001';
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=version+1
where id='ca150000-0000-4000-8000-000000000001';
set local role authenticated;
insert into c01_aal1_results values('revoked',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000003',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","name":"C01 AAL1 copy","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='revoked'),
  'SAI_MEMBERSHIP_REVOKED','receipt replay reauthorizes a revoked membership');
update app_private.superadmin_internal_auth_links set status='revoked',revoked_at=now(),version=version+1
where id='ca140000-0000-4000-8000-000000000001';
set local role authenticated;
insert into c01_aal1_results values('revoked-link',public.superadmin_access_profile_model_duplicate(
  'ca170000-0000-4000-8000-000000000003',
  '{"source_model_id":"ca160000-0000-4000-8000-000000000001","name":"C01 AAL1 copy","reason":"C01 policy regression"}'));
reset role;
select is((select result#>>'{error,code}' from c01_aal1_results where key='revoked-link'),
  'SAI_INTERNAL_CONTEXT_DENIED','receipt replay reauthorizes a revoked auth-link');
select is((select count(*) from app_private.access_profile_model_command_receipts
  where actor_internal_identity_id='ca130000-0000-4000-8000-000000000001'),3::bigint,
  'denials append no command receipt');
select is((select count(*) from public.access_profile_templates
  where created_by_internal_identity_id='ca130000-0000-4000-8000-000000000001'),2::bigint,
  'only the original create and single copy were persisted');
select ok(exists(select 1 from audit.audit_logs
  where actor_internal_identity_id='ca130000-0000-4000-8000-000000000001'
    and outcome<>'success' and permission_code like '%.role_models.%'),
  'identified denials are audited');
select throws_ok(
  $$update app_private.superadmin_internal_memberships
    set status='revoked',revoked_at=now(),version=version+1
    where id='ca150000-0000-4000-8000-000000000004'$$,
  '55000','last active platform owner is protected',
  'the final active Owner remains protected after the phase-policy change');

select * from finish();
rollback;
