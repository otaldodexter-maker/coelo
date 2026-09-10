-- Assiduidade: fecha a escalada de privilegio da fundacao e passa a chave de
-- idempotencia para o servidor.
--
-- Parte 1, autorizacao (OQ-040). A fundacao 20260724152731 deixou tres
-- aberturas que este pacote fecha, todas confirmadas por leitura das
-- definicoes:
--
--   1. app_private.can_access_attendance_child comeca por
--      has_platform_permission('platform.read') antes de olhar para o
--      parametro require_manage. Quem tem apenas leitura de plataforma
--      satisfaz o ramo de gestao e alcanca confirmacao e reversao de registro
--      oficial de presenca.
--   2. A policy attendance_sessions_context e FOR ALL com um USING de nivel de
--      leitura. USING e o que decide quais linhas um DELETE pode alcancar, e
--      DELETE nao tem WITH CHECK; portanto um ator somente-leitura apaga
--      sessoes de chamada.
--   3. attendance_expected_participants_context tem o mesmo formato e o mesmo
--      efeito sobre os participantes esperados.
--
-- Nenhuma dessas correcoes muda contrato de tela ou exige decisao nova: elas
-- restauram o que a propria fundacao ja dizia querer, separando ler de gerir.
--
-- Parte 2, chave de idempotencia (D11, OQ-040). Hoje o cliente Flutter gera a
-- chave em quatro sitios de escrita. Em tres deles a chave nasce de
-- Random.secure() a cada tentativa, entao repetir a mesma intencao produz uma
-- chave nova e o servidor nao tem como reconhecer a repeticao; a protecao de
-- idempotencia existe no formato e nao no efeito. A decisao do Owner de
-- 2026-09-10 (D11) e que o banco gere e devolva a chave. Esta migration cria a
-- reserva: o cliente pede uma chave para uma intencao descrita por ator,
-- comando, agregado e versao esperada, e recebe sempre a mesma chave enquanto
-- aquela intencao continuar valendo.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.attendance.authorization-idempotency', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='attendance hardening must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.attendance_sessions') is null
    or pg_catalog.to_regprocedure(
      'app_private.can_access_attendance_child(uuid,uuid,uuid,uuid,uuid,boolean)') is null then
    raise exception using errcode='55000',
      message='attendance hardening requires the assiduity foundation';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Parte 1: separar ler de gerir
-- ---------------------------------------------------------------------------

