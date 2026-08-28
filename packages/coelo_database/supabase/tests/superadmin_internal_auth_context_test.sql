begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

select ok(to_regprocedure('public.superadmin_auth_bootstrap_context()') is not null
  and to_regprocedure('public.superadmin_auth_resolve_institution_context(uuid)') is not null
  and to_regprocedure('app_private.require_superadmin_internal_context(text)') is not null,
  'the two public wrappers and private context helper exist');
select ok(to_regclass('app_private.superadmin_internal_identities') is not null
  and to_regclass('app_private.superadmin_internal_auth_links') is not null
  and to_regclass('app_private.superadmin_internal_memberships') is not null,
  'the three private identity tables exist');

create temporary table auth_test_snapshot(value jsonb not null);
create temporary table auth_test_responses(sequence_number integer primary key,body jsonb not null);
grant select on auth_test_snapshot to authenticated;
grant select,insert on auth_test_responses to authenticated;
insert into auth_test_snapshot(value) select jsonb_build_object(
  'identities',(select count(*) from app_private.superadmin_internal_identities),
  'auth_links',(select count(*) from app_private.superadmin_internal_auth_links),
  'memberships',(select count(*) from app_private.superadmin_internal_memberships),
  'audit',(select count(*) from audit.audit_logs));

select set_config('request.jwt.claims','{}',true);
set local role authenticated;
insert into auth_test_responses values
  (1,public.superadmin_auth_bootstrap_context()),
  (2,public.superadmin_auth_bootstrap_context());
reset role;

select is((select count(*) from auth_test_responses),2::bigint,
  'two unauthenticated bootstrap calls return JSON without raising');
select ok(not exists(select 1 from auth_test_responses response
  where (select array_agg(key order by key) from jsonb_object_keys(response.body) key)
      <>array['data','error','ok']::text[]
     or (select array_agg(key order by key) from jsonb_object_keys(response.body->'error') key)
      <>array['code','correlation_id','http_status','message']::text[]),
  'success and error envelopes expose exact allowlisted keys');
