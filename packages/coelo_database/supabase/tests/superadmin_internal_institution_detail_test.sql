begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

select ok(
  pg_get_functiondef('public.superadmin_institution_detail_v2(uuid)'::regprocedure)
    like '%require_superadmin_internal_context%'
  and pg_get_functiondef('public.superadmin_institution_detail_v2(uuid)'::regprocedure)
    not like '%current_person_id%',
  'institution detail uses only the internal Superadmin context');

select ok(
  has_function_privilege('authenticated',
    'public.superadmin_institution_detail_v2(uuid)','execute')
  and not has_function_privilege('anon',
    'public.superadmin_institution_detail_v2(uuid)','execute')
  and not has_function_privilege('service_role',
    'public.superadmin_institution_detail_v2(uuid)','execute')
  and not exists(
    select 1 from pg_proc procedure_record,
      lateral aclexplode(coalesce(procedure_record.proacl,
        acldefault('f',procedure_record.proowner))) acl
    where procedure_record.oid='public.superadmin_institution_detail_v2(uuid)'::regprocedure
      and acl.grantee=0 and acl.privilege_type='EXECUTE')
  and not exists(
    select 1 from pg_proc helper_record,
      lateral aclexplode(coalesce(helper_record.proacl,
        acldefault('f',helper_record.proowner))) helper_acl
    where helper_record.oid=
      'app_private.superadmin_institution_detail_payload_v2(uuid)'::regprocedure
      and helper_acl.grantee=0 and helper_acl.privilege_type='EXECUTE')
  and not has_function_privilege('anon',
    'app_private.superadmin_institution_detail_payload_v2(uuid)','execute')
  and not has_function_privilege('authenticated',
    'app_private.superadmin_institution_detail_payload_v2(uuid)','execute')
  and not has_function_privilege('service_role',
    'app_private.superadmin_institution_detail_payload_v2(uuid)','execute'),
  'only authenticated executes the wrapper and no client executes its helper');

insert into public.institutions(id,public_name,slug,status)
values
  ('61000000-0000-4000-8000-000000000001','Instituição sintética A',
    'synthetic-institution-a','draft'),
  ('61000000-0000-4000-8000-000000000002','Instituição sintética B',
    'synthetic-institution-b','draft');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data)
