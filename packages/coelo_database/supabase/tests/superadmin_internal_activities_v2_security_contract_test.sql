begin;
create extension if not exists pgtap with schema extensions;

select plan(37);

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
      or helpers.proconfig<>array['search_path=""']::text[]
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
select lives_ok($contract$
do $verify$
begin
  if not (with allowed(command_kind) as (values
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
  ) select (select array_agg(command_kind order by command_kind) from constrained)=
    (select array_agg(command_kind order by command_kind) from allowed)
    and (select count(*) from constrained)=8) then
    raise exception 'receipt command-kind allowlist is not the exact approved set';
  end if;

  begin
    insert into app_private.superadmin_internal_activity_command_receipts(
      request_id,internal_identity_id,institution_id,activity_id,command_kind,
      request_hash,correlation_id,result_counts
    ) values (
      '7a200000-0000-4000-8000-000000000011',
      '7a200000-0000-4000-8000-000000000012',
      '7a200000-0000-4000-8000-000000000013',
      '7a200000-0000-4000-8000-000000000014','activity.evil',
      decode(repeat('00',32),'hex'),
      '7a200000-0000-4000-8000-000000000015','{}'::jsonb
    );
    raise exception 'unapproved receipt command kind was accepted';
  exception when check_violation then
    if SQLERRM not like '%command_kind_check%' then
      raise;
    end if;
  end;
end
$verify$;
$contract$, 'receipts enforce the exact eight approved mutation kinds and reject activity.evil');
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

-- Task 4 RED: close the final RLS, function ACL, default-ACL and FK-index
-- surface without teaching any people-based policy about the internal realm.
with expected(schema_name,table_name) as (values
  ('public','activity_definitions'),
  ('public','activity_unit_links'),
  ('public','activity_group_links'),
  ('public','activity_group_participants'),
  ('public','activity_group_assignments'),
  ('public','activity_admin_assignments'),
  ('public','activity_assignment_capability_actions'),
  ('public','activity_admin_capability_actions'),
  ('public','activity_capability_policies'),
  ('public','activity_group_capability_settings'),
  ('app_private','superadmin_internal_activity_command_receipts')
), actual as (
  select namespace_record.nspname as schema_name,relation.relname as table_name,
    relation.relrowsecurity,relation.relforcerowsecurity
  from pg_class relation
  join pg_namespace namespace_record on namespace_record.oid=relation.relnamespace
  join expected on expected.schema_name=namespace_record.nspname
    and expected.table_name=relation.relname
)
select ok((select count(*)=11 and bool_and(relrowsecurity and relforcerowsecurity)
  from actual),'all eleven Activity v2 relations enable and force RLS');

with expected(signature) as (values
  ('public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)'),
  ('public.superadmin_activity_detail_v2(uuid,text[])'),
  ('public.superadmin_activity_form_options_v2(uuid,text[],text,integer)'),
  ('public.superadmin_activity_create_v2(uuid,jsonb)'),
  ('public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)'),
  ('public.superadmin_activity_publish_v2(uuid,uuid,bigint)'),
  ('public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])'),
  ('public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)'),
  ('public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)'),
  ('public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)'),
  ('public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)')
), wrappers as (
  select to_regprocedure(signature) as oid from expected
)
select ok((select count(*)=11 and bool_and(
    wrappers.oid is not null
    and owner_role.rolname='postgres'
    and procedure_record.prosecdef
    and procedure_record.provolatile='v'
    and procedure_record.proconfig @> array['search_path=""']::text[])
  from wrappers
  left join pg_proc procedure_record on procedure_record.oid=wrappers.oid
  left join pg_roles owner_role on owner_role.oid=procedure_record.proowner),
  'all eleven wrappers are exact postgres-owned volatile security definers with empty search_path');

