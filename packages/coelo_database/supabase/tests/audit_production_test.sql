begin;

create extension if not exists pgtap with schema extensions;

select plan(78);

select has_column('audit', 'audit_logs', 'correlation_id');
select has_column('audit', 'audit_logs', 'origin');
select has_column('audit', 'audit_logs', 'context_kind');
select has_column('audit', 'audit_logs', 'context_id');
select has_column('audit', 'audit_logs', 'chain_position');
select has_column('audit', 'audit_logs', 'previous_hash');
select has_column('audit', 'audit_logs', 'entry_hash');
select has_column('audit', 'audit_logs', 'payload_contract_version');
select col_not_null('audit', 'audit_logs', 'payload_contract_version');

select has_function('public', 'audit_list_events_for_superadmin',
  array['text','uuid[]','text[]','text[]','text[]','text[]','text[]','uuid','timestamp with time zone','timestamp with time zone','timestamp with time zone','uuid','integer']);
select has_function('public', 'audit_get_event_for_superadmin', array['uuid']);
select has_function('public', 'audit_start_export_for_superadmin', array['text','jsonb','uuid']);
select has_function('public', 'audit_get_export_job_for_superadmin', array['uuid']);
select has_function('public', 'audit_authorize_export_download_for_superadmin', array['uuid']);
select has_function('public', 'audit_materialize_export_for_worker', array['uuid','uuid']);
select has_function('public', 'audit_export_page_for_worker', array['uuid','uuid','bigint','integer']);
select has_function('public', 'audit_complete_export_for_worker', array['uuid','uuid','text','text','text','bigint','text','integer']);
select has_function('public', 'audit_fail_export_for_worker', array['uuid','uuid','text']);
select has_function('public', 'audit_expired_artifacts_for_worker', array['integer']);
select has_function('public', 'audit_expire_export_for_worker', array['uuid','text']);

select ok(
  not has_schema_privilege('anon', 'audit', 'USAGE')
  and not has_schema_privilege('authenticated', 'audit', 'USAGE'),
  'audit schema is not exposed to Data API roles'
);
select ok(
  not has_table_privilege('anon', 'audit.audit_logs', 'SELECT,INSERT,UPDATE,DELETE')
  and not has_table_privilege('authenticated', 'audit.audit_logs', 'SELECT,INSERT,UPDATE,DELETE'),
  'browser roles have no direct audit table access'
);
select ok(
  (select relrowsecurity and relforcerowsecurity from pg_class where oid='audit.audit_logs'::regclass),
  'audit log has forced RLS as defense in depth'
);
select ok(
  not exists(select 1 from pg_policies where schemaname='audit' and tablename='audit_logs'),
  'audit log has no direct client read policy'
);
select ok(
  not has_function_privilege('anon', 'public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)', 'EXECUTE'),
  'only authenticated clients can call the list gateway'
);
select ok(
  not has_function_privilege('anon', 'public.audit_start_export_for_superadmin(text,jsonb,uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.audit_start_export_for_superadmin(text,jsonb,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.audit_authorize_export_download_for_superadmin(uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.audit_authorize_export_download_for_superadmin(uuid)', 'EXECUTE'),
  'only authenticated clients can request exports'
);
select ok(
  has_function_privilege('service_role','public.audit_materialize_export_for_worker(uuid,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','public.audit_materialize_export_for_worker(uuid,uuid)','EXECUTE')
  and has_function_privilege('service_role','public.audit_complete_export_for_worker(uuid,uuid,text,text,text,bigint,text,integer)','EXECUTE')
  and not has_function_privilege('authenticated','public.audit_complete_export_for_worker(uuid,uuid,text,text,text,bigint,text,integer)','EXECUTE'),
  'worker gateways are service-role only'
);
select ok(
  (select bool_and(prosecdef) and bool_and(proconfig @> array['search_path=""'])
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in (
     'audit_list_events_for_superadmin','audit_get_event_for_superadmin','audit_start_export_for_superadmin')),
  'audit gateways are security definer with empty search path'
);
select ok(
  exists(select 1 from public.platform_permissions where code='audit.read' and status='active')
  and exists(select 1 from public.platform_permissions where code='audit.export' and requires_mfa and status='active'),
  'read and MFA-protected export capabilities are separate'
);
select ok(
  exists(select 1 from pg_indexes where schemaname='audit' and indexname='audit_logs_cursor_idx')
  and exists(select 1 from pg_indexes where schemaname='audit' and indexname='audit_logs_correlation_idx')
  and exists(select 1 from pg_indexes where schemaname='audit' and indexname='audit_logs_context_cursor_idx'),
  'cursor, correlation and scoped filters are indexed'
);
select ok(
  exists(select 1 from storage.buckets where id='coelo-operations' and public=false),
  'audit export artifact bucket is private'
);
select ok(
  pg_get_functiondef('app_private.audit_start_export_for_superadmin(text,jsonb,uuid)'::regprocedure)
    like '%actor::text||'':audit_export''%'
  and pg_get_functiondef('app_private.audit_start_export_for_superadmin(text,jsonb,uuid)'::regprocedure)
    like '%interval ''1 hour''%'
  and pg_get_functiondef('app_private.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)'::regprocedure)
    like '%has_mfa_aal2%',
  'export quota is actor-serialized and can_export includes AAL2'
);
select ok(
  (select column_default is null from information_schema.columns
    where table_schema='audit' and table_name='audit_logs' and column_name='chain_position')
  and position('pg_advisory_xact_lock' in pg_get_functiondef('app_private.audit_guard_append_only()'::regprocedure))
      < position('nextval' in pg_get_functiondef('app_private.audit_guard_append_only()'::regprocedure)),
  'chain position is allocated only after acquiring the chain lock'
);
select ok(
  exists(select 1 from pg_indexes where schemaname='audit' and indexname='audit_logs_institution_cursor_idx')
  and exists(select 1 from pg_indexes where schemaname='audit' and indexname='audit_logs_actor_cursor_idx'),
  'institution and actor cursor access paths are indexed'
);