create or replace function app_private.can_access_attendance_child(
  target_institution_id uuid, target_unit_id uuid, target_group_id uuid,
  target_activity_id uuid, target_child_context_id uuid, require_manage boolean
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select
    -- Leitura de plataforma nunca alcanca o ramo de gestao. Gerir exige a
    -- capacidade de gestao, de plataforma ou contextual.
    (
      case when require_manage
        then app_private.has_platform_permission('attendance.manage')
        else app_private.has_platform_permission('platform.read')
          or app_private.has_platform_permission('attendance.manage')
      end
    )
    or app_private.has_context_permission(
      target_institution_id,
      case when require_manage then 'attendance.manage' else 'attendance.read' end,
      target_unit_id, target_group_id, target_activity_id, target_child_context_id, false
    )
    or (
      not require_manage
      and target_child_context_id is not null
      and app_private.guardian_has_capability(
        target_child_context_id, 'manage_attendance_notices'
      )
    )
    or (
      not require_manage
      and target_activity_id is not null
      and app_private.has_activity_capability(
        target_activity_id, target_group_id, 'attendance'
      )
    )
$$;

-- Uma policy FOR ALL com USING de leitura entrega DELETE a quem so pode ler,
-- porque DELETE decide por USING e nao tem WITH CHECK. Separar leitura de
-- escrita e a unica forma de a negativa valer para as quatro operacoes.
drop policy if exists attendance_sessions_context on public.attendance_sessions;
create policy attendance_sessions_read on public.attendance_sessions
for select to authenticated using (
  app_private.can_access_attendance_child(
    institution_id, unit_id, group_id, activity_id, null, false
  )
);
create policy attendance_sessions_write on public.attendance_sessions
for insert to authenticated with check (
  app_private.can_access_attendance_child(
    institution_id, unit_id, group_id, activity_id, null, true
  )
);
create policy attendance_sessions_update on public.attendance_sessions
for update to authenticated
using (
  app_private.can_access_attendance_child(
    institution_id, unit_id, group_id, activity_id, null, true
  )
)
with check (
  app_private.can_access_attendance_child(
    institution_id, unit_id, group_id, activity_id, null, true
  )
);
create policy attendance_sessions_delete on public.attendance_sessions
for delete to authenticated using (
  app_private.can_access_attendance_child(
    institution_id, unit_id, group_id, activity_id, null, true
  )
);

drop policy if exists attendance_expected_participants_context
  on public.attendance_expected_participants;
create policy attendance_expected_participants_read
on public.attendance_expected_participants
for select to authenticated using (
  exists (
    select 1 from public.attendance_sessions session_row
    where session_row.id = attendance_session_id
      and app_private.can_access_attendance_child(
        session_row.institution_id, session_row.unit_id, session_row.group_id,
        session_row.activity_id, child_context_id, false
      )
  )
);
create policy attendance_expected_participants_write
on public.attendance_expected_participants
for insert to authenticated with check (
  exists (
    select 1 from public.attendance_sessions session_row
    where session_row.id = attendance_session_id
      and app_private.can_access_attendance_child(
        session_row.institution_id, session_row.unit_id, session_row.group_id,
        session_row.activity_id, child_context_id, true
      )
  )
);
create policy attendance_expected_participants_update
on public.attendance_expected_participants
for update to authenticated
using (
  exists (
    select 1 from public.attendance_sessions session_row
    where session_row.id = attendance_session_id
      and app_private.can_access_attendance_child(
        session_row.institution_id, session_row.unit_id, session_row.group_id,
        session_row.activity_id, child_context_id, true
      )
  )
)
with check (
  exists (
    select 1 from public.attendance_sessions session_row
    where session_row.id = attendance_session_id
      and app_private.can_access_attendance_child(
        session_row.institution_id, session_row.unit_id, session_row.group_id,
        session_row.activity_id, child_context_id, true
      )
  )
);
create policy attendance_expected_participants_delete
on public.attendance_expected_participants
for delete to authenticated using (
  exists (
    select 1 from public.attendance_sessions session_row
    where session_row.id = attendance_session_id
      and app_private.can_access_attendance_child(
        session_row.institution_id, session_row.unit_id, session_row.group_id,
        session_row.activity_id, child_context_id, true
      )
  )
);

-- A OQ-040 tambem registra que o remoto mantem RLS sem FORCE nestas tabelas.
-- Sem FORCE, o dono da tabela ignora a policy.
do $force$
declare current_table text;
begin
  foreach current_table in array array[
    'attendance_reason_catalog','attendance_sessions',
    'attendance_expected_participants','attendance_notices',
    'attendance_notice_attachments','attendance_records',
    'attendance_record_revisions'
  ] loop
    execute format('alter table public.%I enable row level security', current_table);
    execute format('alter table public.%I force row level security', current_table);
  end loop;
end
$force$;

-- ---------------------------------------------------------------------------
-- Parte 2: chave de idempotencia gerada pelo banco (D11)
-- ---------------------------------------------------------------------------

create table app_private.attendance_idempotency_reservations (
  id uuid primary key default gen_random_uuid(),
  actor_person_id uuid not null references public.people(id) on delete cascade,
  command text not null check (
    command in (
      'create_call','set_participant','mark_remaining_present',
      'clear_presence_marks','complete_call','reopen_call','undo_bulk'
    )
  ),
  aggregate_id uuid,
  intent_digest text not null check (btrim(intent_digest) <> ''),
  idempotency_key uuid not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (actor_person_id, command, intent_digest)
);
create index attendance_idempotency_reservations_key_idx
  on app_private.attendance_idempotency_reservations(idempotency_key);
create index attendance_idempotency_reservations_stale_idx
  on app_private.attendance_idempotency_reservations(created_at)
  where consumed_at is null;

alter table app_private.attendance_idempotency_reservations
  enable row level security;
alter table app_private.attendance_idempotency_reservations
  force row level security;
revoke all on app_private.attendance_idempotency_reservations
  from public, anon, authenticated;
grant all on app_private.attendance_idempotency_reservations to service_role;

-- A intencao e descrita pelo servidor a partir do que o cliente pediu, nunca
-- pelo cliente diretamente: se o cliente escolhesse o digest, ele voltaria a
-- poder trocar a chave a cada tentativa e a reserva nao valeria nada.
create or replace function app_private.attendance_reserve_idempotency_key(
  p_command text,
  p_aggregate_id uuid,
  p_expected_version bigint
) returns uuid
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  digest text;
  reserved uuid;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  if p_command not in (
    'create_call','set_participant','mark_remaining_present',
    'clear_presence_marks','complete_call','reopen_call','undo_bulk'
  ) then
    raise invalid_parameter_value using message='invalid attendance command';
  end if;
  if p_command <> 'create_call' and p_aggregate_id is null then
    raise invalid_parameter_value using message='attendance aggregate required';
  end if;

  -- Versao esperada faz parte da intencao: depois que a chamada avanca, a
  -- intencao antiga deixou de existir e a proxima reserva recebe outra chave.
  digest := p_command || ':' || coalesce(p_aggregate_id::text, '') || ':'
    || coalesce(p_expected_version::text, '');

  insert into app_private.attendance_idempotency_reservations(
    actor_person_id, command, aggregate_id, intent_digest, idempotency_key
  ) values (
    actor, p_command, p_aggregate_id, digest, gen_random_uuid()
  )
  on conflict (actor_person_id, command, intent_digest) do update
    set aggregate_id = excluded.aggregate_id
  returning idempotency_key into reserved;

  return reserved;
end
$$;

create or replace function public.attendance_reserve_idempotency_key(
  command text,
  aggregate_id uuid default null,
  expected_version bigint default null
) returns uuid language sql volatile security invoker set search_path='' as $$
  select app_private.attendance_reserve_idempotency_key(
    command, aggregate_id, expected_version)
$$;

revoke all on function
  app_private.attendance_reserve_idempotency_key(text,uuid,bigint)
  from public, anon, authenticated;
revoke all on function
  public.attendance_reserve_idempotency_key(text,uuid,bigint)
  from public, anon, authenticated;
grant execute on function
  public.attendance_reserve_idempotency_key(text,uuid,bigint)
  to authenticated, service_role;

commit;
