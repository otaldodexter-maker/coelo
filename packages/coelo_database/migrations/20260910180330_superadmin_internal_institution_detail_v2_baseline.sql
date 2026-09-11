begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='internal institution detail migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure('app_private.institution_management_payload(uuid)') is null
    or to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
    ) is null then
    raise object_not_in_prerequisite_state using
      message='internal Auth and institution payload dependencies are required';
  end if;
end
$preflight$;

create function app_private.superadmin_institution_detail_payload_v2(
  p_institution_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select app_private.institution_management_payload(p_institution_id)
$$;

revoke all on function
  app_private.superadmin_institution_detail_payload_v2(uuid)
  from public,anon,authenticated,service_role;

create function public.superadmin_institution_detail_v2(
  p_institution_id uuid
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
    from app_private.require_superadmin_internal_context('platform.read');

    if p_institution_id is null then
      raise insufficient_privilege using
        message='internal institution access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    if context_record.platform_role_code not in('owner','operations','auditor') then
      raise insufficient_privilege using
        message='internal institution access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    if context_record.scope_kind='institution'
      and context_record.scope_institution_id is distinct from p_institution_id then
      raise insufficient_privilege using
        message='internal institution access denied',
        detail='SAI_PERMISSION_DENIED';
    end if;

    response_data:=
      app_private.superadmin_institution_detail_payload_v2(p_institution_id);
    if response_data is null then
      raise insufficient_privilege using
        message='internal institution access denied',
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
      'platform.read','institution.detail',error_code,correlation_id,null);
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
    'institution.detail',
    'success',
    null,
    correlation_id,
    p_institution_id,
    'institution',
    p_institution_id
  );

  return jsonb_build_object(
    'ok',true,
    'data',response_data,
    'error',null
  );
end
$$;

revoke all on function public.superadmin_institution_detail_v2(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_institution_detail_v2(uuid)
  to authenticated;

commit;
