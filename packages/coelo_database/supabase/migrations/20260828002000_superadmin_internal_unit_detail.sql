begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='internal unit detail migration must run as postgres';
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
    or to_regclass('public.units') is null
    or to_regclass('public.institutions') is null
    or to_regclass('public.institution_types') is null
    or to_regclass('public.unit_addresses') is null
    or to_regclass('public.unit_contacts') is null
    or to_regclass('public.plans') is null
    or to_regclass('public.institution_subscriptions') is null then
    raise object_not_in_prerequisite_state using
      message='internal Auth and unit detail dependencies are required';
  end if;
end
$preflight$;

create function app_private.superadmin_unit_detail_payload_v2(
  p_unit_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'id',unit_record.id,
    'name',unit_record.name,
    'slug',unit_record.slug,
    'status',unit_record.status,
    'institution',jsonb_build_object(
      'id',institution.id,
      'name',institution.public_name,
      'type',case when institution_type.id is null then null else
        jsonb_build_object(
          'id',institution_type.id,
          'name',institution_type.name
        )
      end
    ),
    'unit_type',jsonb_build_object(
      'id',unit_type.id,
      'name',unit_type.name
    ),
    'address',case when address.unit_id is null then null else
      jsonb_build_object(
        'country',address.country,
        'state',address.state,
        'city',address.city,
        'district',address.district,
        'street',address.street,
        'number',address.number,
        'complement',address.complement,
        'postal_code',address.postal_code
      )
    end,
    'contact',case when contact.unit_id is null then null else
      jsonb_build_object(
        'email',contact.email,
        'phone',contact.phone,
        'mobile_phone',contact.mobile_phone
      )
    end,
    'effective_plan',case when effective_plan.id is null then null else
      jsonb_build_object(
        'id',effective_plan.id,
        'code',effective_plan.code,
        'name',effective_plan.name,
        'inherited',unit_record.plan_override_id is null
      )
    end
  )
  from public.units unit_record
  join public.institutions institution
    on institution.id=unit_record.institution_id
   and institution.deleted_at is null
  join public.institution_types unit_type
    on unit_type.id=unit_record.institution_type_id
  left join public.institution_types institution_type
    on institution_type.id=institution.institution_type_id
  left join public.unit_addresses address
    on address.unit_id=unit_record.id
   and address.status<>'archived'
  left join public.unit_contacts contact
    on contact.unit_id=unit_record.id
   and contact.status<>'archived'
  left join lateral(
    select subscription.plan_id
    from public.institution_subscriptions subscription
    where subscription.institution_id=institution.id
    order by subscription.created_at desc,subscription.id desc
    limit 1
  ) latest_subscription on unit_record.plan_override_id is null
  left join public.plans effective_plan
    on effective_plan.id=coalesce(
      unit_record.plan_override_id,
      latest_subscription.plan_id
    )
  where unit_record.id=p_unit_id
$$;

revoke all on function
  app_private.superadmin_unit_detail_payload_v2(uuid)
  from public,anon,authenticated,service_role;

create function public.superadmin_unit_detail_v2(
  p_unit_id uuid
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
    from app_private.require_superadmin_internal_context('platform.read');

    if p_unit_id is null then
      raise insufficient_privilege using
        message='internal unit access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    if context_record.platform_role_code not in('owner','operations','auditor') then
      raise insufficient_privilege using
        message='internal unit access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    if context_record.scope_kind not in('platform','institution') then
      raise insufficient_privilege using
        message='internal unit access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    select unit_record.institution_id
      into target_institution_id
    from public.units unit_record
    join public.institutions institution
      on institution.id=unit_record.institution_id
     and institution.deleted_at is null
    where unit_record.id=p_unit_id
      and (
        context_record.scope_kind='platform'
        or (
          context_record.scope_kind='institution'
          and context_record.scope_institution_id=unit_record.institution_id
        )
      )
    for share of unit_record,institution;

    if target_institution_id is null then
      raise insufficient_privilege using
        message='internal unit access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    response_data:=app_private.superadmin_unit_detail_payload_v2(p_unit_id);
    if response_data is null then
      raise insufficient_privilege using
        message='internal unit access denied',
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
      'platform.read','unit.detail',error_code,correlation_id,null);
    return app_private.superadmin_internal_error_envelope(
      error_code,correlation_id);
  end if;

  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,
    context_record.internal_auth_link_id,
    context_record.internal_membership_id,
    context_record.session_id,
    'platform.read',
    context_record.aal,
    'unit.detail',
    'success',
    null,
    correlation_id,
    target_institution_id,
    'unit',
    p_unit_id
  );

  return jsonb_build_object(
    'ok',true,
    'data',response_data,
    'error',null
  );
end
$$;

revoke all on function public.superadmin_unit_detail_v2(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_unit_detail_v2(uuid)
  to authenticated;

commit;