values
  ('62000000-0000-4000-8000-000000000001','authenticated','authenticated',
    'institution-internal-a@invalid.test',now(),now(),now(),'{}','{}'),
  ('62000000-0000-4000-8000-000000000002','authenticated','authenticated',
    'institution-cross-app@invalid.test',now(),now(),now(),'{}','{}'),
  ('62000000-0000-4000-8000-000000000003','authenticated','authenticated',
    'institution-support@invalid.test',now(),now(),now(),'{}','{}'),
  ('62000000-0000-4000-8000-000000000004','authenticated','authenticated',
    'institution-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('62000000-0000-4000-8000-000000000005','authenticated','authenticated',
    'institution-content@invalid.test',now(),now(),now(),'{}','{}'),
  ('62000000-0000-4000-8000-000000000006','authenticated','authenticated',
    'institution-auditor@invalid.test',now(),now(),now(),'{}','{}');

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values
  ('63000000-0000-4000-8000-000000000001',
    '62000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('63000000-0000-4000-8000-000000000002',
    '62000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('63000000-0000-4000-8000-000000000003',
    '62000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()-interval '1 minute'),
  ('63000000-0000-4000-8000-000000000004',
    '62000000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour'),
  ('63000000-0000-4000-8000-000000000005',
    '62000000-0000-4000-8000-000000000004',now(),now(),'aal1',now()+interval '1 hour'),
  ('63000000-0000-4000-8000-000000000006',
    '62000000-0000-4000-8000-000000000004',now(),now(),'aal2',now()+interval '1 hour'),
  ('63000000-0000-4000-8000-000000000007',
    '62000000-0000-4000-8000-000000000005',now(),now(),'aal1',now()+interval '1 hour'),
  ('63000000-0000-4000-8000-000000000008',
    '62000000-0000-4000-8000-000000000006',now(),now(),'aal1',now()+interval '1 hour');

insert into app_private.superadmin_internal_identities(id)
values
  ('64000000-0000-4000-8000-000000000001'),
  ('64000000-0000-4000-8000-000000000003'),
  ('64000000-0000-4000-8000-000000000004'),
  ('64000000-0000-4000-8000-000000000005'),
  ('64000000-0000-4000-8000-000000000006');
insert into app_private.superadmin_internal_auth_links(
  id,internal_identity_id,auth_user_id)
values
  ('65000000-0000-4000-8000-000000000001',
    '64000000-0000-4000-8000-000000000001',
    '62000000-0000-4000-8000-000000000001'),
  ('65000000-0000-4000-8000-000000000003',
    '64000000-0000-4000-8000-000000000003',
    '62000000-0000-4000-8000-000000000003'),
  ('65000000-0000-4000-8000-000000000004',
    '64000000-0000-4000-8000-000000000004',
    '62000000-0000-4000-8000-000000000004'),
  ('65000000-0000-4000-8000-000000000005',
    '64000000-0000-4000-8000-000000000005',
    '62000000-0000-4000-8000-000000000005'),
  ('65000000-0000-4000-8000-000000000006',
    '64000000-0000-4000-8000-000000000006',
    '62000000-0000-4000-8000-000000000006');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '66000000-0000-4000-8000-000000000001',
  '64000000-0000-4000-8000-000000000001',role_record.id,
  'institution','61000000-0000-4000-8000-000000000001'
from public.platform_roles role_record where role_record.code='operations';
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind)
select membership_record.id,membership_record.identity_id,role_record.id,'platform'
from (values
  ('66000000-0000-4000-8000-000000000003'::uuid,
    '64000000-0000-4000-8000-000000000003'::uuid,'support'::text),
  ('66000000-0000-4000-8000-000000000004'::uuid,
    '64000000-0000-4000-8000-000000000004'::uuid,'owner'::text),
  ('66000000-0000-4000-8000-000000000005'::uuid,
    '64000000-0000-4000-8000-000000000005'::uuid,'content'::text),
  ('66000000-0000-4000-8000-000000000006'::uuid,
    '64000000-0000-4000-8000-000000000006'::uuid,'auditor'::text)
) membership_record(id,identity_id,role_code)
join public.platform_roles role_record on role_record.code=membership_record.role_code;

create temporary table institution_detail_responses(
  sequence_number integer primary key,body jsonb not null);
grant select,insert on institution_detail_responses to authenticated;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000001',
  'session_id','63000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (1,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001'));
