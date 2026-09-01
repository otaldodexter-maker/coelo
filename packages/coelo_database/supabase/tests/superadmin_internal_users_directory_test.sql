begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

select ok(
  to_regclass('app_private.superadmin_internal_profiles') is not null
  and to_regclass('app_private.superadmin_internal_membership_scopes') is not null
  and to_regclass('app_private.superadmin_internal_user_command_receipts') is not null,
  'private internal-user profile, scope and receipt tables exist');
select ok(
  to_regprocedure('public.superadmin_internal_users_list(text,uuid[],text[],text[],integer,integer)') is not null
  and to_regprocedure('public.superadmin_internal_user_detail(uuid)') is not null
  and to_regprocedure('public.superadmin_internal_user_profiles()') is not null
  and to_regprocedure('public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)') is not null
  and to_regprocedure('public.superadmin_internal_user_change_status(uuid,uuid,bigint,text,text)') is not null,
  'list, detail, edit and lifecycle RPCs exist');
select is((select count(*) from pg_class table_record
  join pg_namespace schema_record on schema_record.oid=table_record.relnamespace
  where schema_record.nspname='app_private'
    and table_record.relname in('superadmin_internal_profiles','superadmin_internal_membership_scopes',
      'superadmin_internal_user_command_receipts')
    and table_record.relrowsecurity and table_record.relforcerowsecurity),3::bigint,
  'all new private tables force RLS');
select ok(not exists(select 1 from information_schema.role_table_grants grant_record
  where grant_record.table_schema='app_private'
    and grant_record.table_name in('superadmin_internal_profiles','superadmin_internal_membership_scopes',
      'superadmin_internal_user_command_receipts')
    and grant_record.grantee in('PUBLIC','anon','authenticated','service_role')),
  'private tables expose no direct client or service grants');
select ok(not has_function_privilege('anon',
    'public.superadmin_internal_users_list(text,uuid[],text[],text[],integer,integer)','execute')
  and not has_function_privilege('service_role',
    'public.superadmin_internal_users_list(text,uuid[],text[],text[],integer,integer)','execute')
  and has_function_privilege('authenticated',
    'public.superadmin_internal_users_list(text,uuid[],text[],text[],integer,integer)','execute'),
  'directory RPC is executable only by authenticated clients');
select ok(not has_function_privilege('anon',
    'public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)','execute')
  and not has_function_privilege('service_role',
    'public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)','execute')
  and has_function_privilege('authenticated',
    'public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)','execute'),
  'edit RPC is executable only by authenticated clients');
select is((select count(*) from public.platform_permissions
  where code in('platform.member.read','platform.member.update','platform.member.suspend')
    and status='active' and requires_mfa),3::bigint,
  'all internal-user capabilities are explicit, active and MFA guarded');
