-- 20260918120000_medication_in_app_notifications_v2
--
-- R16 Sessao RESERVA / ADR 0042 E7 = b (owner.r12-33) + divida `recipients-bug`
-- (Mesa R16, ADR 0044). Spec 053. Autorizacao nominal do Owner em 18/09/2026
-- (R16-prompt-reserva-20260918.md, lote 82 item a).
--
-- O que muda, sem alterar assinaturas, grants ou triggers existentes:
--   * recipients-bug: os leitores de destinatarios de cuidado
--     (app_private.child_care_notification_recipients_v1) e de Medicacao
--     contavam QUALQUER membership ativa com escopo institution/unit como
--     "equipe da unidade" e com escopo group como "educador da turma" -
--     inclusive memberships de familia (role_code 'guardian' / 'student', que
--     o Principal ja reconhece como papeis de familia). Uma responsavel com
--     membership de familia recebia o sino "por ser equipe". Agora memberships
--     de familia nunca contam como equipe nem como educador.
--   * E7 = b: o responsavel (guardian_links ativo da crianca) passa a receber
--     tambem 'medication.plan.updated' e 'medication.dose.recorded' (ja recebia
--     'medication.plan.created' pela politica de cuidado), sujeito a
--     unit_care_policies.notify_other_guardians como nos demais eventos de
--     cuidado. Nova funcao app_private.medication_notification_recipients_v2;
--     medication_notify_v1 passa a usa-la (mesma assinatura). A v1 fica
--     preservada sem chamadores.
-- Sem e-mail/push. Forward-only, idempotente (create or replace).
-- Reversao (manual): medication_notify_v1 volta a chamar recipients_v1 e
-- child_care_notification_recipients_v1 volta ao corpo de 20260911210500.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'medication notifications v2 migration requires postgres';
  end if;
  if to_regprocedure('app_private.child_care_notification_recipients_v1(uuid,uuid,uuid,uuid)') is null
    or to_regprocedure('app_private.medication_notification_recipients_v1(uuid,uuid,uuid,uuid)') is null
    or to_regprocedure('app_private.medication_notify_v1(public.medication_plans,text,text,uuid,jsonb,uuid)') is null
    or to_regclass('public.guardian_links') is null then
    raise object_not_in_prerequisite_state using message = 'care/medication notifications v1 are required';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- 1. recipients-bug: destinatarios de cuidado (mesma assinatura e grants)
-- ---------------------------------------------------------------------------
create or replace function app_private.child_care_notification_recipients_v1(
  p_institution_id uuid, p_unit_id uuid, p_child_context_id uuid, p_actor_person_id uuid
) returns setof uuid language sql stable security definer set search_path='' as $$
  with policy as (
    select coalesce(p.notify_unit, true) as notify_unit,
      coalesce(p.notify_child_hierarchy, true) as notify_child_hierarchy,
      coalesce(p.notify_other_guardians, true) as notify_other_guardians
    from (select 1) one left join public.unit_care_policies p on p.unit_id = p_unit_id
  ),
  child as (
    select cc.child_person_id from public.child_contexts cc where cc.id = p_child_context_id
  ),
  unit_people as (
    -- equipe da unidade: memberships ativas da instituicao com escopo na unidade ou na
    -- instituicao inteira; memberships de familia (guardian/student) nao sao equipe
    select m.person_id from public.institution_memberships m
    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
      and (m.scope_kind = 'institution' or (m.scope_kind = 'unit' and m.scope_unit_id = p_unit_id))
      and m.role_code not in ('legal_representative', 'guardian', 'student')
      and (select notify_unit from policy)
  ),
  hierarchy_people as (
    -- profissionais atribuidos a crianca
    select m.person_id from public.professional_child_assignments a
    join public.institution_memberships m on m.id = a.membership_id
    where a.child_context_id = p_child_context_id and a.status = 'active' and a.revoked_at is null
      and m.status = 'active' and m.revoked_at is null
      and m.role_code not in ('guardian', 'student')
      and (select notify_child_hierarchy from policy)
    union
    -- professores (memberships com escopo na turma) das turmas da crianca
    select m.person_id from public.child_unit_links cul
    join public.child_group_links cgl on cgl.child_unit_link_id = cul.id and cgl.status = 'active'
    join public.institution_memberships m on m.scope_kind = 'group' and m.scope_group_id = cgl.group_id
      and m.status = 'active' and m.revoked_at is null
      and m.role_code not in ('guardian', 'student')
    where cul.child_context_id = p_child_context_id and cul.status = 'active' and cul.revoked_at is null
      and (select notify_child_hierarchy from policy)
  ),
  guardian_people as (
    select g.guardian_person_id from public.guardian_links g, child
    where g.child_person_id = child.child_person_id and g.status = 'active' and g.revoked_at is null
      and (select notify_other_guardians from policy)
  )
  select distinct all_people.person_id from (
    select person_id from unit_people
    union select person_id from hierarchy_people
    union select guardian_person_id from guardian_people
  ) all_people
  join public.people person on person.id = all_people.person_id
  -- pessoas de servico (espelho das identidades internas do Superadmin/Principal) nao recebem sino
  where person.person_type = 'adult' and person.deleted_at is null and person.status = 'active'
    and all_people.person_id is distinct from p_actor_person_id
