begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='internal person detail migration must run as postgres';
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
    or to_regclass('public.people') is null
    or to_regclass('public.person_auth_links') is null
    or to_regclass('public.institution_memberships') is null
    or to_regclass('public.institution_role_assignments') is null
    or to_regclass('public.institution_roles') is null
    or to_regclass('public.child_contexts') is null
    or to_regclass('public.child_unit_links') is null
    or to_regclass('public.child_group_links') is null
    or to_regclass('public.institutions') is null
    or to_regclass('public.units') is null
    or to_regclass('public.groups') is null then
    raise object_not_in_prerequisite_state using
      message='internal Auth and person detail dependencies are required';
  end if;

  if not exists(
    select 1
    from public.platform_permissions permission_record
    where permission_record.code='people.read'
      and permission_record.status='active'
      and permission_record.requires_mfa=true
  ) then
    raise object_not_in_prerequisite_state using
      message='active MFA people.read capability is required';
  end if;

  if coalesce((
    select array_agg(role_record.code order by role_record.code)
    from public.platform_role_permissions role_permission
    join public.platform_roles role_record
      on role_record.id=role_permission.role_id
     and role_record.status='active'
    join public.platform_permissions permission_record
      on permission_record.id=role_permission.permission_id
    where permission_record.code='people.read'
      and role_permission.effect='allow'
      and role_permission.status='active'
      and role_permission.revoked_at is null
  ),array[]::text[]) is distinct from array['owner']::text[] then
    raise object_not_in_prerequisite_state using
      message='people.read role grants do not match the approved detail matrix';
  end if;

  if exists(
    select 1
    from pg_catalog.pg_proc procedure_record
    join pg_catalog.pg_namespace namespace_record
      on namespace_record.oid=procedure_record.pronamespace
    where namespace_record.nspname in('app_private','public')
      and procedure_record.proname in(
        'superadmin_person_detail_payload_v2','superadmin_person_detail_v2'
      )
  ) then
    raise duplicate_function using
      message='person detail v2 function name is already in use';
  end if;
end
$preflight$;

