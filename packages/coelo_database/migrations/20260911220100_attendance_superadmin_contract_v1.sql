-- 20260911220100_attendance_superadmin_contract_v1
--
-- Contrato completo da Assiduidade para o cliente do Superadmin
-- (apps/superadmin/lib/features/attendance/data/supabase_attendance_repository.dart),
-- Rodada 5, grupo formularios-cuidado-rotina, 11/09/2026; ADR 0034.
-- Sobre a baseline 20260910000000 + ordem-de-aplicacao-producao.txt ate o
-- lote 27 (inclui 20260910010200 attendance_authorization_and_idempotency_v1 e
-- 20260910220700 attendance_dashboard_access_and_context_options_v1).
--
-- O cliente chama catorze RPCs que nao existem em producao nem em migration
-- alguma do repositorio. Este pacote cria todas com os nomes, parametros
-- (p_*) e envelopes JSON que os decoders Dart leem (_call, _participant,
-- _revision, _notice, _metrics, _dashboardSnapshot, _dashboardRanking,
-- _dashboardExportJob):
--
--   superadmin_attendance_directory(p_date)
--   superadmin_attendance_call_detail(p_call_id)
--   superadmin_attendance_create_call(p_institution_id,p_unit_id,p_group_id,
--     p_activity_id,p_session_date,p_idempotency_key)
--   superadmin_attendance_set_participant(p_idempotency_key,p_call_id,
--     p_participant_id,p_state,p_expected_version)
--   superadmin_attendance_correct_participant(p_call_id,p_participant_id,
--     p_state,p_reason,p_expected_version)
--   superadmin_attendance_complete_call(p_call_id,p_expected_version,
--     p_idempotency_key)
--   superadmin_attendance_reopen_call(p_call_id,p_expected_version,p_reason)
--   superadmin_attendance_mark_remaining_present(p_call_id,p_expected_version,
--     p_idempotency_key)
--   superadmin_attendance_clear_presence_marks(p_call_id,p_expected_version,
--     p_idempotency_key)
--   superadmin_attendance_undo_bulk(p_operation_id,p_call_id,p_expected_version)
--   superadmin_attendance_confirm_notice(p_notice_id,p_expected_version)
--   attendance_dashboard_read(16 parametros do historico 20260825171221)
--   attendance_dashboard_ranking_page(11 parametros do historico)
--   attendance_dashboard_request_export(p_request_id,p_kind,p_format,p_filters)
--
-- Regras:
--   * toda logica em app_private.* sem grant a cliente; wrappers public.*
--     security definer com revoke de public/anon/authenticated/service_role
--     antes do grant execute minimo a authenticated;
--   * ator por app_private.current_person_id() (ponte de ator do realm
--     interno v2, 20260910220400); autorizacao por
--     app_private.can_access_attendance_child(...,require_manage) e pelo escopo
--     de app_private.attendance_dashboard_access() (platform > institution >
--     unit > assignments; guardian negado com 42501);
--   * instituicao e unidade derivadas da turma (groups), nunca do payload:
--     p_institution_id/p_unit_id sao apenas conferidos;
--   * comandos com versao esperada (40001 em conflito) e recibo idempotente
--     por chave reservada em app_private.attendance_idempotency_reservations
--     (20260910010200): a resposta e guardada na reserva e devolvida na
--     repeticao sem reexecutar; chave nao reservada e recusada (22023);
--   * auditoria em audit.audit_logs com actor_person_id (hash_version 1),
--     como os pacotes de Cuidado e Rotina da mesma familia;
--   * attendance_dashboard_request_export devolve indisponibilidade honesta
--     (exportacao adiada, ADR 0034) sem criar job, arquivo ou RPC extra.
--
-- Deltas de esquema (forward-only):
--   * public.attendance_sessions.version bigint (versao otimista da chamada),
--     reopen_reason/reopened_by_person_id/reopened_at (motivo legivel da
--     reabertura; a auditoria mascara texto livre por desenho);
--   * attendance_sessions_status_check passa a aceitar 'reopened' e
--     'corrected' (estados que o cliente e o dashboard do historico ja leem);
--   * app_private.attendance_idempotency_reservations.response jsonb (recibo);
--   * app_private.attendance_bulk_operations (recibo reversivel das operacoes
--     em lote, para superadmin_attendance_undo_bulk);
--   * public.attendance_reserve_idempotency_key passa a security definer: em
--     producao o wrapper e security invoker e delega a uma funcao app_private
--     sem grant a authenticated, entao a reserva responde 42501 e nenhum
--     comando do cliente chega a executar (achado desta rodada).
--
-- Fora deste pacote: attendance.export no catalogo e qualquer job de
-- exportacao (adiado); AAL2 (MFA fora do MVP); Edge Function attendance-export.
-- Reversao (manual, forward-only): drop das funcoes criadas aqui, drop da
-- tabela app_private.attendance_bulk_operations, drop das colunas version e
-- response, e restauracao do check de status original.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.attendance.superadmin-contract-v1', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'attendance contract migration requires postgres';
  end if;
  if to_regprocedure('app_private.current_person_id()') is null
    or to_regprocedure('app_private.attendance_dashboard_access()') is null
    or to_regprocedure('app_private.can_access_attendance_child(uuid,uuid,uuid,uuid,uuid,boolean)') is null
    or to_regprocedure('app_private.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)') is null
    or to_regclass('app_private.attendance_idempotency_reservations') is null
    or to_regclass('public.attendance_sessions') is null
    or to_regclass('public.attendance_expected_participants') is null
    or to_regclass('public.attendance_records') is null
    or to_regclass('public.attendance_record_revisions') is null
    or to_regclass('public.attendance_notices') is null
    or to_regclass('public.child_group_links') is null
    or to_regclass('public.child_unit_links') is null
    or to_regclass('public.activity_group_links') is null
    or to_regclass('public.activity_group_participants') is null then
    raise object_not_in_prerequisite_state using message = 'attendance contract dependencies are missing';
  end if;
  if to_regprocedure('public.superadmin_attendance_directory(date)') is not null
    or to_regprocedure('public.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)') is not null then
    raise duplicate_function using message = 'attendance contract functions already exist';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- 1. Esquema
-- ---------------------------------------------------------------------------

alter table public.attendance_sessions
  add column if not exists version bigint not null default 1;
alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_version_check;
alter table public.attendance_sessions
  add constraint attendance_sessions_version_check check (version > 0);

alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_status_check;
alter table public.attendance_sessions
  add constraint attendance_sessions_status_check check (
    status in ('draft','open','reopened','closed','corrected','cancelled')
  );

alter table public.attendance_sessions
  add column if not exists reopen_reason text,
  add column if not exists reopened_by_person_id uuid references public.people(id) on delete restrict,
  add column if not exists reopened_at timestamptz;

alter table app_private.attendance_idempotency_reservations
  add column if not exists response jsonb;

create table if not exists app_private.attendance_bulk_operations (
  id uuid primary key default gen_random_uuid(),
  attendance_session_id uuid not null
    references public.attendance_sessions(id) on delete cascade,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  command text not null check (command in ('mark_remaining_present','clear_presence_marks')),
  affected jsonb not null default '[]'::jsonb,
  previous_version bigint not null,
  current_version bigint not null,
  created_at timestamptz not null default now(),
  undone_at timestamptz
);
create index if not exists attendance_bulk_operations_session_idx
  on app_private.attendance_bulk_operations(attendance_session_id, created_at desc);
alter table app_private.attendance_bulk_operations enable row level security;
alter table app_private.attendance_bulk_operations force row level security;
revoke all on app_private.attendance_bulk_operations from public, anon, authenticated, service_role;

create index if not exists attendance_sessions_dashboard_scope_date_idx
  on public.attendance_sessions(institution_id, unit_id, session_date desc, id)
  include (group_id, activity_id, status, created_by_person_id)
  where status <> 'cancelled';
create index if not exists attendance_records_dashboard_active_idx
  on public.attendance_records(attendance_session_id, outcome, child_context_id)
  where status = 'active';
create index if not exists attendance_notices_dashboard_pending_idx
  on public.attendance_notices(institution_id, unit_id, starts_at, child_context_id)
  where review_status = 'pending' and cancelled_at is null;

