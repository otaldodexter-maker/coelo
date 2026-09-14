-- R13 / ADR 0038 OQ-028 (mapeamento A): Novo=open, Em andamento=pending,
-- Aguardando solicitante=pending (o proprio ticket_status e a flag), Concluido=resolved/closed;
-- expired/revoked aparecem como Concluido com motivo (`closure_reason`). Enum preservado.
-- O gatilho mantem ticket_status coerente quando o enum muda por outro caminho
-- (expiracao, revogacao, fechamento).
create or replace function app_private.support_session_ticket_status_sync_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status in ('resolved','closed','expired','revoked') then
    new.ticket_status := 'completed';
  elsif new.status = 'pending' and new.ticket_status in ('new','completed') then
    new.ticket_status := 'in_progress';
  elsif new.status = 'open' and new.ticket_status = 'completed' then
    new.ticket_status := 'new';
  end if;
  return new;
end $$;
revoke all on function app_private.support_session_ticket_status_sync_v1() from public, anon, authenticated, service_role;
drop trigger if exists support_session_ticket_status_sync on public.support_sessions;
create trigger support_session_ticket_status_sync
  before insert or update of status, ticket_status on public.support_sessions
  for each row execute function app_private.support_session_ticket_status_sync_v1();

-- Reconciliacao dos registros existentes (idempotente).
update public.support_sessions set ticket_status = 'completed'
  where status in ('resolved','closed','expired','revoked') and ticket_status <> 'completed';
update public.support_sessions set status = 'pending'
  where status = 'open' and ticket_status in ('in_progress','waiting_requester');

create or replace function public.superadmin_support_set_status(
  p_request_id uuid, p_session_id uuid, p_status text, p_expected_revision bigint
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare actor_id uuid; result jsonb;
begin
  actor_id := app_private.assert_support_permission();
  if p_status not in ('new','in_progress','waiting_requester','completed') then
    raise exception using errcode = '22023', message = 'invalid_support_status';
  end if;
  if exists(select 1 from public.support_command_receipts where request_id = p_request_id) then
    select response_json into result from public.support_command_receipts where request_id = p_request_id; return result;
  end if;
  update public.support_sessions set ticket_status = p_status, revision = revision + 1,
    updated_at = now(), status = case p_status
      when 'completed' then 'resolved'::public.support_session_status
      when 'new' then 'open'::public.support_session_status
      else 'pending'::public.support_session_status end
    where id = p_session_id and revision = p_expected_revision;
  if not found then raise exception using errcode = '40001', message = 'support_revision_conflict'; end if;
  insert into audit.support_session_actions(support_session_id, action_code, object_type, object_id, metadata_json)
    values (p_session_id, 'support.status', 'support_session', p_session_id, jsonb_build_object('actor_person_id', actor_id, 'status', p_status));
  result := public.superadmin_support_get(p_session_id);
  insert into public.support_command_receipts(request_id, support_session_id, actor_person_id, action_code, response_json)
    values (p_request_id, p_session_id, actor_id, 'status', result);
  return result;
end;
$$;

create or replace function public.superadmin_support_get(p_session_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.assert_support_permission();
  select jsonb_build_object(
    'id', s.id, 'subject', s.subject, 'menu', s.menu_code, 'screen', s.screen_code,
    'description', s.reported_issue, 'requester', s.requester_label,
    'institution_id', s.institution_id, 'unit_id', s.unit_id,
    'status', s.ticket_status, 'priority', s.priority, 'revision', s.revision,
    'created_at', s.opened_at, 'updated_at', s.updated_at,
    'assignee_membership_id', s.assigned_to_membership_id,
    'closure_reason', case when s.status in ('expired','revoked') then s.status::text end,
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
      'id', m.id, 'text', m.message_text,
      'author', case when m.author_membership_id is null then 'requester' else 'support' end,
      'created_at', m.created_at, 'read', m.deleted_at is not null
    ) order by m.created_at, m.id) from public.support_messages m
      where m.support_session_id = s.id and m.deleted_at is null), '[]'::jsonb),
      'activities', coalesce((select jsonb_agg(jsonb_build_object(
      'id', a.id, 'action', a.action_code, 'outcome', a.outcome::text,
      'occurred_at', a.occurred_at, 'metadata', a.metadata_json
    ) order by a.occurred_at, a.id) from audit.support_session_actions a
      where a.support_session_id = s.id), '[]'::jsonb)
  ) into result
  from public.support_sessions s where s.id = p_session_id;
  if result is null then raise exception using errcode = 'P0002', message = 'support_session_not_found'; end if;
  return result;
end;
$$;

create or replace function public.superadmin_support_list(
  p_search text default '', p_statuses text[] default null, p_menus text[] default null,
  p_screens text[] default null, p_assignee_ids uuid[] default null,
  p_unread_only boolean default false, p_page integer default 1, p_page_size integer default 25
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.assert_support_permission();
  if p_page < 1 or p_page_size not between 1 and 100 then
    raise exception using errcode = '22023', message = 'invalid_pagination';
  end if;
  if coalesce(char_length(p_search), 0) > 200 then
    raise exception using errcode = '22023', message = 'invalid_search';
  end if;
  with filtered as (
    select s.*,
      exists(select 1 from public.support_messages m
        where m.support_session_id = s.id and m.deleted_at is null
          and m.author_membership_id is null) as unread
    from public.support_sessions s
    where (coalesce(trim(p_search), '') = '' or s.subject ilike '%' || trim(p_search) || '%'
      or s.reported_issue ilike '%' || trim(p_search) || '%'
      or s.requester_label ilike '%' || trim(p_search) || '%')
      and (p_statuses is null or s.ticket_status = any(p_statuses))
      and (p_menus is null or s.menu_code = any(p_menus))
      and (p_screens is null or s.screen_code = any(p_screens))
      and (p_assignee_ids is null or s.assigned_to_membership_id = any(p_assignee_ids))
      and (not coalesce(p_unread_only, false) or exists(select 1 from public.support_messages m
        where m.support_session_id = s.id and m.deleted_at is null
          and m.author_membership_id is null))
  ), page_rows as (
    select * from filtered order by updated_at desc, id desc
    limit p_page_size offset ((p_page - 1) * p_page_size)
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'subject', subject, 'menu', menu_code, 'screen', screen_code,
      'description', reported_issue, 'requester', requester_label,
      'institution_id', institution_id, 'unit_id', unit_id,
      'status', ticket_status, 'priority', priority, 'revision', revision,
      'created_at', opened_at, 'updated_at', updated_at, 'unread', unread,
      'assignee_membership_id', assigned_to_membership_id,
      'closure_reason', case when status in ('expired','revoked') then status::text end
    ) order by updated_at desc, id desc), '[]'::jsonb),
    'total_items', (select count(*) from filtered), 'page', p_page, 'page_size', p_page_size
  ) into result from page_rows;
  return result;
end;
$$;

revoke all on function public.superadmin_support_set_status(uuid,uuid,text,bigint) from public, anon;
grant execute on function public.superadmin_support_set_status(uuid,uuid,text,bigint) to authenticated;
revoke all on function public.superadmin_support_get(uuid) from public, anon;
grant execute on function public.superadmin_support_get(uuid) to authenticated;
revoke all on function public.superadmin_support_list(text,text[],text[],text[],uuid[],boolean,integer,integer) from public, anon;
grant execute on function public.superadmin_support_list(text,text[],text[],text[],uuid[],boolean,integer,integer) to authenticated;
