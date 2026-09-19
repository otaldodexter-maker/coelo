-- Perfis oficiais — spec 068 §4: o conteúdo oficial entra como post no feed Acontece (feed misto),
-- sem tipo novo no cliente. Lote 107 (Sessão ETAPA-3, 20/09/2026).
--   * public.official_posts: post de texto de um perfil oficial (sem instituição), published/withdrawn,
--     management_version; RLS deny, leitura só por RPC.
--   * superadmin_official_post_publish_v1(p_request_id, p_profile_id, p_caption) e
--     superadmin_official_post_withdraw_v1(p_request_id, p_post_id, p_expected_version, p_reason):
--     contexto interno (notices.publish), owner/operations, recibo idempotente, PT409, auditoria.
--   * superadmin_official_posts_list_v1(p_profile_id, p_limit): lista para o Superadmin.
--   * list_visible_happens_feed: a função de contexto (lote 103) passa a chamar-se
--     list_visible_happens_feed_context_v1 (sem grant a cliente) e a pública faz a união com os posts
--     oficiais publicados — item_type 'post', author = pessoa técnica do perfil, context_label
--     "Coelo · @handle", can_withdraw false, media []. Mesmo cursor (at, kind, id) e mesmo limite.
--   * principal_official_profiles_v1: devolve também `posts` do perfil (para a tela do perfil).
-- Reversão: recriar list_visible_happens_feed a partir de list_visible_happens_feed_context_v1;
-- drop das funções superadmin_official_post*/superadmin_official_posts_list_v1 e da tabela.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then raise exception 'executar como postgres'; end if;
  if to_regprocedure('public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)') is null
    or to_regclass('public.official_profiles') is null
    or to_regclass('app_private.superadmin_internal_lifecycle_receipts') is null then
    raise exception 'pre-requisitos ausentes (lotes 95/103 e recibos de ciclo de vida)';
  end if;
end $preflight$;