with expected(signature) as (values
  ('public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)'),
  ('public.superadmin_activity_detail_v2(uuid,text[])'),
  ('public.superadmin_activity_form_options_v2(uuid,text[],text,integer)'),
  ('public.superadmin_activity_create_v2(uuid,jsonb)'),
  ('public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)'),
  ('public.superadmin_activity_publish_v2(uuid,uuid,bigint)'),
  ('public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])'),
  ('public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)'),
  ('public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)'),
  ('public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)'),
  ('public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)')
), targets as (
  select to_regprocedure(signature) as procedure_oid from expected
), expected_acl as (
  select procedure_oid,'authenticated'::regrole::oid as grantee from targets
), actual_acl as (
  select target.procedure_oid,acl.grantee
  from targets target
  join pg_proc procedure_record on procedure_record.oid=target.procedure_oid
  cross join lateral aclexplode(coalesce(procedure_record.proacl,
    acldefault('f',procedure_record.proowner))) acl
  where acl.privilege_type='EXECUTE'
    and acl.grantee<>procedure_record.proowner
), differences as (
  (select * from actual_acl except select * from expected_acl)
  union all
  (select * from expected_acl except select * from actual_acl)
)
select ok((select count(*)=11 from targets)
  and not exists(select 1 from differences),
  'only authenticated has non-owner EXECUTE on every nominal Activity v2 wrapper');

with expected(signature) as (values
  ('app_private.activity_v2_success_envelope(jsonb)'),
  ('app_private.activity_v2_require_context(text,uuid)'),
  ('app_private.activity_v2_normalize_error(text)'),
  ('app_private.activity_v2_denied_envelope(text,text,text,uuid,uuid)'),
  ('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)'),
  ('app_private.activity_v2_set_marker(app_private.superadmin_internal_context,text,text,uuid)'),
  ('app_private.audit_activity_change()'),
  ('app_private.activity_v2_append_audit(app_private.superadmin_internal_context,uuid,uuid,text,text,jsonb)'),
  ('app_private.activity_v2_finish_command(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,bigint,text,uuid,jsonb)'),
  ('app_private.activity_v2_replay_or_error(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,uuid)'),
  ('app_private.activity_v2_effective_permission(text,text,text,text,text,text,text,text)'),
  ('app_private.activity_v2_validate_participants(uuid,jsonb)'),
  ('app_private.activity_v2_validate_professionals(uuid,jsonb)'),
  ('app_private.activity_v2_command_request_hash(text,uuid,uuid,bigint,jsonb)'),
  ('app_private.activity_v2_error_envelope(text,uuid)'),
  ('app_private.require_activity_v2_internal_marker()'),
  ('app_private.guard_activity_v2_actor_provenance()'),
  ('app_private.prevent_activity_v2_group_activity_admin()')
), helpers as (
  select to_regprocedure(signature) as oid from expected
)
select ok((select count(*)=18 and bool_and(
    helpers.oid is not null
    and owner_role.rolname='postgres'
    and procedure_record.proconfig @> array['search_path=""']::text[])
  from helpers
  left join pg_proc procedure_record on procedure_record.oid=helpers.oid
  left join pg_roles owner_role on owner_role.oid=procedure_record.proowner)
  and not exists(
    select 1 from helpers
    join pg_proc procedure_record on procedure_record.oid=helpers.oid
    cross join lateral aclexplode(coalesce(procedure_record.proacl,
      acldefault('f',procedure_record.proowner))) acl
    where acl.privilege_type='EXECUTE'
      and acl.grantee<>procedure_record.proowner
  ),'all eighteen Activity v2 helpers are postgres-owned, path-safe and non-executable by non-owners');

with global_default as (
  select default_acl.defaclacl
  from pg_default_acl default_acl
  where default_acl.defaclrole='postgres'::regrole
    and default_acl.defaclobjtype='f'
    and default_acl.defaclnamespace=0
), unsafe_acl as (
  select 1
  from pg_default_acl default_acl
  cross join lateral aclexplode(default_acl.defaclacl) acl
  where default_acl.defaclrole='postgres'::regrole
    and default_acl.defaclobjtype='f'
    and default_acl.defaclnamespace in(
      0,'public'::regnamespace::oid,'app_private'::regnamespace::oid)
    and acl.privilege_type='EXECUTE'
    and acl.grantee in(
      0,'anon'::regrole::oid,'authenticated'::regrole::oid,'service_role'::regrole::oid)
)
select ok((select count(*)=1 from global_default)
    and not exists(select 1 from unsafe_acl),
  'postgres has an explicit safe global function default ACL and neither application schema adds client execution');

