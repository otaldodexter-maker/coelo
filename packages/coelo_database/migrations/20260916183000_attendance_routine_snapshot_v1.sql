-- 20260916183000_attendance_routine_snapshot_v1
--
-- R14 Sessao 10 / ADR 0041 B3 (owner.r12-06): snapshot da rotina na chamada
-- (hibrido). Spec 052 secao 4.2.
--
--   * attendance_sessions ganha routine_snapshot_application_id (FK routine_applications,
--     on delete set null), routine_snapshot_revision_no, routine_snapshot_name e
--     routine_snapshot_at (todas nulas para o legado);
--   * app_private.attendance_effective_routine(...): rotina aplicada `active` mais
--     especifica (atividade > turma > unidade > instituicao) que cobre o contexto na
--     data, com a ultima revisao e o nome do modelo de origem;
--   * superadmin_attendance_complete_call grava o snapshot SO na primeira conclusao
--     (routine_snapshot_at nulo), inclusive quando nao ha rotina vigente (snapshot
--     "sem rotina", distinto do legado); concluir apos reabrir nao toca o snapshot;
--   * attendance_call_payload (detalhe e todos os comandos) expoe routine_snapshot,
--     routine_current e routine_source (snapshot | current | none);
--   * superadmin_attendance_call_history_v1 passa a projetar `routine` com a mesma regra;
--   * OQ-047 (lote da familia Assiduidade): versao defasada passa a sinalizar SQLSTATE
--     PT409 (HTTP 409, sem retentativa pelo PostgREST 14.5) em attendance_require_call
--     e superadmin_attendance_undo_bulk, no lugar de 40001.
-- Corpos restantes identicos ao dump de producao de 16/09 (SHA-256 f1f677ca) e a
-- migration 20260916180000. Forward-only, idempotente (add column if not exists +
-- create or replace). Reversao (manual): drop das quatro colunas e da funcao
-- attendance_effective_routine; corpos anteriores no dump.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'attendance routine snapshot migration requires postgres';
  end if;
  if to_regprocedure('app_private.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)') is null
    or to_regprocedure('app_private.attendance_call_payload(uuid)') is null
    or to_regprocedure('app_private.superadmin_attendance_complete_call(uuid,bigint,uuid)') is null
    or to_regprocedure('app_private.attendance_require_call(uuid,bigint,boolean)') is null
    or to_regprocedure('app_private.superadmin_attendance_undo_bulk(uuid,uuid,bigint)') is null
    or to_regclass('public.routine_applications') is null
    or to_regclass('public.routine_application_revisions') is null
    or to_regclass('public.routine_model_versions') is null
    or to_regclass('public.routine_models') is null then
    raise object_not_in_prerequisite_state using message = 'attendance call history v1 and routine foundation are required';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- 1. Esquema
-- ---------------------------------------------------------------------------
alter table public.attendance_sessions
  add column if not exists routine_snapshot_application_id uuid
    references public.routine_applications(id) on delete set null,
  add column if not exists routine_snapshot_revision_no integer,
  add column if not exists routine_snapshot_name text,
  add column if not exists routine_snapshot_at timestamptz;

alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_routine_snapshot_check;
alter table public.attendance_sessions
  add constraint attendance_sessions_routine_snapshot_check check (
    routine_snapshot_at is not null
    or (routine_snapshot_application_id is null and routine_snapshot_revision_no is null
        and routine_snapshot_name is null)
  );

-- ---------------------------------------------------------------------------
-- 2. Rotina vigente para um contexto numa data
-- ---------------------------------------------------------------------------
create or replace function app_private.attendance_effective_routine(
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_activity_id uuid,
  p_date date
) returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'application_id', application_row.id,
    'revision_no', coalesce((
      select max(revision.revision_no) from public.routine_application_revisions revision
      where revision.application_id = application_row.id), 0),
    'name', coalesce(model_row.name, case application_row.scope_kind
      when 'activity' then 'Rotina da atividade'
      when 'group' then 'Rotina da turma'
      when 'unit' then 'Rotina da unidade'
      else 'Rotina da instituição' end),
    'scope_kind', application_row.scope_kind)
  from public.routine_applications application_row
  left join public.routine_model_versions version_row
    on version_row.id = application_row.source_model_version_id
  left join public.routine_models model_row on model_row.id = version_row.model_id
  where application_row.institution_id = p_institution_id
    and application_row.status = 'active'
    and (application_row.valid_from is null or application_row.valid_from <= coalesce(p_date, current_date))
    and (application_row.valid_until is null or application_row.valid_until >= coalesce(p_date, current_date))
    and (
      application_row.scope_kind = 'institution'
      or (application_row.scope_kind = 'unit' and application_row.unit_id = p_unit_id)
      or (application_row.scope_kind = 'group' and application_row.group_id = p_group_id)
      or (application_row.scope_kind = 'activity' and application_row.group_id = p_group_id
          and p_activity_id is not null and application_row.activity_id = p_activity_id)
    )
  order by case application_row.scope_kind
      when 'activity' then 4 when 'group' then 3 when 'unit' then 2 else 1 end desc,
    application_row.updated_at desc, application_row.id
  limit 1
