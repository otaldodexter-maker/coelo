-- SUPPORT-CREATE-INTERNAL-SCOPE-V1 (grupo operacoes, R04)
-- Corrige dois defeitos do lote 7 (20260910230019) em superadmin_support_create:
-- 1. o cliente envia p_institution_id nulo (chamado interno pelo botao de Bug) e
--    a coluna ja aceita nulo, mas a validacao rejeitava com invalid_support_request;
-- 2. support_sessions.reason_code e NOT NULL sem default na baseline e o insert
--    nao o preenchia, entao nenhum chamado podia ser criado.
-- A resolucao do ator (current_person_id/has_platform_permission) nao muda aqui:
-- a ponte entre o realm interno e o realm people e pacote do coordenador.
begin;

create or replace function public.superadmin_support_create(
  p_request_id uuid, p_institution_id uuid, p_unit_id uuid, p_subject text,
  p_menu text, p_screen text, p_reported_issue text, p_requester_label text,
  p_priority text default 'normal'
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare actor_id uuid; session_id uuid; result jsonb;
begin
  actor_id := app_private.assert_support_permission();
  if p_request_id is null or char_length(trim(coalesce(p_subject,''))) not between 1 and 160
    or char_length(trim(coalesce(p_menu,''))) not between 1 and 80
    or char_length(trim(coalesce(p_screen,''))) not between 1 and 120
    or char_length(trim(coalesce(p_requester_label,''))) not between 1 and 160
    or char_length(trim(coalesce(p_reported_issue,''))) not between 1 and 10000
    or p_priority not in ('low','normal','high','urgent')
    or (p_unit_id is not null and p_institution_id is null) then
    raise exception using errcode = '22023', message = 'invalid_support_request';
  end if;
  select support_session_id into session_id from public.support_command_receipts where request_id = p_request_id;
  if session_id is not null then return public.superadmin_support_get(session_id); end if;
  insert into public.support_sessions(
    opened_by_person_id, institution_id, unit_id, subject, menu_code, screen_code,
    requester_label, reported_issue, priority, ticket_status, updated_at,
    scope_kind, reason_code
  ) values (
    actor_id, p_institution_id, p_unit_id, trim(p_subject), trim(p_menu), trim(p_screen),
    trim(p_requester_label), trim(p_reported_issue), p_priority, 'new', now(),
    case when p_institution_id is null then 'platform' else 'institution' end,
    'internal_report'
  ) returning id into session_id;
  insert into audit.support_session_actions(support_session_id, action_code, object_type, object_id, metadata_json)
    values (session_id, 'support.create', 'support_session', session_id, jsonb_build_object('actor_person_id', actor_id));
  result := public.superadmin_support_get(session_id);
  insert into public.support_command_receipts(request_id, support_session_id, actor_person_id, action_code, response_json)
    values (p_request_id, session_id, actor_id, 'create', result);
  return result;
end;
$$;

revoke all on function public.superadmin_support_create(uuid,uuid,uuid,text,text,text,text,text,text) from public, anon;
grant execute on function public.superadmin_support_create(uuid,uuid,uuid,text,text,text,text,text,text) to authenticated;

commit;