create function app_private.superadmin_person_detail_payload_v2(
  p_person_id uuid,
  p_scope_kind text,
  p_scope_institution_id uuid
) returns jsonb
language sql
volatile
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'id',person_record.id,
    'first_name',person_record.first_name,
    'last_name',person_record.last_name,
    'display_name',person_record.display_name,
    'legal_name',person_record.legal_name,
    'type',person_record.person_type,
    'status',person_record.status,
    'auth_link',case
      when exists(
        select 1
        from public.person_auth_links auth_link
        where auth_link.person_id=person_record.id
          and auth_link.status='active'
          and auth_link.revoked_at is null
      ) then 'linked'
      when exists(
        select 1
        from public.person_auth_links auth_link
        where auth_link.person_id=person_record.id
          and auth_link.revoked_at is null
      ) then 'pending'
      else 'unlinked'
    end,
    'memberships',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id',assignment.id,
          'membership_id',membership.id,
          'institution_id',membership.institution_id,
          'institution_name',institution.public_name,
          'unit_id',unit_record.id,
          'unit_name',unit_record.name,
          'group_id',group_record.id,
          'group_name',group_record.name,
          'role',role_record.code,
          'is_platform',false
        )
        order by
          lower(institution.public_name) collate "C",
          institution.id,
          lower(unit_record.name) collate "C" nulls first,
          unit_record.id nulls first,
          lower(group_record.name) collate "C" nulls first,
          group_record.id nulls first,
          assignment.id
      )
      from public.institution_memberships membership
      join public.institution_role_assignments assignment
        on assignment.membership_id=membership.id
       and assignment.status='active'
       and (assignment.starts_at is null or assignment.starts_at<=now())
       and (assignment.expires_at is null or assignment.expires_at>now())
      join public.institution_roles role_record
        on role_record.id=assignment.role_id
       and role_record.status='active'
       and (
         role_record.institution_id is null
         or role_record.institution_id=membership.institution_id
       )
      join public.institutions institution
        on institution.id=membership.institution_id
       and institution.deleted_at is null
      left join public.units unit_record
        on unit_record.id=assignment.scope_unit_id
       and unit_record.institution_id=membership.institution_id
      left join public.groups group_record
        on group_record.id=assignment.scope_group_id
       and group_record.institution_id=membership.institution_id
       and group_record.unit_id=unit_record.id
      where membership.person_id=person_record.id
        and person_record.person_type='adult'
        and membership.status='active'
        and membership.revoked_at is null
        and (
          p_scope_kind='platform'
          or membership.institution_id=p_scope_institution_id
        )
        and (
          (assignment.scope_kind='institution'
            and assignment.scope_unit_id is null
            and assignment.scope_group_id is null)
          or (assignment.scope_kind='unit'
            and unit_record.id is not null
            and assignment.scope_group_id is null)
          or (assignment.scope_kind='group'
            and unit_record.id is not null
            and group_record.id is not null)
        )
    ),'[]'::jsonb) || coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id',child_context.id,
          'membership_id',null,
          'institution_id',child_context.institution_id,
          'institution_name',institution.public_name,
          'unit_id',unit_link.unit_id,
          'unit_name',unit_record.name,
          'group_id',group_link.group_id,
          'group_name',group_record.name,
          'role','student',
          'is_platform',false
        )
        order by
          lower(institution.public_name) collate "C",
          institution.id,
          lower(unit_record.name) collate "C" nulls first,
          unit_record.id nulls first,
          lower(group_record.name) collate "C" nulls first,
          group_record.id nulls first,
          child_context.id
      )
      from public.child_contexts child_context
      join public.institutions institution
        on institution.id=child_context.institution_id
       and institution.deleted_at is null
      left join lateral(
        select candidate.id,candidate.unit_id
        from public.child_unit_links candidate
        join public.units candidate_unit
          on candidate_unit.id=candidate.unit_id
         and candidate_unit.institution_id=child_context.institution_id
        where candidate.child_context_id=child_context.id
          and candidate.status in('pending','awaiting_allocation','active')
          and candidate.revoked_at is null
        order by
          lower(candidate_unit.name) collate "C",
          candidate_unit.id,
          candidate.id
        limit 1
      ) unit_link on true
      left join public.units unit_record
        on unit_record.id=unit_link.unit_id
       and unit_record.institution_id=child_context.institution_id
      left join lateral(
        select candidate.id,candidate.group_id
        from public.child_group_links candidate
        join public.groups candidate_group
          on candidate_group.id=candidate.group_id
         and candidate_group.institution_id=child_context.institution_id
         and candidate_group.unit_id=unit_link.unit_id
        where candidate.child_unit_link_id=unit_link.id
          and candidate.status='active'
          and (candidate.starts_at is null or candidate.starts_at<=now())
          and (candidate.ends_at is null or candidate.ends_at>now())
        order by lower(candidate_group.name) collate "C",candidate_group.id,candidate.id
        limit 1
      ) group_link on true
      left join public.groups group_record
        on group_record.id=group_link.group_id
       and group_record.institution_id=child_context.institution_id
       and group_record.unit_id=unit_link.unit_id
      where child_context.child_person_id=person_record.id
        and person_record.person_type='child'
        and child_context.status='active'
        and (
          p_scope_kind='platform'
          or child_context.institution_id=p_scope_institution_id
        )
    ),'[]'::jsonb),
    'child_contexts',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id',child_context.id,
          'institution_id',child_context.institution_id,
          'institution_name',institution.public_name,
          'unit_id',unit_link.unit_id,
          'unit_name',unit_record.name,
          'group_id',group_link.group_id,
          'group_name',group_record.name,
          'child_unit_link_id',unit_link.id,
          'child_group_link_id',group_link.id
        )
        order by
          lower(institution.public_name) collate "C",
          institution.id,
          lower(unit_record.name) collate "C" nulls first,
          unit_record.id nulls first,
          lower(group_record.name) collate "C" nulls first,
          group_record.id nulls first,
          child_context.id
      )
      from public.child_contexts child_context
      join public.institutions institution
        on institution.id=child_context.institution_id
       and institution.deleted_at is null
      left join lateral(
        select candidate.id,candidate.unit_id
        from public.child_unit_links candidate
        join public.units candidate_unit
          on candidate_unit.id=candidate.unit_id
         and candidate_unit.institution_id=child_context.institution_id
        where candidate.child_context_id=child_context.id
          and candidate.status in('pending','awaiting_allocation','active')
          and candidate.revoked_at is null
        order by
          lower(candidate_unit.name) collate "C",
          candidate_unit.id,
          candidate.id
        limit 1
      ) unit_link on true
      left join public.units unit_record
        on unit_record.id=unit_link.unit_id
       and unit_record.institution_id=child_context.institution_id
      left join lateral(
        select candidate.id,candidate.group_id
        from public.child_group_links candidate
        join public.groups candidate_group
          on candidate_group.id=candidate.group_id
         and candidate_group.institution_id=child_context.institution_id
         and candidate_group.unit_id=unit_link.unit_id
        where candidate.child_unit_link_id=unit_link.id
          and candidate.status='active'
          and (candidate.starts_at is null or candidate.starts_at<=now())
          and (candidate.ends_at is null or candidate.ends_at>now())
        order by lower(candidate_group.name) collate "C",candidate_group.id,candidate.id
        limit 1
      ) group_link on true
      left join public.groups group_record
        on group_record.id=group_link.group_id
       and group_record.institution_id=child_context.institution_id
       and group_record.unit_id=unit_link.unit_id
      where child_context.child_person_id=person_record.id
        and person_record.person_type='child'
        and child_context.status='active'
        and (
          p_scope_kind='platform'
          or child_context.institution_id=p_scope_institution_id
        )
    ),'[]'::jsonb),
    'updated_at',person_record.updated_at
  )
  from public.people person_record
  where person_record.id=p_person_id
    and person_record.deleted_at is null
    and (
      p_scope_kind='platform'
      or (
        p_scope_kind='institution'
        and (
          exists(
            select 1
            from public.institution_memberships membership
            join public.institution_role_assignments assignment
              on assignment.membership_id=membership.id
             and assignment.status='active'
             and (assignment.starts_at is null or assignment.starts_at<=now())
             and (assignment.expires_at is null or assignment.expires_at>now())
            join public.institution_roles role_record
              on role_record.id=assignment.role_id
             and role_record.status='active'
             and (
               role_record.institution_id is null
               or role_record.institution_id=membership.institution_id
             )
            join public.institutions institution
              on institution.id=membership.institution_id
             and institution.deleted_at is null
            left join public.units unit_record
              on unit_record.id=assignment.scope_unit_id
             and unit_record.institution_id=membership.institution_id
            left join public.groups group_record
              on group_record.id=assignment.scope_group_id
             and group_record.institution_id=membership.institution_id
             and group_record.unit_id=unit_record.id
            where membership.person_id=person_record.id
              and person_record.person_type='adult'
              and membership.institution_id=p_scope_institution_id
              and membership.status='active'
              and membership.revoked_at is null
              and (
                (assignment.scope_kind='institution'
                  and assignment.scope_unit_id is null
                  and assignment.scope_group_id is null)
                or (assignment.scope_kind='unit'
                  and unit_record.id is not null
                  and assignment.scope_group_id is null)
                or (assignment.scope_kind='group'
                  and unit_record.id is not null
                  and group_record.id is not null)
              )
          )
          or exists(
            select 1
            from public.child_contexts child_context
            join public.institutions institution
              on institution.id=child_context.institution_id
             and institution.deleted_at is null
            where child_context.child_person_id=person_record.id
              and person_record.person_type='child'
              and child_context.institution_id=p_scope_institution_id
              and child_context.status='active'
          )
        )
      )
    )
  for share of person_record
