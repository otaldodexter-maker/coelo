begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='internal group detail migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
    ) is null
    or to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
    ) is null
    or to_regprocedure(
      'app_private.superadmin_internal_error_envelope(text,uuid)'
    ) is null
    or to_regclass('public.groups') is null
    or to_regclass('public.units') is null
    or to_regclass('public.institutions') is null then
    raise object_not_in_prerequisite_state using
      message='internal Auth and group detail dependencies are required';
  end if;

  if not exists(
    select 1
    from pg_catalog.pg_attribute column_record
    where column_record.attrelid='public.groups'::regclass
      and column_record.attname='unit_id'
      and column_record.attnum>0
      and not column_record.attisdropped
      and column_record.attnotnull
  ) or not exists(
    select 1
    from pg_catalog.pg_constraint constraint_record
    where constraint_record.conrelid='public.groups'::regclass
      and constraint_record.conname='groups_unit_institution_fkey'
      and constraint_record.contype='f'
      and constraint_record.convalidated
  ) then
    raise object_not_in_prerequisite_state using
      message='required Group to Unit hierarchy constraints are missing';
  end if;

  if not exists(
    select 1
    from public.platform_permissions permission_record
    where permission_record.code='groups.read'
      and permission_record.status='active'
      and permission_record.requires_mfa=false
  ) then
    raise object_not_in_prerequisite_state using
      message='active non-MFA groups.read capability is required';
  end if;

  if coalesce((
    select array_agg(role_record.code order by role_record.code)
    from public.platform_role_permissions role_permission
    join public.platform_roles role_record
      on role_record.id=role_permission.role_id
     and role_record.status='active'
    join public.platform_permissions permission_record
      on permission_record.id=role_permission.permission_id
    where permission_record.code='groups.read'
      and role_permission.effect='allow'
      and role_permission.status='active'
      and role_permission.revoked_at is null
  ),array[]::text[]) is distinct from array['operations','owner']::text[] then
    raise object_not_in_prerequisite_state using
      message='groups.read role grants do not match the approved detail matrix';
  end if;

  if exists(
    select 1
    from pg_catalog.pg_proc procedure_record
    join pg_catalog.pg_namespace namespace_record
      on namespace_record.oid=procedure_record.pronamespace
    where namespace_record.nspname in('app_private','public')
      and procedure_record.proname in(
        'superadmin_group_detail_payload_v2','superadmin_group_detail_v2'
      )
  ) then
    raise duplicate_function using
      message='group detail v2 function name is already in use';
  end if;
end
$preflight$;

create function app_private.superadmin_group_detail_payload_v2(
  p_group_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'id',group_record.id,
    'institution',jsonb_build_object(
      'id',institution.id,
      'name',institution.public_name
    ),
    'unit',jsonb_build_object(
      'id',unit_record.id,
      'name',unit_record.name
    ),
    'name',group_record.name,
    'group_type',group_record.group_type,
    'group_type_other_text',group_record.group_type_other_text,
    'status',group_record.status,
    'inherit_appearance',group_record.inherit_appearance,
    'inherit_access',group_record.inherit_access,
    'inherit_activities',group_record.inherit_activities,
    'management_version',group_record.management_version,
    'created_at',group_record.created_at,
    'updated_at',group_record.updated_at
  )
  from public.groups group_record
  join public.institutions institution
    on institution.id=group_record.institution_id
   and institution.deleted_at is null
  join public.units unit_record
    on unit_record.id=group_record.unit_id
   and unit_record.institution_id=group_record.institution_id
  where group_record.id=p_group_id
$$;

revoke all on function
  app_private.superadmin_group_detail_payload_v2(uuid)
  from public,anon,authenticated,service_role;

create function public.superadmin_group_detail_v2(
  p_group_id uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid:=gen_random_uuid();
  target_institution_id uuid;
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('groups.read');

    if p_group_id is null then
      raise insufficient_privilege using
        message='internal group access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    if context_record.platform_role_code not in('owner','operations') then
      raise insufficient_privilege using
        message='internal group access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    if context_record.scope_kind not in('platform','institution') then
      raise insufficient_privilege using
        message='internal group access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    select group_record.institution_id
      into target_institution_id
    from public.groups group_record
    join public.units unit_record
      on unit_record.id=group_record.unit_id
     and unit_record.institution_id=group_record.institution_id
    join public.institutions institution
      on institution.id=group_record.institution_id
     and institution.deleted_at is null
    where group_record.id=p_group_id
      and (
        context_record.scope_kind='platform'
        or (
          context_record.scope_kind='institution'
          and context_record.scope_institution_id=group_record.institution_id
        )
      )
    for share of group_record,unit_record,institution;

    if target_institution_id is null then
      raise insufficient_privilege using
        message='internal group access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    response_data:=app_private.superadmin_group_detail_payload_v2(p_group_id);
    if response_data is null then
      raise insufficient_privilege using
        message='internal group access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when others then
      error_code:='SAI_INTERNAL_ERROR';
  end;

  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'groups.read','group.detail',error_code,correlation_id,null);
    return app_private.superadmin_internal_error_envelope(
      error_code,correlation_id);
  end if;

  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,
    context_record.internal_auth_link_id,
    context_record.internal_membership_id,
    context_record.session_id,
    'groups.read',
    context_record.aal,
    'group.detail',
    'success',
    null,
    correlation_id,
    target_institution_id,
    'group',
    p_group_id
  );

  return jsonb_build_object(
    'ok',true,
    'data',response_data,
    'error',null
  );
end
$$;

revoke all on function public.superadmin_group_detail_v2(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_group_detail_v2(uuid)
  to authenticated;

commit;
