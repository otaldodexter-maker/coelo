begin;

create extension if not exists pgtap with schema extensions;

select plan(42);

select ok(
  to_regprocedure('public.superadmin_person_detail_v2(uuid)') is not null,
  'person detail v2 wrapper exists');

create temporary table person_detail_test_snapshot(value jsonb not null);
create temporary table person_detail_test_responses(
  sequence_number integer primary key,
  body jsonb not null
);

grant select on person_detail_test_snapshot to authenticated;
grant select, insert on person_detail_test_responses to authenticated;

insert into person_detail_test_snapshot(value)
select jsonb_build_object(
  'identities', (select count(*) from app_private.superadmin_internal_identities),
  'auth_links', (select count(*) from app_private.superadmin_internal_auth_links),
  'memberships', (select count(*) from app_private.superadmin_internal_memberships),
  'institutions', (select count(*) from public.institutions),
  'units', (select count(*) from public.units),
  'groups', (select count(*) from public.groups),
  'people', (select count(*) from public.people),
  'institution_memberships', (select count(*) from public.institution_memberships),
  'role_assignments', (select count(*) from public.institution_role_assignments),
  'child_contexts', (select count(*) from public.child_contexts),
  'audit', (select count(*) from audit.audit_logs)
);

select set_config('request.jwt.claims', '{}', true);
set local role authenticated;

do $test$
begin
  if to_regprocedure('public.superadmin_person_detail_v2(uuid)') is not null then
    execute
      'insert into person_detail_test_responses(sequence_number, body)
       values ($1, public.superadmin_person_detail_v2($2))'
      using 1, '91000000-0000-4000-8000-000000000001'::uuid;
    execute
      'insert into person_detail_test_responses(sequence_number, body)
       values ($1, public.superadmin_person_detail_v2($2))'
      using 2, '91000000-0000-4000-8000-000000000001'::uuid;
  end if;
end
$test$;

reset role;

select is(
  (select count(*) from person_detail_test_responses),
  2::bigint,
  'two no-session calls return JSON without raising');

select ok(
  not exists(
    select 1
    from person_detail_test_responses response
    where (
      select array_agg(key order by key)
      from jsonb_object_keys(response.body) key
    ) <> array['data', 'error', 'ok']::text[]
      or (
        select array_agg(key order by key)
        from jsonb_object_keys(response.body -> 'error') key
      ) <> array['code', 'correlation_id', 'http_status', 'message']::text[]
  ),
  'person detail envelopes expose exact allowlisted root and error keys');