select ok(not exists(select 1 from auth_test_responses response
  where (response.body->>'ok')::boolean is not false
    or response.body->'data'<>'null'::jsonb
    or response.body#>>'{error,code}'<>'SAI_AUTH_REQUIRED'
    or (response.body#>>'{error,http_status}')::integer<>401
    or coalesce(response.body#>>'{error,message}','')=''
    or response.body#>>'{error,correlation_id}' !~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
  'both calls return the stable auth-required envelope with semantic 401 metadata');
select ok((select count(distinct body#>>'{error,correlation_id}')=2
  from auth_test_responses),'each failed call receives a distinct correlation id');
select is((select value from auth_test_snapshot),(select jsonb_build_object(
  'identities',(select count(*) from app_private.superadmin_internal_identities),
  'auth_links',(select count(*) from app_private.superadmin_internal_auth_links),
  'memberships',(select count(*) from app_private.superadmin_internal_memberships),
  'audit',(select count(*) from audit.audit_logs))),
  'calls without a validated session create no internal row and no audit event');

select ok(has_function_privilege('authenticated','public.superadmin_auth_bootstrap_context()','execute')
  and has_function_privilege('authenticated','public.superadmin_auth_resolve_institution_context(uuid)','execute')
  and not has_function_privilege('anon','public.superadmin_auth_bootstrap_context()','execute')
  and not has_function_privilege('service_role','public.superadmin_auth_bootstrap_context()','execute')
  and not has_function_privilege('anon','public.superadmin_auth_resolve_institution_context(uuid)','execute')
  and not has_function_privilege('service_role','public.superadmin_auth_resolve_institution_context(uuid)','execute')
  and not exists(select 1 from pg_proc procedure_record,
    lateral aclexplode(coalesce(procedure_record.proacl,acldefault('f',procedure_record.proowner))) acl
    where procedure_record.oid in('public.superadmin_auth_bootstrap_context()'::regprocedure,
      'public.superadmin_auth_resolve_institution_context(uuid)'::regprocedure)
      and acl.grantee=0 and acl.privilege_type='EXECUTE'),
  'only authenticated can execute the public wrappers');
select ok(not has_function_privilege('anon','app_private.require_superadmin_internal_context(text)','execute')
  and not has_function_privilege('authenticated','app_private.require_superadmin_internal_context(text)','execute')
  and not has_function_privilege('service_role','app_private.require_superadmin_internal_context(text)','execute')
  and not exists(select 1 from pg_proc procedure_record,
    lateral aclexplode(coalesce(procedure_record.proacl,acldefault('f',procedure_record.proowner))) acl
    where procedure_record.oid='app_private.require_superadmin_internal_context(text)'::regprocedure
      and acl.grantee=0 and acl.privilege_type='EXECUTE'),
  'the privileged context helper is not executable by client or service roles');
select ok(not exists(select 1 from information_schema.role_table_grants grant_record
  where grant_record.table_schema='app_private'
    and grant_record.table_name in('superadmin_internal_identities',
      'superadmin_internal_auth_links','superadmin_internal_memberships')
    and grant_record.grantee in('PUBLIC','anon','authenticated','service_role')),
  'private identity tables have no direct client or service grants');
select is((select count(*) from pg_class table_record
  join pg_namespace schema_record on schema_record.oid=table_record.relnamespace
  where schema_record.nspname='app_private'
    and table_record.relname in('superadmin_internal_identities',
      'superadmin_internal_auth_links','superadmin_internal_memberships')
    and table_record.relrowsecurity and table_record.relforcerowsecurity),3::bigint,
  'all private identity tables enable and force RLS');
select is((select count(*) from pg_policies policy_record
  where policy_record.schemaname='app_private'
    and policy_record.tablename in('superadmin_internal_identities',
      'superadmin_internal_auth_links','superadmin_internal_memberships')),0::bigint,
  'private identity tables expose no client RLS policies');
select ok(not has_type_privilege('anon','app_private.superadmin_internal_context','usage')
  and not has_type_privilege('authenticated','app_private.superadmin_internal_context','usage')
  and not has_type_privilege('service_role','app_private.superadmin_internal_context','usage'),
  'the private context type has no client or service usage grant');


-- A validated Auth session without a complete internal actor must be denied and audited as v3.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data)
values
  ('10000000-0000-4000-8000-000000000001','authenticated','authenticated',
   'synthetic-auth-v3-1@invalid.test',now(),now(),now(),'{}','{}'),
  ('10000000-0000-4000-8000-000000000002','authenticated','authenticated',
   'synthetic-auth-v3-2@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values
  ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
   now(),now(),'aal1',now()+interval '1 hour'),
  ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002',
   now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id)
values('30000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values('40000000-0000-4000-8000-000000000002',
  '30000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000001',
  'session_id','20000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into auth_test_responses values(3,public.superadmin_auth_bootstrap_context());
reset role;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000002',
  'session_id','20000000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into auth_test_responses values(4,public.superadmin_auth_bootstrap_context());
reset role;

select ok(not exists(select 1 from auth_test_responses where sequence_number in(3,4)
  and ((body->>'ok')::boolean is not false
    or body#>>'{error,code}'<>'SAI_INTERNAL_CONTEXT_DENIED'
    or (body#>>'{error,http_status}')::integer<>403)),
  'validated sessions without a complete internal actor return the stable denied envelope');
select ok((select count(*)=2 and count(distinct correlation_id)=2
  from audit.audit_logs where actor_kind='auth_session'
    and correlation_id in(select (body#>>'{error,correlation_id}')::uuid
      from auth_test_responses where sequence_number in(3,4))
    and hash_version=3 and payload_contract_version=3
    and actor_person_id is null and actor_membership_id is null and support_session_id is null
    and actor_internal_identity_id is null and actor_internal_auth_link_id is null
    and actor_internal_membership_id is null and actor_role_code is null
    and octet_length(session_id_hash)=32 and mfa_aal='aal1'
    and permission_code='platform.read' and action_code='superadmin.auth.bootstrap'
    and outcome='denied' and reason_code='SAI_INTERNAL_CONTEXT_DENIED'
    and institution_id is null and context_kind='global' and context_id is null),
  'each incomplete actor appends exactly one correlated strict global auth_session v3 event');
select ok((select bool_and(app_private.audit_verify_entry(id))
  from audit.audit_logs where actor_kind='auth_session'),
  'auth_session v3 entries participate in the verified append-only chain');
with v3_functions(procedure_oid) as(values
  ('app_private.audit_entry_digest_v3(bigint,bytea,uuid,bytea,text,text,text,uuid,text,text,uuid,text,text,uuid,uuid,public.audit_outcome,smallint,jsonb,jsonb,timestamptz)'::regprocedure),
  ('app_private.audit_append_auth_session_denial(uuid,text,text,text,text,uuid)'::regprocedure),
  ('app_private.audit_entry_matches_digest(audit.audit_logs)'::regprocedure),
  ('app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'::regprocedure)
),client_roles(role_name) as(values('anon'),('authenticated'),('service_role'))
select ok(not exists(select 1 from v3_functions cross join client_roles
    where has_function_privilege(role_name,procedure_oid,'execute'))
  and not exists(select 1 from v3_functions
    join pg_proc procedure_record on procedure_record.oid=procedure_oid
    cross join lateral aclexplode(coalesce(procedure_record.proacl,
      acldefault('f',procedure_record.proowner))) acl
    where acl.grantee=0 and acl.privilege_type='EXECUTE'),
  'all v3 digest, matcher and append helpers deny PUBLIC and every client or service role');
select throws_ok($$insert into audit.audit_logs(
  id,hash_version,actor_kind,session_id_hash,permission_code,mfa_aal,action_code,outcome,
  reason_code,correlation_id,origin,context_kind,occurred_at)
values(gen_random_uuid(),3,'auth_session',decode(repeat('00',32),'hex'),'platform.read',null,
  'test.auth.v3','denied','SAI_PERMISSION_DENIED',gen_random_uuid(),'database','global',now())$$,
  '23514',null,'auth_session v3 rejects a missing MFA assurance level');

with expected(schema_name,function_name) as(values
  ('app_private','guard_superadmin_internal_auth_realm'),
  ('app_private','guard_person_auth_link_internal_realm'),
  ('app_private','guard_superadmin_internal_auth_link_lifecycle'),
  ('app_private','guard_superadmin_internal_membership_lifecycle'),
  ('app_private','guard_superadmin_internal_membership_scope'),
  ('app_private','guard_superadmin_internal_last_owner'),
  ('app_private','guard_superadmin_internal_owner_auth_link'),
  ('app_private','guard_superadmin_internal_owner_role'),
  ('app_private','audit_guard_append_only'),
  ('app_private','audit_verify_entry'),
  ('app_private','audit_append_superadmin_internal'),
  ('app_private','audit_append_auth_session_denial'),
  ('app_private','audit_superadmin_internal_denial_if_identified'),
  ('app_private','audit_get_event_for_superadmin'),
  ('app_private','audit_list_events_for_superadmin'),
  ('app_private','audit_materialize_export_for_worker'),
  ('app_private','require_superadmin_internal_context'),
  ('public','superadmin_auth_bootstrap_context'),
  ('public','superadmin_auth_resolve_institution_context')
)
select ok(not exists(select 1 from expected
  left join pg_namespace namespace_record on namespace_record.nspname=expected.schema_name
  left join pg_proc procedure_record on procedure_record.pronamespace=namespace_record.oid
    and procedure_record.proname=expected.function_name
  left join pg_roles owner_role on owner_role.oid=procedure_record.proowner
  where procedure_record.oid is null or owner_role.rolname<>'postgres'
    or not procedure_record.prosecdef
    or not (coalesce(procedure_record.proconfig,'{}'::text[]) @> array['search_path=""']::text[])),
  'all Auth security definers are postgres-owned with an empty search_path');

-- Invalid or expired sessions stay unaudited because the session itself was not validated.
create temporary table auth_invalid_audit_snapshot(value bigint not null);
insert into auth_invalid_audit_snapshot select count(*) from audit.audit_logs;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('20000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()-interval '1 minute');
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000001',
  'session_id','20000000-0000-4000-8000-000000000099',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into auth_test_responses values(5,public.superadmin_auth_bootstrap_context());
reset role;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000001',
  'session_id','20000000-0000-4000-8000-000000000003',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into auth_test_responses values(6,public.superadmin_auth_bootstrap_context());
reset role;
select ok(not exists(select 1 from auth_test_responses where sequence_number in(5,6)
  and body#>>'{error,code}'<>'SAI_SESSION_INVALID'),
  'missing and expired sessions return the stable session-invalid envelope');
select is((select count(*) from audit.audit_logs),
  (select value from auth_invalid_audit_snapshot),
  'missing and expired sessions create no audit event');

-- Once the session is valid, an append failure must abort instead of returning an unaudited denial.
create function pg_temp.reject_auth_session_audit() returns trigger
language plpgsql as $$begin
  if new.actor_kind='auth_session' then
    raise exception using errcode='P0001',message='forced auth session audit failure';
  end if;
  return new;
end$$;
create trigger auth_session_audit_forced_failure
before insert on audit.audit_logs for each row execute function pg_temp.reject_auth_session_audit();
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000001',
  'session_id','20000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok('select public.superadmin_auth_bootstrap_context()',
  'P0001','forced auth session audit failure',
  'a validated session cannot return a denial when the mandatory audit append fails');
reset role;
drop trigger auth_session_audit_forced_failure on audit.audit_logs;

-- The v3 physical shape rejects malformed hashes and attempted actor attribution.
select throws_ok($$insert into audit.audit_logs(
  id,hash_version,actor_kind,session_id_hash,permission_code,mfa_aal,action_code,outcome,
  reason_code,correlation_id,origin,context_kind,occurred_at)
values(gen_random_uuid(),3,'auth_session',decode(repeat('00',31),'hex'),'platform.read','aal1',
  'test.auth.v3','denied','SAI_PERMISSION_DENIED',gen_random_uuid(),'database','global',now())$$,
  '23514',null,'auth_session v3 rejects a session hash that is not 32 bytes');
select throws_ok($$insert into audit.audit_logs(
  id,hash_version,actor_kind,session_id_hash,permission_code,mfa_aal,actor_role_code,
  action_code,outcome,reason_code,correlation_id,origin,context_kind,occurred_at)
values(gen_random_uuid(),3,'auth_session',decode(repeat('00',32),'hex'),'platform.read','aal1',
  'forged','test.auth.v3','denied','SAI_PERMISSION_DENIED',gen_random_uuid(),
  'database','global',now())$$,'22023','auth session audit cannot carry actor identifiers',
  'auth_session v3 rejects every attempted role or actor attribution');

-- Build explicit v1 and v2 entries so the dispatcher proves a mixed v1/v2/v3 chain.
insert into audit.audit_logs(id,action_code,outcome,correlation_id,origin,context_kind,occurred_at)
values('50000000-0000-4000-8000-000000000001','test.auth.audit.v1','success',
  '51000000-0000-4000-8000-000000000001','database','global',now());
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data)
values('10000000-0000-4000-8000-000000000003','authenticated','authenticated',
  'synthetic-auth-v2@invalid.test',now(),now(),now(),'{}','{}');
insert into app_private.superadmin_internal_identities(id)
values('30000000-0000-4000-8000-000000000003');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values('40000000-0000-4000-8000-000000000003',
  '30000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind)
select '41000000-0000-4000-8000-000000000003',
  '30000000-0000-4000-8000-000000000003',id,'platform'
from public.platform_roles where code='owner';
create temporary table auth_v2_event(id uuid primary key);
insert into auth_v2_event select app_private.audit_append_superadmin_internal(
  '30000000-0000-4000-8000-000000000003',
  '40000000-0000-4000-8000-000000000003',
  '41000000-0000-4000-8000-000000000003',
  '20000000-0000-4000-8000-000000000004','platform.read','aal2',
  'test.auth.audit.v2','success',null,'51000000-0000-4000-8000-000000000002');
with target_events as(
  select id from audit.audit_logs where id='50000000-0000-4000-8000-000000000001'
  union all select id from auth_v2_event
  union all select id from audit.audit_logs where correlation_id in(
    select (body#>>'{error,correlation_id}')::uuid
    from auth_test_responses where sequence_number in(3,4))
)
select ok((select array_agg(distinct log_record.hash_version order by log_record.hash_version)
      =array[1,2,3]::smallint[]
    and bool_and(app_private.audit_verify_entry(log_record.id))
  from audit.audit_logs log_record join target_events on target_events.id=log_record.id),
  'mixed v1, v2 and v3 entries all verify through the versioned digest dispatcher');

-- Reuse the approved legacy audit reader authority only to exercise reader compatibility.
insert into auth.users(id,aud,role,email,created_at,updated_at)
values('10000000-0000-4000-8000-000000000004','authenticated','authenticated',
  'synthetic-audit-reader@invalid.test',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status)
values('52000000-0000-4000-8000-000000000004','adult','Synthetic','Reader',
  'Synthetic Audit Reader','active');
insert into public.person_auth_links(person_id,auth_user_id,status)
values('52000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '52000000-0000-4000-8000-000000000004',id,'active','platform',true
from public.platform_roles where code='owner';
create temporary table auth_v3_target(id uuid primary key,hash_hex text not null);
insert into auth_v3_target
select id,encode(session_id_hash,'hex') from audit.audit_logs
where correlation_id=(select (body#>>'{error,correlation_id}')::uuid
  from auth_test_responses where sequence_number=3);
grant select on auth_v3_target to authenticated,service_role;
create temporary table auth_reader_results(
  detail jsonb,list_result jsonb,hash_search jsonb,export_start jsonb,materialized jsonb);
grant select,insert,update on auth_reader_results to authenticated,service_role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into auth_reader_results(detail,list_result,hash_search,export_start)
select public.audit_get_event_for_superadmin(target.id),
  public.audit_list_events_for_superadmin(p_search=>'Sessão autenticada'),
  public.audit_list_events_for_superadmin(p_search=>target.hash_hex),
  public.audit_start_export_for_superadmin('csv','{}'::jsonb,
    '53000000-0000-4000-8000-000000000001')
from auth_v3_target target;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
update auth_reader_results set materialized=public.audit_materialize_export_for_worker(
  (export_start->>'job_id')::uuid,'54000000-0000-4000-8000-000000000001');
reset role;
select ok((select detail#>>'{actor,kind}'='auth_session'
    and detail#>>'{actor,display_name}'='Sessão autenticada'
    and detail#>'{actor,id}'='null'::jsonb and detail#>'{actor,role_code}'='null'::jsonb
    and position(target.hash_hex in detail::text)=0
  from auth_reader_results cross join auth_v3_target target),
  'audit detail renders a minimized auth_session actor and never exposes its hash');
select ok((select (list_result->>'total_count')::integer>=2
    and not exists(select 1 from jsonb_array_elements(list_result->'items') item
      where item#>>'{actor,kind}'<>'auth_session'
        or item#>>'{actor,display_name}'<>'Sessão autenticada'
        or item#>'{actor,id}'<>'null'::jsonb or item#>'{actor,role_code}'<>'null'::jsonb)
    and position(target.hash_hex in list_result::text)=0
  from auth_reader_results cross join auth_v3_target target),
  'audit list renders auth_session items with null identity and role and no hash');
select is((select (hash_search->>'total_count')::integer from auth_reader_results),0,
  'audit search cannot discover an auth_session event from its session hash');
select ok((select snapshot.row_payload->>'actor_kind'='auth_session'
    and snapshot.row_payload->>'actor_name'='Sessão autenticada'
    and snapshot.row_payload->'actor_id'='null'::jsonb
    and snapshot.row_payload->'actor_role_code'='null'::jsonb
    and position(target.hash_hex in snapshot.row_payload::text)=0
  from auth_reader_results result
  join public.import_jobs job on job.id=(result.export_start->>'job_id')::uuid
  join app_private.audit_export_snapshot_rows snapshot on snapshot.export_job_id=job.id
  join auth_v3_target target on target.id=snapshot.audit_log_id),
  'audit export renders auth_session without identity, role or session hash');
select * from finish();
rollback;