reset role;
update public.institutions
set public_name='Instituição sintética A recarregada'
where id='61000000-0000-4000-8000-000000000001';
set local role authenticated;
insert into institution_detail_responses values
  (2,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001')),
  (3,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000002'));
reset role;

select ok(
  (select body#>>'{data,public_name}'='Instituição sintética A'
    from institution_detail_responses where sequence_number=1)
  and (select body#>>'{data,public_name}'='Instituição sintética A recarregada'
    from institution_detail_responses where sequence_number=2)
  and not exists(
    select 1 from institution_detail_responses where sequence_number in(1,2)
      and ((body->>'ok')::boolean is distinct from true
        or body->'error'<>'null'::jsonb
        or body#>>'{data,id}'<>'61000000-0000-4000-8000-000000000001'
        or (select array_agg(key order by key)
          from jsonb_object_keys(body) key)<>array['data','error','ok']::text[])),
  'detail reload reads the changed persisted value with the exact success envelope');
select is((select count(*) from audit.audit_logs
  where actor_kind='superadmin_internal'
    and action_code='institution.detail'
    and permission_code='platform.read'
    and institution_id='61000000-0000-4000-8000-000000000001'
    and outcome='success'),2::bigint,
  'detail and reload append one minimized v2 success event each');
select ok((select (body->>'ok')::boolean is false
    and body->'data'='null'::jsonb
    and body#>>'{error,code}'='SAI_PERMISSION_DENIED'
    and (body#>>'{error,http_status}')::integer=403
    and (select array_agg(key order by key)
      from jsonb_object_keys(body) key)=array['data','error','ok']::text[]
    and (select array_agg(key order by key)
      from jsonb_object_keys(body->'error') key)=
        array['code','correlation_id','http_status','message']::text[]
  from institution_detail_responses where sequence_number=3),
  'institution-scoped actor receives a stable cross-tenant denial');
select is((select count(*) from audit.audit_logs log_record
  join institution_detail_responses response on response.sequence_number=3
    and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
  where log_record.actor_kind='superadmin_internal'
    and log_record.action_code='institution.detail'
    and log_record.outcome='denied'
    and log_record.reason_code='SAI_PERMISSION_DENIED'
    and log_record.institution_id is null),1::bigint,
  'cross-tenant denial appends exactly one correlated minimized v2 event');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000002',
  'session_id','63000000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (4,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001'));
reset role;
select ok((select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED'
  from institution_detail_responses where sequence_number=4),
  'valid cross-app session without an internal link is denied');
select is((select count(*) from audit.audit_logs log_record
  join institution_detail_responses response on response.sequence_number=4
    and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
  where log_record.actor_kind='auth_session'
    and log_record.action_code='institution.detail'
    and log_record.outcome='denied'),1::bigint,
  'cross-app denial appends exactly one correlated v3 event');

create temporary table institution_invalid_audit_snapshot(value bigint not null);
insert into institution_invalid_audit_snapshot select count(*) from audit.audit_logs;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000002',
  'session_id','63000000-0000-4000-8000-000000000003',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (5,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001'));
reset role;
select ok((select body#>>'{error,code}'='SAI_SESSION_INVALID'
  from institution_detail_responses where sequence_number=5),
  'expired session returns the stable invalid-session envelope');
select is((select value from institution_invalid_audit_snapshot),
  (select count(*) from audit.audit_logs),
  'an expired session creates no audit event');

update app_private.superadmin_internal_memberships
set status='suspended',suspended_at=now(),version=2
where id='66000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000001',
  'session_id','63000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (6,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001'));
reset role;
select ok((select body#>>'{error,code}'='SAI_MEMBERSHIP_SUSPENDED'
  from institution_detail_responses where sequence_number=6),
  'suspended internal membership is denied immediately');
select is((select count(*) from audit.audit_logs log_record
  join institution_detail_responses response on response.sequence_number=6
    and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
  where log_record.actor_kind='superadmin_internal'
    and log_record.reason_code='SAI_MEMBERSHIP_SUSPENDED'
    and log_record.outcome='denied'),1::bigint,
  'suspended membership denial appends exactly one correlated v2 event');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000003',
  'session_id','63000000-0000-4000-8000-000000000004',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (7,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001'));
reset role;
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
  from institution_detail_responses where sequence_number=7),
  'Support remains fail-closed without an active support-session contract');
select is((select count(*) from audit.audit_logs log_record
  join institution_detail_responses response on response.sequence_number=7
    and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
  where log_record.actor_kind='superadmin_internal'
    and log_record.reason_code='SAI_PERMISSION_DENIED'
    and log_record.outcome='denied'),1::bigint,
  'Support denial appends exactly one correlated v2 event');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000004',
  'session_id','63000000-0000-4000-8000-000000000005',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (8,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001'));
reset role;
select ok((select body#>>'{error,code}'='SAI_MFA_REQUIRED'
  from institution_detail_responses where sequence_number=8),
  'Owner at AAL1 is denied until MFA is satisfied');
select is((select count(*) from audit.audit_logs log_record
  join institution_detail_responses response on response.sequence_number=8
    and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
  where log_record.actor_kind='superadmin_internal'
    and log_record.reason_code='SAI_MFA_REQUIRED'
    and log_record.outcome='denied'),1::bigint,
  'Owner MFA denial appends exactly one correlated v2 event');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000005',
  'session_id','63000000-0000-4000-8000-000000000007',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (9,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001'));
reset role;
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
  from institution_detail_responses where sequence_number=9),
  'Content remains fail-closed for Institution details');
