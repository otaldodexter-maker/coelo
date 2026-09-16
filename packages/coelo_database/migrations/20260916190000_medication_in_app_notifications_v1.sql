-- 20260916190000_medication_in_app_notifications_v1
--
-- R14 Sessao 10 / ADR 0041 B8 (owner.r12-33): sino in-app de Medicacao para a
-- equipe administrativa da unidade e os educadores da turma da crianca ao
-- editar o plano (nova versao) e a cada dose registrada. Spec 053.
--
-- Producao ja notifica criar plano e mudancas de status (trigger
-- medication_plans_care_notify_v1 -> notify_child_care_event_v1, audiencia da
-- politica de cuidado, incluindo responsaveis). Este pacote acrescenta, sem
-- alterar o existente:
--   * app_private.medication_notification_recipients_v1: equipe da unidade +
--     educadores/profissionais da crianca (sem responsaveis), respeitando
--     unit_care_policies.notify_unit / notify_child_hierarchy, sem o ator;
--   * app_private.medication_notify_v1: evento + destinatarios, payload sem PII;
--   * trigger em medication_plan_versions (AFTER INSERT, version > 1) ->
--     'medication.plan.updated';
--   * trigger em medication_plan_evidence (AFTER INSERT) -> 'medication.dose.recorded'.
-- Sem e-mail/push; delivery_state permanece 'pending' como nos demais eventos.
-- Forward-only, idempotente (create or replace + drop trigger if exists).
-- Reversao (manual): drop dos dois triggers e das duas funcoes.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'medication notifications migration requires postgres';
  end if;
  if to_regclass('public.context_notification_events') is null
    or to_regclass('public.context_notification_recipients') is null
    or to_regclass('public.medication_plans') is null
    or to_regclass('public.medication_plan_versions') is null
    or to_regclass('public.medication_plan_evidence') is null
    or to_regclass('public.unit_care_policies') is null
    or to_regprocedure('app_private.notify_child_care_event_v1(uuid,uuid,uuid,text,text,uuid,jsonb,uuid)') is null then
    raise object_not_in_prerequisite_state using message = 'care notifications and medication plans are required';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- 1. Destinatarios (B8): equipe da unidade + educadores da turma da crianca
-- ---------------------------------------------------------------------------
create or replace function app_private.medication_notification_recipients_v1(
  p_institution_id uuid,
  p_unit_id uuid,
  p_child_context_id uuid,
  p_actor_person_id uuid
) returns setof uuid
language sql stable security definer
set search_path = ''
as $$
  with policy as (
    select coalesce(p.notify_unit, true) as notify_unit,
      coalesce(p.notify_child_hierarchy, true) as notify_child_hierarchy
    from (select 1) one left join public.unit_care_policies p on p.unit_id = p_unit_id
  ),
  unit_people as (
    -- administradores/equipe da unidade: memberships ativas com escopo na
    -- unidade ou na instituicao inteira (representante legal nao opera)
    select m.person_id from public.institution_memberships m
    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
      and (m.scope_kind = 'institution' or (m.scope_kind = 'unit' and m.scope_unit_id = p_unit_id))
      and m.role_code <> 'legal_representative'
      and (select notify_unit from policy)
  ),
  educator_people as (
    -- profissionais atribuidos a crianca
    select m.person_id from public.professional_child_assignments a
    join public.institution_memberships m on m.id = a.membership_id
    where a.child_context_id = p_child_context_id and a.status = 'active' and a.revoked_at is null
      and m.status = 'active' and m.revoked_at is null
      and (select notify_child_hierarchy from policy)
    union
    -- educadores das turmas ativas da crianca (memberships com escopo na turma)
    select m.person_id from public.child_unit_links cul
    join public.child_group_links cgl on cgl.child_unit_link_id = cul.id and cgl.status = 'active'
    join public.institution_memberships m on m.scope_kind = 'group' and m.scope_group_id = cgl.group_id
      and m.status = 'active' and m.revoked_at is null
    where cul.child_context_id = p_child_context_id and cul.status = 'active' and cul.revoked_at is null
      and (select notify_child_hierarchy from policy)
  )
  select distinct all_people.person_id from (
    select person_id from unit_people
    union select person_id from educator_people
  ) all_people
  join public.people person on person.id = all_people.person_id
  where person.person_type = 'adult' and person.deleted_at is null and person.status = 'active'
    and all_people.person_id is distinct from p_actor_person_id
$$;