select results_eq(
  $$select module_label,screen_label,action_label from public.platform_permissions
    where code in('platform.member.read','platform.member.suspend','platform.member.update')
    order by code$$,
  $$values
    ('Superadmin','Usuários internos','Ver'),
    ('Superadmin','Usuários internos','Gerenciar'),
    ('Superadmin','Usuários internos','Editar')$$,
  'directory capabilities expose coherent module, screen and action labels');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('91000000-0000-4000-8000-000000000001','authenticated','authenticated',
   'owner-internal@invalid.test',now(),now(),now(),'{}','{}'),
  ('91000000-0000-4000-8000-000000000002','authenticated','authenticated',
   'operator-internal@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001',
   now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('93000000-0000-4000-8000-000000000001'),
  ('93000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(
  id,internal_identity_id,auth_user_id
) values
  ('94000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001',
   '91000000-0000-4000-8000-000000000001'),
  ('94000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000002',
   '91000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind
) values
  ('95000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001',
   (select id from public.platform_roles where code='owner'),'platform'),
  ('95000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000002',
   (select id from public.platform_roles where code='operations'),'platform');
insert into app_private.superadmin_internal_profiles(
  internal_identity_id,first_name,last_name,cpf,professional_email,job_title
) values
  ('93000000-0000-4000-8000-000000000001','Olívia','Coelho','52998224725',
   'owner-internal@invalid.test','Owner'),
  ('93000000-0000-4000-8000-000000000002','Ana','Lima','11144477735',
   'operator-internal@invalid.test','Operações');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','91000000-0000-4000-8000-000000000001',
  'session_id','92000000-0000-4000-8000-000000000001',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;

select is((public.superadmin_internal_users_list(null,null,null,null,1,11)->>'total')::integer,
  2,'authorized Owner lists the two private identities');
select is(public.superadmin_internal_user_detail(
  '93000000-0000-4000-8000-000000000002')->'identity'->>'professional_email',
  'operator-internal@invalid.test','detail returns sensitive fields only through its guarded RPC');
select is(public.superadmin_internal_users_list(null,null,null,null,1,11)
  #>>'{items,1,identity,professional_notes}','',
  'directory projection omits professional notes');

select is(public.superadmin_internal_user_update(
  '96000000-0000-4000-8000-000000000001',
  '93000000-0000-4000-8000-000000000002',1,'Revisão operacional',
  jsonb_build_object('identity',jsonb_build_object(
    'first_name','Ana','last_name','Lima','display_name','Ana Lima',
    'birth_date','1990-05-12','cpf','11144477735',
    'professional_email','operator-internal@invalid.test','mobile','11999999999',
    'additional_phone','','job_title','Líder de operações','department','Operações',
    'internal_function','Atendimento','professional_notes','','postal_code','',
    'street','','number','','complement','','neighborhood','','city','','state','',
    'country','Brasil'),'profile_id',(select id from public.platform_roles where code='operations'),
    'scope','platform','scope_ids','[]'::jsonb))->'identity'->>'job_title',
  'Líder de operações','edit persists the guarded professional draft');
select is(public.superadmin_internal_user_update(
  '96000000-0000-4000-8000-000000000001',
  '93000000-0000-4000-8000-000000000002',1,'Revisão operacional',
  jsonb_build_object('identity',jsonb_build_object(
    'first_name','Ana','last_name','Lima','display_name','Ana Lima',
    'birth_date','1990-05-12','cpf','11144477735',
    'professional_email','operator-internal@invalid.test','mobile','11999999999',
    'additional_phone','','job_title','Líder de operações','department','Operações',
    'internal_function','Atendimento','professional_notes','','postal_code','',
    'street','','number','','complement','','neighborhood','','city','','state','',
    'country','Brasil'),'profile_id',(select id from public.platform_roles where code='operations'),
    'scope','platform','scope_ids','[]'::jsonb))->>'version','2',
  'replayed request returns its receipt without applying the stale draft twice');
select is(public.superadmin_internal_user_change_status(
  '96000000-0000-4000-8000-000000000002',
  '93000000-0000-4000-8000-000000000002',2,'suspended','Investigação interna')
  #>>'{memberships,0,status}','suspended','suspend updates membership and credential together');
select is(public.superadmin_internal_user_change_status(
  '96000000-0000-4000-8000-000000000003',
  '93000000-0000-4000-8000-000000000002',3,'active','Acesso revisado')
  #>>'{memberships,0,status}','active','suspension is reversible');
select is(public.superadmin_internal_user_change_status(
  '96000000-0000-4000-8000-000000000004',
  '93000000-0000-4000-8000-000000000001',1,'suspended','Teste de proteção')
  #>>'{error,code}','SAI_LAST_OWNER_PROTECTED','last global Owner cannot be suspended');
select is((select count(*) from audit.audit_logs
  where actor_internal_identity_id='93000000-0000-4000-8000-000000000001'
    and action_code in('superadmin.internal-users.list','superadmin.internal-users.detail',
      'superadmin.internal-users.update','superadmin.internal-users.suspend',
      'superadmin.internal-users.reactivate') and outcome='success'),6::bigint,
  'successful reads and mutations append internal audit events');

reset role;

insert into public.institutions(id,public_name,slug) values
  ('97000000-0000-4000-8000-000000000001','Instituição A','internal-users-test-a'),
  ('97000000-0000-4000-8000-000000000002','Instituição B','internal-users-test-b');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('91000000-0000-4000-8000-000000000003','authenticated','authenticated',
   'limited-actor@invalid.test',now(),now(),now(),'{}','{}'),
  ('91000000-0000-4000-8000-000000000004','authenticated','authenticated',
   'target-a@invalid.test',now(),now(),now(),'{}','{}'),
  ('91000000-0000-4000-8000-000000000005','authenticated','authenticated',
   'target-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('92000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000003',
   now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('93000000-0000-4000-8000-000000000003'),
  ('93000000-0000-4000-8000-000000000004'),
  ('93000000-0000-4000-8000-000000000005');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('94000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000003',
   '91000000-0000-4000-8000-000000000003'),
  ('94000000-0000-4000-8000-000000000004','93000000-0000-4000-8000-000000000004',
   '91000000-0000-4000-8000-000000000004'),
  ('94000000-0000-4000-8000-000000000005','93000000-0000-4000-8000-000000000005',
   '91000000-0000-4000-8000-000000000005');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id
) values
  ('95000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000003',
   (select id from public.platform_roles where code='operations'),'institution',
   '97000000-0000-4000-8000-000000000001'),
  ('95000000-0000-4000-8000-000000000004','93000000-0000-4000-8000-000000000004',
   (select id from public.platform_roles where code='operations'),'institution',
   '97000000-0000-4000-8000-000000000001'),
  ('95000000-0000-4000-8000-000000000005','93000000-0000-4000-8000-000000000005',
   (select id from public.platform_roles where code='operations'),'institution',
   '97000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_membership_scopes(membership_id,institution_id) values
  ('95000000-0000-4000-8000-000000000003','97000000-0000-4000-8000-000000000001'),
  ('95000000-0000-4000-8000-000000000004','97000000-0000-4000-8000-000000000001'),
  ('95000000-0000-4000-8000-000000000005','97000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_profiles(
  internal_identity_id,first_name,last_name,cpf,professional_email,job_title
) values
  ('93000000-0000-4000-8000-000000000003','Lia','Auditora','12345678909',
   'limited-actor@invalid.test','Operações regionais'),
  ('93000000-0000-4000-8000-000000000004','Caio','Almeida','12345678910',
   'target-a@invalid.test','Suporte A'),
  ('93000000-0000-4000-8000-000000000005','Bruna','Barros','12345678911',
   'target-b@invalid.test','Suporte B');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code in(
  'platform.member.read','platform.member.update','platform.member.suspend')
where role_record.code='operations'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','91000000-0000-4000-8000-000000000003',
  'session_id','92000000-0000-4000-8000-000000000003',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;

select is((public.superadmin_internal_users_list(null,null,null,null,1,11)->>'total')::integer,
  2,'institution-scoped actor lists only itself and the target in institution A');
select is(public.superadmin_internal_user_detail(
  '93000000-0000-4000-8000-000000000004')->'identity'->>'first_name','Caio',
  'institution-scoped actor can read a target in the same institution');
select is(public.superadmin_internal_user_detail(
  '93000000-0000-4000-8000-000000000005')#>>'{error,code}','SAI_PERMISSION_DENIED',
  'detail denies an existing UUID from institution B');
select is(public.superadmin_internal_user_detail(
  '93000000-0000-4000-8000-000000000099')#>>'{error,code}','SAI_PERMISSION_DENIED',
  'detail returns the same denial for an unknown UUID');
select is(public.superadmin_internal_user_update(
  '96000000-0000-4000-8000-000000000010',
  '93000000-0000-4000-8000-000000000004',1,'Escopo fora do teto',
  jsonb_build_object('identity',jsonb_build_object(
    'first_name','Caio','last_name','Almeida','display_name','Caio Almeida',
    'birth_date',null,'cpf','12345678910','professional_email','target-a@invalid.test',
    'mobile','','additional_phone','','job_title','Suporte A','department','',
    'internal_function','','professional_notes','','postal_code','','street','','number','',
    'complement','','neighborhood','','city','','state','','country','Brasil'),
    'profile_id',(select id from public.platform_roles where code='operations'),
    'scope','platform','scope_ids','[]'::jsonb))#>>'{error,code}','SAI_PERMISSION_DENIED',
  'limited actor cannot escalate a same-tenant target to platform scope');
select is(public.superadmin_internal_user_update(
  '96000000-0000-4000-8000-000000000011',
  '93000000-0000-4000-8000-000000000005',1,'Tentativa entre tenants',
  jsonb_build_object('identity',jsonb_build_object(
    'first_name','Bruna','last_name','Barros','display_name','Bruna Barros',
    'birth_date',null,'cpf','12345678911','professional_email','target-b@invalid.test',
    'mobile','','additional_phone','','job_title','Suporte B','department','',
    'internal_function','','professional_notes','','postal_code','','street','','number','',
    'complement','','neighborhood','','city','','state','','country','Brasil'),
    'profile_id',(select id from public.platform_roles where code='operations'),
    'scope','limited','scope_ids',jsonb_build_array('97000000-0000-4000-8000-000000000002')))
  #>>'{error,code}','SAI_PERMISSION_DENIED',
  'edit denies a target from institution B before row disclosure');
select is(public.superadmin_internal_user_change_status(
  '96000000-0000-4000-8000-000000000012',
  '93000000-0000-4000-8000-000000000005',1,'suspended','Tentativa entre tenants')
  #>>'{error,code}','SAI_PERMISSION_DENIED','status command denies a target from institution B');
select is(public.superadmin_internal_user_change_status(
  '96000000-0000-4000-8000-000000000013',
  '93000000-0000-4000-8000-000000000004',1,'suspended','Revisão da instituição A')
  #>>'{memberships,0,status}','suspended','status command succeeds inside institution A');
select is(public.superadmin_internal_users_list(
  repeat('x',161),null,null,null,1,11)#>>'{error,code}','SAI_INVALID_INPUT',
  'directory rejects oversized search input');
select is(public.superadmin_internal_users_list(
  null,null,null,null,1,999)#>>'{error,code}','SAI_INVALID_INPUT',
  'directory rejects page sizes outside the allowlist');
select ok((select count(*)>=7 from audit.audit_logs
  where actor_internal_identity_id='93000000-0000-4000-8000-000000000003'
    and outcome='denied' and reason_code in('SAI_PERMISSION_DENIED','SAI_INVALID_INPUT')),
  'cross-scope, IDOR and malformed-input denials are audited for the identified actor');

reset role;
select * from finish();
rollback;