$$;

alter function app_private.child_care_notification_recipients_v1(uuid,uuid,uuid,uuid) owner to postgres;
revoke all on function app_private.child_care_notification_recipients_v1(uuid,uuid,uuid,uuid)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Medicacao v2: equipe da unidade + educadores da turma + responsaveis (E7 = b)
-- ---------------------------------------------------------------------------
create or replace function app_private.medication_notification_recipients_v2(
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
      coalesce(p.notify_child_hierarchy, true) as notify_child_hierarchy,
      coalesce(p.notify_other_guardians, true) as notify_other_guardians
    from (select 1) one left join public.unit_care_policies p on p.unit_id = p_unit_id
  ),
  child as (
    select cc.child_person_id from public.child_contexts cc where cc.id = p_child_context_id
  ),
  unit_people as (
    -- administradores/equipe da unidade (representante legal nao opera; familia nao e equipe)
    select m.person_id from public.institution_memberships m
    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
      and (m.scope_kind = 'institution' or (m.scope_kind = 'unit' and m.scope_unit_id = p_unit_id))
      and m.role_code not in ('legal_representative', 'guardian', 'student')
      and (select notify_unit from policy)
  ),
  educator_people as (
    -- profissionais atribuidos a crianca
    select m.person_id from public.professional_child_assignments a
    join public.institution_memberships m on m.id = a.membership_id
    where a.child_context_id = p_child_context_id and a.status = 'active' and a.revoked_at is null
      and m.status = 'active' and m.revoked_at is null
      and m.role_code not in ('guardian', 'student')
      and (select notify_child_hierarchy from policy)
    union
    -- educadores das turmas ativas da crianca (memberships com escopo na turma)
    select m.person_id from public.child_unit_links cul
    join public.child_group_links cgl on cgl.child_unit_link_id = cul.id and cgl.status = 'active'
    join public.institution_memberships m on m.scope_kind = 'group' and m.scope_group_id = cgl.group_id
      and m.status = 'active' and m.revoked_at is null
      and m.role_code not in ('guardian', 'student')
    where cul.child_context_id = p_child_context_id and cul.status = 'active' and cul.revoked_at is null
      and (select notify_child_hierarchy from policy)
  ),
  guardian_people as (
    -- E7 = b: responsaveis com vinculo ativo recebem plano atualizado e dose registrada
    select g.guardian_person_id from public.guardian_links g, child
    where g.child_person_id = child.child_person_id and g.status = 'active' and g.revoked_at is null
      and (select notify_other_guardians from policy)
  )
  select distinct all_people.person_id from (
    select person_id from unit_people
    union select person_id from educator_people
    union select guardian_person_id from guardian_people
  ) all_people
  join public.people person on person.id = all_people.person_id
  where person.person_type = 'adult' and person.deleted_at is null and person.status = 'active'
    and all_people.person_id is distinct from p_actor_person_id
$$;

alter function app_private.medication_notification_recipients_v2(uuid,uuid,uuid,uuid) owner to postgres;
revoke all on function app_private.medication_notification_recipients_v2(uuid,uuid,uuid,uuid)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. medication_notify_v1 passa a usar a v2 (mesma assinatura; triggers intactos)
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
  from app_private.medication_notification_recipients_v2(
    p_plan.institution_id, target_unit, p_plan.child_context_id, p_actor_person_id) r
  on conflict do nothing;
  return event_id;
end $$;

alter function app_private.medication_notify_v1(public.medication_plans,text,text,uuid,jsonb,uuid) owner to postgres;
revoke all on function app_private.medication_notify_v1(public.medication_plans,text,text,uuid,jsonb,uuid)
  from public, anon, authenticated, service_role;

do $postcheck$
begin
  if to_regprocedure('app_private.medication_notification_recipients_v2(uuid,uuid,uuid,uuid)') is null then
    raise object_not_in_prerequisite_state using message = 'medication_notification_recipients_v2 was not created';
  end if;
  if position('medication_notification_recipients_v2' in
      pg_get_functiondef('app_private.medication_notify_v1(public.medication_plans,text,text,uuid,jsonb,uuid)'::regprocedure)) = 0 then
    raise object_not_in_prerequisite_state using message = 'medication_notify_v1 does not use recipients v2';
  end if;
  if exists (select 1 from pg_trigger where tgname in ('medication_plan_versions_notify_v1','medication_plan_evidence_notify_v1') and tgenabled = 'D') then
    raise object_not_in_prerequisite_state using message = 'medication notification triggers are disabled';
  end if;
end
$postcheck$;

commit;