with expected(schema_name,table_name,constraint_name) as (values
  ('public','activity_capability_policies','activity_capability_policies_capability_id_fkey'),
  ('public','activity_capability_policies','activity_capability_policies_changed_by_person_id_fkey'),
  ('public','activity_group_capability_settings','activity_group_capability_settings_capability_id_fkey'),
  ('public','activity_group_capability_settings','activity_group_capability_settings_changed_by_person_id_fkey'),
  ('public','activity_group_participants','activity_group_participants_activity_group_link_id_fkey'),
  ('public','activity_group_participants','activity_group_participants_added_by_person_id_fkey'),
  ('public','activity_admin_assignments','activity_admin_assignments_activity_fkey'),
  ('public','activity_admin_assignments','activity_admin_assignments_membership_fkey')
), matched as (
  select expected.*,constraint_record.conrelid,constraint_record.conkey
  from expected
  left join pg_namespace namespace_record
    on namespace_record.nspname=expected.schema_name
  left join pg_class relation
    on relation.relnamespace=namespace_record.oid
   and relation.relname=expected.table_name
  left join pg_constraint constraint_record
    on constraint_record.conrelid=relation.oid
   and constraint_record.conname=expected.constraint_name
   and constraint_record.contype='f'
)
select ok((select count(*)=8 and bool_and(
    conrelid is not null and exists(
      select 1
      from pg_index index_record
      where index_record.indrelid=matched.conrelid
        and index_record.indisvalid
        and index_record.indisready
        and index_record.indpred is null
        and (index_record.indkey::smallint[])[0:cardinality(matched.conkey)-1]
          =matched.conkey
    )) from matched),
  'all eight targeted Activity v2 foreign keys have valid full leading-column indexes without duplicate-name assumptions');

with expected(table_name,policy_name) as (values
  ('activity_definitions','activity_definitions_context_read'),
  ('activity_definitions','activity_definitions_institution_update'),
  ('activity_unit_links','activity_unit_links_context_read'),
  ('activity_unit_links','activity_unit_links_authorized_insert'),
  ('activity_unit_links','activity_unit_links_authorized_update'),
  ('activity_group_links','activity_group_links_context_read'),
  ('activity_group_links','activity_group_links_authorized_insert'),
  ('activity_group_links','activity_group_links_authorized_update'),
  ('activity_group_assignments','activity_group_assignments_context_read'),
  ('activity_group_assignments','activity_group_assignments_authorized_insert'),
  ('activity_group_assignments','activity_group_assignments_authorized_update'),
  ('activity_admin_assignments','activity_admin_assignments_authorized_read'),
  ('activity_assignment_capability_actions','activity_assignment_actions_authorized_read'),
  ('activity_capability_policies','activity_capability_policies_read'),
  ('activity_capability_policies','activity_capability_policies_manage_insert'),
  ('activity_capability_policies','activity_capability_policies_manage_update'),
  ('activity_group_capability_settings','activity_group_capability_settings_read'),
  ('activity_group_capability_settings','activity_group_capability_settings_manage_insert'),
  ('activity_group_capability_settings','activity_group_capability_settings_manage_update'),
  ('activity_group_participants','activity_group_participants_read'),
  ('activity_group_participants','activity_group_participants_manage_insert'),
  ('activity_group_participants','activity_group_participants_manage_update')
), policies as (
  select relation.relname as table_name,policy_record.polname as policy_name,
    coalesce(pg_get_expr(policy_record.polqual,policy_record.polrelid),'')||' '||
    coalesce(pg_get_expr(policy_record.polwithcheck,policy_record.polrelid),'') as expression
  from pg_policy policy_record
  join pg_class relation on relation.oid=policy_record.polrelid
  join pg_namespace namespace_record on namespace_record.oid=relation.relnamespace
  where namespace_record.nspname='public'
)
select ok((select count(*)=22 from expected join policies using(table_name,policy_name))
  and not exists(
    select 1 from expected join policies using(table_name,policy_name)
    where expression ~* '(superadmin_internal|activity_v2|internal_marker)'
      or expression !~* '(current_person_id|has_platform_permission|has_institution_permission|has_activity_context_access|has_context_permission)'
  ),'all twenty-two legacy people policies remain on their exact relations and contain no internal-realm bypass');

select * from finish();
rollback;
