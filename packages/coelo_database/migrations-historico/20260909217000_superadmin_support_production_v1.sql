-- SUPPORT-PRODUCTION-V1
-- Camada server-side do diretório de Suporte. O cliente só acessa os RPCs.
begin;

alter table public.support_sessions
  add column if not exists subject text not null default 'Atendimento Coelo',
  add column if not exists menu_code text not null default 'support',
  add column if not exists screen_code text not null default 'support',
  add column if not exists requester_label text not null default 'Solicitante',
  add column if not exists ticket_status text not null default 'new',
  add column if not exists revision bigint not null default 1,
  add column if not exists updated_at timestamptz not null default now();

alter table public.support_sessions
  drop constraint if exists support_sessions_subject_length,
  drop constraint if exists support_sessions_menu_length,
  drop constraint if exists support_sessions_screen_length,
  drop constraint if exists support_sessions_requester_length,
  drop constraint if exists support_sessions_ticket_status_check,
  drop constraint if exists support_sessions_revision_positive,
  add constraint support_sessions_subject_length check (char_length(trim(subject)) between 1 and 160),
  add constraint support_sessions_menu_length check (char_length(trim(menu_code)) between 1 and 80),
  add constraint support_sessions_screen_length check (char_length(trim(screen_code)) between 1 and 120),
  add constraint support_sessions_requester_length check (char_length(trim(requester_label)) between 1 and 160),
  add constraint support_sessions_ticket_status_check check (ticket_status in ('new','in_progress','waiting_requester','completed')),
  add constraint support_sessions_revision_positive check (revision > 0);

create index if not exists support_sessions_ticket_directory_idx
  on public.support_sessions(ticket_status, updated_at desc, id);
create index if not exists support_sessions_menu_screen_idx
  on public.support_sessions(menu_code, screen_code, updated_at desc);

create table if not exists public.support_command_receipts (
  request_id uuid primary key,
  support_session_id uuid not null references public.support_sessions(id) on delete cascade,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  action_code text not null check (action_code in ('create','reply','status','assign')),
  response_json jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.support_command_receipts enable row level security;
alter table public.support_command_receipts force row level security;
alter table public.support_sessions force row level security;
alter table public.support_messages force row level security;
alter table audit.support_session_actions force row level security;

revoke all on table public.support_sessions, public.support_messages,
  audit.support_session_actions, public.support_command_receipts
  from public, anon, authenticated;

create or replace function app_private.assert_support_permission()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  actor_id := app_private.current_person_id();
  if actor_id is null then
    raise exception using errcode = '42501', message = 'internal_actor_required';
  end if;
  if not app_private.has_platform_permission('support.manage') then
    raise exception using errcode = '42501', message = 'permission_denied';
  end if;
  return actor_id;
end;
$$;

revoke all on function app_private.assert_support_permission() from public, anon, authenticated;

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
      'assignee_membership_id', assigned_to_membership_id
    ) order by updated_at desc, id desc), '[]'::jsonb),
    'total_items', (select count(*) from filtered), 'page', p_page, 'page_size', p_page_size
  ) into result from page_rows;
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
  if p_request_id is null or p_institution_id is null or char_length(trim(coalesce(p_subject,''))) not between 1 and 160
    or char_length(trim(coalesce(p_menu,''))) not between 1 and 80
    or char_length(trim(coalesce(p_screen,''))) not between 1 and 120
    or char_length(trim(coalesce(p_requester_label,''))) not between 1 and 160
    or char_length(trim(coalesce(p_reported_issue,''))) not between 1 and 10000
    or p_priority not in ('low','normal','high','urgent') then
    raise exception using errcode = '22023', message = 'invalid_support_request';
  end if;
  select support_session_id into session_id from public.support_command_receipts where request_id = p_request_id;
  if session_id is not null then return public.superadmin_support_get(session_id); end if;
  insert into public.support_sessions(
    opened_by_person_id, institution_id, unit_id, subject, menu_code, screen_code,
    requester_label, reported_issue, priority, ticket_status, updated_at
  ) values (
    actor_id, p_institution_id, p_unit_id, trim(p_subject), trim(p_menu), trim(p_screen),
    trim(p_requester_label), trim(p_reported_issue), p_priority, 'new', now()
  ) returning id into session_id;
  insert into audit.support_session_actions(support_session_id, action_code, object_type, object_id, metadata_json)
    values (session_id, 'support.create', 'support_session', session_id, jsonb_build_object('actor_person_id', actor_id));
  result := public.superadmin_support_get(session_id);
  insert into public.support_command_receipts(request_id, support_session_id, actor_person_id, action_code, response_json)
    values (p_request_id, session_id, actor_id, 'create', result);
  return result;
end;
$$;

create or replace function public.superadmin_support_reply(
  p_request_id uuid, p_session_id uuid, p_message text, p_expected_revision bigint
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare actor_id uuid; current_revision bigint; result jsonb;
begin
  actor_id := app_private.assert_support_permission();
  if p_request_id is null or char_length(trim(coalesce(p_message,''))) not between 1 and 10000 then
    raise exception using errcode = '22023', message = 'invalid_support_message';
  end if;
  if exists(select 1 from public.support_command_receipts where request_id = p_request_id) then
    select response_json into result from public.support_command_receipts where request_id = p_request_id;
    return result;
  end if;
  select revision into current_revision from public.support_sessions where id = p_session_id for update;
  if current_revision is null then raise exception using errcode = 'P0002', message = 'support_session_not_found'; end if;
  if p_expected_revision is null or p_expected_revision <> current_revision then
    raise exception using errcode = '40001', message = 'support_revision_conflict';
  end if;
  insert into public.support_messages(support_session_id, author_person_id, author_membership_id, message_text)
    values (p_session_id, actor_id, actor_id, trim(p_message));
  update public.support_sessions set revision = revision + 1, updated_at = now() where id = p_session_id;
  insert into audit.support_session_actions(support_session_id, action_code, object_type, object_id, metadata_json)
    values (p_session_id, 'support.reply', 'support_session', p_session_id, jsonb_build_object('actor_person_id', actor_id));
  result := public.superadmin_support_get(p_session_id);
  insert into public.support_command_receipts(request_id, support_session_id, actor_person_id, action_code, response_json)
    values (p_request_id, p_session_id, actor_id, 'reply', result);
  return result;
end;
$$;

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
    updated_at = now(), status = case when p_status = 'completed' then 'resolved'::public.support_session_status else 'open'::public.support_session_status end
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

revoke all on function public.superadmin_support_list(text,text[],text[],text[],uuid[],boolean,integer,integer),
  public.superadmin_support_get(uuid), public.superadmin_support_create(uuid,uuid,uuid,text,text,text,text,text,text),
  public.superadmin_support_reply(uuid,uuid,text,bigint), public.superadmin_support_set_status(uuid,uuid,text,bigint)
  from public, anon;
grant execute on function public.superadmin_support_list(text,text[],text[],text[],uuid[],boolean,integer,integer),
  public.superadmin_support_get(uuid), public.superadmin_support_create(uuid,uuid,uuid,text,text,text,text,text,text),
  public.superadmin_support_reply(uuid,uuid,text,bigint), public.superadmin_support_set_status(uuid,uuid,text,bigint)
  to authenticated;

commit;