insert into audit.audit_logs(action_code, object_type, object_id, before_json, after_json)
values ('audit_test.legacy', 'test', '81000000-0000-4000-8000-000000000001',
  '{"cpf":"12345678900","status":"draft"}', '{"token":"secret","status":"active"}');

select ok(
  (select correlation_id is not null and origin='database' and context_kind='global'
     and chain_position is not null and entry_hash is not null
     and payload_contract_version=1 and before_json='{"status":"draft"}'::jsonb
     and after_json='{"status":"active"}'::jsonb
   from audit.audit_logs where object_id='81000000-0000-4000-8000-000000000001'),
  'all inserts are minimized at rest and receive trustworthy integrity metadata'
);
insert into audit.audit_logs(id,action_code,chain_position) values
 ('81000000-0000-4000-8000-000000000010','audit_test.chain_one',-100),
 ('81000000-0000-4000-8000-000000000011','audit_test.chain_two',-101);
select ok(
  (select first.chain_position>0 and second.chain_position>first.chain_position
      and second.previous_hash=first.entry_hash
    from audit.audit_logs first cross join audit.audit_logs second
    where first.id='81000000-0000-4000-8000-000000000010'
      and second.id='81000000-0000-4000-8000-000000000011'),
  'caller-supplied positions are ignored and the hash chain remains monotonic'
);
select throws_ok(
  $$update audit.audit_logs set reason='tampered' where object_id='81000000-0000-4000-8000-000000000001'$$,
  '55000', 'audit logs are append-only', 'updates fail closed'
);
select throws_ok(
  $$delete from audit.audit_logs where object_id='81000000-0000-4000-8000-000000000001'$$,
  '55000', 'audit logs are append-only', 'deletes fail closed'
);
select throws_ok(
  $$insert into audit.audit_logs(action_code,origin,context_kind,context_id)
    values ('audit_test.invalid_origin','browser','global',null)$$,
  '22023', 'invalid audit origin or context', 'untrusted origins are rejected'
);
select throws_ok(
  $$insert into audit.audit_logs(action_code,origin,context_kind,context_id,institution_id)
    values ('audit_test.invalid_context','database','institution',gen_random_uuid(),gen_random_uuid())$$,
  '22023', 'invalid audit origin or context', 'cross-scope context is rejected'
);
insert into audit.audit_logs(id,action_code,payload_contract_version,reason,after_json)
values ('81000000-0000-4000-8000-000000000012','unknown.action',null,
  'Child full name +55 11 99999-9999',
  '{"name":"Child full name","token":"secret","role_code":["secret"],"status":"active"}');
select ok(
  (select payload_contract_version=1 and reason='[redacted]'
      and after_json='{"status":"active"}'::jsonb
    from audit.audit_logs where id='81000000-0000-4000-8000-000000000012'),
  'caller cannot bypass conservative reason and payload minimization'
);
select ok(
  (select previous_hash=(select entry_hash from audit.audit_logs prior
      where prior.chain_position<current_record.chain_position
      order by prior.chain_position desc limit 1)
    from audit.audit_logs current_record where current_record.id='81000000-0000-4000-8000-000000000012'),
  'new entry links to the immediate predecessor'
);

