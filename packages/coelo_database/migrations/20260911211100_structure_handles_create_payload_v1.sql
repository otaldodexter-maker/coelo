-- R05 realm-interno (12): complemento do @ de estrutura (ADR 0034 Decisao 16)
-- sobre candidatos/estrutura/20260911180000_structure_handles_v1 (frente G1).
--
-- Sem mudar assinaturas: o @ entra como campo OPCIONAL `handle` no payload dos
-- RPCs de criacao existentes e, ausente, o servidor gera o padrao hierarquico:
--   * turma: app_private.superadmin_group_save aceita `handle` na criacao
--     (disponibilidade global via structure_handle_in_use; SAI_HANDLE_TAKEN);
--     ausente -> gatilho groups_assign_handle (@turma.unidade). Na edicao, um
--     `handle` diferente do atual e recusado (SAI_HANDLE_USE_SET): a troca
--     passa por superadmin_structure_handle_set_v1 (trava de 30 dias).
--   * unidade: app_private.create_unit_for_superadmin aceita `handle` (ja
--     aceitava, agora com disponibilidade global) e o padrao passa a ser
--     @nomedaunidade.nomedainstituicao (sufixo curto em colisao) em vez de
--     slug + id.
--   * atividade: public.superadmin_activity_create_v2 aceita `handle` (o
--     primeiro segmento vira handle_stem; canonical_handle continua
--     stem.unidade.instituicao pelo gatilho set_activity_canonical_handle).
--   * detail_v2 de Unidades e Turmas devolvem handle e handle_last_changed_at
--     (Turmas tambem o handle da unidade).
-- Corpos reescritos a partir de pg_get_functiondef do descartavel (baseline +
-- ordem de producao + 180000), so com as insercoes marcadas "Decisao 16".
--
-- Reversao: recriar as funcoes como em 20260910160000 (unidade),
-- 20260910180100 (atividade), baseline (group_save) e 20260910180300/180310.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'structure handle payload migration must run as postgres';
  end if;
  if to_regprocedure('app_private.structure_handle_in_use(text,text,uuid)') is null
    or to_regprocedure('app_private.structure_handle_normalize(text)') is null
    or to_regprocedure('app_private.structure_handle_segment(text)') is null
    or to_regprocedure('app_private.superadmin_group_save(uuid,uuid,bigint,jsonb)') is null
    or to_regprocedure('public.superadmin_activity_create_v2(uuid,jsonb)') is null
    or to_regprocedure('app_private.create_unit_for_superadmin(uuid,jsonb)') is null
    or to_regprocedure('app_private.superadmin_unit_detail_payload_v2(uuid)') is null
    or to_regprocedure('app_private.superadmin_group_detail_payload_v2(uuid)') is null
    or not exists (select 1 from information_schema.columns where table_schema='public' and table_name='groups' and column_name='handle') then
    raise object_not_in_prerequisite_state using
      message = 'structure_handles_v1 (20260911180000) and the v2 structure RPCs are required';
  end if;
end
$preflight$;

