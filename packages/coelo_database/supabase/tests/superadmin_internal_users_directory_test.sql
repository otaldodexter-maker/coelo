begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

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
select throws_ok($$select public.superadmin_internal_user_change_status(
  '96000000-0000-4000-8000-000000000004',
  '93000000-0000-4000-8000-000000000001',1,'suspended','Teste de proteção')$$,
  '55000',null,'last global Owner cannot be suspended');
select is((select count(*) from audit.audit_logs
  where actor_internal_identity_id='93000000-0000-4000-8000-000000000001'
    and action_code in('superadmin.internal-users.list','superadmin.internal-users.detail',
      'superadmin.internal-users.update','superadmin.internal-users.suspend',
      'superadmin.internal-users.reactivate') and outcome='success'),6::bigint,
  'successful reads and mutations append internal audit events');

reset role;
select * from finish();
rollback;