$$;

revoke all on function
  app_private.superadmin_person_detail_payload_v2(uuid,text,uuid)
  from public,anon,authenticated,service_role;

create function public.superadmin_person_detail_v2(
  p_person_id uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid:=gen_random_uuid();
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('people.read');

    if p_person_id is null
      or context_record.platform_role_code<>'owner'
      or context_record.scope_kind not in('platform','institution') then
      raise insufficient_privilege using
        message='internal person access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    response_data:=app_private.superadmin_person_detail_payload_v2(
      p_person_id,
      context_record.scope_kind,
      context_record.scope_institution_id
    );
    if response_data is null then
      raise insufficient_privilege using
        message='internal person access denied',
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
      'people.read','person.detail',error_code,correlation_id,null);
    return app_private.superadmin_internal_error_envelope(
      error_code,correlation_id);
  end if;

  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,
    context_record.internal_auth_link_id,
    context_record.internal_membership_id,
    context_record.session_id,
    'people.read',
    context_record.aal,
    'person.detail',
    'success',
    null,
    correlation_id,
    case when context_record.scope_kind='institution'
      then context_record.scope_institution_id else null end,
    'person',
    p_person_id
  );

  return jsonb_build_object(
    'ok',true,
    'data',response_data,
    'error',null
  );
end
$$;

revoke all on function public.superadmin_person_detail_v2(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_person_detail_v2(uuid)
  to authenticated;

commit;
