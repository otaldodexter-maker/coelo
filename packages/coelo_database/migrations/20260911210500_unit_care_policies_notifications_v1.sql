-- R05 realm-interno (6): P32 regra alvo (ADR 0034, Decisao 15, P32)
--
-- (a) politicas macro da unidade para Seguranca infantil e Medicacao:
--     public.unit_care_policies (uma linha por unidade, criada sob demanda com
--     os padroes): child_safety_mode e medication_mode em
--     accept_to_release | inclusion_only | exclusion_only (Medicacao tambem
--     not_tracked = "nao acompanhar"), e as tres chaves de notificacao
--     (unidade, hierarquia da crianca, demais responsaveis). Leitura e escrita
--     pelo realm interno (units.read / units.update) com escopo por
--     instituicao, recibo idempotente e auditoria.
-- (b) notificacoes no sino (context_notification_events + recipients) para a
--     unidade (memberships da instituicao com escopo na unidade ou na
--     instituicao inteira), a hierarquia da crianca (profissionais atribuidos
--     e professores das turmas da crianca) e os demais responsaveis
--     (guardian_links ativos, menos o ator), respeitando as chaves da politica.
--     Gatilhos: autorizacao de pessoa autorizada criada/decidida
--     (Seguranca infantil), restricao criada/alterada, plano de medicacao
--     criado/alterado (se a unidade acompanha Medicacao).
--
-- A decisao continua no Superadmin (P32 B, 171800): este pacote so registra a
-- politica e avisa; o modo escolhido e devolvido ao cliente para a tela de
-- politicas e para o Admin futuro aplicar o fluxo (aceitar para liberar etc.).
--
-- Reversao: drop dos gatilhos *_care_notify_v1, das funcoes
-- app_private.child_care_* / public.superadmin_unit_care_policy_*_v1 e da
-- tabela public.unit_care_policies (dump do lote guarda o conteudo).

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'care policies migration must run as postgres';
  end if;
  if to_regclass('public.context_notification_events') is null
    or to_regclass('public.context_notification_recipients') is null
    or to_regclass('public.authorized_person_authorizations') is null
    or to_regclass('public.child_safety_restrictions') is null
    or to_regclass('public.medication_plans') is null
    or to_regclass('public.professional_child_assignments') is null
    or to_regclass('public.child_group_links') is null
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or not exists (select 1 from public.platform_permissions where code in ('units.read','units.update')) then
    raise object_not_in_prerequisite_state using
      message = 'notification, child safety, medication and units capabilities are required';
  end if;
end
$preflight$;