$$;

alter function app_private.attendance_effective_routine(uuid,uuid,uuid,uuid,date) owner to postgres;
revoke all on function app_private.attendance_effective_routine(uuid,uuid,uuid,uuid,date)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. attendance_call_payload: corpo de producao + chaves de rotina
-- ---------------------------------------------------------------------------
create or replace function app_private.attendance_call_payload(p_session_id uuid) returns jsonb
language plpgsql stable security definer
set search_path = ''
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
    ), '[]'::jsonb),
    -- ADR 0041 B3 (spec 052 §4.2): snapshot gravado na conclusao x rotina vigente.
    'routine_snapshot', case when session_row.routine_snapshot_at is null then null
      else jsonb_build_object(
        'application_id', session_row.routine_snapshot_application_id,
        'revision_no', session_row.routine_snapshot_revision_no,
        'name', session_row.routine_snapshot_name,
        'recorded_at', session_row.routine_snapshot_at) end,
    'routine_current', app_private.attendance_effective_routine(
      session_row.institution_id, session_row.unit_id, session_row.group_id,
      session_row.activity_id, session_row.session_date),
    'routine_source', case
      when session_row.routine_snapshot_at is not null and session_row.routine_snapshot_application_id is not null then 'snapshot'
      when session_row.routine_snapshot_at is not null then 'none'
      when app_private.attendance_effective_routine(
        session_row.institution_id, session_row.unit_id, session_row.group_id,
        session_row.activity_id, session_row.session_date) is null then 'none'
      else 'current' end
  ) into result
  from public.institutions institution
  join public.units unit_row on unit_row.id = session_row.unit_id
  join public.groups group_row on group_row.id = session_row.group_id
  left join public.activity_definitions activity on activity.id = session_row.activity_id
  left join public.people responsible on responsible.id = session_row.created_by_person_id
  where institution.id = session_row.institution_id;

  return result;
end
$$;

-- ---------------------------------------------------------------------------
-- 4. Versao defasada -> PT409 (OQ-047, lote da familia Assiduidade)
-- ---------------------------------------------------------------------------
create or replace function app_private.attendance_require_call(p_call_id uuid, p_expected_version bigint, p_require_manage boolean)
returns public.attendance_sessions
language plpgsql security definer
set search_path = ''
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
    -- PT409: conflito de versao sem retentativa pelo PostgREST (OQ-047).
    raise exception using errcode = 'PT409',
      message = 'attendance call version conflict';
  end if;
  return session_row;
end $$;

create or replace function app_private.superadmin_attendance_undo_bulk(p_operation_id uuid, p_call_id uuid, p_expected_version bigint) returns jsonb
language plpgsql security definer
set search_path = ''
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
    raise exception using errcode = 'PT409',
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

