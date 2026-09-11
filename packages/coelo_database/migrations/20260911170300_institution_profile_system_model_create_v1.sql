-- 20260911170300_institution_profile_system_model_create_v1
-- Defeito de producao (R05, rota real de Perfis > Admin > Criar perfil, 11/09 13:23):
-- superadmin_access_profile_save no dominio institution devolvia 23514
-- institution_roles_global_system_check, porque access_profile_create_internal
-- inseria institution_id null com is_system false. Nenhum perfil Admin podia
-- ser criado pelo Superadmin.
-- Regra (ADR 0034 Decisao 15, P31): criado pela plataforma sem institution_id,
-- o perfil e um modelo do sistema (is_system); com institution_id (validado,
-- instituicao ativa) e um perfil proprio da instituicao. Modelos do sistema
-- de Admin passam a ser editaveis pela plataforma (quem tem
-- institution.roles.manage), como o Owner pediu; os modelos de plataforma
-- (Owner, Auditor...) continuam protegidos. Corpos copiados da baseline com
-- so essas mudancas. Idempotente: create or replace.

CREATE OR REPLACE FUNCTION "app_private"."access_profile_create_internal"("p_actor" "uuid", "p_draft" "jsonb", "p_source_template_id" "uuid" DEFAULT NULL::"uuid", "p_source_template_version" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare domain text:=p_draft->>'domain';profile_id uuid;generated_code text;target_institution_id uuid:=nullif(p_draft->>'institution_id','')::uuid;
  capability jsonb;capabilities jsonb:=coalesce(p_draft->'capabilities','[]'::jsonb);permission_id uuid;
begin
  if p_actor is distinct from app_private.current_person_id() or domain not in('platform','institution')
    or nullif(btrim(p_draft->>'name'),'') is null or char_length(btrim(p_draft->>'name'))>120
    or jsonb_typeof(capabilities)<>'array' or jsonb_array_length(capabilities)>500 then
    raise invalid_parameter_value using message='invalid profile draft';
  end if;
  generated_code:=trim(both '-' from regexp_replace(lower(btrim(p_draft->>'name')),'[^a-z0-9]+','-','g'))
    ||'-'||left(replace(gen_random_uuid()::text,'-',''),8);
  if domain='platform' then
    if coalesce(p_draft->>'max_scope_kind','platform') not in('platform','institution') then
      raise invalid_parameter_value using message='invalid platform profile scope';end if;
    for capability in select value from jsonb_array_elements(capabilities) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.platform_permissions
        where code=capability->>'code' and status='active') then raise invalid_parameter_value using message='unknown or invalid capability';end if;
      if capability->>'effect'='allow' and not app_private.has_platform_permission(capability->>'code') then
        raise insufficient_privilege using message='cannot delegate capability operator does not hold';end if;
    end loop;
    insert into public.platform_roles(code,name,description,status,is_system,created_by,max_scope_kind,source_template_id,source_template_version)
    values(generated_code,btrim(p_draft->>'name'),nullif(btrim(p_draft->>'description'),''),
      coalesce(p_draft->>'status','inactive')::public.record_status,false,p_actor,
      coalesce(p_draft->>'max_scope_kind','platform'),p_source_template_id,p_source_template_version) returning id into profile_id;
    insert into public.platform_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}',p_actor,'active'
    from jsonb_array_elements(capabilities) item join public.platform_permissions permission_record on permission_record.code=item.value->>'code';
  else
    if coalesce(p_draft->>'max_scope_kind','institution') not in('institution','unit','group') then
      raise invalid_parameter_value using message='invalid institution profile scope';end if;
    for capability in select value from jsonb_array_elements(capabilities) loop
      select id into permission_id from public.institution_permissions where code=capability->>'code' and status='active';
      if capability->>'effect' not in('allow','deny') or permission_id is null then
        raise invalid_parameter_value using message='unknown or invalid capability';end if;
      if capability->>'effect'='allow' and not app_private.access_profile_can_delegate_institution(permission_id) then
        raise insufficient_privilege using message='cannot delegate capability operator does not hold';end if;
    end loop;
    -- P31: sem institution_id o perfil e um modelo do sistema (is_system) da
    -- plataforma; com institution_id e um perfil proprio daquela instituicao.
    if target_institution_id is not null and not exists(select 1 from public.institutions institution
        where institution.id=target_institution_id and institution.status='active') then
      raise invalid_parameter_value using message='invalid institution for profile';end if;
    insert into public.institution_roles(institution_id,code,name,description,status,is_system,max_scope_kind,source_template_id,source_template_version)
    values(target_institution_id,generated_code,btrim(p_draft->>'name'),nullif(btrim(p_draft->>'description'),''),
      coalesce(p_draft->>'status','inactive')::public.record_status,target_institution_id is null,
      coalesce(p_draft->>'max_scope_kind','institution'),p_source_template_id,p_source_template_version) returning id into profile_id;
    insert into public.institution_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}',p_actor,'active'
    from jsonb_array_elements(capabilities) item join public.institution_permissions permission_record on permission_record.code=item.value->>'code';
  end if;
  return app_private.access_profile_detail_v2(domain,profile_id);
