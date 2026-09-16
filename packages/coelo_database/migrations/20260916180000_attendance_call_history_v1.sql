-- 20260916180000_attendance_call_history_v1
--
-- R14 Sessao 10 / ADR 0041 B2 (owner.r12-04): leitor do Historico de chamadas
-- (Acompanhamento > Assiduidade > Historico). Spec 052.
--
-- Cria o par app_private/public `superadmin_attendance_call_history_v1`:
--   * escopo do ator identico ao painel/diretorio: attendance_dashboard_access()
--     (guardian e sem leitura -> 42501) + attendance_session_in_scope() por linha;
--   * filtros por instituicao/unidade/turma/atividade (intersecao com o escopo,
--     nunca ampliacao), periodo (padrao 30 dias, maximo 366) e situacao
--     ('pending' = draft/open/reopened; 'completed' = closed/corrected);
--   * paginacao por cursor keyset (session_date desc, created_at desc, id desc),
--     cursor opaco em base64, page_size 1..100 (padrao 20);
--   * itens somente com agregados (presentes/ausentes/atrasos/esperados); nenhum
--     dado de crianca; `routine` nasce null e passa a ser preenchido pela
--     migration do snapshot de rotina (B3);
--   * entrada invalida -> 22023; sem sessao -> 42501.
-- Forward-only e idempotente (create or replace + grants repetiveis). Sem
-- alteracao de tabelas, policies ou funcoes existentes.
-- Reversao (manual): drop das duas funcoes.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'attendance call history migration requires postgres';
  end if;
  if to_regprocedure('app_private.current_person_id()') is null
    or to_regprocedure('app_private.attendance_dashboard_access()') is null
    or to_regprocedure('app_private.attendance_session_in_scope(jsonb,public.attendance_sessions)') is null
    or to_regclass('public.attendance_sessions') is null
    or to_regclass('public.attendance_expected_participants') is null
    or to_regclass('public.attendance_records') is null then
    raise object_not_in_prerequisite_state using message = 'attendance contract v1 is required';
  end if;
end
$preflight$;

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
        'routine', null
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

create or replace function public.superadmin_attendance_call_history_v1(
  p_institution_id uuid default null,
  p_unit_id uuid default null,
  p_group_id uuid default null,
  p_activity_id uuid default null,
  p_start date default null,
  p_end date default null,
  p_status text default null,
  p_cursor text default null,
  p_page_size integer default 20
) returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select app_private.superadmin_attendance_call_history_v1(
    p_institution_id, p_unit_id, p_group_id, p_activity_id,
    p_start, p_end, p_status, p_cursor, p_page_size);
$$;

alter function app_private.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer) owner to postgres;
revoke all on function app_private.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)
  from public, anon, authenticated, service_role;
alter function public.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer) owner to postgres;
revoke all on function public.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)
  to authenticated;

do $postcheck$
begin
  if to_regprocedure('public.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)') is null then
    raise object_not_in_prerequisite_state using message = 'attendance call history v1 was not created';
  end if;
end
$postcheck$;

commit;
