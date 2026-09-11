-- 20260911170600_institution_system_model_delete_v1
-- P45 = B (Owner, 11/09 16:45): um modelo do sistema de perfil de Admin
-- (institution_roles.is_system) criado pelo Superadmin pode ser EXCLUIDO,
-- "apenas conforme hierarquia, como owner". Antes so inativava: o delete
-- devolvia 'system profile is protected' para qualquer is_system.
--
-- Regra que entra, so no ramo institution de
-- app_private.superadmin_access_profile_delete_and_reassign (corpo da
-- baseline, inalterado no resto):
--   * modelo do sistema so pode ser excluido por quem tem
--     institution.roles.manage em membership de PLATAFORMA sem escopo
--     (has_scoped_platform_permission(..., null)): e a hierarquia "como
--     owner"; um perfil de instituicao com institution.roles.manage nao
--     exclui modelo do sistema;
--   * as demais guardas continuam: versao esperada, substituto compativel e
--     ativo quando ha atribuicoes, auditoria e recibo por request_id.
-- Modelos de PLATAFORMA (platform_roles.is_system: owner, operations...)
-- continuam protegidos.

create or replace function app_private.superadmin_access_profile_delete_and_reassign(
  p_request_id uuid, p_domain text, p_profile_id uuid, p_expected_version bigint,
  p_replacement_profile_id uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare actor uuid;payload jsonb:=jsonb_build_object('domain',p_domain,'profile_id',p_profile_id,
  'expected_version',p_expected_version,'replacement_profile_id',p_replacement_profile_id,'reason',p_reason);
  replay jsonb;current_version bigint;is_system boolean;link_count bigint;before_data jsonb;result jsonb;
begin
  actor:=app_private.access_profile_require_mutation(p_domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'delete_and_reassign',payload);if replay is not null then return replay;end if;
  if p_profile_id is null or p_expected_version is null or nullif(btrim(p_reason),'') is null
    or p_replacement_profile_id=p_profile_id then raise invalid_parameter_value using message='invalid delete request';end if;
  if p_domain='platform' then
    perform pg_advisory_xact_lock(hashtextextended('access-profile-full-authority',0));
    select version,platform_roles.is_system,to_jsonb(platform_roles) into current_version,is_system,before_data
      from public.platform_roles where id=p_profile_id for update;
    if current_version is null then raise no_data_found using message='access profile not found';end if;
    if is_system then raise insufficient_privilege using message='system profile is protected';end if;
    if current_version<>p_expected_version then raise serialization_failure using message='stale profile version';end if;
    select count(*) into link_count from public.platform_memberships where role_id=p_profile_id and status='active' and revoked_at is null;
    if link_count>0 and not exists(select 1 from public.platform_roles where id=p_replacement_profile_id and status='active') then
      raise check_violation using message='active replacement required';end if;
    update public.platform_memberships set role_id=p_replacement_profile_id,version=version+1 where role_id=p_profile_id;
    delete from public.platform_roles where id=p_profile_id;perform app_private.assert_full_authority_remains();
  elsif p_domain='institution' then
    select version,institution_roles.is_system,to_jsonb(institution_roles) into current_version,is_system,before_data
      from public.institution_roles where id=p_profile_id for update;
    if current_version is null then raise no_data_found using message='access profile not found';end if;
    -- P45: modelo do sistema de Admin e excluido so pela hierarquia de plataforma (como owner).
    if is_system and not app_private.has_scoped_platform_permission('institution.roles.manage',null) then
      raise insufficient_privilege using message='system profile is protected';end if;
    if current_version<>p_expected_version then raise serialization_failure using message='stale profile version';end if;
    select count(*) into link_count from public.institution_role_assignments where role_id=p_profile_id and status='active';
    if link_count>0 and not exists(select 1 from public.institution_roles replacement
      join public.institution_roles removed on removed.id=p_profile_id where replacement.id=p_replacement_profile_id
        and replacement.status='active' and (replacement.institution_id is null or replacement.institution_id=removed.institution_id)
        and not exists(select 1 from public.institution_role_assignments assignment where assignment.role_id=p_profile_id
          and app_private.access_scope_rank(assignment.scope_kind)>app_private.access_scope_rank(replacement.max_scope_kind))) then
      raise check_violation using message='compatible active replacement required';end if;
    update public.institution_role_assignments set role_id=p_replacement_profile_id,version=version+1,updated_at=now()
      where role_id=p_profile_id;delete from public.institution_roles where id=p_profile_id;
  else raise invalid_parameter_value using message='unsupported profile domain';end if;
  result:=jsonb_build_object('domain',p_domain,'deleted_profile_id',p_profile_id,
    'replacement_profile_id',p_replacement_profile_id,'reassigned_count',link_count,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
  values(actor,'aal2','membership_changed',p_domain||'_access_profile',p_profile_id,'success',p_reason,before_data,result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'delete_and_reassign',payload,result);return result;
end $$;

revoke all on function app_private.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)
  from public, anon, authenticated;
