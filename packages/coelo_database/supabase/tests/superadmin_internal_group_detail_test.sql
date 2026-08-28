begin;

create extension if not exists pgtap with schema extensions;

select plan(33);

select ok(
  to_regprocedure('public.superadmin_group_detail_v2(uuid)') is not null,
  'group detail v2 wrapper exists');

create temporary table group_detail_test_snapshot(value jsonb not null);
create temporary table group_detail_test_responses(
  sequence_number integer primary key,
  body jsonb not null
);

grant select on group_detail_test_snapshot to authenticated;
grant select, insert on group_detail_test_responses to authenticated;

insert into group_detail_test_snapshot(value)
select jsonb_build_object(
  'identities', (select count(*) from app_private.superadmin_internal_identities),
  'auth_links', (select count(*) from app_private.superadmin_internal_auth_links),
  'memberships', (select count(*) from app_private.superadmin_internal_memberships),
  'institutions', (select count(*) from public.institutions),
  'units', (select count(*) from public.units),
  'groups', (select count(*) from public.groups),
  'audit', (select count(*) from audit.audit_logs)
);

select set_config('request.jwt.claims', '{}', true);
set local role authenticated;

do $test$
begin
  if to_regprocedure('public.superadmin_group_detail_v2(uuid)') is not null then
    execute
      'insert into group_detail_test_responses(sequence_number, body)
       values ($1, public.superadmin_group_detail_v2($2))'
      using 1, '81000000-0000-4000-8000-000000000001'::uuid;
    execute
      'insert into group_detail_test_responses(sequence_number, body)
       values ($1, public.superadmin_group_detail_v2($2))'
      using 2, '81000000-0000-4000-8000-000000000001'::uuid;
  end if;
end
$test$;

reset role;

select is(
  (select count(*) from group_detail_test_responses),
  2::bigint,
  'two no-session calls return JSON without raising');

select ok(
  not exists(
    select 1
    from group_detail_test_responses response
    where (
      select array_agg(key order by key)
      from jsonb_object_keys(response.body) key
    ) <> array['data', 'error', 'ok']::text[]
      or (
        select array_agg(key order by key)
        from jsonb_object_keys(response.body -> 'error') key
      ) <> array['code', 'correlation_id', 'http_status', 'message']::text[]
  ),
  'group detail envelopes expose exact allowlisted root and error keys');

select ok(
  not exists(
    select 1
    from group_detail_test_responses response
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
   from group_detail_test_responses),
  'each rejected call receives a distinct correlation id');

select is(
  (select value from group_detail_test_snapshot),
  (select jsonb_build_object(
    'identities', (select count(*) from app_private.superadmin_internal_identities),
    'auth_links', (select count(*) from app_private.superadmin_internal_auth_links),
    'memberships', (select count(*) from app_private.superadmin_internal_memberships),
    'institutions', (select count(*) from public.institutions),
    'units', (select count(*) from public.units),
    'groups', (select count(*) from public.groups),
    'audit', (select count(*) from audit.audit_logs)
  )),
  'calls without a validated session create no domain, identity, or audit row');