insert into auth.users(id,aud,role,email,created_at,updated_at) values
 ('81100000-0000-4000-8000-000000000001','authenticated','authenticated','audit-owner@test.invalid',now(),now()),
 ('81100000-0000-4000-8000-000000000002','authenticated','authenticated','audit-denied@test.invalid',now(),now()),
 ('81100000-0000-4000-8000-000000000003','authenticated','authenticated','audit-scoped@test.invalid',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('81200000-0000-4000-8000-000000000001','adult','Audit','Owner','Audit Owner','active'),
 ('81200000-0000-4000-8000-000000000002','adult','Audit','Denied','Audit Denied','active'),
 ('81200000-0000-4000-8000-000000000003','adult','Audit','Scoped','Audit Scoped','active'),
 ('81200000-0000-4000-8000-000000000004','child','Audit','Child','Audit Child','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('81200000-0000-4000-8000-000000000001','81100000-0000-4000-8000-000000000001','active'),
 ('81200000-0000-4000-8000-000000000002','81100000-0000-4000-8000-000000000002','active'),
 ('81200000-0000-4000-8000-000000000003','81100000-0000-4000-8000-000000000003','active');
insert into public.platform_roles(id,code,name,status,is_system) values
 ('81300000-0000-4000-8000-000000000001','audit_test_denied','Audit denied','active',true),
 ('81300000-0000-4000-8000-000000000002','audit_test_scoped','Audit scoped','active',true),
 ('81300000-0000-4000-8000-000000000003','audit_test_scope_deny','Audit scope deny','active',true);
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '81200000-0000-4000-8000-000000000001',id,'active','platform',true
from public.platform_roles where code='owner';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required) values
 ('81200000-0000-4000-8000-000000000002','81300000-0000-4000-8000-000000000001','active','platform',false);

insert into public.institutions(id,public_name,legal_name,slug,status) values
 ('81500000-0000-4000-8000-000000000001','Audit Institution A','Audit Institution A','audit-institution-a','active'),
 ('81500000-0000-4000-8000-000000000002','Audit Institution B','Audit Institution B','audit-institution-b','active');
insert into public.units(id,institution_id,name,slug,status) values
 ('81600000-0000-4000-8000-000000000001','81500000-0000-4000-8000-000000000001','Audit Unit A','audit-unit-a','active'),
 ('81600000-0000-4000-8000-000000000002','81500000-0000-4000-8000-000000000002','Audit Unit B','audit-unit-b','active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('81700000-0000-4000-8000-000000000001','81500000-0000-4000-8000-000000000001','81600000-0000-4000-8000-000000000001','Audit Group A','active'),
 ('81700000-0000-4000-8000-000000000002','81500000-0000-4000-8000-000000000002','81600000-0000-4000-8000-000000000002','Audit Group B','active');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('81800000-0000-4000-8000-000000000001','81200000-0000-4000-8000-000000000004','81500000-0000-4000-8000-000000000001','active'),
 ('81800000-0000-4000-8000-000000000002','81200000-0000-4000-8000-000000000004','81500000-0000-4000-8000-000000000002','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required) values
 ('81200000-0000-4000-8000-000000000003','81300000-0000-4000-8000-000000000002','active','institution','81500000-0000-4000-8000-000000000001',true),
 ('81200000-0000-4000-8000-000000000001','81300000-0000-4000-8000-000000000003','active','institution','81500000-0000-4000-8000-000000000002',true);
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select '81300000-0000-4000-8000-000000000002',id,'allow','active'
from public.platform_permissions where code in('audit.read','audit.export');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select '81300000-0000-4000-8000-000000000003',id,'deny','active'
from public.platform_permissions where code in('audit.read','audit.export');

insert into audit.audit_logs(id,action_code,object_type,object_id,institution_id,context_kind,context_id,occurred_at) values
 ('81900000-0000-4000-8000-000000000001','audit_test.institution_a','test','81910000-0000-4000-8000-000000000001','81500000-0000-4000-8000-000000000001','institution','81500000-0000-4000-8000-000000000001','2026-08-12T10:04:00Z'),
 ('81900000-0000-4000-8000-000000000002','audit_test.unit_a','test','81910000-0000-4000-8000-000000000002','81500000-0000-4000-8000-000000000001','unit','81600000-0000-4000-8000-000000000001','2026-08-12T10:03:00Z'),
 ('81900000-0000-4000-8000-000000000003','audit_test.group_a','test','81910000-0000-4000-8000-000000000003','81500000-0000-4000-8000-000000000001','group','81700000-0000-4000-8000-000000000001','2026-08-12T10:02:00Z'),
 ('81900000-0000-4000-8000-000000000004','audit_test.child_a','test','81910000-0000-4000-8000-000000000004','81500000-0000-4000-8000-000000000001','child','81800000-0000-4000-8000-000000000001','2026-08-12T10:01:00Z'),
 ('81900000-0000-4000-8000-000000000005','audit_test.institution_b','test','81910000-0000-4000-8000-000000000005','81500000-0000-4000-8000-000000000002','institution','81500000-0000-4000-8000-000000000002','2026-08-12T10:05:00Z'),
 ('81900000-0000-4000-8000-000000000006','audit_test.unit_b','test','81910000-0000-4000-8000-000000000006','81500000-0000-4000-8000-000000000002','unit','81600000-0000-4000-8000-000000000002','2026-08-12T10:06:00Z'),
 ('81900000-0000-4000-8000-000000000007','audit_test.group_b','test','81910000-0000-4000-8000-000000000007','81500000-0000-4000-8000-000000000002','group','81700000-0000-4000-8000-000000000002','2026-08-12T10:07:00Z'),
 ('81900000-0000-4000-8000-000000000008','audit_test.child_b','test','81910000-0000-4000-8000-000000000008','81500000-0000-4000-8000-000000000002','child','81800000-0000-4000-8000-000000000002','2026-08-12T10:08:00Z');
insert into audit.audit_logs(id,actor_person_id,action_code,object_type,object_id,occurred_at)
values ('81900000-0000-4000-8000-000000000009','81200000-0000-4000-8000-000000000004',
  'audit_test.legacy_actor','test','81910000-0000-4000-8000-000000000009','2026-08-12T10:09:00Z');

set local role anon;
select throws_ok(
  $$select public.audit_list_events_for_superadmin()$$,
  '42501', null, 'anonymous callers cannot enumerate audit events'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','81100000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"81100000-0000-4000-8000-000000000002","aal":"aal2","role":"authenticated"}',true);
select throws_ok(
  $$select public.audit_list_events_for_superadmin()$$,
  '42501', 'audit.read required', 'actor without capability cannot list'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','81100000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"81100000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated"}',true);
select ok(
  not exists(select 1 from jsonb_array_elements(public.audit_list_events_for_superadmin()->'items') item
    where item->'institution'->>'id' is distinct from '81500000-0000-4000-8000-000000000001'),
  'institution-scoped reader cannot see global or cross-institution events'
);
select is(
  public.audit_get_event_for_superadmin('81900000-0000-4000-8000-000000000005'),null::jsonb,
  'cross-institution event detail is indistinguishable from not found'
);
select ok(
  not exists(select 1 from (values
    ('81900000-0000-4000-8000-000000000006'::uuid),
    ('81900000-0000-4000-8000-000000000007'::uuid),
    ('81900000-0000-4000-8000-000000000008'::uuid)) target(id)
    where public.audit_get_event_for_superadmin(target.id) is not null),
  'cross-scope unit, group and child details all fail closed'
);
select ok(
  not exists(select 1 from jsonb_array_elements(public.audit_list_events_for_superadmin(
    p_cursor_occurred_at=>'2026-08-12T10:05:00Z',p_cursor_id=>'81900000-0000-4000-8000-000000000005')->'items') item
    where item->'institution'->>'id' is distinct from '81500000-0000-4000-8000-000000000001'),
  'cursor sourced from another scope cannot disclose cross-scope rows'
);
select ok(
  (public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000010')->>'job_id') is not null,
  'institution-scoped export creates an authorized idempotent job'
);
reset role;

set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select lives_ok(
  $$select public.audit_materialize_export_for_worker((select id from public.import_jobs where request_id='81400000-0000-4000-8000-000000000010'),'81400000-0000-4000-8000-000000000099')$$,
  'worker materializes after reauthorizing the actor'
);
select is(
  (public.audit_materialize_export_for_worker(
    (select id from public.import_jobs where request_id='81400000-0000-4000-8000-000000000010'),
    '81400000-0000-4000-8000-000000000097')->>'claimed')::boolean,
  false,
  'concurrent idempotent worker cannot steal an active lease'
);
reset role;
select ok(
  not exists(select 1 from app_private.audit_export_snapshot_rows snapshot
    join audit.audit_logs log_record on log_record.id=snapshot.audit_log_id
    join public.import_jobs job on job.id=snapshot.export_job_id
    where job.request_id='81400000-0000-4000-8000-000000000010'
      and log_record.institution_id is distinct from '81500000-0000-4000-8000-000000000001'),
  'export snapshot contains only the actor authorized institution'
);
update public.platform_memberships set status='revoked',revoked_at=now()
where person_id='81200000-0000-4000-8000-000000000003';
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select throws_ok(
  $$select public.audit_materialize_export_for_worker((select id from public.import_jobs where request_id='81400000-0000-4000-8000-000000000010'),'81400000-0000-4000-8000-000000000098')$$,
  '42501','audit export authorization revoked','worker fails closed after membership revocation'
);
reset role;

set local role service_role;
select set_config('request.jwt.claims','{}',true);
select throws_ok(
  $$select public.audit_expired_artifacts_for_worker(10)$$,
  '42501','audit worker authorization required','worker RPC validates server identity inside SECURITY DEFINER'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','81100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"81100000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',true);
select throws_ok(
  $$select public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000001')$$,
  '42501', 'audit.export and AAL2 required', 'export fails closed below AAL2'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','81100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"81100000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}',true);
select throws_ok(
  $$select public.audit_list_events_for_superadmin(p_cursor_occurred_at=>now(),p_cursor_id=>null)$$,
  '22023', 'invalid audit list filters', 'partial cursor is rejected'
);
select throws_ok(
  $$select public.audit_list_events_for_superadmin(repeat('x',201))$$,
  '22023', 'invalid audit list filters', 'hostile oversized query is rejected'
);
select ok(
  (public.audit_get_event_for_superadmin('81000000-0000-4000-8000-000000000001')->'before') ? 'status'
  and not (public.audit_get_event_for_superadmin('81000000-0000-4000-8000-000000000001')->'before') ? 'cpf'
  and not (public.audit_get_event_for_superadmin('81000000-0000-4000-8000-000000000001')->'after') ? 'token',
  'detail masks legacy sensitive fields server-side'
);
select ok(
  not ((public.audit_list_events_for_superadmin()->'items'->0) ? 'before')
  and not ((public.audit_list_events_for_superadmin()->'items'->0) ? 'after'),
  'list never returns before/after payloads'
);
select ok(
  (public.audit_list_events_for_superadmin()->>'can_export')::boolean,
  'list returns export capability when at least one scope survives a local deny'
);
select ok(
  not exists(select 1 from jsonb_array_elements(public.audit_list_events_for_superadmin()->'items') item
    where item->'institution'->>'id'='81500000-0000-4000-8000-000000000002'),
  'platform allow does not override an explicit institution deny'
);
select ok(
  (public.audit_get_event_for_superadmin('81000000-0000-4000-8000-000000000001')->'actor'->>'display_name')='Sistema'
  and (public.audit_get_event_for_superadmin('81000000-0000-4000-8000-000000000001')->'actor'->>'role_code')='system',
  'system events return a stable structured actor'
);
select is(
  public.audit_get_event_for_superadmin('81900000-0000-4000-8000-000000000009')->'actor'->>'role_code',
  'legacy_unknown',
  'historical actor without trustworthy role evidence is never mislabeled as system'
);
select ok(
  (public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000002')->>'job_id') is not null
  and public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000002')
      = public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000002'),
  'export requests are idempotent'
);
do $$begin
  perform public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000020');
  perform public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000021');
  perform public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000022');
  perform public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000023');
end $$;
select throws_ok(
  $$select public.audit_start_export_for_superadmin('csv','{}','81400000-0000-4000-8000-000000000024')$$,
  '54000','audit export rate limit exceeded','sixth export request in one hour is rejected'
);
select throws_ok(
  $$select public.audit_start_export_for_superadmin('pdf','{}','81400000-0000-4000-8000-000000000003')$$,
  '22023', 'invalid audit export request', 'unsupported export formats fail closed'
);
select throws_ok(
  $$select public.audit_start_export_for_superadmin('csv','{"actor_ids":"not-an-array"}','81400000-0000-4000-8000-000000000004')$$,
  '22023', 'invalid audit export request', 'malformed export filter types fail with a safe error'
);
select throws_ok(
  $$select public.audit_start_export_for_superadmin('csv',null,'81400000-0000-4000-8000-000000000005')$$,
  '22023', 'invalid audit export request', 'null export filters fail closed on direct RPC calls'
);
select ok(
  (public.audit_get_export_job_for_superadmin('81400000-0000-4000-8000-000000000002')->>'state')='PENDENTE',
  'authorized requester can read the real queued job state'
);
select ok(
  (select (summary->>'pii_included')::boolean from public.import_jobs
    where request_id='81400000-0000-4000-8000-000000000002'),
  'export metadata truthfully classifies actor and contextual identifiers as PII'
);
insert into app_private.audit_export_snapshot_rows(export_job_id,ordinal,audit_log_id,row_payload)
select id,1,'81900000-0000-4000-8000-000000000005','{}'::jsonb from public.import_jobs
where request_id='81400000-0000-4000-8000-000000000002';
select is(
  public.audit_get_export_job_for_superadmin(
    (select id from public.import_jobs where request_id='81400000-0000-4000-8000-000000000002')),
  null::jsonb,
  'ready export is unavailable when any snapshot row is outside the current scope'
);
reset role;

insert into audit.audit_logs(id,action_code) values
  ('81900000-0000-4000-8000-000000000099','audit_test.null_resource');
set local role authenticated;
select set_config('request.jwt.claim.sub','81100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"81100000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}',true);
select ok(
  (select item ? 'object_type' and item->'object_type'='null'::jsonb
      and item ? 'object_id' and item->'object_id'='null'::jsonb
    from jsonb_array_elements(public.audit_list_events_for_superadmin(
      p_search=>'audit_test.null_resource')->'items') item limit 1),
  'nullable legacy resources remain explicit nulls without fabricated identifiers'
);
reset role;

update public.import_jobs set processing_state='SUCESSO'
where request_id='81400000-0000-4000-8000-000000000002';
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select lives_ok(
  $$select public.audit_fail_export_for_worker(
    (select id from public.import_jobs where request_id='81400000-0000-4000-8000-000000000002'),
    '81400000-0000-4000-8000-000000000096','late_worker_failure')$$,
  'late worker failure is an idempotent no-op after success'
);
reset role;
select is(
  (select processing_state::text from public.import_jobs
    where request_id='81400000-0000-4000-8000-000000000002'),
  'SUCESSO',
  'failure CAS never downgrades a terminal successful export'
);
create temporary table audit_expiring_job on commit drop as
select id from public.import_jobs where request_id='81400000-0000-4000-8000-000000000002';
update public.import_jobs set summary=summary||jsonb_build_object(
  'storage_path','exports/audit/expired/artifact.csv',
  'retention_expires_at',now()-interval '1 minute')
where id=(select id from audit_expiring_job);
insert into public.import_files(import_job_id,storage_path,file_name,mime_type,size_bytes,checksum_sha256,expires_at)
select id,'exports/audit/expired/artifact.csv','auditoria.csv','text/csv',10,repeat('a',64),now()-interval '1 minute'
from audit_expiring_job;
insert into app_private.audit_export_worker_claims(export_job_id,worker_token,lease_until)
select id,'81400000-0000-4000-8000-000000000095',now()-interval '1 minute' from audit_expiring_job;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select lives_ok(
  $$select public.audit_expire_export_for_worker(
    (select id from audit_expiring_job),'exports/audit/expired/artifact.csv')$$,
  'expired artifact transitions atomically to not-found after physical removal'
);
reset role;
select ok(
  not exists(select 1 from public.import_jobs where id=(select id from audit_expiring_job))
  and not exists(select 1 from public.import_files where import_job_id=(select id from audit_expiring_job))
  and not exists(select 1 from app_private.audit_export_snapshot_rows where export_job_id=(select id from audit_expiring_job))
  and not exists(select 1 from app_private.audit_export_worker_claims where export_job_id=(select id from audit_expiring_job)),
  'expiry erases job, file metadata, PII snapshot and worker claim together'
);

select ok(
  app_private.audit_spreadsheet_cell('=1+1') = '''=1+1'
  and app_private.audit_spreadsheet_cell('+SUM(A1:A2)') = '''+SUM(A1:A2)'
  and app_private.audit_spreadsheet_cell('safe') = 'safe',
  'spreadsheet formula injection is neutralized'
);
select ok(
  not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('audit','app_private') and p.proname like '%purge%'),
  'retention remains indefinite with no purge routine'
);

select * from finish();
rollback;
