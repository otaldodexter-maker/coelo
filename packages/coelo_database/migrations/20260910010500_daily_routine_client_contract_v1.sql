-- Rotina diaria: fecha o contrato que o cliente Flutter ja espera.
--
-- A fundacao 20260910010000 nasceu do teste pgTAP, que especifica o agregado e
-- a seguranca mas nao descreve tudo o que a tela precisa. Ao escrever o
-- repositorio Supabase apareceram tres lacunas concretas, todas vindas de
-- apps/superadmin/lib/features/daily_routine/domain/routine_contract.dart:
--
--   1. RoutineLaunch tem authorMembershipId, e o lancamento nao guardava a
--      membership do autor: guardava so a pessoa. Autoria de rotina e
--      contextual, entao a pessoa sozinha nao diz em que papel ela lancou.
--   2. RoutineChildEntryDraft tem childGroupLinkId e status, e a entrada da
--      crianca so tinha o contexto infantil. Sem o vinculo de turma, o
--      lancamento nao consegue provar que aquela crianca pertencia aquela
--      turma na data.
--   3. O cliente le aplicacao e lancamento por id (fetchApplication e
--      fetchLaunch) e so existia leitura de modelo.
--
-- Forward-only e aditivo: nenhuma coluna existente muda de tipo ou de
-- obrigatoriedade, e as duas leituras novas seguem o mesmo desenho das
-- existentes, com negativa opaca.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.daily-routine.client-contract', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='daily routine client contract must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.routine_launches') is null then
    raise exception using errcode='55000',
      message='daily routine client contract requires the routine foundation';
  end if;
end
$preflight$;

alter table public.routine_launches
  add column if not exists author_membership_id uuid
    references public.institution_memberships(id) on delete set null;

alter table public.routine_child_entries
  add column if not exists child_group_link_id uuid
    references public.child_group_links(id) on delete restrict,
  add column if not exists status text not null default 'draft'
    check (status in ('draft','recorded','skipped'));