-- 1. Politicas macro da unidade --------------------------------------------------
create table public.unit_care_policies (
  unit_id uuid primary key references public.units(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  child_safety_mode text not null default 'accept_to_release'
    check (child_safety_mode in ('accept_to_release','inclusion_only','exclusion_only')),
  medication_mode text not null default 'accept_to_release'
    check (medication_mode in ('accept_to_release','inclusion_only','exclusion_only','not_tracked')),
  notify_unit boolean not null default true,
  notify_child_hierarchy boolean not null default true,
  notify_other_guardians boolean not null default true,
  management_version bigint not null default 1 check (management_version > 0),
  updated_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint unit_care_policies_unit_institution_fkey
    foreign key (unit_id, institution_id) references public.units(id, institution_id) on delete cascade
);
comment on table public.unit_care_policies is
  'P32: politicas macro da unidade para Seguranca infantil e Medicacao e chaves de notificacao no sino; defaults = aceitar para liberar e avisar todos.';
alter table public.unit_care_policies enable row level security;
revoke all on table public.unit_care_policies from public, anon, authenticated, service_role;
create policy unit_care_policies_platform_read on public.unit_care_policies
  for select to authenticated using ((select app_private.has_platform_permission('platform.read')));
grant select on table public.unit_care_policies to authenticated;

create table app_private.unit_care_policy_receipts (
  request_id uuid primary key,
  actor_internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
  unit_id uuid not null references public.units(id),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  result_version bigint not null,
  created_at timestamptz not null default now()
);
alter table app_private.unit_care_policy_receipts enable row level security;
alter table app_private.unit_care_policy_receipts force row level security;
revoke all on table app_private.unit_care_policy_receipts from public, anon, authenticated, service_role;

create function app_private.unit_care_policy_payload_v1(p_unit_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'unit_id', u.id, 'institution_id', u.institution_id,
    'child_safety_mode', coalesce(p.child_safety_mode, 'accept_to_release'),
    'medication_mode', coalesce(p.medication_mode, 'accept_to_release'),
    'notify_unit', coalesce(p.notify_unit, true),
    'notify_child_hierarchy', coalesce(p.notify_child_hierarchy, true),
    'notify_other_guardians', coalesce(p.notify_other_guardians, true),
    'management_version', coalesce(p.management_version, 0),
    'is_default', p.unit_id is null,
    'updated_at', p.updated_at)
  from public.units u left join public.unit_care_policies p on p.unit_id = u.id
  where u.id = p_unit_id
$$;

create function public.superadmin_unit_care_policy_get_v1(p_unit_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text; detail text;
  unit_record public.units%rowtype; payload jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('units.read');
    select * into unit_record from public.units where id = p_unit_id;
    if unit_record.id is null or (ctx.scope_kind = 'institution' and unit_record.institution_id is distinct from ctx.scope_institution_id) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    payload := app_private.unit_care_policy_payload_v1(p_unit_id);
  exception when others then
    get stacked diagnostics detail = pg_exception_detail;
    code := case when detail like 'SAI_%' then detail else 'SAI_INTERNAL_ERROR' end;
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('units.read', 'unit.care_policy.read', code, correlation,
      case when ctx.scope_kind = 'institution' then ctx.scope_institution_id end);
    return app_private.superadmin_internal_error_envelope(code, correlation);
  end if;
  return jsonb_build_object('ok', true, 'data', payload, 'error', null);
end $$;

create function public.superadmin_unit_care_policy_set_v1(p_request_id uuid, p_unit_id uuid, p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text; detail text;
  unit_record public.units%rowtype; unknown_key text; request_hash bytea; prior app_private.unit_care_policy_receipts%rowtype;
  cs_mode text; med_mode text; n_unit boolean; n_hier boolean; n_guard boolean; result_version bigint; replayed boolean := false;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('units.update');
    if ctx.platform_role_code not in ('owner','operations') then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    select * into unit_record from public.units where id = p_unit_id for share;
    if unit_record.id is null or (ctx.scope_kind = 'institution' and unit_record.institution_id is distinct from ctx.scope_institution_id) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_payload = '{}'::jsonb then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    select k into unknown_key from jsonb_object_keys(p_payload) k
    where k not in ('child_safety_mode','medication_mode','notify_unit','notify_child_hierarchy','notify_other_guardians') limit 1;
    if unknown_key is not null then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    cs_mode := p_payload ->> 'child_safety_mode'; med_mode := p_payload ->> 'medication_mode';
    if (p_payload ? 'child_safety_mode' and cs_mode not in ('accept_to_release','inclusion_only','exclusion_only'))
      or (p_payload ? 'medication_mode' and med_mode not in ('accept_to_release','inclusion_only','exclusion_only','not_tracked'))
      or (p_payload ? 'notify_unit' and jsonb_typeof(p_payload -> 'notify_unit') <> 'boolean')
      or (p_payload ? 'notify_child_hierarchy' and jsonb_typeof(p_payload -> 'notify_child_hierarchy') <> 'boolean')
      or (p_payload ? 'notify_other_guardians' and jsonb_typeof(p_payload -> 'notify_other_guardians') <> 'boolean') then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    request_hash := extensions.digest(convert_to(jsonb_build_object('unit_id', p_unit_id, 'payload', p_payload)::text, 'UTF8'), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
    select * into prior from app_private.unit_care_policy_receipts where request_id = p_request_id;
    if prior.request_id is not null then
      if prior.actor_internal_identity_id is distinct from ctx.internal_identity_id or prior.unit_id is distinct from p_unit_id
        or prior.request_hash is distinct from request_hash then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      replayed := true; result_version := prior.result_version;
    else
      insert into public.unit_care_policies(unit_id, institution_id, updated_by_internal_identity_id)
      values (p_unit_id, unit_record.institution_id, ctx.internal_identity_id)
      on conflict (unit_id) do nothing;
      update public.unit_care_policies p set
        child_safety_mode = coalesce(cs_mode, p.child_safety_mode),
        medication_mode = coalesce(med_mode, p.medication_mode),
        notify_unit = coalesce((p_payload ->> 'notify_unit')::boolean, p.notify_unit),
        notify_child_hierarchy = coalesce((p_payload ->> 'notify_child_hierarchy')::boolean, p.notify_child_hierarchy),
        notify_other_guardians = coalesce((p_payload ->> 'notify_other_guardians')::boolean, p.notify_other_guardians),
        management_version = p.management_version + 1,
        updated_by_internal_identity_id = ctx.internal_identity_id,
        updated_at = now()
      where p.unit_id = p_unit_id
      returning management_version into result_version;
      insert into app_private.unit_care_policy_receipts(request_id, actor_internal_identity_id, unit_id, request_hash, result_version)
      values (p_request_id, ctx.internal_identity_id, p_unit_id, request_hash, result_version);
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
        ctx.internal_membership_id, ctx.session_id, 'units.update', ctx.aal, 'unit.care_policy.set', 'success',
        null, correlation, unit_record.institution_id, 'unit', p_unit_id);
    end if;
  exception when others then
    get stacked diagnostics detail = pg_exception_detail;
    code := case when detail like 'SAI_%' then detail else 'SAI_INTERNAL_ERROR' end;
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('units.update', 'unit.care_policy.set', code, correlation,
      case when ctx.scope_kind = 'institution' then ctx.scope_institution_id end);
    return app_private.superadmin_internal_error_envelope(code, correlation);
  end if;
  return jsonb_build_object('ok', true, 'data',
    app_private.unit_care_policy_payload_v1(p_unit_id) || jsonb_build_object('replayed', replayed, 'correlation_id', correlation), 'error', null);
end $$;

-- 2. Destinatarios e fan-out -------------------------------------------------------
create function app_private.child_care_notification_recipients_v1(
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
    -- equipe da unidade: memberships ativas da instituicao com escopo na unidade ou na instituicao inteira
    select m.person_id from public.institution_memberships m
    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
      and (m.scope_kind = 'institution' or (m.scope_kind = 'unit' and m.scope_unit_id = p_unit_id))
      and m.role_code <> 'legal_representative'
      and (select notify_unit from policy)
  ),
  hierarchy_people as (
    -- profissionais atribuidos a crianca
    select m.person_id from public.professional_child_assignments a
    join public.institution_memberships m on m.id = a.membership_id
    where a.child_context_id = p_child_context_id and a.status = 'active' and a.revoked_at is null
      and m.status = 'active' and m.revoked_at is null
      and (select notify_child_hierarchy from policy)
    union
    -- professores (memberships com escopo na turma) das turmas da crianca
    select m.person_id from public.child_unit_links cul
    join public.child_group_links cgl on cgl.child_unit_link_id = cul.id and cgl.status = 'active'
    join public.institution_memberships m on m.scope_kind = 'group' and m.scope_group_id = cgl.group_id
      and m.status = 'active' and m.revoked_at is null
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
  -- pessoas de servico (espelho das identidades internas do Superadmin/Principal,
  -- 220400 e 20260911130000) nao recebem sino: o Superadmin nao e a unidade
  where person.person_type = 'adult' and person.deleted_at is null and person.status = 'active'
    and all_people.person_id is distinct from p_actor_person_id
$$;

create function app_private.notify_child_care_event_v1(
  p_institution_id uuid, p_unit_id uuid, p_child_context_id uuid, p_event_code text,
  p_object_type text, p_object_id uuid, p_payload jsonb, p_actor_person_id uuid
) returns uuid language plpgsql volatile security definer set search_path='' as $$
declare event_id uuid;
begin
  insert into public.context_notification_events(institution_id, unit_id, child_context_id, event_code,
    object_type, object_id, payload_json, created_by_person_id)
  values (p_institution_id, p_unit_id, p_child_context_id, p_event_code, p_object_type, p_object_id,
    coalesce(p_payload, '{}'::jsonb), p_actor_person_id)
  returning id into event_id;
  insert into public.context_notification_recipients(event_id, person_id)
  select event_id, r from app_private.child_care_notification_recipients_v1(p_institution_id, p_unit_id, p_child_context_id, p_actor_person_id) r
  on conflict do nothing;
  return event_id;
end $$;

-- 3. Gatilhos ----------------------------------------------------------------------
create function app_private.child_safety_authorization_care_notify_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op = 'INSERT' then
    perform app_private.notify_child_care_event_v1(new.institution_id, new.unit_id, new.child_context_id,
      'child_safety.authorization.requested', 'authorized_person_authorization', new.id,
      jsonb_build_object('decision_status', new.decision_status::text, 'status', new.status::text), new.created_by_person_id);
  elsif new.decision_status is distinct from old.decision_status then
    perform app_private.notify_child_care_event_v1(new.institution_id, new.unit_id, new.child_context_id,
      'child_safety.authorization.' || new.decision_status::text, 'authorized_person_authorization', new.id,
      jsonb_build_object('decision_status', new.decision_status::text, 'status', new.status::text), new.decided_by_person_id);
  elsif new.status is distinct from old.status then
    perform app_private.notify_child_care_event_v1(new.institution_id, new.unit_id, new.child_context_id,
      'child_safety.authorization.' || new.status::text, 'authorized_person_authorization', new.id,
      jsonb_build_object('decision_status', new.decision_status::text, 'status', new.status::text),
      coalesce(new.suspended_by_person_id, new.created_by_person_id));
  end if;
  return new;
end $$;
create trigger authorized_person_authorizations_care_notify_v1
  after insert or update of decision_status, status on public.authorized_person_authorizations
  for each row execute function app_private.child_safety_authorization_care_notify_v1();

create function app_private.child_safety_restriction_care_notify_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status and new.severity is not distinct from old.severity then
    return new;
  end if;
  perform app_private.notify_child_care_event_v1(new.institution_id, new.unit_id, new.child_context_id,
    case when tg_op = 'INSERT' then 'child_safety.restriction.created' else 'child_safety.restriction.' || new.status::text end,
    'child_safety_restriction', new.id, jsonb_build_object('severity', new.severity::text, 'status', new.status::text),
    coalesce(new.updated_by_person_id, new.created_by_person_id));
  return new;
end $$;
create trigger child_safety_restrictions_care_notify_v1
  after insert or update of status, severity on public.child_safety_restrictions
  for each row execute function app_private.child_safety_restriction_care_notify_v1();

create function app_private.medication_plan_care_notify_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare target_unit uuid; mode text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return new; end if;
  -- unidade do plano ou, no escopo de instituicao, a unidade ativa da crianca
  target_unit := new.unit_id;
  if target_unit is null then
    select cul.unit_id into target_unit from public.child_unit_links cul
    where cul.child_context_id = new.child_context_id and cul.status = 'active' and cul.revoked_at is null
    order by cul.created_at desc limit 1;
  end if;
  select coalesce(p.medication_mode, 'accept_to_release') into mode
  from (select 1) one left join public.unit_care_policies p on p.unit_id = target_unit;
  if mode = 'not_tracked' then return new; end if;
  perform app_private.notify_child_care_event_v1(new.institution_id, target_unit, new.child_context_id,
    case when tg_op = 'INSERT' then 'medication.plan.created' else 'medication.plan.' || new.status end,
    'medication_plan', new.id, jsonb_build_object('status', new.status, 'medication_mode', mode), new.created_by_person_id);
  return new;
end $$;
create trigger medication_plans_care_notify_v1
  after insert or update of status on public.medication_plans
  for each row execute function app_private.medication_plan_care_notify_v1();

-- 4. Donos e privilegios ------------------------------------------------------------
alter table public.unit_care_policies owner to postgres;
alter table app_private.unit_care_policy_receipts owner to postgres;
do $grants$ declare p regprocedure; begin
  foreach p in array array[
    'app_private.unit_care_policy_payload_v1(uuid)'::regprocedure,
    'public.superadmin_unit_care_policy_get_v1(uuid)'::regprocedure,
    'public.superadmin_unit_care_policy_set_v1(uuid,uuid,jsonb)'::regprocedure,
    'app_private.child_care_notification_recipients_v1(uuid,uuid,uuid,uuid)'::regprocedure,
    'app_private.notify_child_care_event_v1(uuid,uuid,uuid,text,text,uuid,jsonb,uuid)'::regprocedure,
    'app_private.child_safety_authorization_care_notify_v1()'::regprocedure,
    'app_private.child_safety_restriction_care_notify_v1()'::regprocedure,
    'app_private.medication_plan_care_notify_v1()'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres', p);
    execute format('revoke all on function %s from public, anon, authenticated, service_role', p);
  end loop;
end $grants$;
grant execute on function public.superadmin_unit_care_policy_get_v1(uuid),
  public.superadmin_unit_care_policy_set_v1(uuid,uuid,jsonb) to authenticated;

commit;