alter function app_private.medication_notification_recipients_v1(uuid,uuid,uuid,uuid) owner to postgres;
revoke all on function app_private.medication_notification_recipients_v1(uuid,uuid,uuid,uuid)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Evento + destinatarios
-- ---------------------------------------------------------------------------
create or replace function app_private.medication_notify_v1(
  p_plan public.medication_plans,
  p_event_code text,
  p_object_type text,
  p_object_id uuid,
  p_payload jsonb,
  p_actor_person_id uuid
) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  target_unit uuid;
  mode text;
  event_id uuid;
begin
  -- unidade do plano ou, no escopo de instituicao, a unidade ativa da crianca
  -- (mesma regra de medication_plan_care_notify_v1)
  target_unit := p_plan.unit_id;
  if target_unit is null then
    select cul.unit_id into target_unit from public.child_unit_links cul
    where cul.child_context_id = p_plan.child_context_id and cul.status = 'active' and cul.revoked_at is null
    order by cul.created_at desc limit 1;
  end if;
  select coalesce(p.medication_mode, 'accept_to_release') into mode
  from (select 1) one left join public.unit_care_policies p on p.unit_id = target_unit;
  if mode = 'not_tracked' then
    return null;
  end if;
  insert into public.context_notification_events(institution_id, unit_id, group_id, child_context_id,
    event_code, object_type, object_id, payload_json, created_by_person_id)
  values (p_plan.institution_id, target_unit, p_plan.group_id, p_plan.child_context_id,
    p_event_code, p_object_type, p_object_id, coalesce(p_payload, '{}'::jsonb), p_actor_person_id)
  returning id into event_id;
  insert into public.context_notification_recipients(event_id, person_id)
  select event_id, r
  from app_private.medication_notification_recipients_v1(
    p_plan.institution_id, target_unit, p_plan.child_context_id, p_actor_person_id) r
  on conflict do nothing;
  return event_id;
end $$;

alter function app_private.medication_notify_v1(public.medication_plans,text,text,uuid,jsonb,uuid) owner to postgres;
revoke all on function app_private.medication_notify_v1(public.medication_plans,text,text,uuid,jsonb,uuid)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Editar plano (nova versao) -> medication.plan.updated
-- ---------------------------------------------------------------------------
create or replace function app_private.medication_plan_version_notify_v1() returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare plan_row public.medication_plans;
begin
  -- a versao 1 nasce com o plano: 'medication.plan.created' ja e emitido pelo
  -- trigger de medication_plans.
  if new.version <= 1 then
    return new;
  end if;
  select * into plan_row from public.medication_plans where id = new.plan_id;
  if plan_row.id is null then
    return new;
  end if;
  perform app_private.medication_notify_v1(plan_row, 'medication.plan.updated', 'medication_plan',
    plan_row.id, jsonb_build_object('version', new.version), new.created_by_person_id);
  return new;
end $$;

alter function app_private.medication_plan_version_notify_v1() owner to postgres;
revoke all on function app_private.medication_plan_version_notify_v1()
  from public, anon, authenticated, service_role;

drop trigger if exists medication_plan_versions_notify_v1 on public.medication_plan_versions;
create trigger medication_plan_versions_notify_v1
  after insert on public.medication_plan_versions
  for each row execute function app_private.medication_plan_version_notify_v1();

-- ---------------------------------------------------------------------------
-- 4. Dose registrada -> medication.dose.recorded
-- ---------------------------------------------------------------------------
create or replace function app_private.medication_plan_evidence_notify_v1() returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare plan_row public.medication_plans;
begin
  select * into plan_row from public.medication_plans where id = new.plan_id;
  if plan_row.id is null then
    return new;
  end if;
  perform app_private.medication_notify_v1(plan_row, 'medication.dose.recorded', 'medication_plan_evidence',
    new.id, jsonb_build_object('outcome', new.outcome, 'occurred_at', new.occurred_at,
      'plan_id', plan_row.id, 'plan_version_id', new.plan_version_id), new.recorded_by_person_id);
  return new;
end $$;

alter function app_private.medication_plan_evidence_notify_v1() owner to postgres;
revoke all on function app_private.medication_plan_evidence_notify_v1()
  from public, anon, authenticated, service_role;

drop trigger if exists medication_plan_evidence_notify_v1 on public.medication_plan_evidence;
create trigger medication_plan_evidence_notify_v1
  after insert on public.medication_plan_evidence
  for each row execute function app_private.medication_plan_evidence_notify_v1();

do $postcheck$
begin
  if not exists (select 1 from pg_trigger where tgname = 'medication_plan_versions_notify_v1')
    or not exists (select 1 from pg_trigger where tgname = 'medication_plan_evidence_notify_v1') then
    raise object_not_in_prerequisite_state using message = 'medication notification triggers were not created';
  end if;
end
$postcheck$;

commit;