end $$;

CREATE OR REPLACE FUNCTION "app_private"."superadmin_access_profile_update"("p_request_id" "uuid", "p_draft" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare domain text:=p_draft->>'domain';profile_id uuid:=nullif(p_draft->>'id','')::uuid;actor uuid;
  replay jsonb;before_data jsonb;profile jsonb;result jsonb;capability jsonb;
  expected_version bigint:=nullif(p_draft->>'expected_version','')::bigint;
begin
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'update',p_draft);if replay is not null then return replay;end if;
  perform pg_advisory_xact_lock(hashtextextended('access-profile-full-authority',0));
  before_data:=app_private.access_profile_detail_v2(domain,profile_id);
  -- P31: modelos do sistema de Admin sao editados so pela plataforma (quem passa
  -- por access_profile_require_mutation('institution')); os de plataforma seguem protegidos.
  if (before_data->>'is_system')::boolean and domain<>'institution' then raise insufficient_privilege using message='system profile is protected';end if;
  if (before_data->>'version')::bigint is distinct from expected_version then raise serialization_failure using message='stale profile version';end if;
  if jsonb_typeof(coalesce(p_draft->'capabilities','[]'))<>'array' then raise invalid_parameter_value using message='invalid capabilities';end if;
  if domain='platform' then
    for capability in select value from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.platform_permissions where code=capability->>'code' and status='active') then
        raise invalid_parameter_value using message='unknown or invalid capability';end if;
      if capability->>'effect'='allow' and not app_private.has_platform_permission(capability->>'code') then
        raise insufficient_privilege using message='cannot delegate capability operator does not hold';end if;
    end loop;
    update public.platform_roles set name=btrim(p_draft->>'name'),description=nullif(btrim(p_draft->>'description'),''),
      status=coalesce(p_draft->>'status',status::text)::public.record_status,
      max_scope_kind=coalesce(p_draft->>'max_scope_kind',max_scope_kind),version=version+1,updated_at=now() where id=profile_id;
    update public.platform_role_permissions set status='inactive',revoked_at=now() where role_id=profile_id and status='active';
    insert into public.platform_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}',actor,'active'
    from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) item
    join public.platform_permissions permission_record on permission_record.code=item.value->>'code'
    on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null,granted_by=actor;
    perform app_private.assert_full_authority_remains();
  elsif domain='institution' then
    for capability in select value from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.institution_permissions where code=capability->>'code' and status='active') then
        raise invalid_parameter_value using message='unknown or invalid capability';end if;
    end loop;
    update public.institution_roles set name=btrim(p_draft->>'name'),description=nullif(btrim(p_draft->>'description'),''),
      status=coalesce(p_draft->>'status',status::text)::public.record_status,
      max_scope_kind=coalesce(p_draft->>'max_scope_kind',max_scope_kind),version=version+1,updated_at=now() where id=profile_id;
    update public.institution_role_permissions set status='inactive',revoked_at=now() where role_id=profile_id and status='active';
    insert into public.institution_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}',actor,'active'
    from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) item
    join public.institution_permissions permission_record on permission_record.code=item.value->>'code'
    on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null,granted_by=actor;
  else raise invalid_parameter_value using message='unsupported profile domain';end if;
  profile:=app_private.access_profile_detail_v2(domain,profile_id);
  result:=jsonb_build_object('profile',profile,'profile_id',profile_id,'domain',domain,
    'version',(profile->>'version')::bigint,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
  values(actor,'aal2','permission_changed',domain||'_access_profile',profile_id,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Atualização de perfil.'),before_data,profile);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'update',p_draft,result);return result;
end $$;