-- Correcao do wrapper de reserva de chave (20260910010200): em producao ele e
-- security invoker e delega para app_private.attendance_reserve_idempotency_key,
-- que nao tem grant a authenticated; a reserva responde 42501 e nenhum comando
-- do cliente chega a executar. O corpo continua so delegando; passa a
-- security definer com search_path fixo. Assinatura e nomes de parametro
-- preservados (o cliente chama por nome: command, aggregate_id,
-- expected_version, scope).
create or replace function public.attendance_reserve_idempotency_key(
  command text,
  aggregate_id uuid default null,
  expected_version bigint default null,
  scope jsonb default null
) returns uuid language sql volatile security definer set search_path='' as $$
  select app_private.attendance_reserve_idempotency_key(
    command, aggregate_id, expected_version, scope)
$$;
alter function public.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb) owner to postgres;
revoke all on function public.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Helpers privados
-- ---------------------------------------------------------------------------

-- Envelope de um aviso familiar como o cliente le (_notice).
create function app_private.attendance_notice_payload(p_notice public.attendance_notices)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'id', p_notice.id,
    'call_id', (
      select session_row.id from public.attendance_sessions session_row
      where session_row.group_id = p_notice.group_id
        and session_row.activity_id is not distinct from p_notice.activity_id
        and session_row.status <> 'cancelled'
        and session_row.session_date between (p_notice.starts_at at time zone 'UTC')::date
          and coalesce((p_notice.ends_at at time zone 'UTC')::date, (p_notice.starts_at at time zone 'UTC')::date)
      order by session_row.session_date desc, session_row.created_at desc limit 1
    ),
    'participant_id', p_notice.child_context_id,
    'participant_name', coalesce((
      select person.display_name from public.child_contexts child_context
      join public.people person on person.id = child_context.child_person_id
      where child_context.id = p_notice.child_context_id), ''),
    'intent', p_notice.notice_type,
    'reason', coalesce(p_notice.reason_detail, (
      select reason.name from public.attendance_reason_catalog reason where reason.id = p_notice.reason_id), ''),
    'start_date', (p_notice.starts_at at time zone 'UTC')::date,
    'end_date', (p_notice.ends_at at time zone 'UTC')::date,
    'note', coalesce(p_notice.note, ''),
    'pending', p_notice.review_status = 'pending' and p_notice.cancelled_at is null
  )
$$;

-- Envelope de uma chamada como o cliente le (_call, _participant, _revision).
-- Nao autoriza: quem chama ja conferiu o acesso a sessao.
create function app_private.attendance_call_payload(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  session_row public.attendance_sessions%rowtype;
  result jsonb;
begin
  select * into session_row from public.attendance_sessions where id = p_session_id;
  if session_row.id is null then
    return null;
  end if;

  select jsonb_build_object(
    'id', session_row.id,
    'institution_id', session_row.institution_id,
    'institution_name', coalesce(institution.public_name, ''),
    'unit_id', session_row.unit_id,
    'unit_name', coalesce(unit_row.name, ''),
    'group_id', session_row.group_id,
    'group_name', coalesce(group_row.name, ''),
    'activity_id', session_row.activity_id,
    'activity_name', activity.name,
    'session_date', session_row.session_date,
    'status', session_row.status,
    'responsible', coalesce(responsible.display_name, ''),
    'can_manage', app_private.can_access_attendance_child(
      session_row.institution_id, session_row.unit_id, session_row.group_id,
      session_row.activity_id, null, true),
    'updated_at', session_row.updated_at,
    'version', session_row.version,
    'participants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', expected.id,
        'participant_id', expected.child_context_id,
        'name', coalesce(child_person.display_name, ''),
        'state', coalesce(record_row.outcome, 'unmarked'),
        'note', coalesce(record_row.note, ''),
        'justification', case notice_row.review_status
          when 'pending' then 'pending' when 'confirmed' then 'accepted'
          when 'rejected' then 'rejected' else null end,
        'notice', case when notice_row.id is null then null
          else app_private.attendance_notice_payload(notice_row) end
      ) order by lower(child_person.display_name), expected.child_context_id)
      from public.attendance_expected_participants expected
      join public.child_contexts child_context on child_context.id = expected.child_context_id
      join public.people child_person on child_person.id = child_context.child_person_id
      left join public.attendance_records record_row
        on record_row.attendance_session_id = session_row.id
       and record_row.child_context_id = expected.child_context_id
       and record_row.status = 'active'
      left join lateral (
        select notice.* from public.attendance_notices notice
        where notice.child_context_id = expected.child_context_id
          and notice.group_id = session_row.group_id
          and notice.cancelled_at is null
          and session_row.session_date between (notice.starts_at at time zone 'UTC')::date
            and coalesce((notice.ends_at at time zone 'UTC')::date, (notice.starts_at at time zone 'UTC')::date)
        order by case notice.review_status when 'pending' then 0 else 1 end, notice.created_at desc
        limit 1
      ) notice_row on true
      where expected.attendance_session_id = session_row.id
        and expected.status = 'active'
    ), '[]'::jsonb),
    'revisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'participant_id', record_row.child_context_id,
        'previous', coalesce(revision.before_json->>'outcome', 'unmarked'),
        'current', case when revision.action_code = 'reverted' then 'unmarked'
          else coalesce(revision.after_json->>'outcome', 'unmarked') end,
        'reason', coalesce(revision.reason, ''),
        'author', coalesce(author.display_name, ''),
        'changed_at', revision.created_at
      ) order by revision.created_at desc, revision.id)
      from public.attendance_record_revisions revision
      join public.attendance_records record_row on record_row.id = revision.attendance_record_id
      join public.people author on author.id = revision.changed_by_person_id
      where record_row.attendance_session_id = session_row.id
        and revision.action_code in ('corrected','reverted')
    ), '[]'::jsonb)
  ) into result
  from public.institutions institution
  join public.units unit_row on unit_row.id = session_row.unit_id
  join public.groups group_row on group_row.id = session_row.group_id
  left join public.activity_definitions activity on activity.id = session_row.activity_id
  left join public.people responsible on responsible.id = session_row.created_by_person_id
  where institution.id = session_row.institution_id;

  return result;
end $$;

-- Carrega e trava a sessao, confere acesso (leitura ou gestao) e versao.
-- Sessao inexistente e sessao fora do escopo respondem igual (42501) para nao
-- enumerar ids; conflito de versao responde 40001, que o cliente traduz em
-- AttendanceVersionConflictException.
create function app_private.attendance_require_call(
  p_call_id uuid, p_expected_version bigint, p_require_manage boolean
) returns public.attendance_sessions
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if p_call_id is null then
    raise invalid_parameter_value using message = 'attendance call required';
  end if;
  select * into session_row from public.attendance_sessions
  where id = p_call_id and status <> 'cancelled' for update;
  if session_row.id is null or not app_private.can_access_attendance_child(
    session_row.institution_id, session_row.unit_id, session_row.group_id,
    session_row.activity_id, null, p_require_manage
  ) then
    raise insufficient_privilege using message = 'attendance call outside scope';
  end if;
  if p_expected_version is not null and p_expected_version <> session_row.version then
    raise exception using errcode = '40001',
      message = 'attendance call version conflict';
  end if;
  return session_row;
end $$;

-- Recibo idempotente. A chave precisa ter sido reservada pelo mesmo ator para
-- o mesmo comando (attendance_reserve_idempotency_key). Devolve a resposta
-- guardada quando a chave ja foi consumida; null quando ainda nao foi.
create function app_private.attendance_replay_receipt(
  p_actor uuid, p_command text, p_idempotency_key uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  reservation app_private.attendance_idempotency_reservations%rowtype;
begin
  if p_idempotency_key is null then
    raise invalid_parameter_value using message = 'attendance idempotency key required';
  end if;
  select * into reservation from app_private.attendance_idempotency_reservations
  where idempotency_key = p_idempotency_key and actor_person_id = p_actor
    and command = p_command
  for update;
  if reservation.id is null then
    raise invalid_parameter_value using message = 'attendance idempotency key not reserved';
  end if;
  return reservation.response;
end $$;

create function app_private.attendance_store_receipt(
  p_actor uuid, p_command text, p_idempotency_key uuid, p_aggregate_id uuid, p_response jsonb
) returns void
language sql
volatile
security definer
set search_path=''
as $$
  update app_private.attendance_idempotency_reservations
     set consumed_at = coalesce(consumed_at, now()),
         aggregate_id = coalesce(aggregate_id, p_aggregate_id),
         response = p_response
   where idempotency_key = p_idempotency_key and actor_person_id = p_actor
     and command = p_command
$$;

create function app_private.attendance_bump_version(p_session_id uuid, p_status text default null)
returns bigint
language sql
volatile
security definer
set search_path=''
as $$
  update public.attendance_sessions
     set version = version + 1,
         status = coalesce(p_status, status),
         updated_at = now()
   where id = p_session_id
  returning version
$$;

create function app_private.attendance_audit(
  p_actor uuid, p_action_code text, p_session public.attendance_sessions,
  p_object_type text, p_object_id uuid, p_reason text, p_after jsonb
) returns void
language sql
volatile
security definer
set search_path=''
as $$
  -- O guard de auditoria minimiza por desenho (LGPD): reason em texto livre
  -- vira '[redacted]' e after_json guarda so chaves da allowlist (ids, status,
  -- state, version). O motivo legivel de correcao fica em
  -- attendance_record_revisions.reason e o de reabertura em
  -- attendance_sessions.reopen_reason.
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, reason, after_json
  ) values (
    p_actor, coalesce(auth.jwt()->>'aal', 'aal1'), p_action_code, p_object_type, p_object_id,
    p_session.institution_id, 'success', p_reason, p_after
  )