select ok(
  not exists(
    select 1
    from person_detail_test_responses response
    where (response.body ->> 'ok')::boolean is not false
      or response.body -> 'data' <> 'null'::jsonb
      or response.body #>> '{error,code}' <> 'SAI_AUTH_REQUIRED'
      or (response.body #>> '{error,http_status}')::integer <> 401
      or coalesce(response.body #>> '{error,message}', '') = ''
      or response.body #>> '{error,correlation_id}' !~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  ),
  'both calls return SAI_AUTH_REQUIRED with semantic 401 metadata');

select ok(
  (select count(distinct body #>> '{error,correlation_id}') = 2
   from person_detail_test_responses),
  'each rejected call receives a distinct correlation id');

select is(
  (select value from person_detail_test_snapshot),
  (select jsonb_build_object(
    'identities', (select count(*) from app_private.superadmin_internal_identities),
    'auth_links', (select count(*) from app_private.superadmin_internal_auth_links),
    'memberships', (select count(*) from app_private.superadmin_internal_memberships),
    'institutions', (select count(*) from public.institutions),
    'units', (select count(*) from public.units),
    'groups', (select count(*) from public.groups),
  'people', (select count(*) from public.people),
  'institution_memberships', (select count(*) from public.institution_memberships),
  'role_assignments', (select count(*) from public.institution_role_assignments),
  'child_contexts', (select count(*) from public.child_contexts),
    'audit', (select count(*) from audit.audit_logs)
  )),
  'calls without a validated session create no domain, identity, or audit row');

select ok(
  coalesce(has_function_privilege(
    'authenticated',
    to_regprocedure('public.superadmin_person_detail_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'anon',
    to_regprocedure('public.superadmin_person_detail_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'service_role',
    to_regprocedure('public.superadmin_person_detail_v2(uuid)'),
    'execute'
  ), false)
  and not exists(
    select 1
    from pg_proc procedure_record,
      lateral aclexplode(coalesce(
        procedure_record.proacl,
        acldefault('f', procedure_record.proowner)
      )) acl
    where procedure_record.oid =
      to_regprocedure('public.superadmin_person_detail_v2(uuid)')
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'only authenticated can execute the person detail wrapper');

select ok(
  to_regprocedure('app_private.superadmin_person_detail_payload_v2(uuid,text,uuid)') is not null
  and not coalesce(has_function_privilege(
    'anon',
    to_regprocedure('app_private.superadmin_person_detail_payload_v2(uuid,text,uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'authenticated',
    to_regprocedure('app_private.superadmin_person_detail_payload_v2(uuid,text,uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'service_role',
    to_regprocedure('app_private.superadmin_person_detail_payload_v2(uuid,text,uuid)'),
    'execute'
  ), false)
  and not exists(
    select 1
    from pg_proc helper_record,
      lateral aclexplode(coalesce(
        helper_record.proacl,
        acldefault('f', helper_record.proowner)
      )) helper_acl
    where helper_record.oid =
      to_regprocedure('app_private.superadmin_person_detail_payload_v2(uuid,text,uuid)')
      and helper_acl.grantee = 0
      and helper_acl.privilege_type = 'EXECUTE'
  ),
  'the private person detail helper is not executable by client or service roles');

select ok(
  (select wrapper.prosecdef and wrapper.provolatile='v'
      and owner_role.rolname='postgres'
      and coalesce(wrapper.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]
    from pg_proc wrapper
    join pg_roles owner_role on owner_role.oid=wrapper.proowner
    where wrapper.oid='public.superadmin_person_detail_v2(uuid)'::regprocedure)
  and
  (select helper.prosecdef and helper.provolatile='v'
      and owner_role.rolname='postgres'
      and coalesce(helper.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]
    from pg_proc helper
    join pg_roles owner_role on owner_role.oid=helper.proowner
    where helper.oid=
      'app_private.superadmin_person_detail_payload_v2(uuid,text,uuid)'::regprocedure),
  'wrapper/helper owner, volatility, SECURITY DEFINER, and search_path are hardened');


select is(
  (select array_agg(namespace_record.nspname || '.' || procedure_record.proname
      || '(' || replace(oidvectortypes(procedure_record.proargtypes),' ','') || ')'
      order by namespace_record.nspname,procedure_record.proname,
        replace(oidvectortypes(procedure_record.proargtypes),' ',''))
   from pg_proc procedure_record
   join pg_namespace namespace_record
     on namespace_record.oid=procedure_record.pronamespace
   where procedure_record.proname in(
     'superadmin_person_detail_payload_v2','superadmin_person_detail_v2'
   )),
  array[
    'app_private.superadmin_person_detail_payload_v2(uuid,text,uuid)',
    'public.superadmin_person_detail_v2(uuid)'
  ]::text[],
  'the v2 Person detail catalog contains exactly the two approved signatures');

select ok(
  exists(
    select 1 from public.platform_permissions permission_record
    where permission_record.code='people.read'
      and permission_record.status='active'
      and permission_record.requires_mfa is true
  )
  and (
    select array_agg(role_record.code order by role_record.code)
    from public.platform_role_permissions grant_record
    join public.platform_roles role_record
      on role_record.id=grant_record.role_id
    join public.platform_permissions permission_record
      on permission_record.id=grant_record.permission_id
    where permission_record.code='people.read'
      and grant_record.effect='allow'
      and grant_record.status='active'
      and grant_record.revoked_at is null
  )=array['owner']::text[],
  'people.read requires MFA and allows only Owner');

insert into public.institution_types(id,code,name,status) values
 ('91000000-0000-4000-8000-000000000201','person-detail-school','Person Detail School','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('91000000-0000-4000-8000-000000000101','Person Institution A','person-institution-a','active','91000000-0000-4000-8000-000000000201'),
 ('91000000-0000-4000-8000-000000000102','Person Institution B','person-institution-b','active','91000000-0000-4000-8000-000000000201'),
 ('91000000-0000-4000-8000-000000000103','Person Institution C','person-institution-c','active','91000000-0000-4000-8000-000000000201');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
 ('91000000-0000-4000-8000-000000000011','91000000-0000-4000-8000-000000000101','Person Unit A','person-unit-a','active','91000000-0000-4000-8000-000000000201'),
 ('91000000-0000-4000-8000-000000000012','91000000-0000-4000-8000-000000000102','Person Unit B','person-unit-b','active','91000000-0000-4000-8000-000000000201'),
 ('91000000-0000-4000-8000-000000000013','91000000-0000-4000-8000-000000000101','Person Unit A2','person-unit-a2','active','91000000-0000-4000-8000-000000000201'),
 ('91000000-0000-4000-8000-000000000014','91000000-0000-4000-8000-000000000101','Person Unit A3','person-unit-a3','active','91000000-0000-4000-8000-000000000201');
insert into public.groups(id,institution_id,unit_id,name,group_type,status) values
 ('91000000-0000-4000-8000-000000000021','91000000-0000-4000-8000-000000000101','91000000-0000-4000-8000-000000000011','Person Group A','class','active'),
 ('91000000-0000-4000-8000-000000000022','91000000-0000-4000-8000-000000000102','91000000-0000-4000-8000-000000000012','Person Group B','class','active'),
 ('91000000-0000-4000-8000-000000000023','91000000-0000-4000-8000-000000000101','91000000-0000-4000-8000-000000000013','Person Group A2','class','active'),
 ('91000000-0000-4000-8000-000000000024','91000000-0000-4000-8000-000000000101','91000000-0000-4000-8000-000000000011','Person Group Archived','class','archived'),
 ('91000000-0000-4000-8000-000000000025','91000000-0000-4000-8000-000000000101','91000000-0000-4000-8000-000000000011','Person Group Expired Link','class','active');

insert into public.people(id,person_type,first_name,last_name,display_name,legal_name,date_of_birth,status) values
 ('91000000-0000-4000-8000-000000000001','adult','Adult','Alpha','Adult Alpha','Adult Alpha Legal','1990-01-01','active'),
 ('91000000-0000-4000-8000-000000000002','child','Child','Beta','Child Beta',null,'2020-01-01','active'),
 ('91000000-0000-4000-8000-000000000003','service','Service','Gamma','Service Gamma',null,null,'active'),
 ('91000000-0000-4000-8000-000000000004','adult','Pending','Delta','Pending Delta',null,null,'draft'),
 ('91000000-0000-4000-8000-000000000006','adult','Tenant','Bravo','Tenant Bravo',null,null,'active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('99000000-0000-4000-8000-000000000001','authenticated','authenticated','person-linked@invalid.test',now(),now(),now(),'{}','{}'),
 ('99000000-0000-4000-8000-000000000002','authenticated','authenticated','person-pending-child@invalid.test',now(),now(),now(),'{}','{}'),
 ('99000000-0000-4000-8000-000000000004','authenticated','authenticated','person-pending-adult@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(id,person_id,auth_user_id,status,revoked_at) values
 ('91000000-0000-4000-8000-000000000301','91000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000001','active',null),
 ('91000000-0000-4000-8000-000000000302','91000000-0000-4000-8000-000000000002','99000000-0000-4000-8000-000000000002','draft',null),
 ('91000000-0000-4000-8000-000000000304','91000000-0000-4000-8000-000000000004','99000000-0000-4000-8000-000000000004','draft',null);

insert into public.institution_roles(id,institution_id,code,name,is_system,status) values
 ('91000000-0000-4000-8000-000000000401','91000000-0000-4000-8000-000000000101','teacher-a','Teacher A',false,'active'),
 ('91000000-0000-4000-8000-000000000402','91000000-0000-4000-8000-000000000102','teacher-b','Teacher B',false,'active'),
 ('91000000-0000-4000-8000-000000000403','91000000-0000-4000-8000-000000000101','assistant-a','Assistant A',false,'active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,scope_group_id,revoked_at) values
 ('91000000-0000-4000-8000-000000000501','91000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000101','teacher-a','active','group','91000000-0000-4000-8000-000000000011','91000000-0000-4000-8000-000000000021',null),
 ('91000000-0000-4000-8000-000000000502','91000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000102','teacher-b','active','institution',null,null,null),
 ('91000000-0000-4000-8000-000000000503','91000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000101','assistant-a','inactive','institution',null,null,null),
 ('91000000-0000-4000-8000-000000000504','91000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000101','assistant-a','active','institution',null,null,now()),
 ('91000000-0000-4000-8000-000000000505','91000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000101','teacher-a','active','institution',null,null,null),
 ('91000000-0000-4000-8000-000000000506','91000000-0000-4000-8000-000000000006','91000000-0000-4000-8000-000000000102','teacher-b','active','institution',null,null,null);
insert into public.institution_role_assignments(id,membership_id,role_id,scope_kind,scope_unit_id,scope_group_id,starts_at,expires_at,status) values
 ('91000000-0000-4000-8000-000000000601','91000000-0000-4000-8000-000000000501','91000000-0000-4000-8000-000000000401','group','91000000-0000-4000-8000-000000000011','91000000-0000-4000-8000-000000000021',now()-interval '1 day',now()+interval '1 day','active'),
 ('91000000-0000-4000-8000-000000000602','91000000-0000-4000-8000-000000000502','91000000-0000-4000-8000-000000000402','institution',null,null,now()-interval '1 day',now()+interval '1 day','active'),
 ('91000000-0000-4000-8000-000000000603','91000000-0000-4000-8000-000000000503','91000000-0000-4000-8000-000000000403','institution',null,null,now()-interval '1 day',now()+interval '1 day','active'),
 ('91000000-0000-4000-8000-000000000604','91000000-0000-4000-8000-000000000504','91000000-0000-4000-8000-000000000403','institution',null,null,now()-interval '1 day',now()+interval '1 day','active'),
 ('91000000-0000-4000-8000-000000000607','91000000-0000-4000-8000-000000000501','91000000-0000-4000-8000-000000000403','institution',null,null,now()-interval '2 days',now()-interval '1 day','active'),
 ('91000000-0000-4000-8000-000000000608','91000000-0000-4000-8000-000000000501','91000000-0000-4000-8000-000000000403','unit','91000000-0000-4000-8000-000000000011',null,now()-interval '1 day',now()+interval '1 day','inactive'),
 ('91000000-0000-4000-8000-000000000605','91000000-0000-4000-8000-000000000505','91000000-0000-4000-8000-000000000401','institution',null,null,now()-interval '1 day',now()+interval '1 day','active'),
 ('91000000-0000-4000-8000-000000000606','91000000-0000-4000-8000-000000000506','91000000-0000-4000-8000-000000000402','institution',null,null,now()-interval '1 day',now()+interval '1 day','active');

insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('91000000-0000-4000-8000-000000000701','91000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000101','active'),
 ('91000000-0000-4000-8000-000000000702','91000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000102','active'),
 ('91000000-0000-4000-8000-000000000703','91000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000103','archived');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at,revoked_at) values
 ('91000000-0000-4000-8000-000000000711','91000000-0000-4000-8000-000000000701','91000000-0000-4000-8000-000000000011','active','91000000-0000-4000-8000-000000000001',now(),null),
 ('91000000-0000-4000-8000-000000000712','91000000-0000-4000-8000-000000000702','91000000-0000-4000-8000-000000000012','pending',null,null,null),
 ('91000000-0000-4000-8000-000000000713','91000000-0000-4000-8000-000000000701','91000000-0000-4000-8000-000000000013','active','91000000-0000-4000-8000-000000000001',now(),null),
 ('91000000-0000-4000-8000-000000000714','91000000-0000-4000-8000-000000000701','91000000-0000-4000-8000-000000000014','active','91000000-0000-4000-8000-000000000001',now(),now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status,starts_at,ends_at) values
 ('91000000-0000-4000-8000-000000000721','91000000-0000-4000-8000-000000000711','91000000-0000-4000-8000-000000000021','active',now()-interval '1 day',now()+interval '1 day'),
 ('91000000-0000-4000-8000-000000000722','91000000-0000-4000-8000-000000000712','91000000-0000-4000-8000-000000000022','active',now()-interval '1 day',now()+interval '1 day'),
 ('91000000-0000-4000-8000-000000000723','91000000-0000-4000-8000-000000000713','91000000-0000-4000-8000-000000000023','active',now()-interval '1 day',now()+interval '1 day'),
 ('91000000-0000-4000-8000-000000000724','91000000-0000-4000-8000-000000000711','91000000-0000-4000-8000-000000000024','inactive',now()-interval '1 day',now()+interval '1 day'),
 ('91000000-0000-4000-8000-000000000725','91000000-0000-4000-8000-000000000711','91000000-0000-4000-8000-000000000025','active',now()-interval '2 days',now()-interval '1 day');

-- Corrupted hierarchy contraproofs exist only inside this rollback-only fixture.
set local session_replication_role='replica';
insert into public.institution_role_assignments(id,membership_id,role_id,scope_kind,scope_unit_id,scope_group_id,starts_at,expires_at,status) values
 ('91000000-0000-4000-8000-000000000609','91000000-0000-4000-8000-000000000501','91000000-0000-4000-8000-000000000403','group','91000000-0000-4000-8000-000000000012','91000000-0000-4000-8000-000000000022',now()-interval '1 day',now()+interval '1 day','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at,revoked_at) values
 ('91000000-0000-4000-8000-000000000715','91000000-0000-4000-8000-000000000701','91000000-0000-4000-8000-000000000012','active','91000000-0000-4000-8000-000000000001',now(),null);
insert into public.child_group_links(id,child_unit_link_id,group_id,status,starts_at,ends_at) values
 ('91000000-0000-4000-8000-000000000726','91000000-0000-4000-8000-000000000711','91000000-0000-4000-8000-000000000022','active',now()-interval '1 day',now()+interval '1 day');
set local session_replication_role='origin';
select is(current_setting('session_replication_role'),'origin',
 'fixture-only trigger bypass is restored before exercising the RPC');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select id,'authenticated','authenticated',email,now(),now(),now(),'{}','{}' from (values
 ('92000000-0000-4000-8000-000000000001'::uuid,'person-owner-platform@invalid.test'),
 ('92000000-0000-4000-8000-000000000002'::uuid,'person-owner-scope@invalid.test'),
 ('92000000-0000-4000-8000-000000000003'::uuid,'person-operations@invalid.test'),
 ('92000000-0000-4000-8000-000000000004'::uuid,'person-auditor@invalid.test'),
 ('92000000-0000-4000-8000-000000000005'::uuid,'person-support@invalid.test'),
 ('92000000-0000-4000-8000-000000000006'::uuid,'person-content@invalid.test'),
 ('92000000-0000-4000-8000-000000000007'::uuid,'person-cross-app@invalid.test'),
 ('92000000-0000-4000-8000-000000000008'::uuid,'person-expired@invalid.test'),
 ('92000000-0000-4000-8000-000000000009'::uuid,'person-link-s@invalid.test'),
 ('92000000-0000-4000-8000-00000000000a'::uuid,'person-link-r@invalid.test'),
 ('92000000-0000-4000-8000-00000000000b'::uuid,'person-member-s@invalid.test'),
 ('92000000-0000-4000-8000-00000000000c'::uuid,'person-member-r@invalid.test')
) actor(id,email);
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('93000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000001',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-000000000003','92000000-0000-4000-8000-000000000002',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-000000000004','92000000-0000-4000-8000-000000000003',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-000000000005','92000000-0000-4000-8000-000000000004',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-000000000006','92000000-0000-4000-8000-000000000005',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-000000000007','92000000-0000-4000-8000-000000000006',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-000000000008','92000000-0000-4000-8000-000000000007',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-000000000009','92000000-0000-4000-8000-000000000008',now(),now(),'aal2',now()-interval '1 minute'),
 ('93000000-0000-4000-8000-00000000000a','92000000-0000-4000-8000-000000000009',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-00000000000b','92000000-0000-4000-8000-00000000000a',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-00000000000c','92000000-0000-4000-8000-00000000000b',now(),now(),'aal2',now()+interval '1 hour'),
 ('93000000-0000-4000-8000-00000000000d','92000000-0000-4000-8000-00000000000c',now(),now(),'aal2',now()+interval '1 hour');

insert into app_private.superadmin_internal_identities(id)
select id from (values
 ('94000000-0000-4000-8000-000000000001'::uuid),('94000000-0000-4000-8000-000000000002'::uuid),
 ('94000000-0000-4000-8000-000000000003'::uuid),('94000000-0000-4000-8000-000000000004'::uuid),
 ('94000000-0000-4000-8000-000000000005'::uuid),('94000000-0000-4000-8000-000000000006'::uuid),
 ('94000000-0000-4000-8000-000000000009'::uuid),('94000000-0000-4000-8000-00000000000a'::uuid),
 ('94000000-0000-4000-8000-00000000000b'::uuid),('94000000-0000-4000-8000-00000000000c'::uuid)
) identity_record(id);
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status,suspended_at,revoked_at) values
 ('95000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','active',null,null),
 ('95000000-0000-4000-8000-000000000002','94000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000002','active',null,null),
 ('95000000-0000-4000-8000-000000000003','94000000-0000-4000-8000-000000000003','92000000-0000-4000-8000-000000000003','active',null,null),
 ('95000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000004','92000000-0000-4000-8000-000000000004','active',null,null),
 ('95000000-0000-4000-8000-000000000005','94000000-0000-4000-8000-000000000005','92000000-0000-4000-8000-000000000005','active',null,null),
 ('95000000-0000-4000-8000-000000000006','94000000-0000-4000-8000-000000000006','92000000-0000-4000-8000-000000000006','active',null,null),
 ('95000000-0000-4000-8000-000000000009','94000000-0000-4000-8000-000000000009','92000000-0000-4000-8000-000000000009','suspended',now(),null),
 ('95000000-0000-4000-8000-00000000000a','94000000-0000-4000-8000-00000000000a','92000000-0000-4000-8000-00000000000a','revoked',null,now()),
 ('95000000-0000-4000-8000-00000000000b','94000000-0000-4000-8000-00000000000b','92000000-0000-4000-8000-00000000000b','active',null,null),
 ('95000000-0000-4000-8000-00000000000c','94000000-0000-4000-8000-00000000000c','92000000-0000-4000-8000-00000000000c','active',null,null);
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status,suspended_at,revoked_at)
select m.id,m.identity_id,r.id,m.scope_kind::app_private.superadmin_internal_scope_kind,m.scope_institution_id,m.status::app_private.superadmin_internal_membership_status,m.suspended_at,m.revoked_at
from (values
 ('96000000-0000-4000-8000-000000000001'::uuid,'94000000-0000-4000-8000-000000000001'::uuid,'owner','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
 ('96000000-0000-4000-8000-000000000002'::uuid,'94000000-0000-4000-8000-000000000002'::uuid,'owner','institution','91000000-0000-4000-8000-000000000101'::uuid,'active',null::timestamptz,null::timestamptz),
 ('96000000-0000-4000-8000-000000000003'::uuid,'94000000-0000-4000-8000-000000000003'::uuid,'operations','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
 ('96000000-0000-4000-8000-000000000004'::uuid,'94000000-0000-4000-8000-000000000004'::uuid,'auditor','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
 ('96000000-0000-4000-8000-000000000005'::uuid,'94000000-0000-4000-8000-000000000005'::uuid,'support','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
 ('96000000-0000-4000-8000-000000000006'::uuid,'94000000-0000-4000-8000-000000000006'::uuid,'content','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
 ('96000000-0000-4000-8000-000000000009'::uuid,'94000000-0000-4000-8000-000000000009'::uuid,'owner','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
 ('96000000-0000-4000-8000-00000000000a'::uuid,'94000000-0000-4000-8000-00000000000a'::uuid,'owner','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
 ('96000000-0000-4000-8000-00000000000b'::uuid,'94000000-0000-4000-8000-00000000000b'::uuid,'owner','platform',null::uuid,'suspended',now(),null::timestamptz),
 ('96000000-0000-4000-8000-00000000000c'::uuid,'94000000-0000-4000-8000-00000000000c'::uuid,'owner','platform',null::uuid,'revoked',null::timestamptz,now())
) m(id,identity_id,role_code,scope_kind,scope_institution_id,status,suspended_at,revoked_at)
join public.platform_roles r on r.code=m.role_code;

create temporary table person_detail_acceptance_responses(sequence_number integer primary key,body jsonb not null);
grant select,insert on person_detail_acceptance_responses to authenticated;

-- Owner platform: stable reads and the three coarse Auth states.
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000001','session_id','93000000-0000-4000-8000-000000000002','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into person_detail_acceptance_responses values
 (10,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')),
 (11,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')),
 (12,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000002')),
 (13,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000003')),
 (14,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000004'));
reset role;
select ok((select body->'data' from person_detail_acceptance_responses where sequence_number=10)=(select body->'data' from person_detail_acceptance_responses where sequence_number=11),
 'two unchanged Person detail reads are stable');
select ok((select (body->>'ok')::boolean and body->'error'='null'::jsonb
 and (select array_agg(key order by key) from jsonb_object_keys(body->'data') key)=array['auth_link','child_contexts','display_name','first_name','id','last_name','legal_name','memberships','status','type','updated_at']::text[]
 from person_detail_acceptance_responses where sequence_number=10),
 'adult detail has the exact minimized root shape');
select ok((select jsonb_typeof(body#>'{data,id}')='string'
 and jsonb_typeof(body#>'{data,first_name}')='string'
 and jsonb_typeof(body#>'{data,last_name}')='string'
 and jsonb_typeof(body#>'{data,display_name}')='string'
 and jsonb_typeof(body#>'{data,legal_name}') in('string','null')
 and jsonb_typeof(body#>'{data,type}')='string'
 and jsonb_typeof(body#>'{data,status}')='string'
 and jsonb_typeof(body#>'{data,auth_link}')='string'
 and jsonb_typeof(body#>'{data,memberships}')='array'
 and jsonb_typeof(body#>'{data,child_contexts}')='array'
 and jsonb_typeof(body#>'{data,updated_at}')='string'
 from person_detail_acceptance_responses where sequence_number=10),
 'Person detail exposes the exact contracted root JSON types');
select ok((select body#>>'{data,type}'='adult' and body#>>'{data,auth_link}'='linked'
 and jsonb_array_length(body#>'{data,memberships}')=2 and body#>'{data,child_contexts}'='[]'::jsonb
 and (select bool_and((select array_agg(key order by key) from jsonb_object_keys(item) key)=array['group_id','group_name','id','institution_id','institution_name','is_platform','membership_id','role','unit_id','unit_name']::text[]) from jsonb_array_elements(body#>'{data,memberships}') item)
 from person_detail_acceptance_responses where sequence_number=10),
 'adult exposes only active hierarchical memberships and linked coarse Auth');
select ok((select body#>>'{data,type}'='child' and body#>>'{data,auth_link}'='pending'
 and jsonb_array_length(body#>'{data,memberships}')=2 and jsonb_array_length(body#>'{data,child_contexts}')=2
 and (select bool_and(item->>'role'='student' and item->'membership_id'='null'::jsonb) from jsonb_array_elements(body#>'{data,memberships}') item)
 and (select bool_and((select array_agg(key order by key) from jsonb_object_keys(item) key)=array['child_group_link_id','child_unit_link_id','group_id','group_name','id','institution_id','institution_name','unit_id','unit_name']::text[]) from jsonb_array_elements(body#>'{data,child_contexts}') item)
 from person_detail_acceptance_responses where sequence_number=12),
 'child exposes only coarse pending Auth and exact active contexts');
select ok(
  (select body#>>'{data,memberships,0,institution_id}'='91000000-0000-4000-8000-000000000101'
     and body#>>'{data,memberships,0,unit_id}'='91000000-0000-4000-8000-000000000011'
     and body#>>'{data,memberships,0,group_id}'='91000000-0000-4000-8000-000000000021'
   from person_detail_acceptance_responses where sequence_number=10)
  and (select body#>>'{data,child_contexts,0,institution_id}'='91000000-0000-4000-8000-000000000101'
     and body#>>'{data,child_contexts,0,unit_id}'='91000000-0000-4000-8000-000000000011'
     and body#>>'{data,child_contexts,0,group_id}'='91000000-0000-4000-8000-000000000021'
     and (select bool_and(
       (select array_agg(key order by key) from jsonb_object_keys(item) key)=
       array['group_id','group_name','id','institution_id','institution_name','is_platform','membership_id','role','unit_id','unit_name']::text[])
       from jsonb_array_elements(body#>'{data,memberships}') item)
   from person_detail_acceptance_responses where sequence_number=12),
  'adult and child hierarchy is server-derived and child membership shape is exact');
select ok(
  (select not (body::text like any(array[
       '%91000000-0000-4000-8000-000000000503%',
       '%91000000-0000-4000-8000-000000000504%',
       '%91000000-0000-4000-8000-000000000603%',
       '%91000000-0000-4000-8000-000000000604%',
       '%91000000-0000-4000-8000-000000000607%',
       '%91000000-0000-4000-8000-000000000608%',
       '%91000000-0000-4000-8000-000000000609%'
     ]))
   from person_detail_acceptance_responses where sequence_number=10)
  and (select body#>>'{data,child_contexts,0,child_unit_link_id}'=
       '91000000-0000-4000-8000-000000000711'
     and body#>>'{data,child_contexts,0,child_group_link_id}'=
       '91000000-0000-4000-8000-000000000721'
     and not (body::text like any(array[
       '%91000000-0000-4000-8000-000000000703%',
       '%91000000-0000-4000-8000-000000000713%',
       '%91000000-0000-4000-8000-000000000714%',
       '%91000000-0000-4000-8000-000000000715%',
       '%91000000-0000-4000-8000-000000000723%',
       '%91000000-0000-4000-8000-000000000724%',
       '%91000000-0000-4000-8000-000000000725%',
       '%91000000-0000-4000-8000-000000000726%'
     ])) from person_detail_acceptance_responses where sequence_number=12),
  'inactive, revoked, expired, cross-hierarchy, and secondary paths are excluded deterministically');
select ok(
  (select bool_and(
      jsonb_typeof(item->'id')='string'
      and jsonb_typeof(item->'membership_id') in('string','null')
      and jsonb_typeof(item->'institution_id')='string'
      and jsonb_typeof(item->'institution_name')='string'
      and jsonb_typeof(item->'unit_id') in('string','null')
      and jsonb_typeof(item->'unit_name') in('string','null')
      and jsonb_typeof(item->'group_id') in('string','null')
      and jsonb_typeof(item->'group_name') in('string','null')
      and jsonb_typeof(item->'role')='string'
      and jsonb_typeof(item->'is_platform')='boolean')
   from person_detail_acceptance_responses response,
     lateral jsonb_array_elements(response.body#>'{data,memberships}') item
   where response.sequence_number in(10,12))
  and (select bool_and(
      jsonb_typeof(item->'id')='string'
      and jsonb_typeof(item->'institution_id')='string'
      and jsonb_typeof(item->'institution_name')='string'
      and jsonb_typeof(item->'unit_id') in('string','null')
      and jsonb_typeof(item->'unit_name') in('string','null')
      and jsonb_typeof(item->'group_id') in('string','null')
      and jsonb_typeof(item->'group_name') in('string','null')
      and jsonb_typeof(item->'child_unit_link_id') in('string','null')
      and jsonb_typeof(item->'child_group_link_id') in('string','null'))
   from person_detail_acceptance_responses response,
     lateral jsonb_array_elements(response.body#>'{data,child_contexts}') item
   where response.sequence_number=12),
  'every nested membership and child context value has the minimized contract type');
select ok((select body#>>'{data,type}'='service' and body#>>'{data,auth_link}'='unlinked' and body#>'{data,memberships}'='[]'::jsonb and body#>'{data,child_contexts}'='[]'::jsonb from person_detail_acceptance_responses where sequence_number=13)
 and (select body#>>'{data,auth_link}'='pending' from person_detail_acceptance_responses where sequence_number=14),
 'service and pending adult preserve coarse Auth without context leakage');

-- Owner AAL1 and institution scope.
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000001','session_id','93000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into person_detail_acceptance_responses values(15,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_MFA_REQUIRED' from person_detail_acceptance_responses where sequence_number=15), 'Owner AAL1 is denied');
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000002','session_id','93000000-0000-4000-8000-000000000003','aal','aal2','role','authenticated')::text,true);
set local role authenticated; insert into person_detail_acceptance_responses values
 (16,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')),
 (17,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000002')),
 (18,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000003')),
 (19,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000006')),
 (20,public.superadmin_person_detail_v2('91000000-0000-4000-8000-00000000ffff')),
 (21,public.superadmin_person_detail_v2(null)); reset role;
select ok((select jsonb_array_length(body#>'{data,memberships}')=1 and body#>>'{data,memberships,0,institution_id}'='91000000-0000-4000-8000-000000000101' from person_detail_acceptance_responses where sequence_number=16),
 'institution scope filters adult memberships to its Institution');
select ok((select jsonb_array_length(body#>'{data,child_contexts}')=1 and jsonb_array_length(body#>'{data,memberships}')=1 and body#>>'{data,child_contexts,0,institution_id}'='91000000-0000-4000-8000-000000000101' and body#>>'{data,memberships,0,institution_id}'='91000000-0000-4000-8000-000000000101' from person_detail_acceptance_responses where sequence_number=17),
 'institution scope filters child contexts to its Institution');
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED' and (body#>>'{error,http_status}')::integer=403 from person_detail_acceptance_responses where sequence_number=18)
 and (select (body->'error')-'correlation_id' from person_detail_acceptance_responses where sequence_number=18)=(select (body->'error')-'correlation_id' from person_detail_acceptance_responses where sequence_number=19)
 and (select (body->'error')-'correlation_id' from person_detail_acceptance_responses where sequence_number=19)=(select (body->'error')-'correlation_id' from person_detail_acceptance_responses where sequence_number=20)
 and (select (body->'error')-'correlation_id' from person_detail_acceptance_responses where sequence_number=20)=(select (body->'error')-'correlation_id' from person_detail_acceptance_responses where sequence_number=21),
 'service, cross-scope, missing and null Person IDs are indistinguishable');

-- Other roles fail closed.
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000003','session_id','93000000-0000-4000-8000-000000000004','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(22,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000004','session_id','93000000-0000-4000-8000-000000000005','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(23,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000005','session_id','93000000-0000-4000-8000-000000000006','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(24,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000006','session_id','93000000-0000-4000-8000-000000000007','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(25,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select ok(
  not exists(select 1 from person_detail_acceptance_responses
    where sequence_number in(22,23,24,25)
      and body#>>'{error,code}' is distinct from 'SAI_PERMISSION_DENIED')
  and (select count(*)=4 from audit.audit_logs log_record
    join person_detail_acceptance_responses response
      on response.sequence_number in(22,23,24,25)
     and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
    where log_record.hash_version=2 and log_record.outcome='denied'
      and log_record.reason_code='SAI_PERMISSION_DENIED'),
 'Operations, Auditor, Support, and Content fail closed with one correlated audit each');

-- Invalid session, internal lifecycle, and cross-app.
create temporary table person_invalid_session_audit(value bigint not null);
insert into person_invalid_session_audit select count(*) from audit.audit_logs where action_code='person.detail';
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000008','session_id','93000000-0000-4000-8000-000000000009','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(26,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000001','session_id','93000000-0000-4000-8000-000000000003','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(27,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_SESSION_INVALID' from person_detail_acceptance_responses where sequence_number=26) and (select body#>>'{error,code}'='SAI_SESSION_INVALID' from person_detail_acceptance_responses where sequence_number=27)
 and (select value from person_invalid_session_audit)=(select count(*) from audit.audit_logs where action_code='person.detail'),
 'expired and cross-user sessions fail before audit');
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000009','session_id','93000000-0000-4000-8000-00000000000a','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(28,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-00000000000a','session_id','93000000-0000-4000-8000-00000000000b','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(29,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-00000000000b','session_id','93000000-0000-4000-8000-00000000000c','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(30,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-00000000000c','session_id','93000000-0000-4000-8000-00000000000d','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(31,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from person_detail_acceptance_responses where sequence_number=28)
 and (select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from person_detail_acceptance_responses where sequence_number=29)
 and (select body#>>'{error,code}'='SAI_MEMBERSHIP_SUSPENDED' from person_detail_acceptance_responses where sequence_number=30)
 and (select body#>>'{error,code}'='SAI_MEMBERSHIP_REVOKED' from person_detail_acceptance_responses where sequence_number=31)
 and (select count(*)=4 from audit.audit_logs l join person_detail_acceptance_responses r on r.sequence_number in(28,29,30,31) and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.outcome='denied'),
 'suspended/revoked internal links and memberships create 1:1 v2 denial audit');
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000007','session_id','93000000-0000-4000-8000-000000000008','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(32,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select ok((select count(*)=1 from audit.audit_logs l join person_detail_acceptance_responses r on r.sequence_number=32 and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=3 and l.actor_kind='auth_session' and l.outcome='denied'),
 'valid Auth session without internal link creates one v3 denial');

-- Role/capability/grant lifecycle, restored between calls.
update public.platform_role_permissions rp set status='inactive',revoked_at=null from public.platform_roles r,public.platform_permissions p where rp.role_id=r.id and rp.permission_id=p.id and r.code='owner' and p.code='people.read';
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000001','session_id','93000000-0000-4000-8000-000000000002','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(33,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
update public.platform_role_permissions rp set status='active',revoked_at=null from public.platform_roles r,public.platform_permissions p where rp.role_id=r.id and rp.permission_id=p.id and r.code='owner' and p.code='people.read';
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from person_detail_acceptance_responses where sequence_number=33), 'inactive people.read grant fails closed');
update public.platform_role_permissions rp set status='active',revoked_at=now() from public.platform_roles r,public.platform_permissions p where rp.role_id=r.id and rp.permission_id=p.id and r.code='owner' and p.code='people.read';
set local role authenticated; insert into person_detail_acceptance_responses values(38,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
update public.platform_role_permissions rp set status='active',revoked_at=null from public.platform_roles r,public.platform_permissions p where rp.role_id=r.id and rp.permission_id=p.id and r.code='owner' and p.code='people.read';
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from person_detail_acceptance_responses where sequence_number=38)
 and (select count(*)=1 from audit.audit_logs log_record join person_detail_acceptance_responses response on response.sequence_number=38 and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid where log_record.hash_version=2 and log_record.outcome='denied' and log_record.reason_code='SAI_PERMISSION_DENIED'),
 'revoked people.read grant fails closed with exactly one correlated v2 audit');
update public.platform_permissions set status='inactive' where code='people.read';
set local role authenticated; insert into person_detail_acceptance_responses values(34,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
update public.platform_permissions set status='active' where code='people.read';
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from person_detail_acceptance_responses where sequence_number=34), 'inactive people.read capability fails closed');
update public.platform_role_permissions rp set effect='deny' from public.platform_roles r,public.platform_permissions p where rp.role_id=r.id and rp.permission_id=p.id and r.code='owner' and p.code='people.read';
set local role authenticated; insert into person_detail_acceptance_responses values(35,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
update public.platform_role_permissions rp set effect='allow' from public.platform_roles r,public.platform_permissions p where rp.role_id=r.id and rp.permission_id=p.id and r.code='owner' and p.code='people.read';
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from person_detail_acceptance_responses where sequence_number=35), 'deny effect on people.read fails closed');

-- An inactive non-Owner role is rejected before capability use.
update public.platform_roles set status='inactive' where code='operations';
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000003','session_id','93000000-0000-4000-8000-000000000004','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into person_detail_acceptance_responses values(37,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001'));
reset role;
update public.platform_roles set status='active' where code='operations';
select ok(
  (select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
   from person_detail_acceptance_responses where sequence_number=37)
  and (select count(*)=1
    from audit.audit_logs log_record
    join person_detail_acceptance_responses response
      on response.sequence_number=37
     and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
    where log_record.hash_version=2
      and log_record.outcome='denied'
      and log_record.reason_code='SAI_PERMISSION_DENIED'),
  'inactive platform role fails closed with exactly one correlated v2 audit');
select ok(
  (select count(*)=5
   from audit.audit_logs log_record
   join person_detail_acceptance_responses response
     on response.sequence_number in(33,34,35,37,38)
    and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
   where log_record.hash_version=2
     and log_record.outcome='denied'
     and log_record.reason_code='SAI_PERMISSION_DENIED'),
  'role, capability, inactive/revoked grant, and deny effect each create one correlated v2 audit');
-- Reload and minimization.
update public.people set display_name='Adult Alpha Reloaded',updated_at=now()+interval '1 second' where id='91000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000001','session_id','93000000-0000-4000-8000-000000000002','aal','aal2','role','authenticated')::text,true); set local role authenticated; insert into person_detail_acceptance_responses values(36,public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{data,display_name}'='Adult Alpha' from person_detail_acceptance_responses where sequence_number=10) and (select body#>>'{data,display_name}'='Adult Alpha Reloaded' from person_detail_acceptance_responses where sequence_number=36),
 'reload observes persisted Person changes');
select ok(not exists(select 1 from person_detail_acceptance_responses r, lateral jsonb_object_keys(case when jsonb_typeof(r.body->'data')='object' then r.body->'data' else '{}'::jsonb end) key where r.body->>'ok'='true' and key in('date_of_birth','contacts','address','document','auth_user_id','email','platform_memberships','guardian_summary','session_id','session_id_hash','created_at')),
 'all success payloads omit forbidden PII, platform, guardian, Auth, and session fields');

select ok(
  (select count(*)=6 from audit.audit_logs
   where action_code='person.detail' and outcome='success'
     and actor_internal_membership_id='96000000-0000-4000-8000-000000000001'
     and institution_id is null and object_type='person')
  and (select count(*)=2 from audit.audit_logs
   where action_code='person.detail' and outcome='success'
     and actor_internal_membership_id='96000000-0000-4000-8000-000000000002'
     and institution_id='91000000-0000-4000-8000-000000000101'
     and object_type='person'),
  'success audit distinguishes platform-global and validated institution scope');
select ok((select count(*)=8 from audit.audit_logs where action_code='person.detail' and outcome='success')
 and not exists(select 1 from audit.audit_logs where action_code='person.detail' and outcome='success' and (hash_version<>2 or payload_contract_version<>2 or permission_code<>'people.read' or object_type<>'person' or object_id is null or reason_code is not null or before_json is not null or after_json is not null or not app_private.audit_verify_entry(id))),
 'Person detail successes are minimized digest-valid v2 audit events');
select ok((select count(*)=18 from audit.audit_logs where action_code='person.detail' and outcome='denied' and hash_version=2)
 and (select count(*)=1 from audit.audit_logs where action_code='person.detail' and outcome='denied' and hash_version=3)
 and not exists(select 1 from audit.audit_logs where action_code='person.detail' and outcome='denied' and (reason_code is null or before_json is not null or after_json is not null or object_id is not null or institution_id is not null or not app_private.audit_verify_entry(id))),
 'Person detail denials are minimized digest-valid v2/v3 audit events');

create function pg_temp.fail_person_detail_audit() returns trigger language plpgsql as $$ begin raise exception using message='forced person detail audit failure'; end $$;
create trigger fail_person_detail_audit before insert on audit.audit_logs for each row when(new.action_code='person.detail') execute function pg_temp.fail_person_detail_audit();
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000001','session_id','93000000-0000-4000-8000-000000000002','aal','aal2','role','authenticated')::text,true); set local role authenticated;
select throws_ok($$select public.superadmin_person_detail_v2('91000000-0000-4000-8000-000000000001')$$,'P0001','forced person detail audit failure','adversarial audit append failure aborts Person detail');
reset role; drop trigger fail_person_detail_audit on audit.audit_logs;
select ok((select bool_and(app_private.audit_verify_entry(id)) from audit.audit_logs where action_code='person.detail'),
 'all Person detail audit entries remain in the verified append-only chain');

select * from finish();
rollback;