select is((select count(*) from audit.audit_logs log_record
  join institution_detail_responses response on response.sequence_number=9
    and log_record.correlation_id=(response.body#>>'{error,correlation_id}')::uuid
  where log_record.actor_kind='superadmin_internal'
    and log_record.reason_code='SAI_PERMISSION_DENIED'
    and log_record.outcome='denied'),1::bigint,
  'Content denial appends exactly one correlated v2 event');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000004',
  'session_id','63000000-0000-4000-8000-000000000006',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (10,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001')),
  (11,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000002'));
reset role;
select ok(not exists(select 1 from institution_detail_responses
  where sequence_number in(10,11) and (body->>'ok')::boolean is distinct from true),
  'platform Owner at AAL2 reads two institutions');
select is((select count(*) from audit.audit_logs
  where actor_internal_membership_id='66000000-0000-4000-8000-000000000004'
    and action_code='institution.detail' and outcome='success'
    and institution_id in('61000000-0000-4000-8000-000000000001',
      '61000000-0000-4000-8000-000000000002')),2::bigint,
  'platform reads append one success event for each Institution');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000006',
  'session_id','63000000-0000-4000-8000-000000000008',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (14,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-000000000001'));
reset role;
select ok(
  (select (body->>'ok')::boolean is true
    and body#>>'{data,id}'='61000000-0000-4000-8000-000000000001'
    from institution_detail_responses where sequence_number=14)
  and (select count(*)=1 from audit.audit_logs
    where actor_internal_membership_id='66000000-0000-4000-8000-000000000006'
      and actor_kind='superadmin_internal'
      and permission_code='platform.read'
      and action_code='institution.detail'
      and outcome='success' and reason_code is null
      and institution_id='61000000-0000-4000-8000-000000000001'
      and object_type='institution'
      and object_id='61000000-0000-4000-8000-000000000001'),
  'Auditor reads Institution detail and appends one minimized v2 success event');

update app_private.superadmin_internal_memberships
set status='active',suspended_at=null,version=3
where id='66000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000001',
  'session_id','63000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_detail_responses values
  (12,public.superadmin_institution_detail_v2('61000000-0000-4000-8000-00000000ffff'));
reset role;
select ok((select (body->'error')-'correlation_id'
    from institution_detail_responses where sequence_number=12)
  =(select (body->'error')-'correlation_id'
    from institution_detail_responses where sequence_number=3),
  'missing and cross-scope Institution IDs are indistinguishable');

select set_config('request.jwt.claims','{}',true);
set local role authenticated;
insert into institution_detail_responses values
  (13,public.superadmin_institution_detail_v2(null));
reset role;
select ok((select body#>>'{error,code}'='SAI_AUTH_REQUIRED'
  from institution_detail_responses where sequence_number=13),
  'authentication is validated before a null Institution ID');

create function pg_temp.fail_institution_detail_audit()
returns trigger language plpgsql as $$
begin
  raise exception using message='forced institution detail audit failure';
end
$$;
create trigger fail_institution_detail_audit
before insert on audit.audit_logs
for each row when(new.action_code='institution.detail')
execute function pg_temp.fail_institution_detail_audit();
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','62000000-0000-4000-8000-000000000004',
  'session_id','63000000-0000-4000-8000-000000000006',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(
  $$select public.superadmin_institution_detail_v2(
    '61000000-0000-4000-8000-000000000001')$$,
  'P0001','forced institution detail audit failure',
  'audit append failure aborts the Institution detail RPC');
reset role;
drop trigger fail_institution_detail_audit on audit.audit_logs;
select ok((select bool_and(app_private.audit_verify_entry(id))
  from audit.audit_logs where action_code='institution.detail'),
  'all institution detail events remain in the verified audit chain');
select ok((select bool_and(procedure_record.prosecdef)
    and bool_and(owner_role.rolname='postgres')
    and bool_and(coalesce(procedure_record.proconfig,'{}'::text[])
      @> array['search_path=""']::text[])
  from pg_proc procedure_record
  join pg_roles owner_role on owner_role.oid=procedure_record.proowner
  where procedure_record.oid in(
    'public.superadmin_institution_detail_v2(uuid)'::regprocedure,
    'app_private.superadmin_institution_detail_payload_v2(uuid)'::regprocedure)),
  'detail wrapper and private implementation are postgres-owned hardened definers');

select * from finish();
rollback;