$$;

-- Escreve o estado de um participante. 'unmarked' reverte o registro ativo;
-- os demais estados inserem (confirmed) ou corrigem (corrected) o registro.
create function app_private.attendance_write_state(
  p_actor uuid, p_session public.attendance_sessions, p_child_context_id uuid,
  p_state text, p_reason text, p_note text default null, p_source_notice_id uuid default null
) returns void
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  existing_record public.attendance_records%rowtype;
  new_record_id uuid;
begin
  if p_state not in ('unmarked','present','absent','late_arrival','early_departure','late_and_early') then
    raise invalid_parameter_value using message = 'invalid attendance state';
  end if;
  if not exists (
    select 1 from public.attendance_expected_participants expected
    where expected.attendance_session_id = p_session.id
      and expected.child_context_id = p_child_context_id
      and expected.status = 'active'
  ) then
    raise invalid_parameter_value using message = 'attendance participant not in call';
  end if;
  if not app_private.can_access_attendance_child(
    p_session.institution_id, p_session.unit_id, p_session.group_id,
    p_session.activity_id, p_child_context_id, true
  ) then
    raise insufficient_privilege using message = 'attendance participant outside scope';
  end if;

  select * into existing_record from public.attendance_records
  where attendance_session_id = p_session.id
    and child_context_id = p_child_context_id and status = 'active'
  for update;

  if p_state = 'unmarked' then
    if existing_record.id is null then
      return;
    end if;
    update public.attendance_records set
      status = 'inactive', reverted_by_person_id = p_actor, reverted_at = now(),
      revert_reason = coalesce(nullif(btrim(p_reason), ''), 'Marcação removida'),
      updated_at = now()
    where id = existing_record.id;
    insert into public.attendance_record_revisions(
      attendance_record_id, action_code, before_json, after_json, reason, changed_by_person_id
    ) select existing_record.id, 'reverted', to_jsonb(existing_record), to_jsonb(current_row),
      coalesce(nullif(btrim(p_reason), ''), 'Marcação removida'), p_actor
    from public.attendance_records current_row where current_row.id = existing_record.id;
    return;
  end if;

  if existing_record.id is null then
    insert into public.attendance_records(
      attendance_session_id, child_context_id, outcome, source_notice_id, note,
      confirmed_by_person_id
    ) values (
      p_session.id, p_child_context_id, p_state, p_source_notice_id,
      nullif(btrim(p_note), ''), p_actor
    ) returning id into new_record_id;
    insert into public.attendance_record_revisions(
      attendance_record_id, action_code, after_json, reason, changed_by_person_id
    ) select new_record_id, 'confirmed', to_jsonb(record_row), nullif(btrim(p_reason), ''), p_actor
    from public.attendance_records record_row where record_row.id = new_record_id;
  else
    if existing_record.outcome = p_state
       and existing_record.note is not distinct from nullif(btrim(p_note), '')
       and existing_record.source_notice_id is not distinct from coalesce(p_source_notice_id, existing_record.source_notice_id) then
      return;
    end if;
    update public.attendance_records set
      outcome = p_state,
      source_notice_id = coalesce(p_source_notice_id, source_notice_id),
      note = coalesce(nullif(btrim(p_note), ''), note),
      confirmed_by_person_id = p_actor, confirmed_at = now(), updated_at = now()
    where id = existing_record.id;
    insert into public.attendance_record_revisions(
      attendance_record_id, action_code, before_json, after_json, reason, changed_by_person_id
    ) select existing_record.id, 'corrected', to_jsonb(existing_record), to_jsonb(record_row),
      nullif(btrim(p_reason), ''), p_actor
    from public.attendance_records record_row where record_row.id = existing_record.id;
  end if;
end $$;

-- Recorte de sessoes visiveis ao ator segundo attendance_dashboard_access.
create function app_private.attendance_session_in_scope(
  p_access jsonb, p_session public.attendance_sessions
) returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select case p_access->>'scope'
    when 'platform' then true
    when 'institution' then p_session.institution_id = (p_access->>'institution_id')::uuid
    when 'unit' then p_session.institution_id = (p_access->>'institution_id')::uuid
      and p_session.unit_id = (p_access->>'unit_id')::uuid
    when 'assignments' then p_session.institution_id = (p_access->>'institution_id')::uuid
      and (
        (p_access->'assigned_group_ids') ? p_session.group_id::text
        or (p_session.activity_id is not null
          and (p_access->'assigned_activity_ids') ? p_session.activity_id::text)
      )
    else false end
  and app_private.can_access_attendance_child(
    p_session.institution_id, p_session.unit_id, p_session.group_id,
    p_session.activity_id, null, false)
$$;

-- ---------------------------------------------------------------------------
-- 3. Leituras do Superadmin
-- ---------------------------------------------------------------------------