-- 1. tabela --------------------------------------------------------------------------------------
create table if not exists public.official_posts (
  id uuid primary key default gen_random_uuid(),
  official_profile_id uuid not null references public.official_profiles(id),
  caption text not null check (btrim(caption) <> '' and char_length(caption) <= 2000),
  status text not null default 'published' check (status in ('published', 'withdrawn')),
  published_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  withdraw_reason text,
  management_version bigint not null default 1,
  created_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists official_posts_published_idx on public.official_posts(published_at desc) where status = 'published';
alter table public.official_posts enable row level security;
alter table public.official_posts force row level security;
revoke all on public.official_posts from public, anon, authenticated, service_role;

-- 2. comandos do Superadmin ------------------------------------------------------------------------
create or replace function app_private.superadmin_official_post_command_v1(
  p_action text, p_request_id uuid, p_profile_id uuid, p_post_id uuid, p_expected_version bigint, p_text text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  error_code text; error_detail text; body text := nullif(btrim(coalesce(p_text, '')), '');
  receipt app_private.superadmin_internal_lifecycle_receipts%rowtype; request_hash bytea;
  post public.official_posts%rowtype; profile public.official_profiles%rowtype; result jsonb; after_json jsonb;
  entity_id uuid;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('notices.publish');
    if ctx.platform_role_code not in ('owner', 'operations') then
      raise insufficient_privilege using message = 'official posts access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_action not in ('publish', 'withdraw')
      or (p_action = 'publish' and (p_profile_id is null or body is null or char_length(body) > 2000))
      or (p_action = 'withdraw' and (p_post_id is null or p_expected_version is null or p_expected_version <= 0
        or body is null or char_length(body) > 500)) then
      raise invalid_parameter_value using message = 'invalid official post request', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    entity_id := coalesce(p_post_id, p_profile_id);
    request_hash := extensions.digest(p_action || '|' || entity_id::text || '|' || coalesce(p_expected_version::text, '')
      || '|' || body, 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
    select * into receipt from app_private.superadmin_internal_lifecycle_receipts where request_id = p_request_id;
    if receipt.request_id is not null then
      if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
        or receipt.entity_id is distinct from entity_id or receipt.request_hash is distinct from request_hash then
        raise invalid_parameter_value using message = 'request id already used', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      return jsonb_build_object('ok', true, 'data', receipt.result_json || jsonb_build_object('replayed', true), 'error', null);
    end if;
    if p_action = 'publish' then
      select * into profile from public.official_profiles o where o.id = p_profile_id and o.status = 'active';
      if profile.id is null then
        raise invalid_parameter_value using message = 'official profile not found', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      insert into public.official_posts(official_profile_id, caption, created_by_internal_identity_id)
      values (profile.id, body, ctx.internal_identity_id) returning * into post;
    else
      select * into post from public.official_posts o where o.id = p_post_id for update;
      if post.id is null then
        raise invalid_parameter_value using message = 'official post not found', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      if post.management_version is distinct from p_expected_version then
        raise exception using errcode = 'PT409', message = 'stale version', detail = 'SAI_CONCURRENT_CHANGE';
      end if;
      if post.status = 'withdrawn' then
        raise invalid_parameter_value using message = 'already withdrawn', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      update public.official_posts set status = 'withdrawn', withdrawn_at = now(), withdraw_reason = body,
        management_version = management_version + 1, updated_at = now()
        where id = post.id returning * into post;
      select * into profile from public.official_profiles o where o.id = post.official_profile_id;
    end if;
    result := jsonb_build_object('id', post.id, 'status', post.status, 'management_version', post.management_version,
      'official_profile_id', post.official_profile_id, 'handle', profile.handle, 'published_at', post.published_at);
    after_json := jsonb_build_object('id', post.id, 'status', post.status, 'management_version', post.management_version);
    insert into app_private.superadmin_internal_lifecycle_receipts(request_id, actor_internal_identity_id, entity, entity_id,
      action_code, expected_version, request_hash, result_json)
    values (p_request_id, ctx.internal_identity_id, 'official_post', entity_id, 'official_post.' || p_action,
      coalesce(p_expected_version, 0), request_hash, result);
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
      ctx.internal_membership_id, ctx.session_id, 'notices.publish', ctx.aal, 'official_post.' || p_action,
      'success'::public.audit_outcome, case when p_action = 'withdraw' then 'LIFECYCLE_OPERATOR_REASON' else null end,
      correlation, null, 'official_post', post.id, after_json);
    return jsonb_build_object('ok', true, 'data', result || jsonb_build_object('replayed', false), 'error', null);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail like 'SAI_%' then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or foreign_key_violation then error_code := 'SAI_INVALID_ARGUMENT';
    when sqlstate 'PT409' then error_code := 'SAI_CONCURRENT_CHANGE';
    when others then error_code := 'SAI_INTERNAL_ERROR';
  end;
  return app_private.superadmin_internal_error_envelope(error_code, correlation);
end
$$;
revoke all on function app_private.superadmin_official_post_command_v1(text, uuid, uuid, uuid, bigint, text)
  from public, anon, authenticated, service_role;

create or replace function public.superadmin_official_post_publish_v1(p_request_id uuid, p_profile_id uuid, p_caption text)
returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_official_post_command_v1('publish', p_request_id, p_profile_id, null, null, p_caption)
$$;
create or replace function public.superadmin_official_post_withdraw_v1(
  p_request_id uuid, p_post_id uuid, p_expected_version bigint, p_reason text
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_official_post_command_v1('withdraw', p_request_id, null, p_post_id, p_expected_version, p_reason)
$$;
create or replace function public.superadmin_official_posts_list_v1(p_profile_id uuid default null, p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context;
begin
  ctx := app_private.superadmin_notice_context('notices.read');
  return jsonb_build_object('ok', true, 'data', jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'official_profile_id', p.official_profile_id, 'handle', o.handle,
      'display_name', o.display_name, 'caption', p.caption, 'status', p.status, 'published_at', p.published_at,
      'withdrawn_at', p.withdrawn_at, 'withdraw_reason', p.withdraw_reason, 'management_version', p.management_version)
      order by p.published_at desc, p.id desc)
    from (select * from public.official_posts x where p_profile_id is null or x.official_profile_id = p_profile_id
          order by x.published_at desc, x.id desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) p
    join public.official_profiles o on o.id = p.official_profile_id), '[]'::jsonb)), 'error', null);
end
$$;
do $grants$ begin
  execute 'alter function public.superadmin_official_post_publish_v1(uuid, uuid, text) owner to postgres';
  execute 'alter function public.superadmin_official_post_withdraw_v1(uuid, uuid, bigint, text) owner to postgres';
  execute 'alter function public.superadmin_official_posts_list_v1(uuid, integer) owner to postgres';
  execute 'revoke all on function public.superadmin_official_post_publish_v1(uuid, uuid, text) from public, anon, service_role';
  execute 'revoke all on function public.superadmin_official_post_withdraw_v1(uuid, uuid, bigint, text) from public, anon, service_role';
  execute 'revoke all on function public.superadmin_official_posts_list_v1(uuid, integer) from public, anon, service_role';
  execute 'grant execute on function public.superadmin_official_post_publish_v1(uuid, uuid, text) to authenticated';
  execute 'grant execute on function public.superadmin_official_post_withdraw_v1(uuid, uuid, bigint, text) to authenticated';
  execute 'grant execute on function public.superadmin_official_posts_list_v1(uuid, integer) to authenticated';
end $grants$;

-- 3. feed Acontece: contexto (lote 103) + posts oficiais -------------------------------------------
do $rename$ begin
  if to_regprocedure('public.list_visible_happens_feed_context_v1(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)') is null then
    alter function public.list_visible_happens_feed(uuid, uuid, uuid, uuid, timestamptz, text, uuid, integer)
      rename to list_visible_happens_feed_context_v1;
  end if;