-- 1. Turmas ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_private.superadmin_group_save(p_request_id uuid, p_group_id uuid, p_expected_version bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_person_id uuid;
  request_hash bytea;
  prior app_private.group_management_command_receipts%rowtype;
  unit_record public.units%rowtype;
  group_record public.groups%rowtype;
  payload_institution_id uuid;
  payload_unit_id uuid;
  local_person jsonb;
  activity_value text;
  invite_value jsonb;
  role_record_id uuid;
  target_membership_id uuid;
  target_person_id uuid;
  target_invitation_id uuid;
  enqueue_invite boolean;
  result jsonb;
begin
  if p_request_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = 'request_id and payload are required';
  end if;
  if (select auth.uid()) is null then raise insufficient_privilege using message = 'authentication required'; end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then raise insufficient_privilege using message = 'active person required'; end if;
  if not app_private.has_platform_permission('groups.manage') then
    raise insufficient_privilege using message = 'groups.manage required';
  end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message = 'MFA AAL2 required'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := app_private.group_management_request_hash(p_payload);
  select receipt.* into prior from app_private.group_management_command_receipts receipt where receipt.request_id = p_request_id;
  if found then
    if prior.actor_person_id <> actor_person_id or prior.request_hash <> request_hash
       or (p_group_id is not null and prior.group_id is distinct from p_group_id) then
      raise invalid_parameter_value using message = 'request_id already used by another command';
    end if;
    result := app_private.group_management_payload(prior.group_id);
    if (result ->> 'management_version')::bigint <> prior.result_management_version then
      raise serialization_failure using message = 'receipt result is no longer current';
    end if;
    return result;
  end if;

  if p_payload - array[
    'institution_id','unit_id','name','group_type','group_type_other_text','status',
    'inherit_appearance','inherit_access','inherit_activities','branding','local_people',
    'activity_ids','invites','type_request','handle'
  ] <> '{}'::jsonb then
    raise invalid_parameter_value using message = 'unknown group payload key';
  end if;
  payload_unit_id := nullif(p_payload ->> 'unit_id', '')::uuid;
  payload_institution_id := nullif(p_payload ->> 'institution_id', '')::uuid;
  select * into unit_record from public.units where id = payload_unit_id and status = 'active';
  if unit_record.id is null then raise invalid_parameter_value using message = 'unknown or inactive unit'; end if;
  if payload_institution_id is distinct from unit_record.institution_id then
    raise invalid_parameter_value using message = 'unit does not belong to institution';
  end if;
  if nullif(btrim(p_payload ->> 'name'), '') is null
     or nullif(btrim(p_payload ->> 'group_type'), '') is null then
    raise invalid_parameter_value using message = 'name and group_type are required';
  end if;

  if p_group_id is null then
    if coalesce(p_expected_version, 0) <> 0 then
      raise invalid_parameter_value using message = 'create expected_version must be zero';
    end if;
    -- Decisao 16: @ opcional na criacao; ausente -> padrao do gatilho groups_assign_handle
    if nullif(btrim(p_payload ->> 'handle'), '') is not null
       and app_private.structure_handle_in_use(app_private.structure_handle_normalize(p_payload ->> 'handle'), 'group', null) then
      raise unique_violation using message = 'handle already in use', detail = 'SAI_HANDLE_TAKEN';
    end if;
    insert into public.groups(
      institution_id, unit_id, name, group_type, group_type_other_text, status,
      inherit_appearance, inherit_access, inherit_activities, created_at, updated_at, handle
    ) values (
      unit_record.institution_id, unit_record.id, btrim(p_payload ->> 'name'),
      lower(btrim(p_payload ->> 'group_type')), nullif(btrim(p_payload ->> 'group_type_other_text'), ''),
      coalesce(p_payload ->> 'status', 'active')::public.record_status,
      coalesce((p_payload ->> 'inherit_appearance')::boolean, true),
      coalesce((p_payload ->> 'inherit_access')::boolean, true),
      coalesce((p_payload ->> 'inherit_activities')::boolean, true), now(), now(),
      nullif(app_private.structure_handle_normalize(p_payload ->> 'handle'), '')
    ) returning * into group_record;
  else
    select * into group_record from public.groups where id = p_group_id for update;
    if group_record.id is null then raise no_data_found using message = 'group not found'; end if;
    if group_record.institution_id <> unit_record.institution_id or group_record.unit_id <> unit_record.id then
      raise invalid_parameter_value using message = 'group hierarchy cannot be changed';
    end if;
    if group_record.management_version <> p_expected_version then
      raise serialization_failure using message = 'stale group version';
    end if;
    -- a troca do @ passa por superadmin_structure_handle_set_v1 (trava de 30 dias)
    if nullif(btrim(p_payload ->> 'handle'), '') is not null
       and app_private.structure_handle_normalize(p_payload ->> 'handle') is distinct from group_record.handle then
      raise invalid_parameter_value using message = 'handle changes use superadmin_structure_handle_set_v1', detail = 'SAI_HANDLE_USE_SET';
    end if;
    update public.groups set
      name = btrim(p_payload ->> 'name'),
      group_type = lower(btrim(p_payload ->> 'group_type')),
      group_type_other_text = nullif(btrim(p_payload ->> 'group_type_other_text'), ''),
      status = coalesce(p_payload ->> 'status', status::text)::public.record_status,
      inherit_appearance = coalesce((p_payload ->> 'inherit_appearance')::boolean, inherit_appearance),
      inherit_access = coalesce((p_payload ->> 'inherit_access')::boolean, inherit_access),
      inherit_activities = coalesce((p_payload ->> 'inherit_activities')::boolean, inherit_activities),
      management_version = management_version + 1, updated_at = now()
    where id = p_group_id returning * into group_record;
  end if;

  if group_record.inherit_appearance then
    delete from public.group_branding where group_id = group_record.id;
  else
    if jsonb_typeof(p_payload -> 'branding') <> 'object' then
      raise invalid_parameter_value using message = 'local branding is required when appearance is customized';
    end if;
    insert into public.group_branding(
      group_id, accent_color, secondary_color, text_color, surface_color,
      updated_by_person_id, updated_at
    ) values (
      group_record.id, nullif(p_payload -> 'branding' ->> 'accent_color', ''),
      nullif(p_payload -> 'branding' ->> 'secondary_color', ''),
      nullif(p_payload -> 'branding' ->> 'text_color', ''),
      nullif(p_payload -> 'branding' ->> 'surface_color', ''), actor_person_id, now()
    ) on conflict (group_id) do update set
      accent_color = excluded.accent_color, secondary_color = excluded.secondary_color,
      text_color = excluded.text_color, surface_color = excluded.surface_color,
      updated_by_person_id = excluded.updated_by_person_id, updated_at = now();
  end if;

  if p_payload ? 'local_people' then
    if jsonb_typeof(p_payload -> 'local_people') <> 'array' then
      raise invalid_parameter_value using message = 'local_people must be an array';
    end if;
    update public.institution_role_assignments assignment
       set status = 'inactive', updated_at = now()
      from public.institution_memberships membership
     where assignment.membership_id = membership.id
       and assignment.scope_kind = 'group'
       and assignment.scope_group_id = group_record.id
       and assignment.status = 'active'
       and membership.institution_id = group_record.institution_id
       and membership.person_id not in (
         select (value ->> 'person_id')::uuid
           from jsonb_array_elements(p_payload -> 'local_people') value
       );
    for local_person in select value from jsonb_array_elements(p_payload -> 'local_people') loop
      target_person_id := nullif(local_person ->> 'person_id', '')::uuid;
      if target_person_id is null or not exists (
        select 1 from public.people where id = target_person_id and status = 'active'
      ) then
        raise invalid_parameter_value using message = 'local person must be an existing active global identity';
      end if;
      select id into role_record_id from public.institution_roles
      where code = local_person ->> 'role_code' and status = 'active'
        and (institution_id is null or institution_id = group_record.institution_id)
      order by institution_id nulls last limit 1;
      if role_record_id is null then raise invalid_parameter_value using message = 'unknown role_code'; end if;
      target_membership_id := null;
      select id into target_membership_id from public.institution_memberships
      where person_id = target_person_id
        and institution_id = group_record.institution_id
        and status = 'active' and revoked_at is null
      order by created_at desc limit 1;
      if target_membership_id is null then
        insert into public.institution_memberships(
          person_id, institution_id, role_code, status, scope_kind,
          scope_unit_id, scope_group_id, invited_by
        ) values (
          target_person_id, group_record.institution_id,
          local_person ->> 'role_code', 'active', 'group', group_record.unit_id,
          group_record.id, actor_person_id
        ) returning id into target_membership_id;
      end if;
      update public.institution_role_assignments set
        status = 'inactive', updated_at = now()
      where membership_id = target_membership_id and status = 'active'
        and scope_kind = 'group' and scope_group_id = group_record.id
        and role_id <> role_record_id;
      insert into public.institution_role_assignments(
        membership_id, role_id, scope_kind, scope_unit_id, scope_group_id,
        status, granted_by
      ) values (
        target_membership_id, role_record_id, 'group', group_record.unit_id,
        group_record.id, 'active', actor_person_id
      ) on conflict do nothing;
    end loop;
  end if;

  if p_payload ? 'activity_ids' then
    if jsonb_typeof(p_payload -> 'activity_ids') <> 'array' then
      raise invalid_parameter_value using message = 'activity_ids must be an array';
    end if;
    update public.activity_group_links set status = 'inactive', updated_at = now()
    where group_id = group_record.id and status = 'active'
      and activity_id not in (
        select value::uuid from jsonb_array_elements_text(p_payload -> 'activity_ids') value
      );
    for activity_value in select value from jsonb_array_elements_text(p_payload -> 'activity_ids') loop
      if not exists (
        select 1 from public.activity_definitions definition
        join public.activity_unit_links unit_link on unit_link.activity_id = definition.id
          and unit_link.unit_id = group_record.unit_id and unit_link.status = 'active'
        where definition.id = activity_value::uuid
          and definition.institution_id = group_record.institution_id
      ) then raise invalid_parameter_value using message = 'activity is outside group hierarchy'; end if;
      insert into public.activity_group_links(activity_id, group_id, institution_id, unit_id, linked_by_person_id, status)
      values (activity_value::uuid, group_record.id, group_record.institution_id, group_record.unit_id, actor_person_id, 'active')
      on conflict (activity_id, group_id) do update set status = 'active', updated_at = now();
    end loop;
  end if;

  if p_payload ? 'invites' then
    if jsonb_typeof(p_payload -> 'invites') <> 'array' then
      raise invalid_parameter_value using message = 'invites must be an array';
    end if;
    update public.invitations invitation
       set invitation_state = 'revoked', revoked_at = now(), status = 'inactive'
     where invitation.group_id = group_record.id
       and invitation.invitation_state = 'pending'
       and invitation.id not in (
         select (value ->> 'invitation_id')::uuid
           from jsonb_array_elements(p_payload -> 'invites') value
          where nullif(value ->> 'invitation_id', '') is not null
            and value ->> 'invitation_id' not like 'invite-%'
       );
    for invite_value in select value from jsonb_array_elements(p_payload -> 'invites') loop
      target_person_id := nullif(invite_value ->> 'person_id', '')::uuid;
      if target_person_id is null or not exists (
        select 1 from public.people where id = target_person_id and status = 'active'
      ) then
        raise invalid_parameter_value using message = 'invite target must be an existing active global identity';
      end if;
      if not exists (
        select 1 from public.institution_roles
         where code = invite_value ->> 'role_code' and status = 'active'
           and (institution_id is null or institution_id = group_record.institution_id)
      ) then
        raise invalid_parameter_value using message = 'unknown invitation role_code';
      end if;
      enqueue_invite := false;
      target_invitation_id := case
        when nullif(invite_value ->> 'invitation_id', '') is null
          or invite_value ->> 'invitation_id' like 'invite-%' then null
        else (invite_value ->> 'invitation_id')::uuid end;
      if target_invitation_id is null then
        insert into public.invitations(
          scope_kind, institution_id, unit_id, group_id, target_person_id,
          role_code, token_hash, expires_at, invitation_state, invited_by,
          send_count, sent_at, last_sent_at
        ) values (
          'group', group_record.institution_id, group_record.unit_id, group_record.id,
          target_person_id, invite_value ->> 'role_code',
          encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'),
          now() + interval '7 days', 'pending', actor_person_id, 1, now(), now()
        ) returning id into target_invitation_id;
        enqueue_invite := true;
      else
        update public.invitations
           set last_sent_at = case when invite_value ->> 'command' = 'resend' then now() else last_sent_at end,
               send_count = case when invite_value ->> 'command' = 'resend' then send_count + 1 else send_count end
         where id = target_invitation_id and group_id = group_record.id
           and institution_id = group_record.institution_id and invitation_state = 'pending';
        if not found then raise no_data_found using message = 'invitation not found in group scope'; end if;
        enqueue_invite := invite_value ->> 'command' = 'resend';
      end if;
      if enqueue_invite then
        insert into app_private.invitation_delivery_queue(invitation_id, requested_by_person_id)
      values (target_invitation_id, actor_person_id)
      on conflict (invitation_id) do update set
        state = 'pending', requested_by_person_id = excluded.requested_by_person_id,
        available_at = now(), updated_at = now();
      end if;
    end loop;
  end if;
  if p_payload ? 'type_request' and jsonb_typeof(p_payload -> 'type_request') = 'object' then
    insert into public.group_type_requests(
      institution_id, group_id, requested_label, justification, requested_by_person_id
    ) values (
      group_record.institution_id, group_record.id,
      p_payload -> 'type_request' ->> 'label',
      p_payload -> 'type_request' ->> 'justification', actor_person_id
    );
  end if;

  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor_person_id, auth.jwt() ->> 'aal',
    case when p_group_id is null then 'group.create' else 'group.update' end,
    'group', group_record.id, group_record.institution_id, 'success',
    jsonb_build_object(
      'management_version', group_record.management_version,
      'inherit_appearance', group_record.inherit_appearance,
      'inherit_access', group_record.inherit_access,
      'inherit_activities', group_record.inherit_activities
    )
  );
  insert into app_private.group_management_command_receipts(
    request_id, request_hash, actor_person_id, group_id, result_management_version
  ) values (
    p_request_id, request_hash, actor_person_id, group_record.id, group_record.management_version
  );
  return app_private.group_management_payload(group_record.id);
