-- Chat interno do Superadmin: fixar conversa e bandeira de cor, por identidade
-- interna e persistidos, sobre a baseline de producao.
--
-- Reescreve 20260910140000 (historico, do grupo principal-chat-sistema) para
-- a forma canonica de producao: auditoria com 13 argumentos. O resto e
-- identico: a preferencia pertence a identidade interna, nao a conversa; a
-- tabela fica em app_private e so e alcancada pelas RPCs v2, que revalidam
-- contexto, capacidade e escopo de instituicao. Exige 20260910240100.
begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='internal chat migration must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)') is null
     or to_regprocedure('app_private.superadmin_chat_success(jsonb)') is null
     or to_regclass('app_private.superadmin_internal_chat_receipts') is null then
    raise exception using errcode='55000',
      message='internal chat v2 baseline is unavailable';
  end if;
end
$$;

create table if not exists app_private.superadmin_internal_chat_preferences(
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  pinned_at timestamptz,
  flag text not null default 'none'
    check (flag in ('none', 'red', 'yellow', 'green', 'blue', 'pink', 'restricted')),
  updated_at timestamptz not null default now(),
  primary key (internal_identity_id, conversation_id)
);

create index if not exists superadmin_internal_chat_preferences_pinned_idx
  on app_private.superadmin_internal_chat_preferences(internal_identity_id, pinned_at desc)
  where pinned_at is not null;

alter table app_private.superadmin_internal_chat_preferences enable row level security;
alter table app_private.superadmin_internal_chat_preferences force row level security;
revoke all on table app_private.superadmin_internal_chat_preferences
  from public, anon, authenticated, service_role;

