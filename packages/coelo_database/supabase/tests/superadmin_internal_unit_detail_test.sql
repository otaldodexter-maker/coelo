begin;

create extension if not exists pgtap with schema extensions;

select plan(31);

select ok(
  to_regprocedure('public.superadmin_unit_detail_v2(uuid)') is not null,
  'unit detail v2 wrapper exists');

create temporary table unit_detail_test_snapshot(value jsonb not null);
create temporary table unit_detail_test_responses(
  sequence_number integer primary key,
  body jsonb not null
);

grant select on unit_detail_test_snapshot to authenticated;
grant select, insert on unit_detail_test_responses to authenticated;

insert into unit_detail_test_snapshot(value)
select jsonb_build_object(
  'identities', (select count(*) from app_private.superadmin_internal_identities),
  'auth_links', (select count(*) from app_private.superadmin_internal_auth_links),
  'memberships', (select count(*) from app_private.superadmin_internal_memberships),
  'institutions', (select count(*) from public.institutions),
  'units', (select count(*) from public.units),
  'audit', (select count(*) from audit.audit_logs)
);

select set_config('request.jwt.claims', '{}', true);
set local role authenticated;

do $test$
begin
  if to_regprocedure('public.superadmin_unit_detail_v2(uuid)') is not null then
    execute
      'insert into unit_detail_test_responses(sequence_number, body)
       values ($1, public.superadmin_unit_detail_v2($2))'
      using 1, '71000000-0000-4000-8000-000000000001'::uuid;
    execute
      'insert into unit_detail_test_responses(sequence_number, body)
       values ($1, public.superadmin_unit_detail_v2($2))'
      using 2, '71000000-0000-4000-8000-000000000001'::uuid;
  end if;
end
$test$;

reset role;

select is(
  (select count(*) from unit_detail_test_responses),
  2::bigint,
  'two no-session calls return JSON without raising');

select ok(
  not exists(
    select 1
    from unit_detail_test_responses response
    where (
      select array_agg(key order by key)
      from jsonb_object_keys(response.body) key
    ) <> array['data', 'error', 'ok']::text[]
      or (
        select array_agg(key order by key)
        from jsonb_object_keys(response.body -> 'error') key
      ) <> array['code', 'correlation_id', 'http_status', 'message']::text[]
  ),
  'unit detail envelopes expose exact allowlisted root and error keys');

select ok(
  not exists(
    select 1
    from unit_detail_test_responses response
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
   from unit_detail_test_responses),
  'each rejected call receives a distinct correlation id');

select is(
  (select value from unit_detail_test_snapshot),
  (select jsonb_build_object(
    'identities', (select count(*) from app_private.superadmin_internal_identities),
    'auth_links', (select count(*) from app_private.superadmin_internal_auth_links),
    'memberships', (select count(*) from app_private.superadmin_internal_memberships),
    'institutions', (select count(*) from public.institutions),
    'units', (select count(*) from public.units),
    'audit', (select count(*) from audit.audit_logs)
  )),
  'calls without a validated session create no domain, identity, or audit row');