end $function$;

-- 2. Atividades --------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.superadmin_activity_create_v2(p_request_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); institution uuid; activity uuid:=gen_random_uuid(); taxonomy uuid; units uuid[]; h bytea; replay jsonb; a public.activity_definitions%rowtype; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.create',null);
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or p_payload-array['institution_id','name','description','taxonomy_id','icon_key','initials','unit_ids','handle']<>'{}'::jsonb
 or jsonb_typeof(p_payload->'institution_id')<>'string' or jsonb_typeof(p_payload->'name')<>'string'
 or jsonb_typeof(p_payload->'taxonomy_id')<>'string' or jsonb_typeof(p_payload->'unit_ids')<>'array'
 or (p_payload?'description' and p_payload->'description'<>'null'::jsonb and jsonb_typeof(p_payload->'description')<>'string')
 or (p_payload?'icon_key' and p_payload->'icon_key'<>'null'::jsonb and jsonb_typeof(p_payload->'icon_key')<>'string')
 or (p_payload?'initials' and p_payload->'initials'<>'null'::jsonb and jsonb_typeof(p_payload->'initials')<>'string')
 or exists(select 1 from jsonb_array_elements(p_payload->'unit_ids') item where jsonb_typeof(item)<>'string')
 or length(btrim(coalesce(p_payload->>'name',''))) not between 1 and 120
 or length(coalesce(p_payload->>'description',''))>500 or length(coalesce(p_payload->>'icon_key',''))>64
 or length(btrim(coalesce(p_payload->>'initials',''))) not between 1 and 2
 or nullif(p_payload->>'institution_id','') is null or nullif(p_payload->>'taxonomy_id','') is null
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 begin institution:=(p_payload->>'institution_id')::uuid; taxonomy:=(p_payload->>'taxonomy_id')::uuid; select array_agg(x::uuid) into units from jsonb_array_elements_text(p_payload->'unit_ids')x; exception when others then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end;
 if p_request_id is null or nullif(btrim(p_payload->>'name'),'') is null or coalesce(array_length(units,1),0) not between 1 and 100 or cardinality(units)<>(select count(distinct unit_id) from unnest(units) unit_id) then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.create',institution); perform app_private.activity_v2_require_context('activities.link_units',institution);
 h:=app_private.activity_v2_command_request_hash('activity.create',institution,null,null,p_payload); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,institution,null,'activity.create',h,correlation); if replay is not null then return replay; end if;
 perform 1 from public.activity_taxonomies t where t.id=taxonomy order by t.id for share;
 perform 1 from public.units u where u.id=any(units) order by u.id for share;
 if not exists(select 1 from public.activity_taxonomies t where t.id=taxonomy and t.status='active' and t.code<>'outros') or (select count(*) from public.units u where u.id=any(units) and u.institution_id=institution and u.status='active')<>cardinality(units) then raise invalid_parameter_value using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.create','create',correlation);
 insert into public.activity_definitions(id,institution_id,name,description,origin_scope_kind,origin_unit_id,created_by_person_id,status,taxonomy_id,handle_stem,identity_mode,identity_initials,identity_color,identity_icon)
 values(activity,institution,btrim(p_payload->>'name'),nullif(btrim(p_payload->>'description'),''),'institution',null,null,'draft',taxonomy,coalesce(nullif(app_private.activity_slugify(split_part(app_private.structure_handle_normalize(p_payload->>'handle'),'.',1)),''),nullif(app_private.activity_slugify(p_payload->>'name'),''),'activity-'||left(activity::text,8)),'initials',nullif(p_payload->>'initials',''),'#D63C00',nullif(p_payload->>'icon_key','')) returning * into a;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_units','link_units',correlation);
 insert into public.activity_unit_links(activity_id,institution_id,unit_id,linked_by_person_id) select activity,institution,x,null from unnest(units)x;
 correlation:=app_private.activity_v2_append_audit(ctx,institution,activity,'activities.create','activity.create',pg_catalog.jsonb_build_object('units',cardinality(units)));
 return app_private.activity_v2_finish_command(ctx,p_request_id,institution,activity,'activity.create',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('units',cardinality(units)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.create','activity.create',code,correlation,institution); end $function$;

-- 3. Unidades ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_private.create_unit_for_superadmin(p_request_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id();tenant uuid;target uuid:=gen_random_uuid();type_id uuid;plan_id uuid;
h bytea;prior app_private.unit_management_command_receipts%rowtype;handle_value text;result jsonb;begin
tenant:=nullif(p_payload->>'institution_id','')::uuid;type_id:=nullif(p_payload->>'unit_type_id','')::uuid;plan_id:=nullif(p_payload->>'plan_override_id','')::uuid;
if p_request_id is null or actor is null or(select auth.uid())is null or not app_private.has_scoped_platform_permission('units.create',tenant)
or not app_private.has_mfa_aal2()then raise insufficient_privilege using message='units.create and AAL2 required';end if;
if nullif(btrim(p_payload->>'name'),'')is null or nullif(btrim(p_payload->>'slug'),'')is null or type_id is null
then raise invalid_parameter_value using message='institution, name, slug and unit type required';end if;
if plan_id is not null and(not app_private.has_platform_permission('units.plan.manage')or not app_private.unit_plan_is_available(plan_id,tenant))
then raise insufficient_privilege using message='units.plan.manage and available plan required';end if;
perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));h:=app_private.unit_management_hash(p_payload);
select*into prior from app_private.unit_management_command_receipts where request_id=p_request_id;
if prior.request_id is not null then if prior.actor_person_id<>actor or prior.command_kind<>'create'or prior.request_hash<>h
then raise invalid_parameter_value using message='request replay mismatch';end if;return app_private.unit_form_payload(prior.unit_id);end if;
-- Decisao 16: @ opcional; ausente -> @nomedaunidade.nomedainstituicao (sufixo curto em colisao)
if nullif(btrim(p_payload->>'handle'),'') is not null then
  handle_value:=app_private.structure_handle_normalize(p_payload->>'handle');
  if app_private.structure_handle_in_use(handle_value,'unit',null) then
    raise unique_violation using message='handle already in use',detail='SAI_HANDLE_TAKEN';
  end if;
else
  handle_value:=coalesce(nullif(app_private.structure_handle_segment(p_payload->>'name'),''),'unidade')
    ||'.'||(select lower(i.slug) from public.institutions i where i.id=tenant);
  -- units_handle_normalized_check: ate 30 caracteres, comeca e termina em [a-z0-9]
  handle_value:=regexp_replace(left(handle_value,30),'[._]+$','');
  if app_private.structure_handle_in_use(handle_value,'unit',null) then
    handle_value:=regexp_replace(left(handle_value,25),'[._]+$','')||'_'||left(replace(target::text,'-',''),4);
  end if;
end if;
insert into public.units(id,institution_id,name,slug,status,unit_type_id,unit_type_other_description,plan_override_id,
management_version,timezone,handle,public_discovery_enabled,public_address_visible,public_contact_visible,
inherit_address,inherit_contact,inherit_branding,inherit_representatives,inherit_administrators,inherit_plan)
values(target,tenant,btrim(p_payload->>'name'),lower(btrim(p_payload->>'slug')),
coalesce(nullif(p_payload->>'unit_status','')::public.record_status,'active'),type_id,
nullif(btrim(p_payload->>'unit_type_other_description'),''),plan_id,1,
coalesce(nullif(p_payload->>'timezone',''),'America/Sao_Paulo'),handle_value,
coalesce((p_payload#>>'{public_profile,discovery_enabled}')::boolean,false),
coalesce((p_payload#>>'{public_profile,address_visible}')::boolean,false),
coalesce((p_payload#>>'{public_profile,contact_visible}')::boolean,false),
coalesce((p_payload#>>'{inheritance,address}')::boolean,true),
coalesce((p_payload#>>'{inheritance,contact}')::boolean,true),
coalesce((p_payload#>>'{inheritance,branding}')::boolean,true),
coalesce((p_payload#>>'{inheritance,representatives}')::boolean,true),
coalesce((p_payload#>>'{inheritance,administrators}')::boolean,true),plan_id is null);
perform app_private.persist_unit_children(target,actor,p_payload);result:=app_private.unit_form_payload(target);
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
values(actor,'aal2','unit.create','unit',target,tenant,'success',jsonb_build_object('unit_type_id',type_id,'plan_override_id',plan_id));
insert into app_private.unit_management_command_receipts values(p_request_id,h,actor,'create',target,1,now());return result;end$function$;

-- 4. Detalhes ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_private.superadmin_unit_detail_payload_v2(p_unit_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'id',unit_record.id,
    'name',unit_record.name,
    'slug',unit_record.slug,
    'handle',unit_record.handle,
    'handle_last_changed_at',unit_record.handle_last_changed_at,
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
  -- Producao usa units.unit_type_id referenciando public.unit_types. A versao
  -- historica juntava institution_types por units.institution_type_id, coluna
  -- que nao existe la, e por isso o pacote nao aplicava sobre a baseline.
  join public.unit_types unit_type
    on unit_type.id=unit_record.unit_type_id
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
$function$;

create or replace function app_private.superadmin_group_detail_payload_v2(p_group_id uuid)
 returns jsonb language sql stable security definer set search_path to '' as $function$
  select jsonb_build_object(
    'id',group_record.id,
    'institution',jsonb_build_object('id',institution.id,'name',institution.public_name),
    'unit',jsonb_build_object('id',unit_record.id,'name',unit_record.name,'handle',unit_record.handle),
    'name',group_record.name,
    'handle',group_record.handle,
    'handle_last_changed_at',group_record.handle_last_changed_at,
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
  join public.institutions institution on institution.id=group_record.institution_id and institution.deleted_at is null
  join public.units unit_record on unit_record.id=group_record.unit_id and unit_record.institution_id=group_record.institution_id
  where group_record.id=p_group_id
$function$;

do $privs$ declare p regprocedure; begin
  foreach p in array array[
    'app_private.superadmin_group_save(uuid,uuid,bigint,jsonb)'::regprocedure,
    'app_private.create_unit_for_superadmin(uuid,jsonb)'::regprocedure,
    'app_private.superadmin_unit_detail_payload_v2(uuid)'::regprocedure,
    'app_private.superadmin_group_detail_payload_v2(uuid)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres', p);
    execute format('revoke all on function %s from public, anon, authenticated, service_role', p);
  end loop;
  execute 'alter function public.superadmin_activity_create_v2(uuid,jsonb) owner to postgres';
  execute 'revoke all on function public.superadmin_activity_create_v2(uuid,jsonb) from public, anon, service_role';
  execute 'grant execute on function public.superadmin_activity_create_v2(uuid,jsonb) to authenticated';
end $privs$;

commit;
