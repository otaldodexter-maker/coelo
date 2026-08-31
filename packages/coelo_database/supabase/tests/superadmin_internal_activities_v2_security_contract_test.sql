begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

select has_table('public','activity_admin_capability_actions',
  'activity-admin capability actions exist');
select has_table('app_private','superadmin_internal_activity_command_receipts',
  'internal Activity receipts exist');
select has_function('app_private','activity_v2_command_request_hash',
  array['text','uuid','uuid','bigint','jsonb'], 'canonical Activity request hash exists');
select has_function('app_private','activity_v2_error_envelope',
  array['text','uuid'], 'Activity error envelope exists');

select ok(coalesce((select role.rolname='postgres'
  from pg_class relation join pg_roles role on role.oid=relation.relowner
  where relation.oid=to_regclass('public.activity_admin_capability_actions')),false),
  'activity-admin capability actions are owned by postgres');
select ok(coalesce((select role.rolname='postgres'
  from pg_class relation join pg_roles role on role.oid=relation.relowner
  where relation.oid=to_regclass('app_private.superadmin_internal_activity_command_receipts')),false),
  'internal Activity receipts are owned by postgres');
select ok(coalesce((select relation.relrowsecurity and relation.relforcerowsecurity
  from pg_class relation
  where relation.oid=to_regclass('public.activity_admin_capability_actions')),false),
  'activity-admin capability actions use FORCE RLS');
select ok(coalesce((select relation.relrowsecurity and relation.relforcerowsecurity
  from pg_class relation
  where relation.oid=to_regclass('app_private.superadmin_internal_activity_command_receipts')),false),
  'internal Activity receipts use FORCE RLS');
select ok(coalesce((select case
  when to_regclass('public.activity_admin_capability_actions') is null then false
  else not exists(
    select 1 from (values ('anon'),('authenticated'),('service_role')) roles(role_name)
    where has_table_privilege(roles.role_name,
      'public.activity_admin_capability_actions','select,insert,update,delete')
  ) end),false),
  'activity-admin capability actions have zero client grants');
select ok(coalesce((select case
  when to_regclass('app_private.superadmin_internal_activity_command_receipts') is null then false
  else not exists(
    select 1 from (values ('anon'),('authenticated'),('service_role')) roles(role_name)
    where has_table_privilege(roles.role_name,
      'app_private.superadmin_internal_activity_command_receipts','select,insert,update,delete')
  ) end),false),
  'internal Activity receipts have zero client grants');
select ok(coalesce((select not exists(select 1 from pg_policy
  where polrelid in (
    to_regclass('public.activity_admin_capability_actions'),
    to_regclass('app_private.superadmin_internal_activity_command_receipts')
  ))),false),
  'Activity permission tables default deny without policies');
select ok(coalesce((
  with expected(proname, identity_arguments) as (values
    ('activity_v2_command_request_hash','p_command_kind text, p_institution_id uuid, p_activity_id uuid, p_expected_version bigint, p_normalized_payload jsonb'),
    ('activity_v2_error_envelope','p_code text, p_correlation_id uuid')
  ), helpers as (
    select procedure_record.oid, procedure_record.proname,
      pg_get_function_identity_arguments(procedure_record.oid) as identity_arguments,
      owner_role.rolname as owner_name, procedure_record.prosecdef, procedure_record.proconfig
    from pg_proc procedure_record
    join pg_namespace namespace_record on namespace_record.oid=procedure_record.pronamespace
    join pg_roles owner_role on owner_role.oid=procedure_record.proowner
    where namespace_record.nspname='app_private'
      and procedure_record.proname in ('activity_v2_command_request_hash','activity_v2_error_envelope')
  )
  select count(*)=2 and not exists(
    select 1 from expected
    left join helpers using (proname,identity_arguments)
    where helpers.oid is null
      or helpers.owner_name<>'postgres'
      or helpers.prosecdef
      or coalesce(array_to_string(helpers.proconfig,','),'') not like '%search_path=%'
      or has_function_privilege('public',helpers.oid,'execute')
      or has_function_privilege('anon',helpers.oid,'execute')
      or has_function_privilege('authenticated',helpers.oid,'execute')
      or has_function_privilege('service_role',helpers.oid,'execute')
  ) from helpers
),false), 'Activity helpers are postgres-owned invokers with empty search_path and zero client EXECUTE grants');

select ok(coalesce((select array_agg(column_name||':'||udt_name order by ordinal_position)=array[
  'id:uuid','activity_admin_assignment_id:uuid','capability_id:uuid','can_view:bool',
  'can_edit:bool','changed_by_person_id:uuid','changed_by_actor_kind:text',
  'created_at:timestamptz','updated_at:timestamptz']::text[]
  from information_schema.columns
  where table_schema='public' and table_name='activity_admin_capability_actions'),false),
  'activity-admin actions have the approved minimal columns');
