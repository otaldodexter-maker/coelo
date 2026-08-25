-- Final Revisao Supabase: forward-only runtime/lint hardening.
-- Public signatures and existing privileges are preserved.

CREATE OR REPLACE FUNCTION app_private.superadmin_access_profile_assignment_link(p_request_id uuid, p_draft jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<vars>>
declare profile_id uuid:=nullif(p_draft->>'profile_id','')::uuid;domain text;actor uuid;replay jsonb;
  person_id uuid:=nullif(p_draft->>'person_id','')::uuid;membership public.institution_memberships%rowtype;
  assignment_id uuid;result jsonb;scope_kind text:=coalesce(p_draft->>'scope_kind','institution');
  template public.access_profile_templates%rowtype;context_record public.guardian_context_permissions%rowtype;
  guardian_person_id uuid;child_context_status public.record_status;profile_version bigint;
  expected_profile_version bigint:=nullif(p_draft->>'profile_version','')::bigint;
  unit_id uuid:=nullif(p_draft->>'unit_id','')::uuid;group_id uuid:=nullif(p_draft->>'group_id','')::uuid;
begin
  domain:=case when exists(select 1 from public.platform_roles where id=profile_id) then 'platform'
    when exists(select 1 from public.institution_roles where id=profile_id) then 'institution'
    when exists(select 1 from public.access_profile_templates template_record
      where template_record.id=profile_id and template_record.domain='principal') then 'principal' end;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'assignment_link',p_draft);if replay is not null then return replay;end if;
  perform app_private.assert_access_profile_assignment_delegable(domain,profile_id);
  if domain='platform' then
    select version into profile_version from public.platform_roles where id=profile_id and status='active' for update;
    if profile_version is null then raise no_data_found using message='active profile not found';end if;
    if expected_profile_version is null or expected_profile_version<>profile_version then
      raise serialization_failure using message='stale profile version';end if;
    if scope_kind not in('platform','institution')
      or (scope_kind='platform' and nullif(p_draft->>'institution_id','') is not null)
      or (scope_kind='institution' and not exists(select 1 from public.institutions institution
        where institution.id=nullif(p_draft->>'institution_id','')::uuid and institution.status='active')) then
      raise invalid_parameter_value using message='invalid platform assignment scope';end if;
    perform 1 from public.people where id=person_id and status='active' and deleted_at is null for update;
    if not found then raise no_data_found using message='person not found';end if;
    insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required,invited_by)
    values(person_id,profile_id,'active',scope_kind,nullif(p_draft->>'institution_id','')::uuid,true,actor)
    returning id into assignment_id;
  elsif domain='institution' then
    select * into membership from public.institution_memberships where id=nullif(p_draft->>'membership_id','')::uuid for update;
    select version into profile_version from public.institution_roles role_record where role_record.id=profile_id
      and role_record.status='active' and (role_record.institution_id is null or role_record.institution_id=membership.institution_id) for update;
    if membership.id is null or membership.person_id<>person_id or membership.status<>'active' or membership.revoked_at is not null
      or profile_version is null then raise no_data_found using message='authorized membership or profile not found';end if;
    if expected_profile_version is null or expected_profile_version<>profile_version then
      raise serialization_failure using message='stale profile version';end if;
    if scope_kind not in('institution','unit','group')
      or (scope_kind='institution' and (unit_id is not null or group_id is not null))
      or (scope_kind='unit' and (unit_id is null or group_id is not null or not exists(select 1 from public.units unit_record
        where unit_record.id=vars.unit_id and unit_record.institution_id=membership.institution_id and unit_record.status='active')))
      or (scope_kind='group' and (group_id is null or not exists(select 1 from public.groups group_record
        where group_record.id=vars.group_id and group_record.institution_id=membership.institution_id and group_record.status='active'
          and (vars.unit_id is null or group_record.unit_id=vars.unit_id)))) then
      raise invalid_parameter_value using message='invalid institution assignment scope';end if;
    insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id,scope_group_id,
      starts_at,expires_at,granted_by,status) values(membership.id,profile_id,scope_kind,unit_id,group_id,
      nullif(p_draft->>'starts_at','')::timestamptz,nullif(p_draft->>'expires_at','')::timestamptz,actor,'active')
    returning id into assignment_id;
  elsif domain='principal' then
    select * into template from public.access_profile_templates template_record
      where template_record.id=profile_id and template_record.domain='principal'
        and template_record.status='active' for update;
    if expected_profile_version is null or template.id is null or template.version<>expected_profile_version then
      raise serialization_failure using message='stale profile model version';end if;
    select context_permission.* into context_record
    from public.guardian_context_permissions context_permission
    where context_permission.id=nullif(p_draft->>'guardian_context_permission_id','')::uuid
      and context_permission.status='active' and (context_permission.expires_at is null or context_permission.expires_at>now())
    for update;
    select guardian.guardian_person_id into guardian_person_id
    from public.guardian_links guardian
    where guardian.id=context_record.guardian_link_id
      and guardian.status='active' and guardian.revoked_at is null;
    select child_context.status into child_context_status
    from public.child_contexts child_context
    where child_context.id=context_record.child_context_id;
    if context_record.id is null or guardian_person_id<>person_id or child_context_status<>'active' then
      raise no_data_found using message='authorized Principal context not found';end if;
    insert into public.guardian_context_permission_grants(guardian_context_permission_id,capability_id,effect,status,
      changed_by_person_id,reason) select context_record.id,item.capability_id,item.effect,'active',actor,
      coalesce(nullif(btrim(p_draft->>'reason'),''),'Modelo Principal copiado como snapshot.')
    from public.access_profile_template_principal_capabilities item where item.template_id=template.id
    on conflict(guardian_context_permission_id,capability_id) do update set effect=excluded.effect,status='active',
      changed_by_person_id=actor,reason=excluded.reason,revoked_at=null,updated_at=now();
    update public.guardian_context_permissions set source_template_id=template.id,source_template_version=template.version,
      starts_at=coalesce(nullif(p_draft->>'starts_at','')::timestamptz,starts_at),
      expires_at=coalesce(nullif(p_draft->>'expires_at','')::timestamptz,expires_at),version=version+1,updated_at=now()
    where id=context_record.id returning id,version into assignment_id,profile_version;
  else raise invalid_parameter_value using message='unsupported profile assignment';end if;
  result:=jsonb_build_object('assignment_id',assignment_id,'profile_id',profile_id,'domain',domain,'person_id',person_id,
    'membership_id',case when domain='institution' then membership.id end,
    'institution_id',case when domain='institution' then membership.institution_id
      when domain='platform' then nullif(p_draft->>'institution_id','')::uuid end,
    'unit_id',unit_id,'group_id',group_id,
    'guardian_context_permission_id',case when domain='principal' then assignment_id end,
    'scope_kind',case when domain='principal' then 'child_context' else scope_kind end,
    'starts_at',nullif(p_draft->>'starts_at',''),'expires_at',nullif(p_draft->>'expires_at',''),
    'version',case when domain='principal' then profile_version::text else '1' end,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','membership_changed',domain||'_access_profile_assignment',assignment_id,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Vínculo de pessoa ao perfil.'),result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'assignment_link',p_draft,result);return result;