-- ---------------------------------------------------------------------------
-- 5. Concluir grava o snapshot na primeira conclusao
-- ---------------------------------------------------------------------------
create or replace function app_private.superadmin_attendance_complete_call(p_call_id uuid, p_expected_version bigint, p_idempotency_key uuid) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  session_row public.attendance_sessions%rowtype;
  receipt jsonb;
  response jsonb;
  new_version bigint;
  effective jsonb;
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
  -- ADR 0041 B3: o snapshot nasce na primeira conclusao e nunca e reescrito
  -- (reabrir para corrigir presenca e concluir de novo preserva o registro).
  if session_row.routine_snapshot_at is null then
    effective := app_private.attendance_effective_routine(
      session_row.institution_id, session_row.unit_id, session_row.group_id,
      session_row.activity_id, session_row.session_date);
    update public.attendance_sessions
       set routine_snapshot_application_id = (effective->>'application_id')::uuid,
           routine_snapshot_revision_no = (effective->>'revision_no')::integer,
           routine_snapshot_name = effective->>'name',
           routine_snapshot_at = now()
     where id = session_row.id;
  end if;
  update public.attendance_sessions
     set closed_by_person_id = actor, closed_at = now()
   where id = session_row.id;
  new_version := app_private.attendance_bump_version(session_row.id, 'closed');
  response := app_private.attendance_call_payload(session_row.id);
  perform app_private.attendance_store_receipt(actor, 'complete_call', p_idempotency_key, session_row.id, response);
  perform app_private.attendance_audit(actor, 'attendance.call.complete', session_row,
    'attendance_session', session_row.id, null,
    -- A allowlist de audit_mask_payload so preserva ids/versoes conhecidos:
    -- scope_id = rotina aplicada do snapshot; management_version = revisao.
    jsonb_build_object('version', new_version,
      'scope_id', response->'routine_snapshot'->>'application_id',
      'management_version', (response->'routine_snapshot'->>'revision_no')::integer));
  return response;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Historico projeta a rotina (snapshot ou vigente)
