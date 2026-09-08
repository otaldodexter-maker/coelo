-- Forward-only nominal READ corrective. Existing writes and ACLs preserved.
begin;

-- Nominal Models READ pre-validation only. No global Auth helper changes.
create function app_private.access_profile_require_any_model_read()
returns void language plpgsql stable security definer set search_path='' as $$
declare
  read_domain text;
  denial_detail text;
begin
  foreach read_domain in array array['platform','institution','principal']::text[] loop
    begin
      perform app_private.access_profile_require_model_action(read_domain,'read',false);
      return;
    exception when insufficient_privilege then
      get stacked diagnostics denial_detail=pg_exception_detail;
      if denial_detail is distinct from 'SAI_PERMISSION_DENIED' then
        raise;
      end if;
    end;
  end loop;
  raise insufficient_privilege using
    message='access model read permission required',detail='SAI_PERMISSION_DENIED';
end
$$;
revoke all on function app_private.access_profile_require_any_model_read()
  from public,anon,authenticated,service_role;

create or replace function app_private.access_profile_model_detail(
  p_model_id uuid,
  p_authorize boolean default true
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  model_record public.access_profile_templates%rowtype;
  capabilities jsonb;
begin
  if p_authorize then
    perform app_private.access_profile_require_any_model_read();
  end if;
  select * into model_record
  from public.access_profile_templates model
  where model.id=p_model_id;
  if model_record.id is null then
    raise no_data_found using message='access profile model not found';
  end if;
  if p_authorize then
    perform app_private.access_profile_require_model_action(model_record.domain,'read',false);
  end if;
  if model_record.domain='platform' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',permission_record.code,'effect',model_permission.effect::text
    ) order by permission_record.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_platform_permissions model_permission
    join public.platform_permissions permission_record
      on permission_record.id=model_permission.permission_id
    where model_permission.template_id=model_record.id;
  elsif model_record.domain='institution' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',permission_record.code,'effect',model_permission.effect::text
    ) order by permission_record.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_institution_permissions model_permission
    join public.institution_permissions permission_record
      on permission_record.id=model_permission.permission_id
    where model_permission.template_id=model_record.id;
  else
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',capability.code,'effect',model_capability.effect::text
    ) order by capability.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_principal_capabilities model_capability
    join public.guardian_permission_capabilities capability
      on capability.id=model_capability.capability_id
    where model_capability.template_id=model_record.id;
  end if;
  return to_jsonb(model_record)||jsonb_build_object(
    'application_code',case model_record.domain
      when 'platform' then 'superadmin'
      when 'institution' then 'admin'
      else 'principal' end,
    'capabilities',capabilities,
    'capability_count',jsonb_array_length(capabilities)
  );
end
$$;

create or replace function app_private.access_profile_model_call(
  p_operation text,p_args jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare result jsonb;domain text;permission_action text;actor uuid;
  correlation uuid:=gen_random_uuid();error_code text;error_detail text;sql_state text;
  object_id uuid;
begin
  begin
    if p_operation in('list','detail','catalog') then
      perform app_private.access_profile_require_any_model_read();
    end if;
    domain:=case
      when p_operation in('list','create','export','import_preview','import_confirm')
        then coalesce(p_args->>'domain',p_args#>>'{draft,domain}')
      when p_operation='catalog' then 'platform'
      when p_operation in('detail','delete') then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args->>'model_id','')::uuid)
      when p_operation='update' then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args#>>'{draft,id}','')::uuid)
      when p_operation='duplicate' then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args#>>'{draft,source_model_id}','')::uuid)
    end;
    permission_action:=case p_operation
      when 'list' then 'read' when 'detail' then 'read' when 'catalog' then 'read'
      when 'duplicate' then 'create' when 'import_preview' then 'import'
      when 'import_confirm' then 'import' else p_operation end;
    if p_operation='list' then
      result:=app_private.superadmin_access_profile_models_cursor(
        p_args->>'query',domain,p_args->>'status',p_args->>'scope',
        coalesce((p_args->>'limit')::integer,25),p_args->>'after_name',
        nullif(p_args->>'after_id','')::uuid);
    elsif p_operation='detail' then
      result:=app_private.access_profile_model_detail(
        nullif(p_args->>'model_id','')::uuid,true);
    elsif p_operation='create' then
      result:=app_private.superadmin_access_profile_model_create(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='update' then
      result:=app_private.superadmin_access_profile_model_update(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='delete' then
      result:=app_private.superadmin_access_profile_model_delete(
        nullif(p_args->>'request_id','')::uuid,
        nullif(p_args->>'model_id','')::uuid,(p_args->>'expected_version')::bigint,
        p_args->>'reason');
    elsif p_operation='duplicate' then
      result:=app_private.superadmin_access_profile_model_duplicate(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='export' then
      result:=app_private.superadmin_access_profile_models_export(domain);
    elsif p_operation='import_preview' then
      result:=app_private.superadmin_access_profile_models_import_preview(
        domain,p_args->'rows');
    elsif p_operation='import_confirm' then
      result:=app_private.superadmin_access_profile_models_import_confirm(
        nullif(p_args->>'request_id','')::uuid,domain,p_args->'rows',p_args->>'reason');
    elsif p_operation='catalog' then
      result:=app_private.superadmin_access_permission_catalog();
    else
      raise invalid_parameter_value using message='unsupported model operation';
    end if;
    if p_operation in('list','detail','catalog','import_preview') then
      actor:=app_private.access_profile_require_model_action(
        coalesce(domain,'platform'),permission_action,false);
      object_id:=case when p_operation='detail'
        then nullif(p_args->>'model_id','')::uuid else null end;
      perform app_private.access_profile_model_audit_success(
        actor,coalesce(domain,'platform'),permission_action,object_id);
    end if;
  exception when others then
    get stacked diagnostics error_detail=pg_exception_detail,sql_state=returned_sqlstate;
    error_code:=case
      when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID',
        'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
        'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
        then error_detail
      when sql_state='40001' then 'SAI_CONCURRENT_CHANGE'
      when sql_state in('22023','22P02','23514','23505','22001')
        then 'SAI_INVALID_ARGUMENT'
      when sql_state in('P0002','42501') then 'SAI_PERMISSION_DENIED'
      else 'SAI_INTERNAL_ERROR' end;
    perform app_private.audit_superadmin_internal_denial_if_identified(
      coalesce(case when domain in('platform','institution','principal')
        then domain else 'platform' end||'.role_models.'||
        coalesce(permission_action,'read'),'platform.role_models.read'),
      'superadmin.access-profile-models.'||coalesce(p_operation,'invalid'),
      error_code,correlation,null);
    return app_private.access_profile_model_error_envelope(error_code,correlation);
  end;
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

commit;