end $function$;

CREATE OR REPLACE FUNCTION app_private.superadmin_access_profile_import_confirm(p_request_id uuid, p_job_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<vars>>
declare actor uuid:=app_private.current_person_id();job public.import_jobs%rowtype;row_record record;
  created_count int:=0;definition jsonb;result jsonb;
  payload jsonb:=jsonb_build_object('job_id',p_job_id,'version',p_expected_version);replay jsonb;
  domain text;kind text;required_permission text;definition_id uuid;
begin
  if actor is null or not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message='MFA AAL2 required';end if;
  replay:=app_private.access_profile_replay(p_request_id,actor,'import_confirm',payload);
  if replay is not null then return replay;end if;
  select * into job from public.import_jobs where id=p_job_id for update;
  if job.id is null or job.target_domain<>'access_profiles_import' or job.created_by<>actor
    or job.summary->>'phase'<>'preview_ready' then
    raise no_data_found using message='import job unavailable';end if;
  if job.version<>p_expected_version then raise serialization_failure using message='stale import version';end if;
  if exists(select 1 from public.import_errors where import_job_id=job.id) then
    raise check_violation using message='import validation errors must be resolved';end if;
  for row_record in select * from public.import_rows
    where import_job_id=job.id and error_code is null order by row_number loop
    domain:=row_record.payload_json->>'domain';kind:=row_record.payload_json->>'record_kind';
    required_permission:=case domain when 'platform' then 'platform.roles.import'
      when 'institution' then 'institution.roles.import' when 'principal' then 'principal.roles.import' end;
    if required_permission is null or not app_private.has_platform_permission(required_permission) then
      raise insufficient_privilege using message='definition import permission required';end if;
    perform app_private.access_profile_require_mutation(domain);
    if kind='profile' and domain in('platform','institution') then
      definition:=app_private.access_profile_create_internal(actor,
        row_record.payload_json||jsonb_build_object('status','inactive'));
    else
      definition:=app_private.access_profile_model_create_internal(actor,
        row_record.payload_json||jsonb_build_object('status','inactive'));
      definition_id:=(definition->>'id')::uuid;
      update public.access_profile_templates set definition_kind=kind where id=definition_id;
      definition:=app_private.access_profile_model_detail(definition_id);
    end if;
    created_count:=created_count+1;
  end loop;
  insert into public.import_results(import_job_id,created_count,completed_at)
  values(job.id,vars.created_count,now())
  on conflict(import_job_id) do update
  set created_count=excluded.created_count,completed_at=excluded.completed_at;
  update public.import_jobs set processing_state='SUCESSO',status='active',finished_at=now(),
    version=version+1,updated_at=now(),summary=summary||jsonb_build_object('phase','completed',
      'created_count',created_count,'imported_status','inactive') where id=job.id returning * into job;
  result:=jsonb_build_object('job_id',job.id,'status',job.processing_state,'phase','completed',
    'created_count',created_count,'version',job.version,'replayed',false,'format','csv',
    'template_version','access-profiles-v1');
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','permission_changed','access_profile_import',job.id,'success',
    'Importação de definições access-profiles-v1 concluída sem vínculos ou PII.',result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'import_confirm',payload,result);
  return result;
end $function$;
