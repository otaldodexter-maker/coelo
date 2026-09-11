-- R06 estrutura (@ no cliente): structure_handles_client_v1
-- Depende de 20260911180000 (structure_handles_v1) e 20260911211100
-- (handle no payload dos RPCs v2 de criacao), ambos em producao (lotes 42/43).
--
-- O que muda (sem mudar assinaturas):
--   * public.superadmin_activity_save_v2 aceita `definition.handle` (o cliente
--     cria pelo save_v2, nao pelo create_v2 direto): na criacao o campo segue
--     para superadmin_activity_create_v2 (211100), que faz do primeiro segmento
--     o handle_stem; na edicao um handle diferente do stem atual e recusado
--     com ACTIVITY_INVALID_INPUT (a troca passa por superadmin_structure_handle_set_v1)
--     e um igual e ignorado.
--   * app_private.group_management_payload (resposta de superadmin_group_get e
--     superadmin_group_save) passa a devolver `handle` e
--     `handle_last_changed_at`, para o assistente de Turmas mostrar o @ atual
--     na edicao. Chave aditiva: o parser do cliente tolera chaves novas
--     (01a8c3e27, R05).
--
-- Reversao: reaplicar o corpo de 20260910180110 (save_v2) e o de
-- 20260910000000 (group_management_payload).

do $guard$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'structure handles client migration must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)') is null
    or to_regprocedure('public.superadmin_structure_handle_set_v1(uuid,text,uuid,bigint,text)') is null
    or to_regprocedure('app_private.structure_handle_normalize(text)') is null
    or to_regprocedure('app_private.activity_slugify(text)') is null
    or to_regprocedure('app_private.group_management_payload(uuid)') is null
    or not exists (select 1 from information_schema.columns where table_schema='public' and table_name='groups' and column_name='handle_last_changed_at') then
    raise feature_not_supported using
      message = 'structure_handles_v1 (20260911180000), 211100 and activity save v2 (180110) are required';
  end if;
end
$guard$;

