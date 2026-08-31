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
  where polrelid=to_regclass('public.activity_admin_capability_actions'))),false),
  'activity-admin capability actions default deny without policies');
select ok(coalesce((select not exists(select 1 from pg_policy
  where polrelid=to_regclass('app_private.superadmin_internal_activity_command_receipts'))),false),
  'internal Activity receipts default deny without policies');

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
select ok(coalesce((select exists(select 1 from pg_constraint constraint_record
  where constraint_record.conrelid=
    to_regclass('app_private.superadmin_internal_activity_command_receipts')
    and pg_get_constraintdef(constraint_record.oid) like
      '%activity.create%activity.update%activity.publish%activity.set_units%activity.set_groups%activity.set_participants%activity.set_professionals%activity.set_permissions%')),false),
  'receipts allow exactly the eight Activity mutation kinds');
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

select lives_ok($$select 1 / case when
  app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000001',
    '7a200000-0000-4000-8000-000000000002',3,
    '{"alpha":1,"beta":{"z":true,"a":null}}'::jsonb)=
  app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000001',
    '7a200000-0000-4000-8000-000000000002',3,
    '{"beta":{"a":null,"z":true},"alpha":1}'::jsonb)
  and octet_length(app_private.activity_v2_command_request_hash('activity.update',
    '7a200000-0000-4000-8000-000000000001',
    '7a200000-0000-4000-8000-000000000002',3,'{}'::jsonb))=32
  then 1 else 0 end$$, 'canonical Activity hashes are deterministic SHA-256');
select lives_ok($$select 1 / case when
  app_private.activity_v2_error_envelope('ACTIVITY_INVALID_INPUT',
    '7a200000-0000-4000-8000-000000000003')->'error'=
    jsonb_build_object('code','ACTIVITY_INVALID_INPUT','message','Revise os dados enviados.',
      'http_status',422,'correlation_id','7a200000-0000-4000-8000-000000000003'::uuid)
  and (app_private.activity_v2_error_envelope('ACTIVITY_NOT_FOUND',
    '7a200000-0000-4000-8000-000000000003')->'error'->>'http_status')::integer=404
  and (app_private.activity_v2_error_envelope('ACTIVITY_DEPENDENCIES_ACTIVE',
    '7a200000-0000-4000-8000-000000000003')->'error'->>'http_status')::integer=409
  and app_private.activity_v2_error_envelope('unapproved.error',
    '7a200000-0000-4000-8000-000000000003')->'error'->>'code'='SAI_INTERNAL_ERROR'
  then 1 else 0 end$$, 'Activity errors are allowlisted with approved 422/404/409 mappings');

select * from finish();
rollback;