-- ---------------------------------------------------------------------------
create or replace function app_private.superadmin_attendance_call_history_v1(
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_activity_id uuid,
  p_start date,
  p_end date,
  p_status text,
  p_cursor text,
  p_page_size integer
) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  access_payload jsonb;
  period_start date := coalesce(p_start, current_date - 30);
  period_end date := coalesce(p_end, current_date);
  page_size integer := coalesce(p_page_size, 20);
  status_filter text := nullif(btrim(coalesce(p_status, '')), '');
  cursor_text text;
  cursor_date date;
  cursor_created timestamptz;
  cursor_id uuid;
  result jsonb;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if period_start > period_end or period_end - period_start > 366 then
    raise invalid_parameter_value using message = 'invalid attendance period';
  end if;
  if page_size < 1 or page_size > 100 then
    raise invalid_parameter_value using message = 'invalid page size';
  end if;
  if status_filter is not null and status_filter not in ('pending', 'completed') then
    raise invalid_parameter_value using message = 'invalid attendance status';
  end if;
  if nullif(btrim(coalesce(p_cursor, '')), '') is not null then
    begin
      cursor_text := convert_from(decode(btrim(p_cursor), 'base64'), 'utf8');
      cursor_date := split_part(cursor_text, '|', 1)::date;
      cursor_created := split_part(cursor_text, '|', 2)::timestamptz;
      cursor_id := split_part(cursor_text, '|', 3)::uuid;
    exception when others then
      raise invalid_parameter_value using message = 'invalid attendance history cursor';
    end;
    if cursor_date is null or cursor_created is null or cursor_id is null then
      raise invalid_parameter_value using message = 'invalid attendance history cursor';
    end if;
  end if;

  access_payload := app_private.attendance_dashboard_access();
  if access_payload->>'scope' = 'guardian'
     or coalesce((access_payload->>'can_read')::boolean, false) is not true then
    raise insufficient_privilege using message = 'attendance.read required';
  end if;

  with visible_sessions as materialized (
    select session_row.*
    from public.attendance_sessions session_row
    where session_row.session_date between period_start and period_end
      and session_row.status <> 'cancelled'
      and (p_institution_id is null or session_row.institution_id = p_institution_id)
      and (p_unit_id is null or session_row.unit_id = p_unit_id)
      and (p_group_id is null or session_row.group_id = p_group_id)
      and (p_activity_id is null or session_row.activity_id = p_activity_id)
      and (status_filter is null
        or (status_filter = 'pending' and session_row.status in ('draft', 'open', 'reopened'))
        or (status_filter = 'completed' and session_row.status in ('closed', 'corrected')))
      and (cursor_id is null
        or (session_row.session_date, session_row.created_at, session_row.id)
           < (cursor_date, cursor_created, cursor_id))
      and app_private.attendance_session_in_scope(access_payload, session_row)
    order by session_row.session_date desc, session_row.created_at desc, session_row.id desc
    limit page_size + 1
  ), page_rows as (
    select session_row.*, row_number() over (
      order by session_row.session_date desc, session_row.created_at desc, session_row.id desc
    ) as row_index
    from visible_sessions session_row
  ), counted as (
    select page_rows.*,
      (select count(*) from public.attendance_expected_participants expected
        where expected.attendance_session_id = page_rows.id and expected.status = 'active')::integer as expected,
      (select count(*) from public.attendance_records record_row
        where record_row.attendance_session_id = page_rows.id and record_row.status = 'active')::integer as official_records,
      (select count(*) from public.attendance_records record_row
        where record_row.attendance_session_id = page_rows.id and record_row.status = 'active'
          and record_row.outcome in ('present', 'late_arrival', 'early_departure', 'late_and_early'))::integer as present,
      (select count(*) from public.attendance_records record_row
        where record_row.attendance_session_id = page_rows.id and record_row.status = 'active'
          and record_row.outcome = 'absent')::integer as absent,
      (select count(*) from public.attendance_records record_row
        where record_row.attendance_session_id = page_rows.id and record_row.status = 'active'
          and record_row.outcome in ('late_arrival', 'late_and_early'))::integer as late,
      (select count(*) from public.attendance_records record_row
        where record_row.attendance_session_id = page_rows.id and record_row.status = 'active'
          and record_row.outcome in ('early_departure', 'late_and_early'))::integer as early_departures
    from page_rows
    where page_rows.row_index <= page_size
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', counted.id,
        'session_date', counted.session_date,
        'institution_id', counted.institution_id,
        'institution_name', coalesce(institution.public_name, ''),
        'unit_id', counted.unit_id,
        'unit_name', coalesce(unit_row.name, ''),
        'group_id', counted.group_id,
        'group_name', coalesce(group_row.name, ''),
        'activity_id', counted.activity_id,
        'activity_name', activity.name,
        'context', concat_ws(' · ', institution.public_name, unit_row.name, group_row.name, activity.name),
        'responsible', coalesce(responsible.display_name, ''),
        'status', counted.status,
        'expected', counted.expected,
        'official_records', counted.official_records,
        'present', counted.present,
        'absent', counted.absent,
        'late', counted.late,
        'early_departures', counted.early_departures,
        'created_at', counted.created_at,
        'updated_at', counted.updated_at,
        'version', counted.version,
        'can_open', true,
        -- ADR 0041 B3 (spec 052 4.2): snapshot da conclusao; senao rotina vigente.
        'routine', case
          when counted.routine_snapshot_at is not null and counted.routine_snapshot_application_id is not null then
            jsonb_build_object('source', 'snapshot',
              'application_id', counted.routine_snapshot_application_id,
              'revision_no', counted.routine_snapshot_revision_no,
              'name', counted.routine_snapshot_name,
              'recorded_at', counted.routine_snapshot_at)
          when counted.routine_snapshot_at is not null then jsonb_build_object('source', 'none')
          else coalesce(
            app_private.attendance_effective_routine(counted.institution_id, counted.unit_id,
              counted.group_id, counted.activity_id, counted.session_date) || jsonb_build_object('source', 'current'),
            jsonb_build_object('source', 'none'))
        end
      ) order by counted.row_index)
      from counted
      join public.institutions institution on institution.id = counted.institution_id
      join public.units unit_row on unit_row.id = counted.unit_id
      join public.groups group_row on group_row.id = counted.group_id
      left join public.activity_definitions activity on activity.id = counted.activity_id
      left join public.people responsible on responsible.id = counted.created_by_person_id
    ), '[]'::jsonb),
    'has_more', exists (select 1 from page_rows where page_rows.row_index > page_size),
    'next_cursor', case when exists (select 1 from page_rows where page_rows.row_index > page_size)
      then (select translate(encode(convert_to(
              counted.session_date::text || '|' || counted.created_at::text || '|' || counted.id::text,
              'utf8'), 'base64'), E'\n', '')
            from counted where counted.row_index = page_size)
      else null end,
    'page_size', page_size,
    'period_start', period_start,
    'period_end', period_end,
    'scope', access_payload->>'scope'
  ) into result;

  return result;
end $$;

do $postcheck$
begin
  if to_regprocedure('app_private.attendance_effective_routine(uuid,uuid,uuid,uuid,date)') is null
    or not exists (select 1 from pg_attribute where attrelid = 'public.attendance_sessions'::regclass
      and attname = 'routine_snapshot_at' and not attisdropped) then
    raise object_not_in_prerequisite_state using message = 'attendance routine snapshot v1 was not applied';
  end if;
end
$postcheck$;

commit;