create function app_private.superadmin_attendance_directory(p_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  access_payload jsonb;
  effective_date date := coalesce(p_date, current_date);
  result jsonb;
begin
  access_payload := app_private.attendance_dashboard_access();
  if access_payload->>'scope' = 'guardian'
     or coalesce((access_payload->>'can_read')::boolean, false) is not true then
    raise insufficient_privilege using message = 'attendance.read required';
  end if;

  with visible_sessions as materialized (
    select session_row.*
    from public.attendance_sessions session_row
    where session_row.session_date = effective_date
      and session_row.status <> 'cancelled'
      and app_private.attendance_session_in_scope(access_payload, session_row)
  ), visible_records as (
    select record_row.outcome, record_row.source_notice_id
    from visible_sessions session_row
    join public.attendance_records record_row
      on record_row.attendance_session_id = session_row.id and record_row.status = 'active'
  ), metrics as (
    select count(*)::integer as official_records,
      count(*) filter (where outcome in ('present','late_arrival','early_departure','late_and_early'))::integer as numerator,
      count(*) filter (where outcome = 'absent' and source_notice_id is not null)::integer as justified_absences,
      count(*) filter (where outcome = 'absent' and source_notice_id is null)::integer as unjustified_absences,
      count(*) filter (where outcome in ('late_arrival','late_and_early'))::integer as late,
      count(*) filter (where outcome in ('early_departure','late_and_early'))::integer as early_departures
    from visible_records
  )
  select jsonb_build_object(
    'calls', coalesce((
      select jsonb_agg(app_private.attendance_call_payload(session_row.id)
        order by session_row.created_at desc, session_row.id)
      from visible_sessions session_row), '[]'::jsonb),
    'notices', coalesce((
      select jsonb_agg(app_private.attendance_notice_payload(notice)
        order by notice.starts_at desc, notice.id)
      from public.attendance_notices notice
      where notice.review_status = 'pending' and notice.cancelled_at is null
        and effective_date between (notice.starts_at at time zone 'UTC')::date
          and coalesce((notice.ends_at at time zone 'UTC')::date, (notice.starts_at at time zone 'UTC')::date)
        and exists (
          select 1 from visible_sessions session_row
          where session_row.group_id = notice.group_id
            and session_row.activity_id is not distinct from notice.activity_id)
        and app_private.can_access_attendance_child(
          notice.institution_id, notice.unit_id, notice.group_id, notice.activity_id,
          notice.child_context_id, false)
    ), '[]'::jsonb),
    'metrics', jsonb_build_object(
      'presence_percent', case when metrics.official_records = 0 then 0
        else round(metrics.numerator::numeric / metrics.official_records * 100, 2) end,
      'justified_absences', metrics.justified_absences,
      'unjustified_absences', metrics.unjustified_absences,
      'late', metrics.late,
      'early_departures', metrics.early_departures
    )
  ) into result from metrics;
  return result;
end $$;

create function app_private.superadmin_attendance_call_detail(p_call_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if p_call_id is null then
    return null;
  end if;
  select * into session_row from public.attendance_sessions
  where id = p_call_id and status <> 'cancelled';
  -- Inexistente e fora do escopo respondem igual (null) para nao enumerar.
  if session_row.id is null or not app_private.can_access_attendance_child(
    session_row.institution_id, session_row.unit_id, session_row.group_id,
    session_row.activity_id, null, false
  ) then
    return null;
  end if;
  return app_private.attendance_call_payload(session_row.id);
end $$;

-- ---------------------------------------------------------------------------
-- 4. Comandos do Superadmin
-- ---------------------------------------------------------------------------

create function app_private.superadmin_attendance_create_call(
  p_institution_id uuid, p_unit_id uuid, p_group_id uuid, p_activity_id uuid,
  p_session_date date, p_idempotency_key uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  group_row public.groups%rowtype;
  link_row public.activity_group_links%rowtype;
  session_row public.attendance_sessions%rowtype;
  existing_id uuid;
  receipt jsonb;
  response jsonb;
  inserted integer;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  receipt := app_private.attendance_replay_receipt(actor, 'create_call', p_idempotency_key);
  if receipt is not null then
    return receipt;
  end if;
  if p_group_id is null or p_session_date is null then
    raise invalid_parameter_value using message = 'attendance call group and date required';
  end if;

  -- Instituicao e unidade vem da turma; o payload apenas precisa concordar.
  select * into group_row from public.groups where id = p_group_id and status = 'active';
  if group_row.id is null
     or (p_institution_id is not null and p_institution_id <> group_row.institution_id)
     or (p_unit_id is not null and p_unit_id <> group_row.unit_id) then
    raise insufficient_privilege using message = 'attendance call context outside scope';
  end if;
  if p_activity_id is not null then
    select * into link_row from public.activity_group_links link
    where link.activity_id = p_activity_id and link.group_id = group_row.id
      and link.unit_id = group_row.unit_id and link.institution_id = group_row.institution_id
      and link.status = 'active'
      and link.starts_at::date <= p_session_date
      and (link.ends_at is null or link.ends_at::date > p_session_date)
    order by link.starts_at desc limit 1;
    if link_row.id is null then
      raise insufficient_privilege using message = 'attendance call activity outside scope';
    end if;
  end if;
  if not app_private.can_access_attendance_child(
    group_row.institution_id, group_row.unit_id, group_row.id, p_activity_id, null, true
  ) then
    raise insufficient_privilege using message = 'attendance.manage required';
  end if;

  -- Chamada ja aberta para o mesmo contexto e dia: devolve a existente.
  select session_row_existing.id into existing_id
  from public.attendance_sessions session_row_existing
  where session_row_existing.group_id = group_row.id
    and session_row_existing.activity_id is not distinct from p_activity_id
    and session_row_existing.session_date = p_session_date
    and session_row_existing.status <> 'cancelled'
  order by session_row_existing.created_at desc limit 1;
  if existing_id is not null then
    response := app_private.attendance_call_payload(existing_id);
    perform app_private.attendance_store_receipt(actor, 'create_call', p_idempotency_key, existing_id, response);
    return response;
  end if;

  insert into public.attendance_sessions(
    institution_id, unit_id, group_id, activity_id, session_kind, session_date,
    status, created_by_person_id
  ) values (
    group_row.institution_id, group_row.unit_id, group_row.id, p_activity_id,
    case when p_activity_id is null then 'group' else 'activity' end, p_session_date,
    'open', actor
  ) returning * into session_row;

  if p_activity_id is null then
    insert into public.attendance_expected_participants(
      attendance_session_id, child_context_id, child_group_link_id
    )
    select session_row.id, child_context.id, child_group.id
    from public.child_group_links child_group
    join public.child_unit_links child_unit on child_unit.id = child_group.child_unit_link_id
    join public.child_contexts child_context on child_context.id = child_unit.child_context_id
    where child_group.group_id = group_row.id and child_group.status = 'active'
      and (child_group.starts_at is null or child_group.starts_at::date <= p_session_date)
      and (child_group.ends_at is null or child_group.ends_at::date > p_session_date)
      and child_unit.unit_id = group_row.unit_id
      and child_unit.status = 'active'
      and child_context.status = 'active'
      and child_context.institution_id = group_row.institution_id
    on conflict (attendance_session_id, child_context_id) do nothing;
  else
    insert into public.attendance_expected_participants(
      attendance_session_id, child_context_id, child_group_link_id, activity_group_participant_id
    )
    select session_row.id, child_context.id, child_group.id, participant.id
    from public.activity_group_participants participant
    join public.child_group_links child_group on child_group.id = participant.child_group_link_id
    join public.child_unit_links child_unit on child_unit.id = child_group.child_unit_link_id
    join public.child_contexts child_context on child_context.id = child_unit.child_context_id
    where participant.activity_group_link_id = link_row.id
      and participant.status = 'active' and participant.removed_at is null
      and child_group.group_id = group_row.id and child_group.status = 'active'
      and child_unit.unit_id = group_row.unit_id and child_unit.status = 'active'
      and child_context.status = 'active'
      and child_context.institution_id = group_row.institution_id
    on conflict (attendance_session_id, child_context_id) do nothing;
  end if;
  get diagnostics inserted = row_count;

  response := app_private.attendance_call_payload(session_row.id);
  perform app_private.attendance_store_receipt(actor, 'create_call', p_idempotency_key, session_row.id, response);
  perform app_private.attendance_audit(actor, 'attendance.call.create', session_row,
    'attendance_session', session_row.id, null,
    jsonb_build_object('group_id', group_row.id, 'activity_id', p_activity_id,
      'session_date', p_session_date, 'participants', inserted, 'version', session_row.version));
  return response;
end $$;

create function app_private.superadmin_attendance_set_participant(
  p_idempotency_key uuid, p_call_id uuid, p_participant_id uuid, p_state text, p_expected_version bigint
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
  receipt jsonb;
  response jsonb;
  new_version bigint;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  receipt := app_private.attendance_replay_receipt(actor, 'set_participant', p_idempotency_key);
  if receipt is not null then
    return receipt;
  end if;
  session_row := app_private.attendance_require_call(p_call_id, p_expected_version, true);
  if session_row.status not in ('open','reopened') then
    raise object_not_in_prerequisite_state using message = 'attendance call is not open';
  end if;
  perform app_private.attendance_write_state(actor, session_row, p_participant_id, p_state, null);
  new_version := app_private.attendance_bump_version(session_row.id);
  response := app_private.attendance_call_payload(session_row.id);
  perform app_private.attendance_store_receipt(actor, 'set_participant', p_idempotency_key, session_row.id, response);
  perform app_private.attendance_audit(actor, 'attendance.participant.set', session_row,
    'attendance_session', session_row.id, null,
    jsonb_build_object('child_context_id', p_participant_id, 'state', p_state, 'version', new_version));
  return response;
end $$;

create function app_private.superadmin_attendance_correct_participant(
  p_call_id uuid, p_participant_id uuid, p_state text, p_reason text, p_expected_version bigint
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
  reason text := nullif(btrim(p_reason), '');
  new_version bigint;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if reason is null or length(reason) > 500 then
    raise invalid_parameter_value using message = 'attendance correction reason required';
  end if;
  session_row := app_private.attendance_require_call(p_call_id, p_expected_version, true);
  perform app_private.attendance_write_state(actor, session_row, p_participant_id, p_state, reason);
  new_version := app_private.attendance_bump_version(session_row.id,
    case when session_row.status in ('closed','corrected') then 'corrected' else null end);
  perform app_private.attendance_audit(actor, 'attendance.participant.correct', session_row,
    'attendance_session', session_row.id, reason,
    jsonb_build_object('child_context_id', p_participant_id, 'state', p_state, 'version', new_version));
  return app_private.attendance_call_payload(session_row.id);
end $$;

create function app_private.superadmin_attendance_complete_call(
  p_call_id uuid, p_expected_version bigint, p_idempotency_key uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
  receipt jsonb;
  response jsonb;
  new_version bigint;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  receipt := app_private.attendance_replay_receipt(actor, 'complete_call', p_idempotency_key);
  if receipt is not null then
    return receipt;
  end if;
  session_row := app_private.attendance_require_call(p_call_id, p_expected_version, true);
  if session_row.status not in ('open','reopened') then
    raise object_not_in_prerequisite_state using message = 'attendance call is not open';
  end if;
  update public.attendance_sessions
     set closed_by_person_id = actor, closed_at = now()
   where id = session_row.id;
  new_version := app_private.attendance_bump_version(session_row.id, 'closed');
  response := app_private.attendance_call_payload(session_row.id);
  perform app_private.attendance_store_receipt(actor, 'complete_call', p_idempotency_key, session_row.id, response);
  perform app_private.attendance_audit(actor, 'attendance.call.complete', session_row,
    'attendance_session', session_row.id, null, jsonb_build_object('version', new_version));
  return response;
end $$;

create function app_private.superadmin_attendance_reopen_call(
  p_call_id uuid, p_expected_version bigint, p_reason text
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
  reason text := nullif(btrim(p_reason), '');
  new_version bigint;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if reason is null or length(reason) > 500 then
    raise invalid_parameter_value using message = 'attendance reopen reason required';
  end if;
  session_row := app_private.attendance_require_call(p_call_id, p_expected_version, true);
  if session_row.status not in ('closed','corrected') then
    raise object_not_in_prerequisite_state using message = 'attendance call is not completed';
  end if;
  update public.attendance_sessions
     set reopen_reason = reason, reopened_by_person_id = actor, reopened_at = now()
   where id = session_row.id;
  new_version := app_private.attendance_bump_version(session_row.id, 'reopened');
  perform app_private.attendance_audit(actor, 'attendance.call.reopen', session_row,
    'attendance_session', session_row.id, reason, jsonb_build_object('version', new_version));
  return app_private.attendance_call_payload(session_row.id);
end $$;

create function app_private.superadmin_attendance_bulk(
  p_command text, p_call_id uuid, p_expected_version bigint, p_idempotency_key uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
  receipt jsonb;
  response jsonb;
  affected jsonb := '[]'::jsonb;
  affected_ids jsonb;
  new_version bigint;
  operation_id uuid;
  target record;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  receipt := app_private.attendance_replay_receipt(actor, p_command, p_idempotency_key);
  if receipt is not null then
    return receipt;
  end if;
  session_row := app_private.attendance_require_call(p_call_id, p_expected_version, true);
  if session_row.status not in ('open','reopened') then
    raise object_not_in_prerequisite_state using message = 'attendance call is not open';
  end if;

  for target in
    select expected.child_context_id, record_row.outcome, record_row.note, record_row.source_notice_id
    from public.attendance_expected_participants expected
    left join public.attendance_records record_row
      on record_row.attendance_session_id = session_row.id
     and record_row.child_context_id = expected.child_context_id
     and record_row.status = 'active'
    where expected.attendance_session_id = session_row.id and expected.status = 'active'
      and app_private.can_access_attendance_child(
        session_row.institution_id, session_row.unit_id, session_row.group_id,
        session_row.activity_id, expected.child_context_id, true)
      and ((p_command = 'mark_remaining_present' and record_row.id is null)
        or (p_command = 'clear_presence_marks' and record_row.id is not null))
    order by expected.child_context_id
  loop
    affected := affected || jsonb_build_object(
      'child_context_id', target.child_context_id,
      'previous_state', coalesce(target.outcome, 'unmarked'),
      'previous_note', target.note,
      'previous_source_notice_id', target.source_notice_id);
    if p_command = 'mark_remaining_present' then
      perform app_private.attendance_write_state(actor, session_row, target.child_context_id,
        'present', 'Marcação em lote');
    else
      perform app_private.attendance_write_state(actor, session_row, target.child_context_id,
        'unmarked', 'Limpeza em lote');
    end if;
  end loop;

  new_version := app_private.attendance_bump_version(session_row.id);
  insert into app_private.attendance_bulk_operations(
    attendance_session_id, actor_person_id, command, affected, previous_version, current_version
  ) values (
    session_row.id, actor, p_command, affected, session_row.version, new_version
  ) returning id into operation_id;

  select coalesce(jsonb_agg(item->'child_context_id'), '[]'::jsonb) into affected_ids
  from jsonb_array_elements(affected) item;

  response := jsonb_build_object(
    'call', app_private.attendance_call_payload(session_row.id),
    'receipt', jsonb_build_object(
      'operation_id', operation_id,
      'call_id', session_row.id,
      'affected_participant_ids', affected_ids,
      'previous_version', session_row.version,
      'current_version', new_version
    )
  );
  perform app_private.attendance_store_receipt(actor, p_command, p_idempotency_key, session_row.id, response);
  perform app_private.attendance_audit(actor, 'attendance.call.' || p_command, session_row,
    'attendance_session', session_row.id, null,
    jsonb_build_object('operation_id', operation_id,
      'affected', jsonb_array_length(affected_ids), 'version', new_version));
  return response;
end $$;

create function app_private.superadmin_attendance_undo_bulk(
  p_operation_id uuid, p_call_id uuid, p_expected_version bigint
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
  operation app_private.attendance_bulk_operations%rowtype;
  item jsonb;
  new_version bigint;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  session_row := app_private.attendance_require_call(p_call_id, p_expected_version, true);
  select * into operation from app_private.attendance_bulk_operations
  where id = p_operation_id and attendance_session_id = session_row.id for update;
  if operation.id is null then
    raise invalid_parameter_value using message = 'attendance bulk operation not found';
  end if;
  if operation.undone_at is not null then
    return app_private.attendance_call_payload(session_row.id);
  end if;
  -- So a ultima operacao da chamada pode ser desfeita: a versao atual da
  -- chamada precisa ser a que a operacao produziu.
  if operation.current_version <> session_row.version then
    raise exception using errcode = '40001',
      message = 'attendance call version conflict';
  end if;
  if session_row.status not in ('open','reopened') then
    raise object_not_in_prerequisite_state using message = 'attendance call is not open';
  end if;

  for item in select value from jsonb_array_elements(operation.affected) loop
    perform app_private.attendance_write_state(actor, session_row,
      (item->>'child_context_id')::uuid, item->>'previous_state', 'Desfazer operação em lote',
      item->>'previous_note', (item->>'previous_source_notice_id')::uuid);
  end loop;

  update app_private.attendance_bulk_operations set undone_at = now() where id = operation.id;
  new_version := app_private.attendance_bump_version(session_row.id);
  perform app_private.attendance_audit(actor, 'attendance.call.undo_bulk', session_row,
    'attendance_session', session_row.id, null,
    jsonb_build_object('operation_id', operation.id, 'command', operation.command,
      'affected', jsonb_array_length(operation.affected), 'version', new_version));
  return app_private.attendance_call_payload(session_row.id);
end $$;

create function app_private.superadmin_attendance_confirm_notice(
  p_notice_id uuid, p_expected_version bigint
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  notice public.attendance_notices%rowtype;
  session_row public.attendance_sessions%rowtype;
  target_state text;
  new_version bigint;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  select * into notice from public.attendance_notices
  where id = p_notice_id and cancelled_at is null for update;
  if notice.id is null or not app_private.can_access_attendance_child(
    notice.institution_id, notice.unit_id, notice.group_id, notice.activity_id,
    notice.child_context_id, true
  ) then
    raise insufficient_privilege using message = 'attendance notice outside scope';
  end if;

  select session_candidate.id into session_row.id
  from public.attendance_sessions session_candidate
  where session_candidate.group_id = notice.group_id
    and session_candidate.activity_id is not distinct from notice.activity_id
    and session_candidate.status <> 'cancelled'
    and session_candidate.session_date between (notice.starts_at at time zone 'UTC')::date
      and coalesce((notice.ends_at at time zone 'UTC')::date, (notice.starts_at at time zone 'UTC')::date)
  order by session_candidate.session_date desc, session_candidate.created_at desc limit 1;
  if session_row.id is null then
    raise object_not_in_prerequisite_state using message = 'no attendance call for this notice';
  end if;
  session_row := app_private.attendance_require_call(session_row.id, p_expected_version, true);

  if notice.review_status = 'pending' then
    update public.attendance_notices set review_status = 'confirmed',
      reviewed_by_person_id = actor, reviewed_at = now(), updated_at = now()
    where id = notice.id;
  end if;

  target_state := case notice.notice_type
    when 'absence' then 'absent'
    when 'late_arrival' then 'late_arrival'
    when 'early_departure' then 'early_departure'
    else 'present' end;
  if exists (
    select 1 from public.attendance_expected_participants expected
    where expected.attendance_session_id = session_row.id
      and expected.child_context_id = notice.child_context_id and expected.status = 'active'
  ) then
    perform app_private.attendance_write_state(actor, session_row, notice.child_context_id,
      target_state, 'Aviso familiar confirmado', null, notice.id);
  end if;
  new_version := app_private.attendance_bump_version(session_row.id);
  perform app_private.attendance_audit(actor, 'attendance.notice.confirm', session_row,
    'attendance_notice', notice.id, null,
    jsonb_build_object('child_context_id', notice.child_context_id,
      'notice_type', notice.notice_type, 'state', target_state, 'version', new_version));
  return app_private.attendance_call_payload(session_row.id);
end $$;

-- ---------------------------------------------------------------------------
-- 5. Dashboard (corpo do historico 20260825171221 adaptado a baseline)
-- ---------------------------------------------------------------------------

create function app_private.attendance_dashboard_ranking_page(
  p_start date,p_end date,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,
  p_activity_id uuid,p_child_id uuid,p_kind text,p_direction text,p_page integer,p_page_size integer
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  result jsonb;
  access_payload jsonb;
  scope_name text;
begin
  if p_kind not in('institutions','units','groups','activities','students','teachers')
     or p_direction not in('highest','lowest') or p_page<1 or p_page_size not between 1 and 100 then
    raise invalid_parameter_value using message='invalid ranking request';
  end if;
  access_payload:=app_private.attendance_dashboard_access();
  scope_name:=access_payload->>'scope';
  if (scope_name='guardian' and p_kind<>'students')
     or (scope_name in('institution','unit','assignments') and p_kind='institutions')
     or (scope_name in('unit','assignments') and p_kind='units') then
    raise insufficient_privilege using message='ranking outside attendance scope';
  end if;

  if p_kind='teachers' then
    with authorized_sessions as materialized (
      select session.*
      from public.attendance_sessions session
      where session.session_date between p_start and p_end
        and session.status<>'cancelled'
        and (p_institution_id is null or session.institution_id=p_institution_id)
        and (p_unit_id is null or session.unit_id=p_unit_id)
        and (p_group_id is null or session.group_id=p_group_id)
        and (p_activity_id is null or session.activity_id=p_activity_id)
        and app_private.can_access_attendance_child(
          session.institution_id,session.unit_id,session.group_id,session.activity_id,null,false)
    ), ranked as (
      select person.id,person.display_name as label,
        count(*)::integer as total_records,
        count(*) filter(where session.status in('closed','corrected'))::integer as completed,
        case when count(*)=0 then null else
          count(*) filter(where session.status in('closed','corrected'))::numeric/count(*)*100 end as percent,
        count(*) over()::integer as total_items
      from authorized_sessions session
      join public.people person on person.id=session.created_by_person_id
      group by person.id,person.display_name
    ), paged as (
      select * from ranked
      order by case when p_direction='highest' then percent end desc nulls last,
               case when p_direction='lowest' then percent end asc nulls last,label,id
      offset (p_page-1)*p_page_size limit p_page_size
    )
    select jsonb_build_object(
      'kind',p_kind,'direction',p_direction,'total',coalesce(max(total_items),0),
      'items',coalesce(jsonb_agg(jsonb_build_object(
        'id',id,'label',label,'official_records',total_records,'percent',percent,
        'auxiliary_label',completed||' de '||total_records||' chamadas concluídas'
      )),'[]'::jsonb)
    ) into result from paged;
    return result;
  end if;

  with authorized_sessions as materialized (
    select session.*
    from public.attendance_sessions session
    where session.session_date between p_start and p_end
      and session.status in('closed','corrected')
      and (p_institution_id is null or session.institution_id=p_institution_id)
      and (p_unit_id is null or session.unit_id=p_unit_id)
      and (p_group_id is null or session.group_id=p_group_id)
      and (p_activity_id is null or session.activity_id=p_activity_id)
      and (
        app_private.can_access_attendance_child(
          session.institution_id,session.unit_id,session.group_id,session.activity_id,p_child_id,false)
        or (p_child_id is null and exists(
          select 1 from public.attendance_expected_participants expected
          where expected.attendance_session_id=session.id and expected.status='active'
            and app_private.can_access_attendance_child(
              session.institution_id,session.unit_id,session.group_id,session.activity_id,
              expected.child_context_id,false)
        ))
      )
  ), source_rows as (
    select
      case p_kind
        when 'institutions' then session.institution_id
        when 'units' then session.unit_id
        when 'groups' then session.group_id
        when 'activities' then session.activity_id
        when 'students' then record.child_context_id
      end as item_id,
      case p_kind
        when 'institutions' then institution.public_name
        when 'units' then unit_record.name
        when 'groups' then group_record.name
        when 'activities' then activity.name
        when 'students' then child_person.display_name
      end as label,
      record.outcome
    from authorized_sessions session
    join public.attendance_records record
      on record.attendance_session_id=session.id and record.status='active'
    join public.institutions institution on institution.id=session.institution_id
    join public.units unit_record on unit_record.id=session.unit_id
    join public.groups group_record on group_record.id=session.group_id
    left join public.activity_definitions activity on activity.id=session.activity_id
    join public.child_contexts child_context on child_context.id=record.child_context_id
    join public.people child_person on child_person.id=child_context.child_person_id
    where (p_child_id is null or record.child_context_id=p_child_id)
      and app_private.can_access_attendance_child(
        session.institution_id,session.unit_id,session.group_id,session.activity_id,
        record.child_context_id,false)
  ), ranked as (
    select item_id,label,count(*)::integer as official_records,
      count(*) filter(where outcome in('present','late_arrival','early_departure','late_and_early'))
        ::numeric/count(*)*100 as percent,
      count(*) over()::integer as total_items
    from source_rows where item_id is not null
    group by item_id,label
  ), paged as (
    select * from ranked
    order by case when p_direction='highest' then percent end desc,
             case when p_direction='lowest' then percent end asc,label,item_id
    offset (p_page-1)*p_page_size limit p_page_size
  )
  select jsonb_build_object(
    'kind',p_kind,'direction',p_direction,'total',coalesce(max(total_items),0),
    'items',coalesce(jsonb_agg(jsonb_build_object(
      'id',item_id,'label',label,'official_records',official_records,'percent',percent
    )),'[]'::jsonb)
  ) into result from paged;
  return result;
end $$;

create function app_private.attendance_dashboard_read(
  p_start date,p_end date,p_granularity text,p_institution_id uuid,p_unit_id uuid,
  p_group_id uuid,p_activity_id uuid,p_child_id uuid,p_search text,p_statuses text[],
  p_responsible_id uuid,p_sort text,p_desc boolean,p_page integer,p_page_size integer,
  p_ranking_direction text
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid:=app_private.current_person_id();
  access_payload jsonb;
  result jsonb;
  previous_start date;
  days integer;
begin
  if actor is null then raise insufficient_privilege using message='authentication required'; end if;
  if p_start is null or p_end is null or p_start>p_end
     or p_end-p_start>366 then raise invalid_parameter_value using message='invalid attendance period'; end if;
  if p_granularity not in('daily','weekly','monthly')
     or p_sort not in('context','date','responsible','presence','status')
     or p_page<1 or p_page_size not between 1 and 100
     or p_ranking_direction not in('highest','lowest')
     or coalesce(length(p_search),0)>120 then
    raise invalid_parameter_value using message='invalid dashboard query';
  end if;
  if p_statuses is not null and exists(
    select 1 from unnest(p_statuses) value where value not in('pending','completed','inReview')
  ) then raise invalid_parameter_value using message='invalid attendance status'; end if;

  access_payload:=app_private.attendance_dashboard_access();
  if access_payload->>'scope'='guardian' and (
    p_institution_id is not null or p_unit_id is not null or p_group_id is not null
    or p_activity_id is not null or p_responsible_id is not null
  ) then
    raise insufficient_privilege using message='filter outside attendance scope';
  end if;
  days:=p_end-p_start+1;
  previous_start:=p_start-days;

  with authorized_sessions as materialized (
    select session.*,institution.public_name as institution_name,unit_record.name as unit_name,
      group_record.name as group_name,activity.name as activity_name,
      responsible.display_name as responsible_name
    from public.attendance_sessions session
    join public.institutions institution on institution.id=session.institution_id
    join public.units unit_record on unit_record.id=session.unit_id
    join public.groups group_record on group_record.id=session.group_id
    left join public.activity_definitions activity on activity.id=session.activity_id
    join public.people responsible on responsible.id=session.created_by_person_id
    where session.session_date between previous_start and p_end and session.status<>'cancelled'
      and (p_institution_id is null or session.institution_id=p_institution_id)
      and (p_unit_id is null or session.unit_id=p_unit_id)
      and (p_group_id is null or session.group_id=p_group_id)
      and (p_activity_id is null or session.activity_id=p_activity_id)
      and (p_responsible_id is null or session.created_by_person_id=p_responsible_id)
      and (
        app_private.can_access_attendance_child(
          session.institution_id,session.unit_id,session.group_id,session.activity_id,p_child_id,false)
        or (p_child_id is null and exists(
          select 1 from public.attendance_expected_participants expected
          where expected.attendance_session_id=session.id and expected.status='active'
            and app_private.can_access_attendance_child(
              session.institution_id,session.unit_id,session.group_id,session.activity_id,
              expected.child_context_id,false)
        ))
      )
  ), official_records as materialized (
    select session.*,record.child_context_id,record.outcome
    from authorized_sessions session
    join public.attendance_records record
      on record.attendance_session_id=session.id and record.status='active'
    where session.status in('closed','corrected')
      and (p_child_id is null or record.child_context_id=p_child_id)
      and app_private.can_access_attendance_child(
        session.institution_id,session.unit_id,session.group_id,session.activity_id,
        record.child_context_id,false)
  ), current_metrics as (
    select count(*)::integer as official_records,
      count(*) filter(where outcome in('present','late_arrival','early_departure','late_and_early'))::integer as numerator,
      count(*) filter(where outcome='absent')::integer as absences
    from official_records where session_date between p_start and p_end
  ), pending as (
    select count(*)::integer as count from authorized_sessions
    where session_date between p_start and p_end and status in('draft','open','reopened')
  ), reviews as (
    select count(*)::integer as count
    from public.attendance_notices notice
    where notice.review_status='pending' and notice.cancelled_at is null
      and (notice.starts_at at time zone 'UTC')::date between p_start and p_end
      and (p_institution_id is null or notice.institution_id=p_institution_id)
      and (p_unit_id is null or notice.unit_id=p_unit_id)
      and (p_group_id is null or notice.group_id=p_group_id)
      and (p_activity_id is null or notice.activity_id=p_activity_id)
      and (p_child_id is null or notice.child_context_id=p_child_id)
      and app_private.can_access_attendance_child(
        notice.institution_id,notice.unit_id,notice.group_id,notice.activity_id,
        notice.child_context_id,false)
  ), calls_base as (
    select session.id,
      concat_ws(' · ',session.institution_name,session.unit_name,session.group_name,session.activity_name) as context,
      session.session_date,session.responsible_name,session.created_by_person_id,
      case when session.status in('closed','corrected') then 'completed' else 'pending' end as dashboard_status,
      count(record.*) filter(where record.status='active')::integer as official_records,
      count(record.*) filter(where record.status='active' and record.outcome in('present','late_arrival','early_departure','late_and_early'))::integer as numerator,
      count(record.*) filter(where record.status='active' and record.outcome='present')::integer as present,
      count(record.*) filter(where record.status='active' and record.outcome='absent')::integer as absent,
      count(record.*) filter(where record.status='active' and record.outcome in('late_arrival','late_and_early'))::integer as late
    from authorized_sessions session
    left join public.attendance_records record
      on record.attendance_session_id=session.id
     and app_private.can_access_attendance_child(
       session.institution_id,session.unit_id,session.group_id,session.activity_id,
       record.child_context_id,false)
    where session.session_date between p_start and p_end
    group by session.id,session.institution_name,session.unit_name,session.group_name,
      session.activity_name,session.session_date,session.responsible_name,
      session.created_by_person_id,session.status
  ), calls_filtered as (
    select *,count(*) over()::integer as total_items from calls_base
    where (coalesce(btrim(p_search),'')='' or context ilike '%'||btrim(p_search)||'%')
      and (p_statuses is null or cardinality(p_statuses)=0 or dashboard_status=any(p_statuses))
  ), calls_page as (
    select * from calls_filtered
    order by
      case when p_sort='date' and p_desc then session_date end desc,
      case when p_sort='date' and not p_desc then session_date end asc,
      case when p_sort='context' and p_desc then context end desc,
      case when p_sort='context' and not p_desc then context end asc,
      case when p_sort='responsible' and p_desc then responsible_name end desc,
      case when p_sort='responsible' and not p_desc then responsible_name end asc,
      case when p_sort='status' and p_desc then dashboard_status end desc,
      case when p_sort='status' and not p_desc then dashboard_status end asc,
      case when p_sort='presence' and p_desc then numerator/nullif(official_records,0)::numeric end desc nulls last,
      case when p_sort='presence' and not p_desc then numerator/nullif(official_records,0)::numeric end asc nulls last,
      session_date desc,id
    offset (p_page-1)*p_page_size limit p_page_size
  ), series_raw as (
    select case p_granularity
        when 'weekly' then date_trunc('week',session_date::timestamp)::date
        when 'monthly' then date_trunc('month',session_date::timestamp)::date
        else session_date end as bucket,
      session_date>=p_start as current_period,count(*)::integer as official_records,
      count(*) filter(where outcome in('present','late_arrival','early_departure','late_and_early'))::integer as numerator,
      count(*) filter(where outcome='absent')::integer as absences,
      count(*) filter(where outcome in('late_arrival','late_and_early'))::integer as late
    from official_records
    group by 1,2
  ), current_series as (
    select *,row_number() over(order by bucket) as ordinal from series_raw where current_period
  ), previous_series as (
    select *,row_number() over(order by bucket) as ordinal from series_raw where not current_period
  ), series as (
    select current_series.bucket,current_series.official_records,current_series.numerator,
      current_series.absences,current_series.late,
      previous_series.official_records as previous_records,
      previous_series.numerator as previous_numerator
    from current_series left join previous_series using(ordinal)
  )
  select jsonb_build_object(
    'access',access_payload,
    'context_label',case when access_payload->>'scope'='guardian' then 'Todas as crianças'
      else coalesce((select public_name from public.institutions where id=p_institution_id),'Todas as instituições') end,
    'kpis',jsonb_build_object(
      'presence',jsonb_build_object('official_records',metrics.official_records,
        'percent',case when metrics.official_records=0 then null else metrics.numerator::numeric/metrics.official_records*100 end),
      'pending_calls',pending.count,'absences',metrics.absences,'in_review',reviews.count
    ),
    'attention',jsonb_build_array(
      jsonb_build_object('id','pending-calls','label','Chamadas pendentes','detail','Aguardando conclusão','count',pending.count),
      jsonb_build_object('id','absences','label','Faltas no período','detail','Registros oficiais','count',metrics.absences),
      jsonb_build_object('id','reviews','label','Em revisão','detail','Avisos familiares pendentes','count',reviews.count)
    ),
    'rankings',case access_payload->>'scope'
      when 'platform' then jsonb_build_array(
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'institutions',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'units',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'groups',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'activities',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'students',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'teachers',p_ranking_direction,1,3))
      when 'institution' then jsonb_build_array(
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'units',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'groups',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'activities',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'students',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'teachers',p_ranking_direction,1,3))
      when 'guardian' then jsonb_build_array(
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'students',p_ranking_direction,1,3))
      else jsonb_build_array(
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'groups',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'activities',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'students',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'teachers',p_ranking_direction,1,3))
    end,
    'series',coalesce((select jsonb_agg(jsonb_build_object(
      'start',bucket,'label',to_char(bucket,'DD/MM'),'official_records',official_records,
      'percent',case when official_records=0 then null else numerator::numeric/official_records*100 end,
      'previous_official_records',previous_records,
      'previous_percent',case when previous_records=0 then null else previous_numerator::numeric/previous_records*100 end,
      'absences',absences,'late',late
    ) order by bucket) from series),'[]'::jsonb),
    'calls',jsonb_build_object(
      'page',p_page,'page_size',p_page_size,'total_items',coalesce((select max(total_items) from calls_page),0),
      'items',coalesce((select jsonb_agg(jsonb_build_object(
        'id',id,
        'context',case when access_payload->>'scope'='guardian' then 'Registro de assiduidade' else context end,
        'date',session_date,
        'responsible',case when access_payload->>'scope'='guardian' then 'Equipe responsável' else responsible_name end,
        'present',present,'absent',absent,'late',late,'official_records',official_records,
        'presence_percent',case when official_records=0 then null else numerator::numeric/official_records*100 end,
        'status',dashboard_status,'can_open',access_payload->>'scope'<>'guardian'
      ) order by session_date desc,id) from calls_page),'[]'::jsonb)
    )
  ) into result
  from current_metrics metrics cross join pending cross join reviews;
  return result;
end $$;

-- Exportacao adiada (ADR 0034): resposta honesta no envelope que o cliente
-- decodifica (_dashboardExportJob), sem job, arquivo, RPC extra ou Edge Function.
create function app_private.attendance_dashboard_request_export(
  p_request_id uuid, p_kind text, p_format text, p_filters jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  access_payload jsonb;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if p_request_id is null or p_kind not in ('overview','table') or p_format not in ('csv','xlsx')
     or p_filters is null or jsonb_typeof(p_filters) <> 'object' then
    raise invalid_parameter_value using message = 'invalid attendance export request';
  end if;
  access_payload := app_private.attendance_dashboard_access();
  if access_payload->>'scope' = 'guardian' then
    raise insufficient_privilege using message = 'attendance.export required';
  end if;
  return jsonb_build_object(
    'id', p_request_id,
    'job_id', p_request_id,
    'state', 'failed',
    'file_name', null,
    'download_url', null,
    'error_code', 'EXPORT_UNAVAILABLE',
    'message', 'Exportação de assiduidade adiada para depois do MVP (ADR 0034).'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 6. Wrappers publicos (assinaturas exatamente como o cliente chama)
-- ---------------------------------------------------------------------------

create function public.superadmin_attendance_directory(p_date date default null)
returns jsonb language sql stable security definer set search_path=''
as $$ select app_private.superadmin_attendance_directory($1) $$;

create function public.superadmin_attendance_call_detail(p_call_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$ select app_private.superadmin_attendance_call_detail($1) $$;

create function public.superadmin_attendance_create_call(
  p_institution_id uuid, p_unit_id uuid, p_group_id uuid, p_activity_id uuid default null,
  p_session_date date default null, p_idempotency_key uuid default null
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_create_call($1,$2,$3,$4,$5,$6) $$;

create function public.superadmin_attendance_set_participant(
  p_idempotency_key uuid, p_call_id uuid, p_participant_id uuid, p_state text, p_expected_version bigint
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_set_participant($1,$2,$3,$4,$5) $$;

create function public.superadmin_attendance_correct_participant(
  p_call_id uuid, p_participant_id uuid, p_state text, p_reason text, p_expected_version bigint
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_correct_participant($1,$2,$3,$4,$5) $$;

create function public.superadmin_attendance_complete_call(
  p_call_id uuid, p_expected_version bigint, p_idempotency_key uuid
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_complete_call($1,$2,$3) $$;

create function public.superadmin_attendance_reopen_call(
  p_call_id uuid, p_expected_version bigint, p_reason text
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_reopen_call($1,$2,$3) $$;

create function public.superadmin_attendance_mark_remaining_present(
  p_call_id uuid, p_expected_version bigint, p_idempotency_key uuid
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_bulk('mark_remaining_present',$1,$2,$3) $$;

create function public.superadmin_attendance_clear_presence_marks(
  p_call_id uuid, p_expected_version bigint, p_idempotency_key uuid
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_bulk('clear_presence_marks',$1,$2,$3) $$;

create function public.superadmin_attendance_undo_bulk(
  p_operation_id uuid, p_call_id uuid, p_expected_version bigint
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_undo_bulk($1,$2,$3) $$;

create function public.superadmin_attendance_confirm_notice(
  p_notice_id uuid, p_expected_version bigint
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.superadmin_attendance_confirm_notice($1,$2) $$;

create function public.attendance_dashboard_read(
  p_start date,p_end date,p_granularity text,p_institution_id uuid default null,
  p_unit_id uuid default null,p_group_id uuid default null,p_activity_id uuid default null,
  p_child_id uuid default null,p_search text default '',p_statuses text[] default null,
  p_responsible_id uuid default null,p_sort text default 'date',p_desc boolean default true,
  p_page integer default 1,p_page_size integer default 20,p_ranking_direction text default 'highest'
) returns jsonb language sql stable security definer set search_path=''
as $$ select app_private.attendance_dashboard_read($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16) $$;

create function public.attendance_dashboard_ranking_page(
  p_start date,p_end date,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,
  p_activity_id uuid,p_child_id uuid,p_kind text,p_direction text,p_page integer,p_page_size integer
) returns jsonb language sql stable security definer set search_path=''
as $$ select app_private.attendance_dashboard_ranking_page($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) $$;

create function public.attendance_dashboard_request_export(
  p_request_id uuid, p_kind text, p_format text, p_filters jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.attendance_dashboard_request_export($1,$2,$3,$4) $$;

-- ---------------------------------------------------------------------------
-- 7. Owner, revoke e grant minimo
-- ---------------------------------------------------------------------------

do $grants$
declare
  private_signature text;
  public_signature text;
begin
  foreach private_signature in array array[
    'app_private.attendance_notice_payload(public.attendance_notices)',
    'app_private.attendance_call_payload(uuid)',
    'app_private.attendance_require_call(uuid,bigint,boolean)',
    'app_private.attendance_replay_receipt(uuid,text,uuid)',
    'app_private.attendance_store_receipt(uuid,text,uuid,uuid,jsonb)',
    'app_private.attendance_bump_version(uuid,text)',
    'app_private.attendance_audit(uuid,text,public.attendance_sessions,text,uuid,text,jsonb)',
    'app_private.attendance_write_state(uuid,public.attendance_sessions,uuid,text,text,text,uuid)',
    'app_private.attendance_session_in_scope(jsonb,public.attendance_sessions)',
    'app_private.superadmin_attendance_directory(date)',
    'app_private.superadmin_attendance_call_detail(uuid)',
    'app_private.superadmin_attendance_create_call(uuid,uuid,uuid,uuid,date,uuid)',
    'app_private.superadmin_attendance_set_participant(uuid,uuid,uuid,text,bigint)',
    'app_private.superadmin_attendance_correct_participant(uuid,uuid,text,text,bigint)',
    'app_private.superadmin_attendance_complete_call(uuid,bigint,uuid)',
    'app_private.superadmin_attendance_reopen_call(uuid,bigint,text)',
    'app_private.superadmin_attendance_bulk(text,uuid,bigint,uuid)',
    'app_private.superadmin_attendance_undo_bulk(uuid,uuid,bigint)',
    'app_private.superadmin_attendance_confirm_notice(uuid,bigint)',
    'app_private.attendance_dashboard_ranking_page(date,date,uuid,uuid,uuid,uuid,uuid,text,text,integer,integer)',
    'app_private.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)',
    'app_private.attendance_dashboard_request_export(uuid,text,text,jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', private_signature);
    execute format('revoke all on function %s from public, anon, authenticated, service_role', private_signature);
  end loop;

  foreach public_signature in array array[
    'public.superadmin_attendance_directory(date)',
    'public.superadmin_attendance_call_detail(uuid)',
    'public.superadmin_attendance_create_call(uuid,uuid,uuid,uuid,date,uuid)',
    'public.superadmin_attendance_set_participant(uuid,uuid,uuid,text,bigint)',
    'public.superadmin_attendance_correct_participant(uuid,uuid,text,text,bigint)',
    'public.superadmin_attendance_complete_call(uuid,bigint,uuid)',
    'public.superadmin_attendance_reopen_call(uuid,bigint,text)',
    'public.superadmin_attendance_mark_remaining_present(uuid,bigint,uuid)',
    'public.superadmin_attendance_clear_presence_marks(uuid,bigint,uuid)',
    'public.superadmin_attendance_undo_bulk(uuid,uuid,bigint)',
    'public.superadmin_attendance_confirm_notice(uuid,bigint)',
    'public.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)',
    'public.attendance_dashboard_ranking_page(date,date,uuid,uuid,uuid,uuid,uuid,text,text,integer,integer)',
    'public.attendance_dashboard_request_export(uuid,text,text,jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', public_signature);
    execute format('revoke all on function %s from public, anon, authenticated, service_role', public_signature);
    execute format('grant execute on function %s to authenticated', public_signature);
  end loop;
end
$grants$;

commit;