select ok(coalesce((select array_agg(column_name||':'||udt_name order by ordinal_position)=array[
  'request_id:uuid','internal_identity_id:uuid','institution_id:uuid','activity_id:uuid',
  'command_kind:text','request_hash:bytea','resulting_version:int8','resulting_status:text',
  'correlation_id:uuid','result_counts:jsonb','created_at:timestamptz']::text[]
  from information_schema.columns
  where table_schema='app_private' and table_name='superadmin_internal_activity_command_receipts'),false),
  'receipts exclude payload and PII columns');
select ok(coalesce((select exists(select 1 from pg_constraint constraint_record
  where constraint_record.conrelid=
    to_regclass('app_private.superadmin_internal_activity_command_receipts')
    and pg_get_constraintdef(constraint_record.oid) like '%octet_length(request_hash) = 32%')),false),
  'receipts require a 32-byte request hash');
select ok(coalesce((
  with allowed(command_kind) as (values
    ('activity.create'),('activity.update'),('activity.publish'),('activity.set_units'),
    ('activity.set_groups'),('activity.set_participants'),('activity.set_professionals'),
    ('activity.set_permissions')
  ), constrained(command_kind) as (
    select matched[1]
    from pg_constraint constraint_record
    cross join lateral regexp_matches(
      lower(pg_get_constraintdef(constraint_record.oid)),
      '''(activity\.[a-z_]+)''','g'
    ) as matched
    where constraint_record.conrelid=
      to_regclass('app_private.superadmin_internal_activity_command_receipts')
  )
  select (select array_agg(command_kind order by command_kind) from constrained)=
    (select array_agg(command_kind order by command_kind) from allowed)
    and (select count(*) from constrained)=8
),false), 'receipts allow exactly the eight approved Activity mutation kinds');
select ok(coalesce((select exists(select 1 from pg_constraint constraint_record
  where constraint_record.conrelid=to_regclass('public.activity_admin_capability_actions')
    and constraint_record.contype='u'
    and pg_get_constraintdef(constraint_record.oid) like
      '%UNIQUE (activity_admin_assignment_id, capability_id)%')),false),
  'activity-admin actions are unique per assignment and capability');
select ok(coalesce((select exists(select 1 from pg_constraint constraint_record
  where constraint_record.conrelid=to_regclass('public.activity_admin_capability_actions')
    and pg_get_constraintdef(constraint_record.oid) like
      '%FOREIGN KEY (activity_admin_assignment_id)%ON DELETE CASCADE%')),false),
  'activity-admin action assignment FK cascades');
select ok(coalesce((select exists(select 1 from pg_constraint constraint_record
  where constraint_record.conrelid=to_regclass('public.activity_admin_capability_actions')
    and pg_get_constraintdef(constraint_record.oid) like
      '%FOREIGN KEY (capability_id)%ON DELETE RESTRICT%')),false),
  'activity-admin action capability FK restricts');
select ok(coalesce((select exists(select 1 from pg_constraint constraint_record
  where constraint_record.conrelid=to_regclass('public.activity_admin_capability_actions')
    and pg_get_constraintdef(constraint_record.oid) like
      '%FOREIGN KEY (changed_by_person_id)%ON DELETE RESTRICT%')),false),
  'activity-admin action person FK restricts');
select ok(coalesce((select exists(select 1 from pg_constraint constraint_record
  where constraint_record.conrelid=
    to_regclass('app_private.superadmin_internal_activity_command_receipts')
    and pg_get_constraintdef(constraint_record.oid) like
      '%FOREIGN KEY (internal_identity_id)%ON DELETE RESTRICT%')),false),
  'receipt identity FK restricts');
select ok(coalesce((select exists(select 1 from pg_constraint constraint_record
  where constraint_record.conrelid=
    to_regclass('app_private.superadmin_internal_activity_command_receipts')
    and pg_get_constraintdef(constraint_record.oid) like
      '%FOREIGN KEY (institution_id)%ON DELETE RESTRICT%')),false),
  'receipt institution FK restricts');
select has_index('public','activity_admin_capability_actions',
  'activity_admin_capability_actions_assignment_idx','admin assignment FK is indexed');
select has_index('public','activity_admin_capability_actions',
  'activity_admin_capability_actions_capability_idx','capability FK is indexed');
select has_index('public','activity_admin_capability_actions',
  'activity_admin_capability_actions_changed_by_person_idx','person FK is indexed');
select has_index('app_private','superadmin_internal_activity_command_receipts',
  'superadmin_internal_activity_command_receipts_identity_idx','receipt identity FK is indexed');