select ok(
  coalesce(has_function_privilege(
    'authenticated',
    to_regprocedure('public.superadmin_group_detail_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'anon',
    to_regprocedure('public.superadmin_group_detail_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'service_role',
    to_regprocedure('public.superadmin_group_detail_v2(uuid)'),
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
      to_regprocedure('public.superadmin_group_detail_v2(uuid)')
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'only authenticated can execute the group detail wrapper');

select ok(
  to_regprocedure('app_private.superadmin_group_detail_payload_v2(uuid)') is not null
  and not coalesce(has_function_privilege(
    'anon',
    to_regprocedure('app_private.superadmin_group_detail_payload_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'authenticated',
    to_regprocedure('app_private.superadmin_group_detail_payload_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'service_role',
    to_regprocedure('app_private.superadmin_group_detail_payload_v2(uuid)'),
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
      to_regprocedure('app_private.superadmin_group_detail_payload_v2(uuid)')
      and helper_acl.grantee = 0
      and helper_acl.privilege_type = 'EXECUTE'
  ),
  'the private group detail helper is not executable by client or service roles');

select ok(
  (select wrapper.prosecdef and wrapper.provolatile='v'
      and owner_role.rolname='postgres'
      and coalesce(wrapper.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]
    from pg_proc wrapper
    join pg_roles owner_role on owner_role.oid=wrapper.proowner
    where wrapper.oid='public.superadmin_group_detail_v2(uuid)'::regprocedure)
  and
  (select helper.prosecdef and helper.provolatile='s'
      and owner_role.rolname='postgres'
      and coalesce(helper.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]
    from pg_proc helper
    join pg_roles owner_role on owner_role.oid=helper.proowner
    where helper.oid=
      'app_private.superadmin_group_detail_payload_v2(uuid)'::regprocedure)
  and pg_get_functiondef(
    'public.superadmin_group_detail_v2(uuid)'::regprocedure
  ) ~* 'for[[:space:]]+share[[:space:]]+of[[:space:]]+group_record[[:space:]]*,[[:space:]]*unit_record[[:space:]]*,[[:space:]]*institution',
  'wrapper/helper metadata and target FOR SHARE lock are hardened');


select is(
  (select array_agg(namespace_record.nspname || '.' || procedure_record.proname
      || '(' || oidvectortypes(procedure_record.proargtypes) || ')'
      order by namespace_record.nspname,procedure_record.proname,
        oidvectortypes(procedure_record.proargtypes))
   from pg_proc procedure_record
   join pg_namespace namespace_record
     on namespace_record.oid=procedure_record.pronamespace
   where procedure_record.proname in(
     'superadmin_group_detail_payload_v2','superadmin_group_detail_v2'
   )),
  array[
    'app_private.superadmin_group_detail_payload_v2(uuid)',
    'public.superadmin_group_detail_v2(uuid)'
  ]::text[],
  'the v2 Group detail catalog contains exactly the two approved signatures');

select ok(
  exists(
    select 1 from public.platform_permissions permission_record
    where permission_record.code='groups.read'
      and permission_record.status='active'
      and permission_record.requires_mfa is false
  )
  and (
    select array_agg(role_record.code order by role_record.code)
    from public.platform_role_permissions grant_record
    join public.platform_roles role_record
      on role_record.id=grant_record.role_id
    join public.platform_permissions permission_record
      on permission_record.id=grant_record.permission_id
    where permission_record.code='groups.read'
      and grant_record.effect='allow'
      and grant_record.status='active'
      and grant_record.revoked_at is null
  )=array['operations','owner']::text[]
  and exists(
    select 1 from pg_attribute attribute_record
    where attribute_record.attrelid='public.groups'::regclass
      and attribute_record.attname='unit_id'
      and attribute_record.attnotnull
      and not attribute_record.attisdropped
  )
  and exists(
    select 1 from pg_constraint constraint_record
    where constraint_record.conrelid='public.groups'::regclass
      and constraint_record.conname='groups_unit_institution_fkey'
      and constraint_record.contype='f'
      and constraint_record.convalidated
  ),
  'groups.read grants and the required Group hierarchy constraints are exact');

insert into public.institution_types(id,code,name,status) values
  ('81000000-0000-4000-8000-000000000201','group-detail-school',
   'Group Detail School','active');

insert into public.institutions(
  id,public_name,slug,status,institution_type_id
) values
  ('81000000-0000-4000-8000-000000000101','Group Detail Institution A',
   'group-detail-institution-a','active',
   '81000000-0000-4000-8000-000000000201'),
  ('81000000-0000-4000-8000-000000000102','Group Detail Institution B',
   'group-detail-institution-b','active',
   '81000000-0000-4000-8000-000000000201');

insert into public.units(
  id,institution_id,name,slug,status,institution_type_id
) values
  ('81000000-0000-4000-8000-000000000011',
   '81000000-0000-4000-8000-000000000101','Group Detail Unit A1',
   'group-detail-unit-a1','active','81000000-0000-4000-8000-000000000201'),
  ('81000000-0000-4000-8000-000000000012',
   '81000000-0000-4000-8000-000000000101','Group Detail Unit A2',
   'group-detail-unit-a2','active','81000000-0000-4000-8000-000000000201'),
  ('81000000-0000-4000-8000-000000000013',
   '81000000-0000-4000-8000-000000000102','Group Detail Unit B1',
   'group-detail-unit-b1','active','81000000-0000-4000-8000-000000000201');

insert into public.groups(
  id,institution_id,unit_id,name,group_type,group_type_other_text,status,
  inherit_appearance,inherit_access,inherit_activities,management_version,
  created_at,updated_at
) values
  ('81000000-0000-4000-8000-000000000001',
   '81000000-0000-4000-8000-000000000101',
   '81000000-0000-4000-8000-000000000011','Group Detail Alpha',
   'class',null,'active',true,false,true,1,now(),now()),
  ('81000000-0000-4000-8000-000000000002',
   '81000000-0000-4000-8000-000000000101',
   '81000000-0000-4000-8000-000000000012','Group Detail Lab',
   'other','Laboratorio sintetico','draft',false,true,false,2,now(),now()),
  ('81000000-0000-4000-8000-000000000003',
   '81000000-0000-4000-8000-000000000102',
   '81000000-0000-4000-8000-000000000013','Group Detail Beta',
   'class',null,'active',true,true,true,1,now(),now()),
  ('81000000-0000-4000-8000-000000000005',
   '81000000-0000-4000-8000-000000000101',
   '81000000-0000-4000-8000-000000000011','Group Detail Inactive',
   'class',null,'inactive',true,true,true,1,now(),now()),
  ('81000000-0000-4000-8000-000000000006',
   '81000000-0000-4000-8000-000000000101',
   '81000000-0000-4000-8000-000000000011','Group Detail Suspended',
   'class',null,'suspended',true,true,true,1,now(),now()),
  ('81000000-0000-4000-8000-000000000007',
   '81000000-0000-4000-8000-000000000101',
   '81000000-0000-4000-8000-000000000011','Group Detail Archived',
   'class',null,'archived',true,true,true,1,now(),now());

insert into auth.users(
  id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data
)
select id,'authenticated','authenticated',email,now(),now(),now(),'{}','{}'
from (values
  ('82000000-0000-4000-8000-000000000001'::uuid,'group-detail-ops@invalid.test'),
  ('82000000-0000-4000-8000-000000000002'::uuid,'group-detail-auditor@invalid.test'),
  ('82000000-0000-4000-8000-000000000003'::uuid,'group-detail-owner@invalid.test'),
  ('82000000-0000-4000-8000-000000000004'::uuid,'group-detail-scope@invalid.test'),
  ('82000000-0000-4000-8000-000000000005'::uuid,'group-detail-support@invalid.test'),
  ('82000000-0000-4000-8000-000000000006'::uuid,'group-detail-content@invalid.test'),
  ('82000000-0000-4000-8000-000000000007'::uuid,'group-detail-cross@invalid.test'),
  ('82000000-0000-4000-8000-000000000008'::uuid,'group-detail-expired@invalid.test'),
  ('82000000-0000-4000-8000-000000000009'::uuid,'group-detail-link-s@invalid.test'),
  ('82000000-0000-4000-8000-00000000000a'::uuid,'group-detail-link-r@invalid.test'),
  ('82000000-0000-4000-8000-00000000000b'::uuid,'group-detail-member-s@invalid.test'),
  ('82000000-0000-4000-8000-00000000000c'::uuid,'group-detail-member-r@invalid.test')
) actor(id,email);

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values
  ('83000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-000000000003','82000000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-000000000004','82000000-0000-4000-8000-000000000003',now(),now(),'aal2',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-000000000005','82000000-0000-4000-8000-000000000004',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-000000000006','82000000-0000-4000-8000-000000000005',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-000000000007','82000000-0000-4000-8000-000000000006',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-000000000008','82000000-0000-4000-8000-000000000007',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-000000000009','82000000-0000-4000-8000-000000000008',now(),now(),'aal1',now()-interval '1 minute'),
  ('83000000-0000-4000-8000-00000000000a','82000000-0000-4000-8000-000000000009',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-00000000000b','82000000-0000-4000-8000-00000000000a',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-00000000000c','82000000-0000-4000-8000-00000000000b',now(),now(),'aal1',now()+interval '1 hour'),
  ('83000000-0000-4000-8000-00000000000d','82000000-0000-4000-8000-00000000000c',now(),now(),'aal1',now()+interval '1 hour');

insert into app_private.superadmin_internal_identities(id)
select id from (values
  ('84000000-0000-4000-8000-000000000001'::uuid),
  ('84000000-0000-4000-8000-000000000002'::uuid),
  ('84000000-0000-4000-8000-000000000003'::uuid),
  ('84000000-0000-4000-8000-000000000004'::uuid),
  ('84000000-0000-4000-8000-000000000005'::uuid),
  ('84000000-0000-4000-8000-000000000006'::uuid),
  ('84000000-0000-4000-8000-000000000009'::uuid),
  ('84000000-0000-4000-8000-00000000000a'::uuid),
  ('84000000-0000-4000-8000-00000000000b'::uuid),
  ('84000000-0000-4000-8000-00000000000c'::uuid)
) identity_record(id);

insert into app_private.superadmin_internal_auth_links(
  id,internal_identity_id,auth_user_id,status,suspended_at,revoked_at
) values
  ('85000000-0000-4000-8000-000000000001','84000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001','active',null,null),
  ('85000000-0000-4000-8000-000000000002','84000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000002','active',null,null),
  ('85000000-0000-4000-8000-000000000003','84000000-0000-4000-8000-000000000003','82000000-0000-4000-8000-000000000003','active',null,null),
  ('85000000-0000-4000-8000-000000000004','84000000-0000-4000-8000-000000000004','82000000-0000-4000-8000-000000000004','active',null,null),
  ('85000000-0000-4000-8000-000000000005','84000000-0000-4000-8000-000000000005','82000000-0000-4000-8000-000000000005','active',null,null),
  ('85000000-0000-4000-8000-000000000006','84000000-0000-4000-8000-000000000006','82000000-0000-4000-8000-000000000006','active',null,null),
  ('85000000-0000-4000-8000-000000000009','84000000-0000-4000-8000-000000000009','82000000-0000-4000-8000-000000000009','suspended',now(),null),
  ('85000000-0000-4000-8000-00000000000a','84000000-0000-4000-8000-00000000000a','82000000-0000-4000-8000-00000000000a','revoked',null,now()),
  ('85000000-0000-4000-8000-00000000000b','84000000-0000-4000-8000-00000000000b','82000000-0000-4000-8000-00000000000b','active',null,null),
  ('85000000-0000-4000-8000-00000000000c','84000000-0000-4000-8000-00000000000c','82000000-0000-4000-8000-00000000000c','active',null,null);

insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,
  status,suspended_at,revoked_at
)
select m.id,m.identity_id,r.id,m.scope_kind::app_private.superadmin_internal_scope_kind,
  m.scope_institution_id,m.status::app_private.superadmin_internal_membership_status,
  m.suspended_at,m.revoked_at
from (values
  ('86000000-0000-4000-8000-000000000001'::uuid,'84000000-0000-4000-8000-000000000001'::uuid,'operations','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('86000000-0000-4000-8000-000000000002'::uuid,'84000000-0000-4000-8000-000000000002'::uuid,'auditor','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('86000000-0000-4000-8000-000000000003'::uuid,'84000000-0000-4000-8000-000000000003'::uuid,'owner','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('86000000-0000-4000-8000-000000000004'::uuid,'84000000-0000-4000-8000-000000000004'::uuid,'operations','institution','81000000-0000-4000-8000-000000000101'::uuid,'active',null::timestamptz,null::timestamptz),
  ('86000000-0000-4000-8000-000000000005'::uuid,'84000000-0000-4000-8000-000000000005'::uuid,'support','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('86000000-0000-4000-8000-000000000006'::uuid,'84000000-0000-4000-8000-000000000006'::uuid,'content','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('86000000-0000-4000-8000-000000000009'::uuid,'84000000-0000-4000-8000-000000000009'::uuid,'operations','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('86000000-0000-4000-8000-00000000000a'::uuid,'84000000-0000-4000-8000-00000000000a'::uuid,'operations','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('86000000-0000-4000-8000-00000000000b'::uuid,'84000000-0000-4000-8000-00000000000b'::uuid,'operations','platform',null::uuid,'suspended',now(),null::timestamptz),
  ('86000000-0000-4000-8000-00000000000c'::uuid,'84000000-0000-4000-8000-00000000000c'::uuid,'operations','platform',null::uuid,'revoked',null::timestamptz,now())
) m(id,identity_id,role_code,scope_kind,scope_institution_id,status,suspended_at,revoked_at)
join public.platform_roles r on r.code=m.role_code;

create temporary table group_detail_acceptance_responses(
  sequence_number integer primary key,body jsonb not null);
grant select,insert on group_detail_acceptance_responses to authenticated;

-- Operations: exact shape, nullable/filled other text and all physical statuses.
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000001','session_id','83000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into group_detail_acceptance_responses values
 (10,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')),
 (11,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000002')),
 (33,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')),
 (34,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000002')),
 (35,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000005')),
 (36,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000006')),
 (37,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000007'));
reset role;

select ok((select (body->>'ok')::boolean and body->'error'='null'::jsonb
 and (select array_agg(key order by key) from jsonb_object_keys(body->'data') key)=array['created_at','group_type','group_type_other_text','id','inherit_access','inherit_activities','inherit_appearance','institution','management_version','name','status','unit','updated_at']::text[]
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,institution}') key)=array['id','name']::text[]
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,unit}') key)=array['id','name']::text[]
 from group_detail_acceptance_responses where sequence_number=10),
 'Operations AAL1 receives the exact Group detail shape');
select ok((select jsonb_typeof(body#>'{data,id}')='string'
 and jsonb_typeof(body#>'{data,institution}')='object'
 and jsonb_typeof(body#>'{data,unit}')='object'
 and jsonb_typeof(body#>'{data,name}')='string'
 and jsonb_typeof(body#>'{data,group_type}')='string'
 and jsonb_typeof(body#>'{data,status}')='string'
 and jsonb_typeof(body#>'{data,inherit_appearance}')='boolean'
 and jsonb_typeof(body#>'{data,inherit_access}')='boolean'
 and jsonb_typeof(body#>'{data,inherit_activities}')='boolean'
 and jsonb_typeof(body#>'{data,management_version}')='number'
 and jsonb_typeof(body#>'{data,created_at}')='string'
 and jsonb_typeof(body#>'{data,updated_at}')='string'
 from group_detail_acceptance_responses where sequence_number=10),
 'Group detail exposes the contracted JSON types');
select ok((select body#>'{data,group_type_other_text}'='null'::jsonb
 and body#>>'{data,institution,name}'='Group Detail Institution A'
 and body#>>'{data,unit,name}'='Group Detail Unit A1'
 from group_detail_acceptance_responses where sequence_number=10),
 'null other text and hierarchy names derive from server rows');
select ok((select body#>>'{data,group_type}'='other'
 and body#>>'{data,group_type_other_text}'='Laboratorio sintetico'
 and (body#>>'{data,management_version}')::bigint=2
 from group_detail_acceptance_responses where sequence_number=11),
 'filled other text and management version are preserved');
select is((select array_agg(body#>>'{data,status}' order by sequence_number)
 from group_detail_acceptance_responses where sequence_number between 33 and 37),
 array['active','draft','inactive','suspended','archived']::text[],
 'all five physical record statuses remain readable without transitions');

-- Owner AAL1/AAL2 and platform scope across Institutions.
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000003','session_id','83000000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(12,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_MFA_REQUIRED' from group_detail_acceptance_responses where sequence_number=12)
 and (select count(*)=1 from audit.audit_logs l join group_detail_acceptance_responses r on r.sequence_number=12 and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.reason_code='SAI_MFA_REQUIRED'),
 'Owner AAL1 is denied with one correlated v2 audit');
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000003','session_id','83000000-0000-4000-8000-000000000004','aal','aal2','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values
 (13,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')),
 (14,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000003')); reset role;
select ok(not exists(select 1 from group_detail_acceptance_responses where sequence_number in(13,14) and (body->>'ok')::boolean is distinct from true),
 'Owner AAL2 platform scope reads Groups in Institutions A and B');

-- Institution scope, no oracle, and role allowlist.
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000004','session_id','83000000-0000-4000-8000-000000000005','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values
 (15,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')),
 (16,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000002')),
 (17,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000003')),
 (18,public.superadmin_group_detail_v2('81000000-0000-4000-8000-00000000ffff')); reset role;
select ok(not exists(select 1 from group_detail_acceptance_responses where sequence_number in(15,16) and (body->>'ok')::boolean is distinct from true),
 'institution scope reads Groups in its own Institution across sibling Units');
select ok((select (body->'error')-'correlation_id' from group_detail_acceptance_responses where sequence_number=17)
 =(select (body->'error')-'correlation_id' from group_detail_acceptance_responses where sequence_number=18)
 and (select count(*)=2 from audit.audit_logs l join group_detail_acceptance_responses r on r.sequence_number in(17,18) and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.reason_code='SAI_PERMISSION_DENIED' and l.institution_id is null and l.object_id is null),
 'cross-scope and missing Group IDs return indistinguishable minimized denials');

select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000002','session_id','83000000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(19,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000005','session_id','83000000-0000-4000-8000-000000000006','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(20,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000006','session_id','83000000-0000-4000-8000-000000000007','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(21,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select ok(not exists(select 1 from group_detail_acceptance_responses where sequence_number in(19,20,21) and body#>>'{error,code}'<>'SAI_PERMISSION_DENIED')
 and (select count(*)=3 from audit.audit_logs l join group_detail_acceptance_responses r on r.sequence_number in(19,20,21) and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.reason_code='SAI_PERMISSION_DENIED'),
 'Auditor, Support, and Content fail closed with one v2 audit each');

-- Invalid sessions create no audit.
create temporary table group_detail_invalid_session_snapshot(value bigint not null);
insert into group_detail_invalid_session_snapshot select count(*) from audit.audit_logs where action_code='group.detail';
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000008','session_id','83000000-0000-4000-8000-000000000009','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(22,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000001','session_id','83000000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(23,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_SESSION_INVALID' from group_detail_acceptance_responses where sequence_number=22)
 and (select body#>>'{error,code}'='SAI_SESSION_INVALID' from group_detail_acceptance_responses where sequence_number=23)
 and (select value from group_detail_invalid_session_snapshot)=(select count(*) from audit.audit_logs where action_code='group.detail'),
 'expired and cross-user sessions are rejected before audit');

-- Link and membership lifecycle.
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000009','session_id','83000000-0000-4000-8000-00000000000a','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(24,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-00000000000a','session_id','83000000-0000-4000-8000-00000000000b','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(25,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-00000000000b','session_id','83000000-0000-4000-8000-00000000000c','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(26,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-00000000000c','session_id','83000000-0000-4000-8000-00000000000d','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(27,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from group_detail_acceptance_responses where sequence_number=24)
 and (select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from group_detail_acceptance_responses where sequence_number=25)
 and (select body#>>'{error,code}'='SAI_MEMBERSHIP_SUSPENDED' from group_detail_acceptance_responses where sequence_number=26)
 and (select body#>>'{error,code}'='SAI_MEMBERSHIP_REVOKED' from group_detail_acceptance_responses where sequence_number=27)
 and (select count(*)=4 from audit.audit_logs l join group_detail_acceptance_responses r on r.sequence_number in(24,25,26,27) and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.outcome='denied'),
 'suspended/revoked links and memberships deny with 1:1 v2 audit');

-- Valid Auth session without internal link is audited as v3.
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000007','session_id','83000000-0000-4000-8000-000000000008','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(28,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from group_detail_acceptance_responses where sequence_number=28)
 and (select count(*)=1 from audit.audit_logs l join group_detail_acceptance_responses r on r.sequence_number=28 and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=3 and l.payload_contract_version=3 and l.actor_kind='auth_session' and l.outcome='denied'),
 'valid cross-app Auth session without internal link receives one v3 denial');

-- Persistence/reload and effective grant revocation.
update public.groups set name='Group Detail Alpha Reloaded',management_version=2,updated_at=now() where id='81000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000001','session_id','83000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(30,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{data,name}'='Group Detail Alpha' and (body#>>'{data,management_version}')::bigint=1 from group_detail_acceptance_responses where sequence_number=10)
 and (select body#>>'{data,name}'='Group Detail Alpha Reloaded' and (body#>>'{data,management_version}')::bigint=2 from group_detail_acceptance_responses where sequence_number=30),
 'reload observes the persisted Group update and version');

update public.platform_role_permissions role_permission set status='inactive',revoked_at=now()
from public.platform_roles role_record,public.platform_permissions permission_record
where role_permission.role_id=role_record.id and role_permission.permission_id=permission_record.id
 and role_record.code='operations' and permission_record.code='groups.read';
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000001','session_id','83000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into group_detail_acceptance_responses values(31,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')); reset role;
update public.platform_role_permissions role_permission set status='active',revoked_at=null
from public.platform_roles role_record,public.platform_permissions permission_record
where role_permission.role_id=role_record.id and role_permission.permission_id=permission_record.id
 and role_record.code='operations' and permission_record.code='groups.read';
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from group_detail_acceptance_responses where sequence_number=31)
 and (select count(*)=1 from audit.audit_logs l join group_detail_acceptance_responses r on r.sequence_number=31 and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.reason_code='SAI_PERMISSION_DENIED'),
 'revoked effective groups.read grant denies with one v2 audit');

-- Role, capability, and grant state are revalidated on every call.
update public.platform_roles
set status='inactive'
where code='operations';
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000001','session_id','83000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into group_detail_acceptance_responses values(38,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001'));
reset role;
update public.platform_roles
set status='active'
where code='operations';
select ok(
  (select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
   from group_detail_acceptance_responses where sequence_number=38)
  and (select count(*)=1
    from audit.audit_logs log_record
    join group_detail_acceptance_responses response
      on response.sequence_number=38
     and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
    where log_record.hash_version=2
      and log_record.actor_kind='superadmin_internal'
      and log_record.outcome='denied'
      and log_record.reason_code='SAI_PERMISSION_DENIED'),
  'inactive Operations role denies with exactly one correlated v2 audit');

update public.platform_permissions
set status='inactive'
where code='groups.read';
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000001','session_id','83000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into group_detail_acceptance_responses values(39,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001'));
reset role;
update public.platform_permissions
set status='active'
where code='groups.read';
select ok(
  (select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
   from group_detail_acceptance_responses where sequence_number=39)
  and (select count(*)=1
    from audit.audit_logs log_record
    join group_detail_acceptance_responses response
      on response.sequence_number=39
     and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
    where log_record.hash_version=2
      and log_record.actor_kind='superadmin_internal'
      and log_record.outcome='denied'
      and log_record.reason_code='SAI_PERMISSION_DENIED'),
  'inactive groups.read capability denies with exactly one correlated v2 audit');

update public.platform_role_permissions role_permission
set effect='deny'
from public.platform_roles role_record,
  public.platform_permissions permission_record
where role_permission.role_id=role_record.id
  and role_permission.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code='groups.read';
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000001','session_id','83000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into group_detail_acceptance_responses values(40,public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001'));
reset role;
update public.platform_role_permissions role_permission
set effect='allow'
from public.platform_roles role_record,
  public.platform_permissions permission_record
where role_permission.role_id=role_record.id
  and role_permission.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code='groups.read';
select ok(
  (select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
   from group_detail_acceptance_responses where sequence_number=40)
  and (select count(*)=1
    from audit.audit_logs log_record
    join group_detail_acceptance_responses response
      on response.sequence_number=40
     and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
    where log_record.hash_version=2
      and log_record.actor_kind='superadmin_internal'
      and log_record.outcome='denied'
      and log_record.reason_code='SAI_PERMISSION_DENIED'),
  'deny effect on groups.read denies with exactly one correlated v2 audit');
select ok((select count(*)=12 from audit.audit_logs where action_code='group.detail' and outcome='success')
 and not exists(select 1 from audit.audit_logs where action_code='group.detail' and outcome='success' and (hash_version<>2 or payload_contract_version<>2 or permission_code<>'groups.read' or reason_code is not null or reason is not null or before_json is not null or after_json is not null or octet_length(session_id_hash)<>32 or object_type<>'group' or object_id is null or institution_id is null or not app_private.audit_verify_entry(id))),
 'all successes have 1:1 minimized digest-valid v2 audit');
select ok((select count(*)=14 from audit.audit_logs where action_code='group.detail' and outcome='denied' and hash_version=2)
 and (select count(*)=1 from audit.audit_logs where action_code='group.detail' and outcome='denied' and hash_version=3)
 and not exists(select 1 from audit.audit_logs where action_code='group.detail' and outcome='denied' and (reason_code is null or reason is distinct from reason_code or before_json is not null or after_json is not null or institution_id is not null or object_id is not null or octet_length(session_id_hash)<>32 or not app_private.audit_verify_entry(id))),
 'all identified denials are 1:1 minimized digest-valid v2/v3 audit');

create function pg_temp.fail_group_detail_audit() returns trigger language plpgsql as $$
begin raise exception using message='forced group detail audit failure'; end $$;
create trigger fail_group_detail_audit before insert on audit.audit_logs
for each row when(new.action_code='group.detail') execute function pg_temp.fail_group_detail_audit();
select set_config('request.jwt.claims',jsonb_build_object('sub','82000000-0000-4000-8000-000000000003','session_id','83000000-0000-4000-8000-000000000004','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.superadmin_group_detail_v2('81000000-0000-4000-8000-000000000001')$$,'P0001','forced group detail audit failure','adversarial audit append failure aborts Group detail');
reset role;
drop trigger fail_group_detail_audit on audit.audit_logs;
select ok((select bool_and(app_private.audit_verify_entry(id)) from audit.audit_logs where action_code='group.detail'),
 'all Group detail events remain in the verified append-only chain');

select * from finish();

rollback;