-- ---------------------------------------------------------------------------
-- Leitura de aplicacao e de lancamento
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_routine_application_detail(
  p_application_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  application_row public.routine_applications;
  revision_row public.routine_application_revisions;
begin
  actor := app_private.require_routine_actor('routine.read', false);
  select * into application_row
  from public.routine_applications
  where id = p_application_id
    and app_private.routine_scope_allowed(
      'routine.read', institution_id, unit_id, group_id);
  if application_row.id is null then
    raise no_data_found using message='routine application unavailable';
  end if;
  select * into revision_row from public.routine_application_revisions
  where application_id = application_row.id
  order by revision_no desc limit 1;

  return jsonb_build_object(
    'id', application_row.id,
    'source_model_version_id', application_row.source_model_version_id,
    'institution_id', application_row.institution_id,
    'unit_id', application_row.unit_id,
    'group_id', application_row.group_id,
    'activity_id', application_row.activity_id,
    'parent_application_id', application_row.parent_application_id,
    'scope_kind', application_row.scope_kind,
    'status', application_row.status,
    'inheritance_mode', application_row.inheritance_mode,
    'visibility', application_row.visibility,
    'valid_from', application_row.valid_from,
    'valid_until', application_row.valid_until,
    'starts_at', application_row.starts_at,
    'ends_at', application_row.ends_at,
    'management_version', application_row.management_version,
    'effective_version', coalesce(revision_row.revision_no, 0),
    'can_manage', app_private.routine_scope_allowed(
      'routine.manage_applications', application_row.institution_id,
      application_row.unit_id, application_row.group_id),
    'assignees', coalesce((
      select jsonb_agg(jsonb_build_object(
        'membership_id', assignee_row.membership_id,
        'responsibility', assignee_row.responsibility) order by assignee_row.membership_id)
      from public.routine_application_assignees assignee_row
      where assignee_row.application_id = application_row.id), '[]'::jsonb)
  );
end
$$;

create or replace function app_private.superadmin_routine_launch_detail(
  p_launch_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  launch_row public.routine_launches;
begin
  actor := app_private.require_routine_actor('routine.read', false);
  select * into launch_row
  from public.routine_launches
  where id = p_launch_id
    and app_private.routine_scope_allowed(
      'routine.read', institution_id, unit_id, group_id);
  if launch_row.id is null then
    raise no_data_found using message='routine launch unavailable';
  end if;

  return jsonb_build_object(
    'id', launch_row.id,
    'application_id', launch_row.application_id,
    'application_revision_id', launch_row.application_revision_id,
    'institution_id', launch_row.institution_id,
    'unit_id', launch_row.unit_id,
    'group_id', launch_row.group_id,
    'author_membership_id', launch_row.author_membership_id,
    'launch_date', launch_row.launch_date,
    'status', launch_row.status,
    'management_version', launch_row.management_version,
    'can_manage', app_private.routine_scope_allowed(
      'routine.record', launch_row.institution_id,
      launch_row.unit_id, launch_row.group_id),
    'children', coalesce((
      select jsonb_agg(jsonb_build_object(
        'entry_id', entry_row.id,
        'child_context_id', entry_row.child_context_id,
        'child_group_link_id', entry_row.child_group_link_id,
        'status', entry_row.status,
        'answers', coalesce((
          select jsonb_agg(jsonb_build_object(
            'answer_id', answer_row.id,
            'field_id', answer_row.field_id,
            'value', answer_row.value_json) order by answer_row.field_id)
          from public.routine_answers answer_row
          where answer_row.child_entry_id = entry_row.id), '[]'::jsonb)
      ) order by entry_row.created_at)
      from public.routine_child_entries entry_row
      where entry_row.launch_id = launch_row.id), '[]'::jsonb)
  );
end
$$;

create or replace function public.superadmin_routine_application_detail(application_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_routine_application_detail(application_id)
$$;

create or replace function public.superadmin_routine_launch_detail(launch_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_routine_launch_detail(launch_id)
$$;

-- ---------------------------------------------------------------------------
-- O rascunho passa a gravar autoria contextual e vinculo de turma
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_routine_save_launch_draft(
  p_request_id uuid,
  p_launch_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_launch_id, gen_random_uuid());
  launch_row public.routine_launches;
  application_row public.routine_applications;
  revision_row public.routine_application_revisions;
  author_membership uuid;
  entry_item jsonb;
  answer_item jsonb;
  entry_id uuid;
  response jsonb;
begin
  actor := app_private.require_routine_actor('routine.record', false);
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'save_launch_draft');
  if response is not null then return response; end if;

  if p_launch_id is not null then
    select * into launch_row
    from public.routine_launches
    where id = aggregate_id
      and app_private.routine_scope_allowed(
        'routine.record', institution_id, unit_id, group_id)
    for update;
    if launch_row.id is null then
      raise no_data_found using message='routine launch unavailable';
    end if;
    if launch_row.management_version <> p_expected_version then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    if launch_row.status <> 'draft' then
      raise check_violation using message='routine launch is not a draft';
    end if;
    select * into application_row from public.routine_applications
    where id = launch_row.application_id;
  else
    if p_expected_version <> 0 then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    select * into application_row from public.routine_applications
    where id = (p_payload->>'application_id')::uuid;
    if application_row.id is null then
      raise no_data_found using message='routine application unavailable';
    end if;
    perform app_private.require_routine_scope(
      'routine.record', application_row.institution_id,
      application_row.unit_id, application_row.group_id, false
    );
    select * into revision_row from public.routine_application_revisions
    where application_id = application_row.id
    order by revision_no desc limit 1;
    -- A autoria e derivada da sessao e do tenant do lancamento, nunca aceita
    -- do payload: aceitar deixaria um profissional lancar em nome de outro.
    select membership.id into author_membership
    from public.institution_memberships membership
    where membership.person_id = actor
      and membership.institution_id = application_row.institution_id
      and membership.status = 'active'
      and membership.revoked_at is null
    limit 1;
    insert into public.routine_launches(
      id, institution_id, unit_id, group_id, application_id,
      application_revision_id, author_membership_id, launch_date, status,
      created_by_person_id
    ) values (
      aggregate_id, application_row.institution_id, application_row.unit_id,
      application_row.group_id, application_row.id, revision_row.id,
      author_membership,
      coalesce((p_payload->>'launch_date')::date, current_date), 'draft', actor
    ) returning * into launch_row;
  end if;

  for entry_item in
    select value from jsonb_array_elements(coalesce(p_payload->'entries','[]'::jsonb))
  loop
    insert into public.routine_child_entries(
      launch_id, child_context_id, child_group_link_id, status
    ) values (
      aggregate_id,
      (entry_item->>'child_context_id')::uuid,
      (entry_item->>'child_group_link_id')::uuid,
      coalesce(entry_item->>'status','draft')
    )
    on conflict (launch_id, child_context_id) do update set
      child_group_link_id = excluded.child_group_link_id,
      status = excluded.status
    returning id into entry_id;

    for answer_item in
      select value from jsonb_array_elements(coalesce(entry_item->'answers','[]'::jsonb))
    loop
      insert into public.routine_answers(
        child_entry_id, field_id, value_json, answered_by_person_id, answered_at
      ) values (
        entry_id, (answer_item->>'field_id')::uuid, answer_item->'value', actor, now()
      )
      on conflict (child_entry_id, field_id) do update set
        value_json = excluded.value_json,
        answered_by_person_id = excluded.answered_by_person_id,
        answered_at = excluded.answered_at;
    end loop;
  end loop;

  perform app_private.validate_routine_launch_answers(aggregate_id, false);

  update public.routine_launches
    set management_version = management_version + 1, updated_at = now()
  where id = aggregate_id returning * into launch_row;

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', launch_row.management_version,
    'status', launch_row.status
  );
  insert into app_private.routine_command_receipts
    values (p_request_id, actor, 'save_launch_draft', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.launch.save_draft', 'routine_launch',
    aggregate_id, launch_row.institution_id, 'success', response
  );
  return response;
end
$$;

do $grants$
declare current_signature text;
begin
  foreach current_signature in array array[
    'app_private.superadmin_routine_application_detail(uuid)',
    'app_private.superadmin_routine_launch_detail(uuid)',
    'public.superadmin_routine_application_detail(uuid)',
    'public.superadmin_routine_launch_detail(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      current_signature);
    execute format('grant execute on function %s to authenticated, service_role',
      current_signature);
  end loop;
end
$grants$;

commit;