select has_index('app_private','superadmin_internal_activity_command_receipts',
  'superadmin_internal_activity_command_receipts_institution_idx','receipt institution FK is indexed');
select has_index('app_private','superadmin_internal_activity_command_receipts',
  'superadmin_internal_activity_command_receipts_activity_idx','receipt activity lookup is indexed');

select lives_ok($$with base as (
  select app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000001',
    '7a200000-0000-4000-8000-000000000002',3,
    '{"alpha":1,"beta":{"z":true,"a":null}}'::jsonb) as digest
) select 1 / case when encode(digest,'hex')=
  '7c14f9b93431c6f7289a263900290c1cc37e96d8c0039fb833c05b26ed2a65bb'
  and digest=app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000001','7a200000-0000-4000-8000-000000000002',3,
    '{"beta":{"a":null,"z":true},"alpha":1}'::jsonb)
  and digest<>app_private.activity_v2_command_request_hash('activity.publish',
    '7a200000-0000-4000-8000-000000000001','7a200000-0000-4000-8000-000000000002',3,
    '{"alpha":1,"beta":{"z":true,"a":null}}'::jsonb)
  and digest<>app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000004','7a200000-0000-4000-8000-000000000002',3,
    '{"alpha":1,"beta":{"z":true,"a":null}}'::jsonb)
  and digest<>app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000001','7a200000-0000-4000-8000-000000000005',3,
    '{"alpha":1,"beta":{"z":true,"a":null}}'::jsonb)
  and digest<>app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000001','7a200000-0000-4000-8000-000000000002',4,
    '{"alpha":1,"beta":{"z":true,"a":null}}'::jsonb)
  and digest<>app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000001','7a200000-0000-4000-8000-000000000002',3,
    '{"alpha":2,"beta":{"z":true,"a":null}}'::jsonb)
  then 1 else 0 end from base$$,
  'canonical Activity hash has the fixed vector, canonical JSON, and five independent inputs');
select lives_ok($$with expected(code,http_status,message) as (values
  ('ACTIVITY_INVALID_INPUT',422,'Revise os dados enviados.'),
  ('ACTIVITY_INVALID_REFERENCE',422,'Revise os dados enviados.'),
  ('ACTIVITY_NOT_FOUND',404,'Atividade não encontrada.'),
  ('ACTIVITY_INVALID_STATE',409,'O estado mudou. Recarregue e tente novamente.'),
  ('ACTIVITY_DEPENDENCIES_ACTIVE',409,'O estado mudou. Recarregue e tente novamente.'),
  ('SAI_AUTH_REQUIRED',401,'Autenticação necessária.'),
  ('SAI_SESSION_INVALID',401,'Autenticação necessária.'),
  ('SAI_INTERNAL_CONTEXT_DENIED',403,'Acesso não autorizado.'),
  ('SAI_MEMBERSHIP_SUSPENDED',403,'Acesso não autorizado.'),
  ('SAI_MEMBERSHIP_REVOKED',403,'Acesso não autorizado.'),
  ('SAI_PERMISSION_DENIED',403,'Acesso não autorizado.'),
  ('SAI_MFA_REQUIRED',403,'Confirme o segundo fator.'),
  ('SAI_LAST_OWNER_PROTECTED',409,'O estado mudou. Recarregue e tente novamente.'),
  ('SAI_CONCURRENT_CHANGE',409,'O estado mudou. Recarregue e tente novamente.'),
  ('SAI_INTERNAL_ERROR',500,'Não foi possível concluir a operação.')
), checked as (
  select expected.*, app_private.activity_v2_error_envelope(expected.code,
    '7a200000-0000-4000-8000-000000000003'::uuid) as envelope from expected
) select 1 / case when not exists(select 1 from checked where envelope<>
  jsonb_build_object('ok',false,'data',null,'error',jsonb_build_object(
    'code',code,'message',message,'http_status',http_status,
    'correlation_id','7a200000-0000-4000-8000-000000000003'::uuid))
  or (select array_agg(key order by key) from jsonb_object_keys(envelope->'error') as key)<>
    array['code','correlation_id','http_status','message']::text[])
  and app_private.activity_v2_error_envelope('unapproved.error',
    '7a200000-0000-4000-8000-000000000003'::uuid)=jsonb_build_object(
      'ok',false,'data',null,'error',jsonb_build_object('code','SAI_INTERNAL_ERROR',
      'message','Não foi possível concluir a operação.','http_status',500,
      'correlation_id','7a200000-0000-4000-8000-000000000003'::uuid))
  then 1 else 0 end$$,
  'Activity errors table-drive every approved envelope, exact error keys, and unknown fallback');

select * from finish();
rollback;