-- ---------------------------------------------------------------------------
-- superadmin_activity_save_v2: definition.handle na criacao
-- ---------------------------------------------------------------------------
create or replace function public.superadmin_activity_save_v2(
  p_request_id uuid,
  p_activity_id uuid,
  p_expected_version bigint,
  p_publish boolean,
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  ctx app_private.superadmin_internal_context;
  initial_ctx app_private.superadmin_internal_context;
  capability_ctx app_private.superadmin_internal_context;
  activity public.activity_definitions%rowtype;
  correlation_id uuid := gen_random_uuid();
  institution_id uuid;
  unit_ids uuid[];
  group_ids uuid[];
  definition jsonb;
  result jsonb;
  request_hash bytea;
  receipt app_private.superadmin_internal_activity_save_receipts%rowtype;
  current_activity_id uuid := p_activity_id;
  current_version bigint;
  groups_to_detach uuid[] := '{}'::uuid[];
  selected_to_all uuid[] := '{}'::uuid[];
  bridge_group_ids uuid[] := '{}'::uuid[];
  bridge_group_participation jsonb := '{}'::jsonb;
  prune_participants jsonb := '[]'::jsonb;
  prune_professionals jsonb := '[]'::jsonb;
  prune_group_settings jsonb := '[]'::jsonb;
  prune_professional_actions jsonb := '[]'::jsonb;
  needs_participant_prune boolean := false;
  needs_professional_prune boolean := false;
  needs_permission_prune boolean := false;
  needs_group_bridge boolean := false;
  required_capability text := case
    when p_activity_id is null then 'activities.create'
    else 'activities.manage'
  end;
  required_capabilities text[];
  error_code text;
begin
  begin
    select * into strict ctx
    from app_private.activity_v2_require_context(required_capability, null);

    if p_request_id is null
      or p_expected_version is null
      or p_publish is null
      or p_payload is null
      or jsonb_typeof(p_payload) <> 'object'
      or not (p_payload ?& array[
        'institution_id','definition','unit_ids','group_ids',
        'group_participation','participants','professional_assignments',
        'capability_policies','group_capability_settings',
        'professional_capability_actions'
      ])
      or exists(
        select 1 from jsonb_object_keys(p_payload) key
        where key not in(
          'institution_id','definition','unit_ids','group_ids',
          'group_participation','participants','professional_assignments',
          'capability_policies','group_capability_settings',
          'professional_capability_actions'
        )
      )
      or jsonb_typeof(p_payload->'institution_id') <> 'string'
      or jsonb_typeof(p_payload->'definition') <> 'object'
      or (p_payload->'definition') = '{}'::jsonb
      or exists(
        select 1 from jsonb_object_keys(p_payload->'definition') key
        where key not in('name','description','taxonomy_id','icon_key','initials','handle')
      )
      or jsonb_typeof(p_payload->'unit_ids') <> 'array'
      or jsonb_typeof(p_payload->'group_ids') <> 'array'
      or jsonb_typeof(p_payload->'group_participation') <> 'object'
      or jsonb_typeof(p_payload->'participants') <> 'array'
      or jsonb_typeof(p_payload->'professional_assignments') <> 'array'
      or jsonb_typeof(p_payload->'capability_policies') <> 'object'
      or jsonb_typeof(p_payload->'group_capability_settings') <> 'array'
      or jsonb_typeof(p_payload->'professional_capability_actions') <> 'array'
    then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;

    begin
      institution_id := (p_payload->>'institution_id')::uuid;
      select coalesce(array_agg(item.value::uuid order by item.ordinality), '{}'::uuid[])
      into unit_ids
      from jsonb_array_elements_text(p_payload->'unit_ids') with ordinality item(value, ordinality);
      select coalesce(array_agg(item.value::uuid order by item.ordinality), '{}'::uuid[])
      into group_ids
      from jsonb_array_elements_text(p_payload->'group_ids') with ordinality item(value, ordinality);
    exception when others then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end;

    if (
      select coalesce(array_agg(key order by key), '{}'::text[])
      from jsonb_object_keys(p_payload->'group_participation') key
    ) <> (
      select coalesce(array_agg(group_id::text order by group_id::text), '{}'::text[])
      from unnest(group_ids) group_id
    ) or exists(
      select 1
      from jsonb_each_text(p_payload->'group_participation') participation
      where participation.value is null
        or participation.value not in ('all', 'selected')
    ) then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;

    definition := p_payload->'definition';
    if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;
    if p_activity_id is null then
      if p_expected_version <> 0 then
        raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
      end if;
      select * into strict ctx
      from app_private.activity_v2_require_context('activities.create', institution_id);
    else
      if p_expected_version < 1 then
        raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
      end if;
      select * into activity
      from public.activity_definitions candidate
      where candidate.id = p_activity_id
        and (ctx.scope_kind <> 'institution'
          or candidate.institution_id = ctx.scope_institution_id);
      if activity.id is null then
        raise no_data_found using detail = 'ACTIVITY_NOT_FOUND';
      end if;
      select * into strict ctx
      from app_private.activity_v2_require_context('activities.manage', activity.institution_id);
      if institution_id <> activity.institution_id then
        raise foreign_key_violation using detail = 'ACTIVITY_INVALID_REFERENCE';
      end if;
    end if;

    initial_ctx := ctx;
    required_capabilities := array[
      'activities.link_units','activities.link_groups',
      'activities.assign_people','activities.manage_permissions'
    ]::text[] || case when p_publish
      then array['activities.manage']::text[]
      else '{}'::text[]
    end;
    foreach required_capability in array required_capabilities loop
      perform app_private.activity_v2_require_context(required_capability, institution_id);
    end loop;

    required_capability := case
      when p_activity_id is null then 'activities.create'
      else 'activities.manage'
    end;
    request_hash := app_private.activity_v2_command_request_hash(
      'activity.save',institution_id,p_activity_id,p_expected_version,
      pg_catalog.jsonb_build_object('publish',p_publish,'payload',p_payload)
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_request_id::text,0)
    );
    -- A request lock may wait behind another transaction. READ COMMITTED gives
    -- every statement below a fresh snapshot; bind it to the original actor and
    -- scope before a private receipt can be exposed or any child can mutate.
    select * into strict ctx
    from app_private.activity_v2_require_context(required_capability, institution_id);
    if row(
      ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
      ctx.auth_user_id,ctx.session_id,ctx.platform_role_id,ctx.platform_role_code,
      ctx.scope_kind,ctx.scope_institution_id,ctx.resolved_institution_id,
      ctx.aal,ctx.permission_code,ctx.requires_mfa
    ) is distinct from row(
      initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,
      initial_ctx.internal_membership_id,initial_ctx.auth_user_id,initial_ctx.session_id,
      initial_ctx.platform_role_id,initial_ctx.platform_role_code,initial_ctx.scope_kind,
      initial_ctx.scope_institution_id,initial_ctx.resolved_institution_id,
      initial_ctx.aal,initial_ctx.permission_code,initial_ctx.requires_mfa
    ) then
      raise insufficient_privilege using detail = 'SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    foreach required_capability in array required_capabilities loop
      select * into strict capability_ctx
      from app_private.activity_v2_require_context(required_capability, institution_id);
      if row(
        capability_ctx.internal_identity_id,capability_ctx.internal_auth_link_id,
        capability_ctx.internal_membership_id,capability_ctx.auth_user_id,
        capability_ctx.session_id,capability_ctx.platform_role_id,
        capability_ctx.platform_role_code,
        capability_ctx.scope_kind,capability_ctx.scope_institution_id,
        capability_ctx.resolved_institution_id,capability_ctx.aal
      ) is distinct from row(
        initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,
        initial_ctx.internal_membership_id,initial_ctx.auth_user_id,initial_ctx.session_id,
        initial_ctx.platform_role_id,initial_ctx.platform_role_code,initial_ctx.scope_kind,
        initial_ctx.scope_institution_id,initial_ctx.resolved_institution_id,initial_ctx.aal
      ) then
        raise insufficient_privilege using detail = 'SAI_INTERNAL_CONTEXT_DENIED';
      end if;
    end loop;
    if not exists(
      select 1
      from auth.sessions session_record
      where session_record.id = initial_ctx.session_id
        and session_record.user_id = initial_ctx.auth_user_id
        and (session_record.not_after is null
          or session_record.not_after > pg_catalog.clock_timestamp())
    ) then
      raise insufficient_privilege using detail = 'SAI_SESSION_INVALID';
    end if;
    required_capability := case
      when p_activity_id is null then 'activities.create'
      else 'activities.manage'
    end;
    select * into receipt
    from app_private.superadmin_internal_activity_save_receipts candidate
    where candidate.request_id = p_request_id;
    if receipt.request_id is not null then
      if receipt.internal_identity_id <> ctx.internal_identity_id then
        raise insufficient_privilege using detail = 'SAI_PERMISSION_DENIED';
      end if;
      if receipt.institution_id is distinct from institution_id
        or (p_activity_id is not null and receipt.activity_id is distinct from p_activity_id)
        or receipt.request_hash <> request_hash
      then
        raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE';
      end if;
      return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
        'activity_id',receipt.activity_id,
        'management_version',receipt.resulting_version,
        'status',receipt.resulting_status,
        'correlation_id',receipt.correlation_id,
        'replayed',true
      ));
    end if;

    if p_activity_id is null then
      required_capability := 'activities.create';
      result := public.superadmin_activity_create_v2(
        app_private.activity_request_uuid('activity-save-create', p_request_id),
        definition || pg_catalog.jsonb_build_object(
          'institution_id', institution_id,
          'unit_ids', to_jsonb(unit_ids)
        )
      );
    else
      required_capability := 'activities.manage';
      -- Decisao 16: na edicao a troca do @ passa por
      -- superadmin_structure_handle_set_v1 (trava de 30 dias); um `handle`
      -- diferente do stem atual e recusado (ACTIVITY_INVALID_INPUT: o
      -- normalizador de codigos da familia so deixa passar a lista fechada) e
      -- um igual e simplesmente ignorado.
      if definition ? 'handle' then
        if nullif(pg_catalog.btrim(definition->>'handle'),'') is not null
           and app_private.activity_slugify(split_part(app_private.structure_handle_normalize(definition->>'handle'),'.',1))
             is distinct from activity.handle_stem then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        end if;
        definition := definition - 'handle';
      end if;
      result := public.superadmin_activity_update_v2(
        app_private.activity_request_uuid('activity-save-update', p_request_id),
        p_activity_id,
        p_expected_version,
        definition
      );
    end if;

    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_activity_id := (result#>>'{data,activity_id}')::uuid;
    current_version := (result#>>'{data,management_version}')::bigint;

    if p_activity_id is not null then
      select coalesce(array_agg(link.group_id order by link.group_id), '{}'::uuid[])
      into groups_to_detach
      from public.activity_group_links link
      where link.activity_id = current_activity_id
        and link.status = 'active'
        and (
          not (link.group_id = any(group_ids))
          or not (link.unit_id = any(unit_ids))
        );

      select coalesce(array_agg(link.group_id order by link.group_id), '{}'::uuid[])
      into selected_to_all
      from public.activity_group_links link
      where link.activity_id = current_activity_id
        and link.status = 'active'
        and link.group_id = any(group_ids)
        and link.unit_id = any(unit_ids)
        and link.participation_mode = 'selected'
        and (p_payload->'group_participation')->>(link.group_id::text) = 'all';

      select exists(
        select 1
        from public.activity_group_participants participant
        join public.activity_group_links link
          on link.id = participant.activity_group_link_id
        where link.activity_id = current_activity_id
          and participant.status = 'active'
          and (
            link.group_id = any(groups_to_detach)
            or link.group_id = any(selected_to_all)
          )
      ) into needs_participant_prune;

      select exists(
        select 1
        from public.activity_group_assignments assignment
        join public.activity_group_links link
          on link.id = assignment.activity_group_link_id
        where link.activity_id = current_activity_id
          and link.group_id = any(groups_to_detach)
          and assignment.assignment_role = 'instructor'
          and assignment.status = 'active'
          and assignment.revoked_at is null
      ) into needs_professional_prune;

      select exists(
        select 1
        from public.activity_group_capability_settings setting
        join public.activity_group_links link
          on link.id = setting.activity_group_link_id
        where link.activity_id = current_activity_id
          and link.group_id = any(groups_to_detach)
      ) into needs_permission_prune;

      select exists(
        select 1
        from public.activity_group_links link
        where link.activity_id = current_activity_id
          and link.status = 'active'
          and not (link.unit_id = any(unit_ids))
      ) into needs_group_bridge;

      if needs_participant_prune then
        select coalesce(
          jsonb_agg(
            element.value
            order by element.value->>'group_id', element.value->>'child_group_link_id'
          ),
          '[]'::jsonb
        )
        into prune_participants
        from jsonb_array_elements(p_payload->'participants') element(value)
        where element.value->'belongs' = 'true'::jsonb
          and exists(
            select 1
            from public.activity_group_links link
            where link.activity_id = current_activity_id
              and link.status = 'active'
              and link.group_id::text = element.value->>'group_id'
              and link.group_id = any(group_ids)
              and link.unit_id = any(unit_ids)
              and link.participation_mode = 'selected'
              and (p_payload->'group_participation')->>(link.group_id::text) = 'selected'
          );

        required_capability := 'activities.assign_people';
        result := public.superadmin_activity_set_participants_v2(
          app_private.activity_request_uuid('activity-save-participants-prune', p_request_id),
          current_activity_id,current_version,prune_participants
        );
        if result#>>'{ok}' is distinct from 'true' then
          raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
        end if;
        current_version := (result#>>'{data,management_version}')::bigint;
      end if;

      if needs_professional_prune then
        select coalesce(
          jsonb_agg(
            element.value
            order by element.value->>'role', element.value->>'group_id',
              element.value->>'membership_id'
          ),
          '[]'::jsonb
        )
        into prune_professionals
        from jsonb_array_elements(p_payload->'professional_assignments') element(value)
        where element.value->>'role' = 'activity_admin'
          or (
            element.value->>'role' = 'instructor'
            and exists(
              select 1
              from public.activity_group_links link
              where link.activity_id = current_activity_id
                and link.status = 'active'
                and link.group_id::text = element.value->>'group_id'
                and link.group_id = any(group_ids)
                and link.unit_id = any(unit_ids)
            )
          );

        required_capability := 'activities.assign_people';
        result := public.superadmin_activity_set_professionals_v2(
          app_private.activity_request_uuid('activity-save-professionals-prune', p_request_id),
          current_activity_id,current_version,prune_professionals
        );
        if result#>>'{ok}' is distinct from 'true' then
          raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
        end if;
        current_version := (result#>>'{data,management_version}')::bigint;
      end if;

      if needs_permission_prune then
        select coalesce(
          jsonb_agg(element.value order by element.value->>'group_id'),
          '[]'::jsonb
        )
        into prune_group_settings
        from jsonb_array_elements(p_payload->'group_capability_settings') element(value)
        where exists(
          select 1
          from public.activity_group_links link
          where link.activity_id = current_activity_id
            and link.status = 'active'
            and link.group_id::text = element.value->>'group_id'
            and link.group_id = any(group_ids)
            and link.unit_id = any(unit_ids)
        );

        select coalesce(
          jsonb_agg(
            element.value
            order by element.value->>'role', element.value->>'group_id',
              element.value->>'membership_id'
          ),
          '[]'::jsonb
        )
        into prune_professional_actions
        from jsonb_array_elements(p_payload->'professional_capability_actions') element(value)
        where (
          element.value->>'role' = 'activity_admin'
          and exists(
            select 1
            from public.activity_admin_assignments assignment
            where assignment.activity_id = current_activity_id
              and assignment.membership_id::text = element.value->>'membership_id'
              and assignment.status = 'active'
              and assignment.revoked_at is null
          )
        ) or (
          element.value->>'role' = 'instructor'
          and exists(
            select 1
            from public.activity_group_assignments assignment
            join public.activity_group_links link
              on link.id = assignment.activity_group_link_id
            where link.activity_id = current_activity_id
              and link.group_id::text = element.value->>'group_id'
              and assignment.membership_id::text = element.value->>'membership_id'
              and assignment.assignment_role = 'instructor'
              and assignment.status = 'active'
              and assignment.revoked_at is null
              and link.status = 'active'
          )
        );

        required_capability := 'activities.manage_permissions';
        result := public.superadmin_activity_set_permissions_v2(
          app_private.activity_request_uuid('activity-save-permissions-prune', p_request_id),
          current_activity_id,current_version,p_payload->'capability_policies',
          prune_group_settings,prune_professional_actions
        );
        if result#>>'{ok}' is distinct from 'true' then
          raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
        end if;
        current_version := (result#>>'{data,management_version}')::bigint;
      end if;

      if needs_group_bridge then
        select coalesce(array_agg(link.group_id order by link.group_id), '{}'::uuid[])
        into bridge_group_ids
        from public.activity_group_links link
        where link.activity_id = current_activity_id
          and link.status = 'active'
          and link.group_id = any(group_ids)
          and link.unit_id = any(unit_ids);

        select coalesce(
          jsonb_object_agg(
            link.group_id::text,
            (p_payload->'group_participation')->>(link.group_id::text)
            order by link.group_id::text
          ),
          '{}'::jsonb
        )
        into bridge_group_participation
        from public.activity_group_links link
        where link.activity_id = current_activity_id
          and link.status = 'active'
          and link.group_id = any(bridge_group_ids);

        required_capability := 'activities.link_groups';
        result := public.superadmin_activity_set_groups_v2(
          app_private.activity_request_uuid('activity-save-groups-prune', p_request_id),
          current_activity_id,current_version,bridge_group_ids,bridge_group_participation
        );
        if result#>>'{ok}' is distinct from 'true' then
          raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
        end if;
        current_version := (result#>>'{data,management_version}')::bigint;
      end if;

      required_capability := 'activities.link_units';
      result := public.superadmin_activity_set_units_v2(
        app_private.activity_request_uuid('activity-save-units', p_request_id),
        current_activity_id,current_version,unit_ids
      );
      if result#>>'{ok}' is distinct from 'true' then
        raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
      end if;
      current_version := (result#>>'{data,management_version}')::bigint;
    end if;

    required_capability := 'activities.link_groups';
    result := public.superadmin_activity_set_groups_v2(
      app_private.activity_request_uuid('activity-save-groups', p_request_id),
      current_activity_id,current_version,group_ids,p_payload->'group_participation'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    required_capability := 'activities.assign_people';
    result := public.superadmin_activity_set_participants_v2(
      app_private.activity_request_uuid('activity-save-participants', p_request_id),
      current_activity_id,current_version,p_payload->'participants'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    result := public.superadmin_activity_set_professionals_v2(
      app_private.activity_request_uuid('activity-save-professionals', p_request_id),
      current_activity_id,current_version,p_payload->'professional_assignments'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    required_capability := 'activities.manage_permissions';
    result := public.superadmin_activity_set_permissions_v2(
      app_private.activity_request_uuid('activity-save-permissions', p_request_id),
      current_activity_id,current_version,p_payload->'capability_policies',
      p_payload->'group_capability_settings',p_payload->'professional_capability_actions'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    if p_publish then
      required_capability := 'activities.manage';
      result := public.superadmin_activity_publish_v2(
        app_private.activity_request_uuid('activity-save-publish', p_request_id),
        current_activity_id,current_version
      );
      if result#>>'{ok}' is distinct from 'true' then
        raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
      end if;
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;
    correlation_id := (result#>>'{data,correlation_id}')::uuid;
    insert into app_private.superadmin_internal_activity_save_receipts(
      request_id,internal_identity_id,institution_id,activity_id,request_hash,
      resulting_version,resulting_status,correlation_id
    ) values(
      p_request_id,ctx.internal_identity_id,institution_id,current_activity_id,request_hash,
      current_version,result#>>'{data,status}',correlation_id
    );
    return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
      'activity_id',current_activity_id,
      'management_version',current_version,
      'status',result#>>'{data,status}',
      'correlation_id',correlation_id,
      'replayed',false
    ));
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    error_code := coalesce(nullif(error_code, ''), 'SAI_INTERNAL_ERROR');
  end;

  return app_private.activity_v2_denied_envelope(
    required_capability,'activity.save',error_code,correlation_id,institution_id
  );
end
$$;

-- ---------------------------------------------------------------------------
-- group_management_payload: handle e handle_last_changed_at
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "app_private"."group_management_payload"("p_group_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with target as (
    select group_record.*, institution_record.public_name as institution_name,
           unit_record.name as unit_name,
           unit_branding_record.inherit_institution_branding,
           unit_branding_record.accent_color as unit_accent_color,
           unit_branding_record.secondary_color as unit_secondary_color,
           unit_branding_record.text_color as unit_text_color,
           unit_branding_record.surface_color as unit_surface_color,
           institution_branding_record.accent_color as institution_accent_color,
           institution_branding_record.secondary_color as institution_secondary_color,
           institution_branding_record.text_color as institution_text_color,
           institution_branding_record.surface_color as institution_surface_color,
           group_branding_record.accent_color as group_accent_color,
           group_branding_record.secondary_color as group_secondary_color,
           group_branding_record.text_color as group_text_color,
           group_branding_record.surface_color as group_surface_color
    from public.groups group_record
    join public.institutions institution_record on institution_record.id = group_record.institution_id
    join public.units unit_record on unit_record.id = group_record.unit_id
      and unit_record.institution_id = group_record.institution_id
    left join public.unit_branding unit_branding_record on unit_branding_record.unit_id = group_record.unit_id
    left join public.institution_branding institution_branding_record
      on institution_branding_record.institution_id = group_record.institution_id
    left join public.group_branding group_branding_record on group_branding_record.group_id = group_record.id
    where group_record.id = p_group_id
  ), effective_access as (
    select membership.person_id, person_record.display_name,
           assignment.scope_kind,
           case assignment.scope_kind
             when 'institution' then 'institution'
             when 'unit' then 'unit'
             else 'group_local'
           end as origin,
           role_record.id as profile_id, role_record.code as profile_code,
           role_record.name as profile_name,
           coalesce(jsonb_agg(distinct permission_record.code)
             filter (where permission_record.code is not null), '[]'::jsonb) as capabilities
    from target
    join public.institution_memberships membership
      on membership.institution_id = target.institution_id
     and membership.status = 'active' and membership.revoked_at is null
    join public.people person_record on person_record.id = membership.person_id
    join public.institution_role_assignments assignment
      on assignment.membership_id = membership.id and assignment.status = 'active'
     and (assignment.starts_at is null or assignment.starts_at <= now())
     and (assignment.expires_at is null or assignment.expires_at > now())
     and (
       assignment.scope_kind = 'institution'
       or (assignment.scope_kind = 'unit' and assignment.scope_unit_id = target.unit_id)
       or (assignment.scope_kind = 'group' and assignment.scope_group_id = target.id)
     )
    join public.institution_roles role_record on role_record.id = assignment.role_id
      and role_record.status = 'active'
    left join public.institution_role_permissions role_permission
      on role_permission.role_id = role_record.id
     and role_permission.status = 'active' and role_permission.revoked_at is null
    left join public.institution_permissions permission_record
      on permission_record.id = role_permission.permission_id and permission_record.status = 'active'
    group by membership.person_id, person_record.display_name, assignment.scope_kind,
             role_record.id, role_record.code, role_record.name
  ), access_rows as (
    select jsonb_agg(jsonb_build_object(
      'person_id', person_id, 'display_name', display_name,
      'origin', origin, 'inherited', origin <> 'group_local',
      'profile_id', profile_id, 'profile_code', profile_code,
      'profile_name', profile_name, 'capabilities', capabilities,
      'restrictions', coalesce((
        select jsonb_agg(override_record.permission_code order by override_record.permission_code)
        from public.institution_memberships membership
        join public.institution_member_permission_overrides override_record
          on override_record.membership_id = membership.id
         and override_record.effect = 'deny' and override_record.status = 'active'
         and override_record.revoked_at is null
        where membership.person_id = effective_access.person_id
          and membership.institution_id = (select institution_id from target)
          and (override_record.scope_kind = 'institution'
            or (override_record.scope_kind = 'unit' and override_record.scope_id = (select unit_id from target))
            or (override_record.scope_kind = 'group' and override_record.scope_id = p_group_id))
      ), '[]'::jsonb)
    ) order by (origin <> 'group_local') desc, display_name) as value from effective_access
  )
  select jsonb_build_object(
    'id', target.id, 'institution_id', target.institution_id,
    'institution_name', target.institution_name, 'unit_id', target.unit_id,
    'unit_name', target.unit_name, 'name', target.name,
    'handle', target.handle, 'handle_last_changed_at', target.handle_last_changed_at,
    'group_type', target.group_type,
    'group_type_other_text', target.group_type_other_text,
    'status', target.status, 'inherit_appearance', target.inherit_appearance,
    'inherit_access', target.inherit_access,
    'inherit_activities', target.inherit_activities,
    'management_version', target.management_version,
    'appearance_origin', case
      when not target.inherit_appearance then 'group_local'
      when coalesce(target.inherit_institution_branding, true) then 'institution'
      else 'unit' end,
    'effective_appearance', jsonb_build_object(
      'accent_color', case when not target.inherit_appearance then target.group_accent_color
        when coalesce(target.inherit_institution_branding, true) then target.institution_accent_color
        else target.unit_accent_color end,
      'secondary_color', case when not target.inherit_appearance then target.group_secondary_color
        when coalesce(target.inherit_institution_branding, true) then target.institution_secondary_color
        else target.unit_secondary_color end,
      'text_color', case when not target.inherit_appearance then target.group_text_color
        when coalesce(target.inherit_institution_branding, true) then target.institution_text_color
        else target.unit_text_color end,
      'surface_color', case when not target.inherit_appearance then target.group_surface_color
        when coalesce(target.inherit_institution_branding, true) then target.institution_surface_color
        else target.unit_surface_color end
    ),
    'effective_access', coalesce((select value from access_rows), '[]'::jsonb),
    'activity_ids', case when target.inherit_activities then
      coalesce((select jsonb_agg(unit_link.activity_id order by unit_link.activity_id)
        from public.activity_unit_links unit_link
        where unit_link.unit_id = target.unit_id and unit_link.status = 'active'), '[]'::jsonb)
      else coalesce((select jsonb_agg(link.activity_id order by link.activity_id)
        from public.activity_group_links link
        where link.group_id = target.id and link.status = 'active'), '[]'::jsonb)
      end,
    'invites', coalesce((select jsonb_agg(jsonb_build_object(
      'id', invitation.id, 'person_id', invitation.target_person_id,
      'display_name', person_record.display_name, 'role_code', invitation.role_code,
      'status', invitation.invitation_state, 'send_count', invitation.send_count
    ) order by invitation.created_at)
      from public.invitations invitation
      join public.people person_record on person_record.id = invitation.target_person_id
      where invitation.group_id = target.id
        and invitation.institution_id = target.institution_id
        and invitation.invitation_state <> 'revoked'), '[]'::jsonb),
    'created_at', target.created_at, 'updated_at', target.updated_at
  ) from target
$$;