create or replace function app_private.superadmin_chat_set_preference(
  p_capability text,
  p_conversation_id uuid,
  p_pinned boolean,
  p_flag text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  institution uuid;
  saved app_private.superadmin_internal_chat_preferences%rowtype;
  code text;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context(p_capability);
    if p_conversation_id is null
        or (p_pinned is null and p_flag is null)
        or (p_flag is not null and p_flag not in (
          'none', 'red', 'yellow', 'green', 'blue', 'pink', 'restricted')) then
      raise invalid_parameter_value using detail = 'CHAT_INVALID_INPUT';
    end if;
    -- O escopo da conversa e revalidado aqui, e nao no cliente: uma conversa de
    -- outra instituicao nao pode nem receber preferencia.
    select institution_id into institution
    from public.conversations
    where id = p_conversation_id
      and (ctx.scope_kind <> 'institution' or institution_id = ctx.scope_institution_id);
    if institution is null then
      raise no_data_found using detail = 'CHAT_NOT_FOUND';
    end if;
    insert into app_private.superadmin_internal_chat_preferences(
      internal_identity_id, conversation_id, pinned_at, flag)
    values (
      ctx.internal_identity_id,
      p_conversation_id,
      case when coalesce(p_pinned, false) then now() else null end,
      coalesce(p_flag, 'none'))
    on conflict (internal_identity_id, conversation_id) do update set
      pinned_at = case
        when p_pinned is null then app_private.superadmin_internal_chat_preferences.pinned_at
        when p_pinned then coalesce(
          app_private.superadmin_internal_chat_preferences.pinned_at, now())
        else null end,
      flag = coalesce(p_flag, app_private.superadmin_internal_chat_preferences.flag),
      updated_at = now()
    returning * into saved;
    perform app_private.audit_append_superadmin_internal(
      ctx.internal_identity_id, ctx.internal_auth_link_id, ctx.internal_membership_id,
      ctx.session_id, p_capability, ctx.aal, 'chat.conversation.preference', 'success',
      null, correlation, institution, 'conversation', p_conversation_id);
    return app_private.superadmin_chat_success(jsonb_build_object(
      'conversation_id', saved.conversation_id,
      'pinned_at', saved.pinned_at,
      'flag', saved.flag));
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  perform app_private.audit_superadmin_internal_denial_if_identified(
    p_capability, 'chat.conversation.preference', code, correlation);
  return app_private.superadmin_chat_error(code, correlation);
end $$;

create or replace function public.superadmin_chat_set_pinned_v2(
  p_conversation_id uuid,
  p_pinned boolean
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select app_private.superadmin_chat_set_preference(
    'chat.internal.read', p_conversation_id, p_pinned, null);
$$;

create or replace function public.superadmin_chat_set_flag_v2(
  p_conversation_id uuid,
  p_flag text
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select app_private.superadmin_chat_set_preference(
    'chat.internal.read', p_conversation_id, null, p_flag);
$$;

-- A inbox passa a devolver a preferencia e a colocar as fixadas na frente.
create or replace function public.superadmin_chat_inbox_v2(
  p_cursor_activity_at timestamptz default null,
  p_cursor_conversation_id uuid default null,
  p_limit integer default 30,
  p_search text default null,
  p_unread_only boolean default false
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  result jsonb;
  code text;
  normalized_search text := nullif(btrim(p_search), '');
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('chat.internal.read');
    if p_limit is null or p_limit not between 1 and 100
       or (p_cursor_activity_at is null) <> (p_cursor_conversation_id is null)
       or length(coalesce(normalized_search, '')) > 100 then
      raise invalid_parameter_value using detail = 'CHAT_INVALID_INPUT';
    end if;
    with candidate as (
      select conversation_row.id, conversation_row.title, conversation_row.conversation_type,
        conversation_row.scope_kind, conversation_row.institution_id,
        conversation_row.is_read_only,
        latest.id latest_message_id, latest.body_text latest_message_text,
        latest.created_at latest_message_at,
        coalesce(latest.created_at, conversation_row.updated_at) activity_at,
        preference.pinned_at,
        coalesce(preference.flag, 'none') flag,
        (select count(*) from public.messages unread_message
         left join app_private.superadmin_internal_chat_receipts receipt
           on receipt.message_id = unread_message.id
          and receipt.internal_identity_id = ctx.internal_identity_id
         where unread_message.conversation_id = conversation_row.id
           and unread_message.status = 'active' and unread_message.deleted_at is null
           and unread_message.author_internal_identity_id is distinct from ctx.internal_identity_id
           and receipt.read_at is null) unread_count
      from public.conversations conversation_row
      left join lateral(
        select message_row.id, message_row.body_text, message_row.created_at
        from public.messages message_row
        where message_row.conversation_id = conversation_row.id
          and message_row.status = 'active' and message_row.deleted_at is null
        order by message_row.created_at desc, message_row.id desc limit 1) latest on true
      left join app_private.superadmin_internal_chat_preferences preference
        on preference.conversation_id = conversation_row.id
       and preference.internal_identity_id = ctx.internal_identity_id
      where (ctx.scope_kind <> 'institution'
          or conversation_row.institution_id = ctx.scope_institution_id)
        and (normalized_search is null
          or conversation_row.title ilike '%' || normalized_search || '%'
          or latest.body_text ilike '%' || normalized_search || '%')
    ), eligible as (
      select * from candidate where not p_unread_only or unread_count > 0
    ), filtered as (
      select * from eligible
      where p_cursor_activity_at is null
        or (activity_at, id) < (p_cursor_activity_at, p_cursor_conversation_id)
    ), page as (
      select * from filtered order by activity_at desc, id desc limit p_limit + 1
    ), stats as (
      select count(*) total, coalesce(sum(unread_count), 0) total_unread from eligible
    )
    select pg_catalog.jsonb_build_object(
      'items', coalesce((select jsonb_agg(jsonb_build_object(
        'conversation_id', item.id, 'title', coalesce(item.title, ''),
        'conversation_type', item.conversation_type, 'scope_kind', item.scope_kind,
        'institution_id', item.institution_id, 'latest_message_id', item.latest_message_id,
        'latest_message_text', coalesce(item.latest_message_text, ''),
        'latest_message_at', item.latest_message_at, 'unread_count', item.unread_count,
        'activity_at', item.activity_at, 'is_read_only', item.is_read_only,
        'pinned_at', item.pinned_at, 'flag', item.flag)
        -- Fixadas primeiro, e so entao a ordem por atividade. A paginacao
        -- continua ancorada em activity_at, entao o cursor nao muda.
        order by (item.pinned_at is null), item.pinned_at desc,
          item.activity_at desc, item.id desc)
        from (select * from page limit p_limit) item), '[]'::jsonb),
      'total', (select total from stats),
      'total_unread', (select total_unread from stats),
      'has_more', (select count(*) > p_limit from page),
      'next_cursor', case when (select count(*) from page) > p_limit then
        (select jsonb_build_object('timestamp', item.activity_at, 'id', item.id)
         from (select * from page limit p_limit) item
         order by item.activity_at, item.id limit 1) else null end
    ) into result;
    return app_private.superadmin_chat_success(result);
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'chat.internal.read', 'chat.inbox', code, correlation);
  return app_private.superadmin_chat_error(code, correlation);
end $$;

do $$
declare p text;
begin
  foreach p in array array[
    'app_private.superadmin_chat_set_preference(text,uuid,boolean,text)'::regprocedure::text,
    'public.superadmin_chat_set_pinned_v2(uuid,boolean)'::regprocedure::text,
    'public.superadmin_chat_set_flag_v2(uuid,text)'::regprocedure::text,
    'public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)'::regprocedure::text
  ] loop
    execute format('alter function %s owner to postgres', p);
    execute format(
      'revoke all on function %s from public,anon,authenticated,service_role', p);
  end loop;
end $$;

grant execute on function public.superadmin_chat_set_pinned_v2(uuid, boolean) to authenticated;
grant execute on function public.superadmin_chat_set_flag_v2(uuid, text) to authenticated;
grant execute on function public.superadmin_chat_inbox_v2(
  timestamptz, uuid, integer, text, boolean) to authenticated;

commit;
