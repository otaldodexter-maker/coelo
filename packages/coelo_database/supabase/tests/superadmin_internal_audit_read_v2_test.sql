begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

select has_function(
  'public','audit_list_events_for_superadmin',
  array['text','uuid[]','text[]','text[]','text[]','text[]','text[]','uuid',
    'timestamp with time zone','timestamp with time zone','timestamp with time zone','uuid','integer'],
  'the nominal thirteen-argument audit list signature is preserved'
);
select has_function(
  'public','audit_get_event_for_superadmin',array['uuid'],
  'the nominal audit detail signature is preserved'
);
select ok((
  select owner_role.rolname='postgres' and procedure_record.prosecdef
    and procedure_record.provolatile='v'
    and coalesce(procedure_record.proconfig,'{}'::text[]) @> array['search_path=""']::text[]
  from pg_catalog.pg_proc procedure_record
  join pg_catalog.pg_roles owner_role on owner_role.oid=procedure_record.proowner
  where procedure_record.oid=
    'public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)'::regprocedure
),'the audited list wrapper is a postgres-owned volatile security definer with empty search_path');
select ok(
  has_function_privilege('authenticated',
    'public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)','execute')
  and has_function_privilege('authenticated','public.audit_get_event_for_superadmin(uuid)','execute')
  and not has_function_privilege('anon',
    'public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)','execute')
  and not has_function_privilege('service_role',
    'public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)','execute')
  and not has_function_privilege('anon','public.audit_get_event_for_superadmin(uuid)','execute')
  and not has_function_privilege('service_role','public.audit_get_event_for_superadmin(uuid)','execute')
  and not exists(
    select 1 from pg_catalog.pg_proc procedure_record
    cross join lateral pg_catalog.aclexplode(coalesce(procedure_record.proacl,
      pg_catalog.acldefault('f',procedure_record.proowner))) acl
    where procedure_record.oid in(
      'public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)'::regprocedure,
      'public.audit_get_event_for_superadmin(uuid)'::regprocedure)
      and acl.grantee=0 and acl.privilege_type='EXECUTE'
  ),'only authenticated can execute the two public audit readers'
);
select ok(
  not has_function_privilege('authenticated','public.audit_start_export_for_superadmin(text,jsonb,uuid)','execute')
  and not has_function_privilege('authenticated','public.audit_get_export_job_for_superadmin(uuid)','execute')
  and not has_function_privilege('authenticated','public.audit_authorize_export_download_for_superadmin(uuid)','execute')
  and not has_function_privilege('anon','public.audit_start_export_for_superadmin(text,jsonb,uuid)','execute')
  and not has_function_privilege('anon','public.audit_get_export_job_for_superadmin(uuid)','execute')
  and not has_function_privilege('anon','public.audit_authorize_export_download_for_superadmin(uuid)','execute')
  and not exists(
    select 1 from pg_catalog.pg_proc procedure_record
    cross join lateral pg_catalog.aclexplode(coalesce(procedure_record.proacl,
      pg_catalog.acldefault('f',procedure_record.proowner))) acl
    where procedure_record.oid in(
      'public.audit_start_export_for_superadmin(text,jsonb,uuid)'::regprocedure,
      'public.audit_get_export_job_for_superadmin(uuid)'::regprocedure,
      'public.audit_authorize_export_download_for_superadmin(uuid)'::regprocedure)
      and acl.grantee=0 and acl.privilege_type='EXECUTE'
  ),'general audit export RPCs expose no client or PUBLIC execute path'
);
select ok(
  has_function_privilege('service_role','public.audit_materialize_export_for_worker(uuid,uuid)','execute')
  and has_function_privilege('service_role','public.audit_export_page_for_worker(uuid,uuid,bigint,integer)','execute')
  and has_function_privilege('service_role','public.audit_complete_export_for_worker(uuid,uuid,text,text,text,bigint,text,integer)','execute'),
  'existing service worker permissions remain intact'
);
select ok((
  select pg_catalog.strpos(definition,'require_superadmin_internal_context(''audit.read'')')>0
    and pg_catalog.strpos(definition,'audit_assert_permission')=0
    and pg_catalog.strpos(definition,'audit_authorization_scope')=0
    and pg_catalog.strpos(definition,'current_person_id')=0
    and pg_catalog.strpos(definition,'''can_export'',false')>0
  from (select pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.pg_get_functiondef(
    'app_private.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)'::regprocedure
  ),'[[:space:]]+','','g')) definition) source
),'list authorization is internal-only and export remains false');

insert into public.institutions(id,public_name,legal_name,slug,status) values
 ('9a140000-0000-4000-8000-000000000001','Audit I014 A','Audit I014 A','audit-i014-a','active'),
 ('9a140000-0000-4000-8000-000000000002','Audit I014 B','Audit I014 B','audit-i014-b','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
 ('9a110000-0000-4000-8000-000000000001','authenticated','authenticated','i014-platform@invalid.test',now(),now(),now(),'{}','{}'),
 ('9a110000-0000-4000-8000-000000000002','authenticated','authenticated','i014-institution@invalid.test',now(),now(),now(),'{}','{}'),
 ('9a110000-0000-4000-8000-000000000003','authenticated','authenticated','i014-legacy@invalid.test',now(),now(),now(),'{}','{}'),
 ('9a110000-0000-4000-8000-000000000004','authenticated','authenticated','i014-link-revoked@invalid.test',now(),now(),now(),'{}','{}'),
 ('9a110000-0000-4000-8000-000000000005','authenticated','authenticated','i014-membership-revoked@invalid.test',now(),now(),now(),'{}','{}'),
 ('9a110000-0000-4000-8000-000000000006','authenticated','authenticated','i014-capability-revoked@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9a120000-0000-4000-8000-000000000001','9a110000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
 ('9a120000-0000-4000-8000-000000000002','9a110000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
 ('9a120000-0000-4000-8000-000000000003','9a110000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour'),
 ('9a120000-0000-4000-8000-000000000004','9a110000-0000-4000-8000-000000000004',now(),now(),'aal1',now()+interval '1 hour'),
 ('9a120000-0000-4000-8000-000000000005','9a110000-0000-4000-8000-000000000005',now(),now(),'aal1',now()+interval '1 hour'),
 ('9a120000-0000-4000-8000-000000000006','9a110000-0000-4000-8000-000000000006',now(),now(),'aal1',now()+interval '1 hour'),
 ('9a120000-0000-4000-8000-000000000099','9a110000-0000-4000-8000-000000000001',now(),now(),'aal1',now()-interval '1 minute');

insert into public.platform_roles(id,code,name,status,is_system,max_scope_kind) values
 ('9a130000-0000-4000-8000-000000000006','audit_i014_revoked','Audit I014 revoked','active',true,'platform'),
 ('9a130000-0000-4000-8000-000000000007','audit_i014_reader','Audit I014 reader','active',true,'platform');
insert into public.platform_role_permissions(role_id,permission_id,effect,status,revoked_at)
select '9a130000-0000-4000-8000-000000000006',permission_record.id,'allow','active',now()
from public.platform_permissions permission_record where permission_record.code='audit.read';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select '9a130000-0000-4000-8000-000000000007',permission_record.id,'allow','active'
from public.platform_permissions permission_record where permission_record.code='audit.read';

insert into app_private.superadmin_internal_identities(id) values
 ('9a150000-0000-4000-8000-000000000001'),
 ('9a150000-0000-4000-8000-000000000002'),
 ('9a150000-0000-4000-8000-000000000004'),
 ('9a150000-0000-4000-8000-000000000005'),
 ('9a150000-0000-4000-8000-000000000006');
insert into app_private.superadmin_internal_auth_links(
  id,internal_identity_id,auth_user_id,status,revoked_at) values
 ('9a160000-0000-4000-8000-000000000001','9a150000-0000-4000-8000-000000000001','9a110000-0000-4000-8000-000000000001','active',null),
 ('9a160000-0000-4000-8000-000000000002','9a150000-0000-4000-8000-000000000002','9a110000-0000-4000-8000-000000000002','active',null),
 ('9a160000-0000-4000-8000-000000000004','9a150000-0000-4000-8000-000000000004','9a110000-0000-4000-8000-000000000004','revoked',now()),
 ('9a160000-0000-4000-8000-000000000005','9a150000-0000-4000-8000-000000000005','9a110000-0000-4000-8000-000000000005','active',null),
 ('9a160000-0000-4000-8000-000000000006','9a150000-0000-4000-8000-000000000006','9a110000-0000-4000-8000-000000000006','active',null);
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status,revoked_at)
select fixture.id,fixture.identity_id,role_record.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,
  fixture.institution_id,fixture.status::app_private.superadmin_internal_membership_status,fixture.revoked_at
from (values
 ('9a170000-0000-4000-8000-000000000001'::uuid,'9a150000-0000-4000-8000-000000000001'::uuid,'audit_i014_reader','platform',null::uuid,'active',null::timestamptz),
 ('9a170000-0000-4000-8000-000000000002','9a150000-0000-4000-8000-000000000002','audit_i014_reader','institution','9a140000-0000-4000-8000-000000000001','active',null),
 ('9a170000-0000-4000-8000-000000000004','9a150000-0000-4000-8000-000000000004','owner','platform',null,'active',null),
 ('9a170000-0000-4000-8000-000000000005','9a150000-0000-4000-8000-000000000005','owner','platform',null,'revoked',now()),
 ('9a170000-0000-4000-8000-000000000006','9a150000-0000-4000-8000-000000000006','audit_i014_revoked','platform',null,'active',null)
) fixture(id,identity_id,role_code,scope_kind,institution_id,status,revoked_at)
join public.platform_roles role_record on role_record.code=fixture.role_code;

insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9a180000-0000-4000-8000-000000000003','adult','Legacy','Audit','Legacy Audit','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('9a180000-0000-4000-8000-000000000003','9a110000-0000-4000-8000-000000000003','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '9a180000-0000-4000-8000-000000000003',id,'active','platform',false
from public.platform_roles where code='owner';

insert into audit.audit_logs(id,action_code,object_type,object_id,institution_id,
  context_kind,context_id,occurred_at,actor_person_id) values
 ('9a190000-0000-4000-8000-000000000001','i014.event.global','test','9a191000-0000-4000-8000-000000000001',null,'global',null,'2026-09-08T10:00:00Z',null),
 ('9a190000-0000-4000-8000-000000000002','i014.event.a','test','9a191000-0000-4000-8000-000000000002','9a140000-0000-4000-8000-000000000001','institution','9a140000-0000-4000-8000-000000000001','2026-09-08T09:00:00Z','9a180000-0000-4000-8000-000000000003'),
 ('9a190000-0000-4000-8000-000000000003','i014.event.b','test','9a191000-0000-4000-8000-000000000003','9a140000-0000-4000-8000-000000000002','institution','9a140000-0000-4000-8000-000000000002','2026-09-08T08:00:00Z',null),
 ('9a190000-0000-4000-8000-000000000010','i014.cursor','test','9a191000-0000-4000-8000-000000000010','9a140000-0000-4000-8000-000000000001','institution','9a140000-0000-4000-8000-000000000001','2026-09-08T07:00:00Z',null),
 ('9a190000-0000-4000-8000-000000000011','i014.cursor','test','9a191000-0000-4000-8000-000000000011','9a140000-0000-4000-8000-000000000001','institution','9a140000-0000-4000-8000-000000000001','2026-09-08T07:00:00Z',null);
insert into audit.audit_logs(id,action_code,object_type,object_id,institution_id,context_kind,context_id,
  before_json,after_json,reason,occurred_at) values
 ('9a190000-0000-4000-8000-000000000020','i014.detail','test','9a191000-0000-4000-8000-000000000020',
  '9a140000-0000-4000-8000-000000000001','institution','9a140000-0000-4000-8000-000000000001',
  '{"status":"draft","cpf":"forbidden"}','{"status":"active","token":"forbidden"}',
  'approved_reason','2026-09-08T06:00:00Z');
select app_private.audit_append_auth_session_denial(
  '9a120000-0000-4000-8000-000000000001','audit.read','aal1','i014.session',
  'SAI_PERMISSION_DENIED','9a199000-0000-4000-8000-000000000001');

create temporary table i014_results(label text primary key,body jsonb);
grant select,insert on i014_results to authenticated;

select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000001',
  'session_id','9a120000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values
 ('platform',public.audit_list_events_for_superadmin(p_search=>'i014.event')),
 ('filters',public.audit_list_events_for_superadmin(
    p_actor_ids=>array['9a180000-0000-4000-8000-000000000003']::uuid[],
    p_context_kinds=>array['institution'],p_action_codes=>array['i014.event.a'],
    p_resource_types=>array['test'],p_outcomes=>array['success'],
    p_origins=>array['database'],p_institution_id=>'9a140000-0000-4000-8000-000000000001',
    p_from=>'2026-09-08T08:59:00Z',p_to=>'2026-09-08T09:01:00Z')),
 ('platform_detail',public.audit_get_event_for_superadmin('9a190000-0000-4000-8000-000000000020')),
 ('session_minimized',public.audit_list_events_for_superadmin(p_search=>'i014.session')),
 ('limit_null',public.audit_list_events_for_superadmin(p_limit=>null)),
 ('limit_zero',public.audit_list_events_for_superadmin(p_limit=>0)),
 ('limit_101',public.audit_list_events_for_superadmin(p_limit=>101)),
 ('limit_one',public.audit_list_events_for_superadmin(p_search=>'i014.event',p_limit=>1)),
 ('limit_100',public.audit_list_events_for_superadmin(p_search=>'i014.event',p_limit=>100)),
 ('partial_cursor',public.audit_list_events_for_superadmin(p_cursor_occurred_at=>'2026-09-08T07:00:00Z')),
 ('wrong_cursor_time',public.audit_list_events_for_superadmin(p_search=>'i014.cursor',
    p_cursor_occurred_at=>'2026-09-08T07:00:01Z',p_cursor_id=>'9a190000-0000-4000-8000-000000000011')),
 ('cursor_page1',public.audit_list_events_for_superadmin(p_search=>'i014.cursor',p_limit=>1)),
 ('null_array',public.audit_list_events_for_superadmin(p_action_codes=>array[null]::text[])),
 ('invalid_search',public.audit_list_events_for_superadmin(p_search=>repeat('x',201))),
 ('invalid_range',public.audit_list_events_for_superadmin(p_from=>'2026-09-09',p_to=>'2026-09-08')),
 ('invalid_scope_and_limit',public.audit_list_events_for_superadmin(
    p_institution_id=>'9a140000-0000-4000-8000-000000000099',p_limit=>0));
insert into i014_results
select 'cursor_page2',public.audit_list_events_for_superadmin(p_search=>'i014.cursor',p_limit=>1,
  p_cursor_occurred_at=>(body#>>'{next_cursor,occurred_at}')::timestamptz,
  p_cursor_id=>(body#>>'{next_cursor,event_id}')::uuid)
from i014_results where label='cursor_page1';
insert into i014_results values
 ('cursor_reload',public.audit_list_events_for_superadmin(p_search=>'i014.cursor',p_limit=>1));
reset role;

select ok((select body->>'can_export'='false' and body->>'total_count'='3'
  and jsonb_array_length(body->'items')=3 from i014_results where label='platform'),
  'platform scope reads global and both institutions while export stays deferred');
select ok((select body->>'total_count'='1' and jsonb_array_length(body->'items')=1
    and body#>>'{items,0,id}'='9a190000-0000-4000-8000-000000000002'
    from i014_results where label='filters'),
  'all nominal filters compose inside the authorized platform scope');
select ok((select body#>>'{id}'='9a190000-0000-4000-8000-000000000020'
  and body#>>'{before,status}'='draft' and not (body->'before' ? 'cpf')
  and body#>>'{after,status}'='active' and not (body->'after' ? 'token')
  and body#>>'{integrity,verified}'='true' from i014_results where label='platform_detail'),
  'detail preserves minimization and verified integrity');
select ok((select body#>'{items,0,actor,id}'='null'::jsonb
  and body#>'{items,0,actor,role_code}'='null'::jsonb
  and body#>>'{items,0,actor,display_name}'='Sessão autenticada'
  from i014_results where label='session_minimized'),
  'auth_session list projection exposes no raw or derived identity');
select ok((select bool_and(body#>>'{error,code}'='SAI_INVALID_ARGUMENT')
  from i014_results where label in('limit_null','limit_zero','limit_101')),
  'NULL, zero and limits above one hundred are rejected');
select ok((select bool_and(body->>'can_export'='false' and body ? 'items')
  from i014_results where label in('limit_one','limit_100')),
  'limits one and one hundred remain accepted');
select is((select body#>>'{error,code}' from i014_results where label='partial_cursor'),
  'SAI_INVALID_ARGUMENT','partial cursors are rejected');
select is((select body#>>'{error,code}' from i014_results where label='wrong_cursor_time'),
  'SAI_INVALID_ARGUMENT','cursor timestamp must match the scoped ordered row');
select is((select body#>>'{items,0,id}' from i014_results where label='cursor_page1'),
  '9a190000-0000-4000-8000-000000000011','tie ordering uses descending event id');
select is((select body#>>'{items,0,id}' from i014_results where label='cursor_page2'),
  '9a190000-0000-4000-8000-000000000010','the validated cursor continues without duplicate rows');
select is((select body#>>'{items,0,id}' from i014_results where label='cursor_reload'),
  '9a190000-0000-4000-8000-000000000011','success audit appends do not perturb a filtered first-page reload');
select is((select body#>>'{error,code}' from i014_results where label='null_array'),
  'SAI_INVALID_ARGUMENT','NULL filter elements are rejected');
select ok((select bool_and(body#>>'{error,code}'='SAI_INVALID_ARGUMENT')
  from i014_results where label in('invalid_search','invalid_range','invalid_scope_and_limit')),
  'oversized search, inverted timestamps and forged scope plus invalid input are rejected');

select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000002',
  'session_id','9a120000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values
 ('institution',public.audit_list_events_for_superadmin(p_search=>'i014.event')),
 ('institution_b_filter',public.audit_list_events_for_superadmin(p_search=>'i014.event',
    p_institution_id=>'9a140000-0000-4000-8000-000000000002')),
 ('institution_detail_a',public.audit_get_event_for_superadmin('9a190000-0000-4000-8000-000000000020')),
 ('institution_detail_b',public.audit_get_event_for_superadmin('9a190000-0000-4000-8000-000000000003')),
 ('institution_detail_missing',public.audit_get_event_for_superadmin('9a190000-0000-4000-8000-000000000099')),
 ('foreign_cursor',public.audit_list_events_for_superadmin(p_search=>'i014.event',
    p_cursor_occurred_at=>'2026-09-08T08:00:00Z',p_cursor_id=>'9a190000-0000-4000-8000-000000000003'));
reset role;
select ok((select body->>'total_count'='1' and body#>>'{items,0,id}'='9a190000-0000-4000-8000-000000000002'
  from i014_results where label='institution'),
  'institution scope sees only its own institution and no global event');
select is((select body->>'total_count' from i014_results where label='institution_b_filter'),'0',
  'a cross-tenant list filter discloses no rows');
select is((select body#>>'{id}' from i014_results where label='institution_detail_a'),
  '9a190000-0000-4000-8000-000000000020','institution detail reads its own event');
select ok((select body is null from i014_results where label='institution_detail_b')
  and (select body is null from i014_results where label='institution_detail_missing'),
  'cross-scope and nonexistent detail are indistinguishable');
select is((select body#>>'{error,code}' from i014_results where label='foreign_cursor'),
  'SAI_INVALID_ARGUMENT','cursor from another institution is rejected without data');

select set_config('request.jwt.claims','{}',true);
set local role authenticated;
insert into i014_results values('auth_missing',public.audit_list_events_for_superadmin());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000001',
  'session_id','not-a-uuid','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values('session_malformed',public.audit_list_events_for_superadmin());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000001',
  'session_id','9a120000-0000-4000-8000-000000000098','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values('session_deleted',public.audit_list_events_for_superadmin());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000001',
  'session_id','9a120000-0000-4000-8000-000000000099','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values('session_expired',public.audit_list_events_for_superadmin());
reset role;
select ok((select body#>>'{error,code}'='SAI_AUTH_REQUIRED' from i014_results where label='auth_missing')
  and (select bool_and(body#>>'{error,code}'='SAI_SESSION_INVALID') from i014_results
    where label in('session_malformed','session_deleted','session_expired')),
  'missing auth and malformed, deleted or expired sessions use stable 039 envelopes');

select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000003',
  'session_id','9a120000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values('legacy_people',public.audit_list_events_for_superadmin());
reset role;
select is((select body#>>'{error,code}' from i014_results where label='legacy_people'),
  'SAI_INTERNAL_CONTEXT_DENIED','a privileged People-realm actor cannot enter the internal reader');
select ok((select count(*)=1 from audit.audit_logs where actor_kind='auth_session'
  and correlation_id=(select (body#>>'{error,correlation_id}')::uuid from i014_results where label='legacy_people')
  and actor_person_id is null and actor_role_code is null and actor_internal_identity_id is null
  and octet_length(session_id_hash)=32 and permission_code='audit.read'
  and action_code='superadmin.audit.list' and outcome='denied'),
  'the valid legacy session denial is audited as minimized auth_session v3');

select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000004',
  'session_id','9a120000-0000-4000-8000-000000000004','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values('link_revoked',public.audit_list_events_for_superadmin());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000005',
  'session_id','9a120000-0000-4000-8000-000000000005','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values('membership_revoked',public.audit_list_events_for_superadmin());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000006',
  'session_id','9a120000-0000-4000-8000-000000000006','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values('capability_revoked',public.audit_list_events_for_superadmin());
reset role;
select ok((select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from i014_results where label='link_revoked')
  and (select body#>>'{error,code}'='SAI_MEMBERSHIP_REVOKED' from i014_results where label='membership_revoked')
  and (select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from i014_results where label='capability_revoked'),
  'revoked link, membership and capability each fail closed');

select set_config('request.jwt.claims',jsonb_build_object('sub','9a110000-0000-4000-8000-000000000001',
  'session_id','9a120000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into i014_results values('aal1',public.audit_list_events_for_superadmin(p_search=>'i014.event'));
select throws_ok($$select public.audit_start_export_for_superadmin('csv','{}','9a1e0000-0000-4000-8000-000000000001')$$,
  '42501',null,'authenticated cannot invoke the deferred start-export RPC');
select throws_ok($$select public.audit_get_export_job_for_superadmin('9a1e0000-0000-4000-8000-000000000001')$$,
  '42501',null,'authenticated cannot invoke the deferred export-status RPC');
select throws_ok($$select public.audit_authorize_export_download_for_superadmin('9a1e0000-0000-4000-8000-000000000001')$$,
  '42501',null,'authenticated cannot invoke the deferred export-download RPC');
reset role;
select ok((select body ? 'items' and body->>'can_export'='false' from i014_results where label='aal1'),
  'AAL1 is accepted for the MVP reader');
select ok((select count(*)>=1 from audit.audit_logs where actor_kind='superadmin_internal'
    and actor_internal_identity_id='9a150000-0000-4000-8000-000000000001'
    and permission_code='audit.read' and action_code='superadmin.audit.list' and outcome='success')
  and (select count(*)>=1 from audit.audit_logs where actor_kind='superadmin_internal'
    and actor_internal_identity_id='9a150000-0000-4000-8000-000000000001'
    and permission_code='audit.read' and action_code='superadmin.audit.detail' and outcome='success'),
  'successful list and detail reads are audited with internal provenance');
select ok((select count(*)>=1 from audit.audit_logs where actor_kind='superadmin_internal'
  and actor_internal_identity_id='9a150000-0000-4000-8000-000000000001'
  and permission_code='audit.read' and action_code='superadmin.audit.list'
  and outcome='denied' and reason_code='SAI_INVALID_ARGUMENT')
  and (select count(*)=1 from audit.audit_logs where actor_kind='superadmin_internal'
    and correlation_id=(select (body#>>'{error,correlation_id}')::uuid
      from i014_results where label='invalid_scope_and_limit')
    and institution_id is null and reason_code='SAI_INVALID_ARGUMENT'),
  'invalid requests are audited without trusting a forged institution id');
select is((select count(*) from public.import_jobs where request_id='9a1e0000-0000-4000-8000-000000000001'),0::bigint,
  'deferred client calls create no export job');
select is((select count(*) from public.import_results result_record
  join public.import_jobs job_record on job_record.id=result_record.import_job_id
  where job_record.request_id='9a1e0000-0000-4000-8000-000000000001'),0::bigint,
  'deferred client calls create no export result or artifact metadata');

select * from finish();
rollback;