select ok(
  coalesce(has_function_privilege(
    'authenticated',
    to_regprocedure('public.superadmin_unit_detail_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'anon',
    to_regprocedure('public.superadmin_unit_detail_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'service_role',
    to_regprocedure('public.superadmin_unit_detail_v2(uuid)'),
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
      to_regprocedure('public.superadmin_unit_detail_v2(uuid)')
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'only authenticated can execute the unit detail wrapper');

select ok(
  to_regprocedure('app_private.superadmin_unit_detail_payload_v2(uuid)') is not null
  and not coalesce(has_function_privilege(
    'anon',
    to_regprocedure('app_private.superadmin_unit_detail_payload_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'authenticated',
    to_regprocedure('app_private.superadmin_unit_detail_payload_v2(uuid)'),
    'execute'
  ), false)
  and not coalesce(has_function_privilege(
    'service_role',
    to_regprocedure('app_private.superadmin_unit_detail_payload_v2(uuid)'),
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
      to_regprocedure('app_private.superadmin_unit_detail_payload_v2(uuid)')
      and helper_acl.grantee = 0
      and helper_acl.privilege_type = 'EXECUTE'
  ),
  'the private unit detail helper is not executable by client or service roles');

select ok(
  (select wrapper.prosecdef and wrapper.provolatile='v'
      and owner_role.rolname='postgres'
      and coalesce(wrapper.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]
    from pg_proc wrapper
    join pg_roles owner_role on owner_role.oid=wrapper.proowner
    where wrapper.oid='public.superadmin_unit_detail_v2(uuid)'::regprocedure)
  and
  (select helper.prosecdef and helper.provolatile='s'
      and owner_role.rolname='postgres'
      and coalesce(helper.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]
    from pg_proc helper
    join pg_roles owner_role on owner_role.oid=helper.proowner
    where helper.oid=
      'app_private.superadmin_unit_detail_payload_v2(uuid)'::regprocedure)
  and pg_get_functiondef(
    'public.superadmin_unit_detail_v2(uuid)'::regprocedure
  ) ~* 'for[[:space:]]+share[[:space:]]+of[[:space:]]+unit_record[[:space:]]*,[[:space:]]*institution',
  'wrapper/helper metadata and target FOR SHARE lock are hardened');

insert into public.institution_types(id,code,name,status) values
  ('71000000-0000-4000-8000-000000000201','unit-detail-school',
    'Unit Detail School','active'),
  ('71000000-0000-4000-8000-000000000202','unit-detail-campus',
    'Unit Detail Campus','active');
insert into public.plans(id,code,name,status) values
  ('71000000-0000-4000-8000-000000000301','unit-detail-override',
    'Unit Detail Override','active'),
  ('71000000-0000-4000-8000-000000000302','unit-detail-inherited-old',
    'Unit Detail Inherited Old','active'),
  ('71000000-0000-4000-8000-000000000303','unit-detail-inherited-latest',
    'Unit Detail Inherited Latest','active');
insert into public.institutions(
  id,public_name,slug,status,institution_type_id
) values
  ('71000000-0000-4000-8000-000000000101','Unit Detail Institution A',
    'unit-detail-institution-a','active',
    '71000000-0000-4000-8000-000000000201'),
  ('71000000-0000-4000-8000-000000000102','Unit Detail Institution B',
    'unit-detail-institution-b','active',
    '71000000-0000-4000-8000-000000000201');
insert into public.units(
  id,institution_id,name,slug,status,institution_type_id,plan_override_id
) values
  ('71000000-0000-4000-8000-000000000001',
    '71000000-0000-4000-8000-000000000101','Unit Detail Override Unit',
    'unit-detail-override-unit','active',
    '71000000-0000-4000-8000-000000000202',
    '71000000-0000-4000-8000-000000000301'),
  ('71000000-0000-4000-8000-000000000002',
    '71000000-0000-4000-8000-000000000101','Unit Detail Inherited Unit',
    'unit-detail-inherited-unit','active',
    '71000000-0000-4000-8000-000000000202',null),
  ('71000000-0000-4000-8000-000000000003',
    '71000000-0000-4000-8000-000000000101','Unit Detail Archived Children',
    'unit-detail-archived-children','active',
    '71000000-0000-4000-8000-000000000202',null),
  ('71000000-0000-4000-8000-000000000004',
    '71000000-0000-4000-8000-000000000102','Unit Detail No Plan',
    'unit-detail-no-plan','active',
    '71000000-0000-4000-8000-000000000202',null);
insert into public.unit_addresses(
  unit_id,country,state,city,district,street,number,complement,postal_code,status
) values
  ('71000000-0000-4000-8000-000000000001','BR','SP','São Paulo','Centro',
    'Rua Sintética','10','Sala 1','01001000','active'),
  ('71000000-0000-4000-8000-000000000003','BR','RJ','Rio de Janeiro',
    'Centro','Rua Arquivada','20',null,'20000000','archived');
insert into public.unit_contacts(unit_id,email,phone,mobile_phone,status) values
  ('71000000-0000-4000-8000-000000000001',
    'unit-detail@invalid.test','1130000000','11900000000','active'),
  ('71000000-0000-4000-8000-000000000003',
    'archived-unit-detail@invalid.test',null,null,'archived');
insert into public.institution_subscriptions(
  id,institution_id,plan_id,status,created_at
) values
  ('71000000-0000-4000-8000-000000000401',
    '71000000-0000-4000-8000-000000000101',
    '71000000-0000-4000-8000-000000000302','active',
    '2026-08-28 12:00:00+00'),
  ('71000000-0000-4000-8000-000000000402',
    '71000000-0000-4000-8000-000000000101',
    '71000000-0000-4000-8000-000000000303','active',
    '2026-08-28 12:00:00+00');

insert into auth.users(
  id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data
)
select id,'authenticated','authenticated',email,now(),now(),now(),'{}','{}'
from (values
  ('72000000-0000-4000-8000-000000000001'::uuid,'unit-detail-ops@invalid.test'),
  ('72000000-0000-4000-8000-000000000002'::uuid,'unit-detail-auditor@invalid.test'),
  ('72000000-0000-4000-8000-000000000003'::uuid,'unit-detail-owner@invalid.test'),
  ('72000000-0000-4000-8000-000000000004'::uuid,'unit-detail-scope@invalid.test'),
  ('72000000-0000-4000-8000-000000000005'::uuid,'unit-detail-support@invalid.test'),
  ('72000000-0000-4000-8000-000000000006'::uuid,'unit-detail-content@invalid.test'),
  ('72000000-0000-4000-8000-000000000007'::uuid,'unit-detail-cross@invalid.test'),
  ('72000000-0000-4000-8000-000000000008'::uuid,'unit-detail-expired@invalid.test'),
  ('72000000-0000-4000-8000-000000000009'::uuid,'unit-detail-link-s@invalid.test'),
  ('72000000-0000-4000-8000-00000000000a'::uuid,'unit-detail-link-r@invalid.test'),
  ('72000000-0000-4000-8000-00000000000b'::uuid,'unit-detail-member-s@invalid.test'),
  ('72000000-0000-4000-8000-00000000000c'::uuid,'unit-detail-member-r@invalid.test')
) actor(id,email);
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values
  ('73000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-000000000002','72000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-000000000003','72000000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-000000000004','72000000-0000-4000-8000-000000000003',now(),now(),'aal2',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-000000000005','72000000-0000-4000-8000-000000000004',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-000000000006','72000000-0000-4000-8000-000000000005',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-000000000007','72000000-0000-4000-8000-000000000006',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-000000000008','72000000-0000-4000-8000-000000000007',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-000000000009','72000000-0000-4000-8000-000000000008',now(),now(),'aal1',now()-interval '1 minute'),
  ('73000000-0000-4000-8000-00000000000a','72000000-0000-4000-8000-000000000009',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-00000000000b','72000000-0000-4000-8000-00000000000a',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-00000000000c','72000000-0000-4000-8000-00000000000b',now(),now(),'aal1',now()+interval '1 hour'),
  ('73000000-0000-4000-8000-00000000000d','72000000-0000-4000-8000-00000000000c',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id)
select id from (values
  ('74000000-0000-4000-8000-000000000001'::uuid),
  ('74000000-0000-4000-8000-000000000002'::uuid),
  ('74000000-0000-4000-8000-000000000003'::uuid),
  ('74000000-0000-4000-8000-000000000004'::uuid),
  ('74000000-0000-4000-8000-000000000005'::uuid),
  ('74000000-0000-4000-8000-000000000006'::uuid),
  ('74000000-0000-4000-8000-000000000009'::uuid),
  ('74000000-0000-4000-8000-00000000000a'::uuid),
  ('74000000-0000-4000-8000-00000000000b'::uuid),
  ('74000000-0000-4000-8000-00000000000c'::uuid)
) identity_record(id);
insert into app_private.superadmin_internal_auth_links(
  id,internal_identity_id,auth_user_id,status,suspended_at,revoked_at
) values
  ('75000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001','active',null,null),
  ('75000000-0000-4000-8000-000000000002','74000000-0000-4000-8000-000000000002','72000000-0000-4000-8000-000000000002','active',null,null),
  ('75000000-0000-4000-8000-000000000003','74000000-0000-4000-8000-000000000003','72000000-0000-4000-8000-000000000003','active',null,null),
  ('75000000-0000-4000-8000-000000000004','74000000-0000-4000-8000-000000000004','72000000-0000-4000-8000-000000000004','active',null,null),
  ('75000000-0000-4000-8000-000000000005','74000000-0000-4000-8000-000000000005','72000000-0000-4000-8000-000000000005','active',null,null),
  ('75000000-0000-4000-8000-000000000006','74000000-0000-4000-8000-000000000006','72000000-0000-4000-8000-000000000006','active',null,null),
  ('75000000-0000-4000-8000-000000000009','74000000-0000-4000-8000-000000000009','72000000-0000-4000-8000-000000000009','suspended',now(),null),
  ('75000000-0000-4000-8000-00000000000a','74000000-0000-4000-8000-00000000000a','72000000-0000-4000-8000-00000000000a','revoked',null,now()),
  ('75000000-0000-4000-8000-00000000000b','74000000-0000-4000-8000-00000000000b','72000000-0000-4000-8000-00000000000b','active',null,null),
  ('75000000-0000-4000-8000-00000000000c','74000000-0000-4000-8000-00000000000c','72000000-0000-4000-8000-00000000000c','active',null,null);
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,
  status,suspended_at,revoked_at
)
select m.id,m.identity_id,r.id,m.scope_kind::
  app_private.superadmin_internal_scope_kind,m.scope_institution_id,m.status::
  app_private.superadmin_internal_membership_status,m.suspended_at,m.revoked_at
from (values
  ('76000000-0000-4000-8000-000000000001'::uuid,'74000000-0000-4000-8000-000000000001'::uuid,'operations','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('76000000-0000-4000-8000-000000000002'::uuid,'74000000-0000-4000-8000-000000000002'::uuid,'auditor','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('76000000-0000-4000-8000-000000000003'::uuid,'74000000-0000-4000-8000-000000000003'::uuid,'owner','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('76000000-0000-4000-8000-000000000004'::uuid,'74000000-0000-4000-8000-000000000004'::uuid,'operations','institution','71000000-0000-4000-8000-000000000101'::uuid,'active',null::timestamptz,null::timestamptz),
  ('76000000-0000-4000-8000-000000000005'::uuid,'74000000-0000-4000-8000-000000000005'::uuid,'support','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('76000000-0000-4000-8000-000000000006'::uuid,'74000000-0000-4000-8000-000000000006'::uuid,'content','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('76000000-0000-4000-8000-000000000009'::uuid,'74000000-0000-4000-8000-000000000009'::uuid,'operations','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('76000000-0000-4000-8000-00000000000a'::uuid,'74000000-0000-4000-8000-00000000000a'::uuid,'operations','platform',null::uuid,'active',null::timestamptz,null::timestamptz),
  ('76000000-0000-4000-8000-00000000000b'::uuid,'74000000-0000-4000-8000-00000000000b'::uuid,'operations','platform',null::uuid,'suspended',now(),null::timestamptz),
  ('76000000-0000-4000-8000-00000000000c'::uuid,'74000000-0000-4000-8000-00000000000c'::uuid,'operations','platform',null::uuid,'revoked',null::timestamptz,now())
) m(id,identity_id,role_code,scope_kind,scope_institution_id,status,suspended_at,revoked_at)
join public.platform_roles r on r.code=m.role_code;
create temporary table unit_detail_acceptance_responses(
  sequence_number integer primary key,body jsonb not null);
grant select,insert on unit_detail_acceptance_responses to authenticated;

select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000001','session_id','73000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into unit_detail_acceptance_responses values
 (10,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')),
 (27,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000002')),
 (28,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000004')),
 (29,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000003'));
reset role;
select ok((select (body->>'ok')::boolean and body->'error'='null'::jsonb
 and (select array_agg(key order by key) from jsonb_object_keys(body->'data') key)=array['address','contact','effective_plan','id','institution','name','slug','status','unit_type']::text[]
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,institution}') key)=array['id','name','type']::text[]
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,institution,type}') key)=array['id','name']::text[]
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,unit_type}') key)=array['id','name']::text[]
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,address}') key)=array['city','complement','country','district','number','postal_code','state','street']::text[]
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,contact}') key)=array['email','mobile_phone','phone']::text[]
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,effective_plan}') key)=array['code','id','inherited','name']::text[]
 and body#>>'{data,address,postal_code}'='01001000'
 and body#>>'{data,contact,email}'='unit-detail@invalid.test'
 from unit_detail_acceptance_responses where sequence_number=10),
 'Operations AAL1 platform reads exact top-level and nested shape with active children');
select ok((select body#>>'{data,effective_plan,id}'='71000000-0000-4000-8000-000000000301'
 and (body#>>'{data,effective_plan,inherited}')::boolean is false
 from unit_detail_acceptance_responses where sequence_number=10),
 'override plan wins with inherited false');
select is((select count(*) from audit.audit_logs where actor_internal_membership_id='76000000-0000-4000-8000-000000000001' and action_code='unit.detail' and outcome='success'),4::bigint,
 'Operations calls append one v2 success event each');

select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000002','session_id','73000000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into unit_detail_acceptance_responses values(11,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001'));
reset role;
select ok((select (body->>'ok')::boolean from unit_detail_acceptance_responses where sequence_number=11)
 and (select count(*)=1 from audit.audit_logs where actor_internal_membership_id='76000000-0000-4000-8000-000000000002' and action_code='unit.detail' and outcome='success'),
 'Auditor AAL1 reads and appends one success audit');

select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000003','session_id','73000000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into unit_detail_acceptance_responses values(12,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001'));
reset role;
select ok((select body#>>'{error,code}'='SAI_MFA_REQUIRED' from unit_detail_acceptance_responses where sequence_number=12)
 and (select count(*)=1 from audit.audit_logs l join unit_detail_acceptance_responses r on r.sequence_number=12 and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.reason_code='SAI_MFA_REQUIRED'),
 'Owner AAL1 is denied and correlated in v2 audit');
select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000003','session_id','73000000-0000-4000-8000-000000000004','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into unit_detail_acceptance_responses values
 (13,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')),
 (14,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000004'));
reset role;
select ok(not exists(select 1 from unit_detail_acceptance_responses where sequence_number in(13,14) and (body->>'ok')::boolean is distinct from true)
 and (select count(*)=2 from audit.audit_logs where actor_internal_membership_id='76000000-0000-4000-8000-000000000003' and action_code='unit.detail' and outcome='success'),
 'Owner AAL2 platform reads Institutions A and B with 1:1 audit');

select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000004','session_id','73000000-0000-4000-8000-000000000005','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into unit_detail_acceptance_responses values
 (15,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')),
 (16,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000002')),
 (17,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000004')),
 (18,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-00000000ffff'));
reset role;
select ok(not exists(select 1 from unit_detail_acceptance_responses where sequence_number in(15,16) and (body->>'ok')::boolean is distinct from true),
 'institution scope reads own and sibling Units');
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED' and (body#>>'{error,http_status}')::integer=403 from unit_detail_acceptance_responses where sequence_number=17)
 and (select (body->'error')-'correlation_id' from unit_detail_acceptance_responses where sequence_number=17)
 =(select (body->'error')-'correlation_id' from unit_detail_acceptance_responses where sequence_number=18)
 and (select count(*)=2 from audit.audit_logs l join unit_detail_acceptance_responses r on r.sequence_number in(17,18) and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.reason_code='SAI_PERMISSION_DENIED' and l.institution_id is null and l.object_id is null),
 'cross-tenant and missing Units are identical 403 denials with minimized v2 audit');

select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000005','session_id','73000000-0000-4000-8000-000000000006','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(19,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000006','session_id','73000000-0000-4000-8000-000000000007','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(20,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select ok(not exists(select 1 from unit_detail_acceptance_responses where sequence_number in(19,20) and body#>>'{error,code}'<>'SAI_PERMISSION_DENIED')
 and (select count(*)=2 from audit.audit_logs l join unit_detail_acceptance_responses r on r.sequence_number in(19,20) and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.reason_code='SAI_PERMISSION_DENIED'),
 'Support and Content fail closed with one correlated v2 denial each');

create temporary table unit_detail_expired_audit_snapshot(value bigint not null);
insert into unit_detail_expired_audit_snapshot select count(*) from audit.audit_logs where action_code='unit.detail';
select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000008','session_id','73000000-0000-4000-8000-000000000009','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(21,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_SESSION_INVALID' from unit_detail_acceptance_responses where sequence_number=21)
 and (select value from unit_detail_expired_audit_snapshot)=(select count(*) from audit.audit_logs where action_code='unit.detail'),
 'expired session is denied before payload without audit');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','72000000-0000-4000-8000-000000000001',
  'session_id','73000000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into unit_detail_acceptance_responses values(
  31,public.superadmin_unit_detail_v2(
    '71000000-0000-4000-8000-000000000001'));
reset role;
select ok(
  (select body#>>'{error,code}'='SAI_SESSION_INVALID'
   from unit_detail_acceptance_responses where sequence_number=31)
  and not exists(
    select 1 from audit.audit_logs log_record
    join unit_detail_acceptance_responses response
      on response.sequence_number=31
     and log_record.correlation_id=
       (response.body#>>'{error,correlation_id}')::uuid
  ),
  'session_id owned by another Auth user is invalid and creates zero audit');

select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000009','session_id','73000000-0000-4000-8000-00000000000a','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(22,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-00000000000a','session_id','73000000-0000-4000-8000-00000000000b','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(23,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-00000000000b','session_id','73000000-0000-4000-8000-00000000000c','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(24,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-00000000000c','session_id','73000000-0000-4000-8000-00000000000d','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(25,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select ok(
 (select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from unit_detail_acceptance_responses where sequence_number=22)
 and (select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from unit_detail_acceptance_responses where sequence_number=23)
 and (select body#>>'{error,code}'='SAI_MEMBERSHIP_SUSPENDED' from unit_detail_acceptance_responses where sequence_number=24)
 and (select body#>>'{error,code}'='SAI_MEMBERSHIP_REVOKED' from unit_detail_acceptance_responses where sequence_number=25)
 and (select count(*)=4 from audit.audit_logs l join unit_detail_acceptance_responses r on r.sequence_number in(22,23,24,25) and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=2 and l.outcome='denied'),
 'suspended/revoked Auth links and memberships deny immediately with 1:1 v2 audit');

select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000007','session_id','73000000-0000-4000-8000-000000000008','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(26,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED' from unit_detail_acceptance_responses where sequence_number=26)
 and (select count(*)=1 from audit.audit_logs l join unit_detail_acceptance_responses r on r.sequence_number=26 and l.correlation_id=(r.body#>>'{error,correlation_id}')::uuid where l.hash_version=3 and l.payload_contract_version=3 and l.actor_kind='auth_session' and l.outcome='denied'),
 'valid session without internal link receives one correlated v3 denial');
select ok((select body#>>'{data,effective_plan,id}'='71000000-0000-4000-8000-000000000303' and (body#>>'{data,effective_plan,inherited}')::boolean from unit_detail_acceptance_responses where sequence_number=27),
 'latest subscription tie is broken by id with inherited true');
select ok((select body#>'{data,effective_plan}'='null'::jsonb from unit_detail_acceptance_responses where sequence_number=28),
 'Unit without override or subscription has null effective plan');
select ok((select body#>'{data,address}'='null'::jsonb and body#>'{data,contact}'='null'::jsonb from unit_detail_acceptance_responses where sequence_number=29),
 'archived address and contact are symmetrically absent');

update public.units set name='Unit Detail Override Unit Reloaded' where id='71000000-0000-4000-8000-000000000001';
update public.unit_addresses set street='Rua Sintética Recarregada',updated_at=now() where unit_id='71000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000001','session_id','73000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated; insert into unit_detail_acceptance_responses values(30,public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')); reset role;
select ok((select body#>>'{data,name}'='Unit Detail Override Unit' and body#>>'{data,address,street}'='Rua Sintética' from unit_detail_acceptance_responses where sequence_number=10)
 and (select body#>>'{data,name}'='Unit Detail Override Unit Reloaded' and body#>>'{data,address,street}'='Rua Sintética Recarregada' from unit_detail_acceptance_responses where sequence_number=30),
 'reload observes changed persisted Unit and address');

update public.platform_role_permissions role_permission
set status='inactive',revoked_at=now()
from public.platform_roles role_record,
  public.platform_permissions permission_record
where role_permission.role_id=role_record.id
  and role_permission.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code='platform.read';
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','72000000-0000-4000-8000-000000000001',
  'session_id','73000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into unit_detail_acceptance_responses values(
  32,public.superadmin_unit_detail_v2(
    '71000000-0000-4000-8000-000000000001'));
reset role;
update public.platform_role_permissions role_permission
set status='active',revoked_at=null
from public.platform_roles role_record,
  public.platform_permissions permission_record
where role_permission.role_id=role_record.id
  and role_permission.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code='platform.read';
select ok(
  (select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
   from unit_detail_acceptance_responses where sequence_number=32)
  and (select count(*)=1
    from audit.audit_logs log_record
    join unit_detail_acceptance_responses response
      on response.sequence_number=32
     and log_record.correlation_id=
       (response.body#>>'{error,correlation_id}')::uuid
    where log_record.hash_version=2
      and log_record.actor_kind='superadmin_internal'
      and log_record.outcome='denied'
      and log_record.reason_code='SAI_PERMISSION_DENIED'),
  'revoked effective platform.read grant denies and appends exactly one v2 audit');

select ok((select count(*)=10 from audit.audit_logs where action_code='unit.detail' and outcome='success')
 and not exists(select 1 from unit_detail_acceptance_responses where sequence_number in(10,11,13,14,15,16,27,28,29,30) and ((select array_agg(key order by key) from jsonb_object_keys(body) key)<>array['data','error','ok']::text[] or (select array_agg(key order by key) from jsonb_object_keys(body->'data') key)<>array['address','contact','effective_plan','id','institution','name','slug','status','unit_type']::text[] or body->'data' ?| array['branding','groups_count','activities_count','plan_override','document','people','created_at','updated_at']))
 and not exists(select 1 from audit.audit_logs where action_code='unit.detail' and outcome='success' and (hash_version<>2 or payload_contract_version<>2 or permission_code<>'platform.read' or reason_code is not null or reason is not null or before_json is not null or after_json is not null or octet_length(session_id_hash)<>32 or object_type<>'unit' or object_id is null or institution_id is null or not app_private.audit_verify_entry(id))),
 'all successes have exact output and 1:1 minimized digest-valid v2 audit');
select ok((select count(*)=10 from audit.audit_logs where action_code='unit.detail' and outcome='denied' and hash_version=2)
 and (select count(*)=1 from audit.audit_logs where action_code='unit.detail' and outcome='denied' and hash_version=3)
 and not exists(select 1 from audit.audit_logs where action_code='unit.detail' and outcome='denied' and (reason_code is null or reason is distinct from reason_code or before_json is not null or after_json is not null or institution_id is not null or object_id is not null or octet_length(session_id_hash)<>32 or not app_private.audit_verify_entry(id))),
 'denials are 1:1 minimized digest-valid v2/v3 audit events');

create function pg_temp.fail_unit_detail_audit() returns trigger language plpgsql as $$
begin raise exception using message='forced unit detail audit failure'; end $$;
create trigger fail_unit_detail_audit before insert on audit.audit_logs
for each row when(new.action_code='unit.detail') execute function pg_temp.fail_unit_detail_audit();
select set_config('request.jwt.claims',jsonb_build_object('sub','72000000-0000-4000-8000-000000000003','session_id','73000000-0000-4000-8000-000000000004','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.superadmin_unit_detail_v2('71000000-0000-4000-8000-000000000001')$$,'P0001','forced unit detail audit failure','adversarial audit append failure aborts Unit detail');
reset role;
drop trigger fail_unit_detail_audit on audit.audit_logs;
select ok((select bool_and(app_private.audit_verify_entry(id)) from audit.audit_logs where action_code='unit.detail'),
 'all Unit detail events remain in the verified append-only chain');

select * from finish();

rollback;