end $rename$;
revoke all on function public.list_visible_happens_feed_context_v1(uuid, uuid, uuid, uuid, timestamptz, text, uuid, integer)
  from public, anon, authenticated, service_role;

create or replace function public.list_visible_happens_feed(
  p_institution_id uuid, p_unit_id uuid, p_group_id uuid, p_activity_id uuid,
  p_before_at timestamptz, p_before_type text, p_before_id uuid, p_limit integer default 20
) returns table(item_type text, item_id uuid, effective_published_at timestamptz, payload jsonb)
language plpgsql security definer set search_path = '' as $$
declare lim integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  return query
  with context_items as (
    -- a função de contexto autoriza o ator (raise quando não pode ler) e aplica o cursor
    select c.item_type, c.item_id, c.effective_published_at, c.payload
    from public.list_visible_happens_feed_context_v1(p_institution_id, p_unit_id, p_group_id, p_activity_id,
      p_before_at, p_before_type, p_before_id, lim) c
  ),
  official_items as (
    select 'post'::text as item_type, op.id as item_id, op.published_at as effective_published_at,
      jsonb_build_object('author_name', o.display_name, 'author_initials', upper(left(o.display_name, 1)),
        'author_person_id', o.person_id, 'context_label', 'Coelo · @' || o.handle, 'caption', op.caption,
        'management_version', op.management_version, 'can_withdraw', false, 'media', '[]'::jsonb,
        'official_profile', jsonb_build_object('id', o.id, 'handle', o.handle, 'display_name', o.display_name)) as payload
    from public.official_posts op
    join public.official_profiles o on o.id = op.official_profile_id and o.status = 'active'
    where op.status = 'published'
      and (p_before_at is null or (op.published_at, 'post', op.id) < (p_before_at, coalesce(p_before_type, 'zz'), p_before_id))
    order by op.published_at desc, op.id desc limit lim
  )
  select u.item_type, u.item_id, u.effective_published_at, u.payload
  from (select * from context_items union all select * from official_items) u
  order by u.effective_published_at desc, u.item_type desc, u.item_id desc
  limit lim;
end
$$;
alter function public.list_visible_happens_feed(uuid, uuid, uuid, uuid, timestamptz, text, uuid, integer) owner to postgres;
revoke all on function public.list_visible_happens_feed(uuid, uuid, uuid, uuid, timestamptz, text, uuid, integer) from public, anon;
grant execute on function public.list_visible_happens_feed(uuid, uuid, uuid, uuid, timestamptz, text, uuid, integer) to authenticated, service_role;

-- 4. tela do perfil oficial no Principal: posts do perfil ------------------------------------------
create or replace function public.principal_official_profiles_v1(p_handle text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid;
  profile public.official_profiles;
  profiles jsonb;
  items jsonb := '[]'::jsonb;
  posts jsonb := '[]'::jsonb;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  actor := app_private.current_person_id();
  if actor is null then
    raise insufficient_privilege using message = 'principal_context_denied';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', o.id, 'handle', o.handle, 'display_name', o.display_name, 'description', o.description,
      'mandatory', o.mandatory, 'person_id', o.person_id, 'sort_order', o.sort_order,
      'followers', (select count(*) from public.follow_links f
        where f.target_kind = 'person' and f.target_id = o.person_id and f.status = 'active'),
      'following', exists (select 1 from public.follow_links f
        where f.follower_person_id = actor and f.target_kind = 'person'
          and f.target_id = o.person_id and f.status = 'active'))
      order by o.sort_order, o.handle), '[]'::jsonb)
    into profiles
  from public.official_profiles o where o.status = 'active';

  if p_handle is null then
    return jsonb_build_object('ok', true, 'data', jsonb_build_object('profiles', profiles), 'error', null);
  end if;

  select * into profile from public.official_profiles o
  where o.handle = lower(btrim(p_handle)) and o.status = 'active';
  if profile.id is null then
    raise no_data_found using message = 'official profile not found', detail = 'OFFICIAL_PROFILE_NOT_FOUND';
  end if;

  select coalesce(jsonb_agg(item), '[]'::jsonb) into items
  from jsonb_array_elements(public.list_my_principal_for_you('all', null, 100) #> '{data,items}') item
  where item #>> '{author,id}' = profile.id::text;

  select coalesce(jsonb_agg(jsonb_build_object('id', op.id, 'caption', op.caption, 'published_at', op.published_at)
      order by op.published_at desc, op.id desc), '[]'::jsonb) into posts
  from (select * from public.official_posts x where x.official_profile_id = profile.id and x.status = 'published'
        order by x.published_at desc, x.id desc limit 50) op;

  return jsonb_build_object('ok', true, 'data', jsonb_build_object(
    'profiles', profiles,
    'profile', (select p from jsonb_array_elements(profiles) p where p ->> 'id' = profile.id::text),
    'items', items, 'posts', posts), 'error', null);
end
$$;

commit;
