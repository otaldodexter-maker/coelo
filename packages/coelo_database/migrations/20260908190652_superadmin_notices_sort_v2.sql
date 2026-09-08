-- Candidate migration, reserved locally by R01-C05-I007. Not applied remotely.
--
-- Adds operator-chosen ordering to the Communications directory without letting
-- the client decide anything the server does not re-derive:
--
--   * the sort column is resolved by a fixed CASE over an allowlist, never by
--     SQL assembled from client text;
--   * every page re-authorises actor, tenant and capability through
--     superadmin_notice_context, exactly as before;
--   * the keyset cursor is bound to the caller's scope and to the query it was
--     issued for. A cursor from a different sort or filter is a legitimate UX
--     transition and restarts at page one with cursor_reset; a malformed cursor
--     or one issued for another scope fails without returning rows;
--   * the id tiebreak follows the chosen direction, so the ORDER BY and the
--     row-tuple keyset comparison always agree. Ascending pages order by id asc
--     and resume with >, descending pages order by id desc and resume with <.
--     Mixing them duplicates or skips rows whose sort value ties.
--
-- The previous signature is dropped first so the two never coexist as an
-- ambiguous overload.

begin;

-- Single fixed expression per allowed column. Timestamps become fixed-width UTC
-- text so one keyset column serves every ordering without type juggling.
create or replace function app_private.superadmin_notice_sort_value(
  p_notice public.platform_notices,
  p_sort_column text
) returns text language sql immutable set search_path = '' as $$
  select case p_sort_column
    when 'updated_at' then
      to_char(p_notice.updated_at at time zone 'UTC', 'YYYYMMDDHH24MISSUS')
    when 'starts_at' then
      coalesce(to_char(p_notice.starts_at at time zone 'UTC', 'YYYYMMDDHH24MISSUS'), '')
    when 'title' then lower(p_notice.title)
    when 'type' then p_notice.notice_type::text
    when 'priority' then p_notice.priority_code
    when 'status' then p_notice.status::text
  end
$$;

-- The cursor carries two hashes. The scope hash must match exactly, so a cursor
-- minted for another scope can never be replayed here. The query hash may
-- differ, which only means the operator changed sort or filters.
create or replace function app_private.superadmin_notice_cursor_fingerprint(
  p_scope_key text,
  p_sort_column text,
  p_sort_ascending boolean,
  p_types text[],
  p_search text,
  p_statuses text[],
  p_priorities text[]
) returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest(convert_to(p_scope_key, 'UTF8'), 'md5'), 'hex')
    || '.'
    || encode(
      extensions.digest(
        convert_to(
          jsonb_build_object(
            'sort_column', p_sort_column,
            'sort_ascending', p_sort_ascending,
            'types', coalesce(to_jsonb(p_types), 'null'::jsonb),
            'search', coalesce(btrim(p_search), ''),
            'statuses', coalesce(to_jsonb(p_statuses), 'null'::jsonb),
            'priorities', coalesce(to_jsonb(p_priorities), 'null'::jsonb)
          )::text,
          'UTF8'
        ),
        'md5'
      ),
      'hex'
    )
$$;

-- NOTICE_INVALID_CURSOR is raised below, so it has to be a declared code. Both
-- allowlists are reproduced from 20260901185008_superadmin_internal_notices_v2.sql
-- with the single new entry added; nothing else changes. Without this, a
-- malformed or out-of-scope cursor would be normalised to SAI_INTERNAL_ERROR and
-- the caller could not tell an unusable cursor from a server fault.
-- create or replace preserves owner and ACL, so neither function needs a grant.
create or replace function app_private.superadmin_notice_error(
  p_code text, p_correlation_id uuid
) returns jsonb language sql immutable security definer set search_path = '' as $$
  select case
    when p_code like 'SAI_%' then
      app_private.superadmin_internal_error_envelope(p_code, p_correlation_id)
    else pg_catalog.jsonb_build_object(
      'ok', false, 'data', null,
      'error', pg_catalog.jsonb_build_object(
        'code', case when p_code in (
          'NOTICE_INVALID_INPUT', 'NOTICE_INVALID_CURSOR', 'NOTICE_NOT_FOUND',
          'NOTICE_CONFLICT', 'NOTICE_INVALID_TRANSITION', 'NOTICE_TERMINAL',
          'NOTICE_MEDIA_BLOCKED'
        ) then p_code else 'NOTICE_INTERNAL_ERROR' end,
        'message', case
          when p_code = 'NOTICE_INVALID_INPUT' then 'Revise os dados da comunicação.'
          when p_code = 'NOTICE_INVALID_CURSOR' then 'A lista mudou. Recarregue e tente novamente.'
          when p_code = 'NOTICE_NOT_FOUND' then 'Comunicação não encontrada.'
          when p_code = 'NOTICE_CONFLICT' then 'A comunicação foi alterada. Recarregue e tente novamente.'
          when p_code in ('NOTICE_INVALID_TRANSITION', 'NOTICE_TERMINAL') then 'Esta transição não é permitida.'
          when p_code = 'NOTICE_MEDIA_BLOCKED' then 'A mídia ainda não está disponível.'
          else 'Não foi possível concluir a operação.' end,
        'correlation_id', p_correlation_id,
        'http_status', case
          when p_code = 'NOTICE_NOT_FOUND' then 404
          when p_code = 'NOTICE_CONFLICT' then 409
          when p_code in ('NOTICE_INVALID_INPUT', 'NOTICE_INVALID_CURSOR',
            'NOTICE_INVALID_TRANSITION', 'NOTICE_TERMINAL', 'NOTICE_MEDIA_BLOCKED') then 422
          else 500 end)) end
$$;

create or replace function app_private.superadmin_notice_denied(
  p_permission_code text, p_action_code text, p_code text, p_correlation_id uuid
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare normalized_code text := case when p_code in (
  'NOTICE_INVALID_INPUT', 'NOTICE_INVALID_CURSOR', 'NOTICE_NOT_FOUND', 'NOTICE_CONFLICT',
  'NOTICE_INVALID_TRANSITION', 'NOTICE_TERMINAL', 'NOTICE_MEDIA_BLOCKED',
  'SAI_AUTH_REQUIRED', 'SAI_SESSION_INVALID', 'SAI_INTERNAL_CONTEXT_DENIED',
  'SAI_MEMBERSHIP_SUSPENDED', 'SAI_MEMBERSHIP_REVOKED',
  'SAI_PERMISSION_DENIED', 'SAI_MFA_REQUIRED') then p_code
  else 'SAI_INTERNAL_ERROR' end;
begin
  perform app_private.audit_superadmin_internal_denial_if_identified(
    p_permission_code, p_action_code, normalized_code, p_correlation_id);
  return app_private.superadmin_notice_error(normalized_code, p_correlation_id);
end
$$;

drop function if exists public.superadmin_notice_directory_v2(
  text[], text, text[], text[], timestamptz, uuid, integer);

create function public.superadmin_notice_directory_v2(
  p_types text[] default null,
  p_search text default null,
  p_statuses text[] default null,
  p_priorities text[] default null,
  p_cursor_occurred_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 25,
  p_sort_column text default 'updated_at',
  p_sort_ascending boolean default false,
  p_cursor_sort_value text default null,
  p_cursor_fingerprint text default null
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid(); items jsonb; next_row record;
  error_code text; has_more boolean; scope_key text; fingerprint text;
  cursor_sort_value text; cursor_id uuid; cursor_reset boolean := false;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.read');
    if p_limit not between 1 and 100 or char_length(coalesce(p_search, '')) > 120
      or p_sort_column is null
      or p_sort_column not in ('updated_at', 'starts_at', 'title', 'type', 'priority', 'status')
      or p_sort_ascending is null
      or (p_types is not null and not (p_types <@ array['popup','notice','critical_notice','content_card','highlight','for_you']::text[]))
      or (p_statuses is not null and not (p_statuses <@ array['draft','scheduled','active','paused','expired','inactive']::text[]))
      or (p_priorities is not null and not (p_priorities <@ array['routine','important','urgent']::text[])) then
      raise invalid_parameter_value using message = 'invalid directory query', detail = 'NOTICE_INVALID_INPUT';
    end if;

    scope_key := coalesce(context_record.scope_kind, '') || ':'
      || coalesce(context_record.scope_institution_id::text, '')
      || ':' || coalesce(context_record.platform_role_code, '');
    fingerprint := app_private.superadmin_notice_cursor_fingerprint(
      scope_key, p_sort_column, p_sort_ascending, p_types, p_search, p_statuses, p_priorities);

    -- The legacy cursor is still accepted while the caller orders by the
    -- default column, so the existing client keeps working unchanged.
    cursor_sort_value := coalesce(
      p_cursor_sort_value,
      case
        when p_cursor_occurred_at is not null and p_sort_column = 'updated_at'
        then to_char(p_cursor_occurred_at at time zone 'UTC', 'YYYYMMDDHH24MISSUS')
      end);
    cursor_id := p_cursor_id;

    if (cursor_sort_value is null) <> (cursor_id is null) then
      raise invalid_parameter_value using message = 'invalid cursor', detail = 'NOTICE_INVALID_CURSOR';
    end if;

    if cursor_id is not null then
      if p_cursor_fingerprint is not null then
        -- Structure first: anything that is not two md5 halves is malformed and
        -- returns no rows, rather than being silently treated as page one.
        if p_cursor_fingerprint !~ '^[0-9a-f]{32}\.[0-9a-f]{32}$' then
          raise invalid_parameter_value using message = 'invalid cursor', detail = 'NOTICE_INVALID_CURSOR';
        end if;
        if split_part(p_cursor_fingerprint, '.', 1) <> split_part(fingerprint, '.', 1) then
          -- Cursor minted for another scope. Refuse; never fall back to page one.
          raise insufficient_privilege using message = 'cursor out of scope', detail = 'NOTICE_INVALID_CURSOR';
        end if;
        if split_part(p_cursor_fingerprint, '.', 2) <> split_part(fingerprint, '.', 2) then
          -- Same scope, different query: the operator changed sort or filters.
          cursor_reset := true;
          cursor_sort_value := null;
          cursor_id := null;
        end if;
      elsif p_sort_column <> 'updated_at' or p_sort_ascending then
        -- A cursor without a fingerprint can only be the legacy one, which only
        -- ever existed for the default ordering.
        cursor_reset := true;
        cursor_sort_value := null;
        cursor_id := null;
      end if;
    end if;

    perform app_private.superadmin_notice_refresh_lifecycle();

    -- notice_row carries the untouched table row so the projection is fed a
    -- value that already has type public.platform_notices. A whole-row
    -- reference to this CTE would not: the CTE also carries sort_value and
    -- page_row, and record-to-composite coercion requires an exact column
    -- match. Every other Notice directory in this repository keeps the row in
    -- its own column for the same reason.
    with filtered as (
      select notice_record.*, notice_record as notice_row,
        app_private.superadmin_notice_sort_value(notice_record, p_sort_column) as sort_value
      from public.platform_notices notice_record
      where (p_search is null or notice_record.title ilike '%' ||
          replace(replace(btrim(p_search), '%', '\%'), '_', '\_') || '%' escape '\')
        and (p_types is null or notice_record.notice_type::text = any(p_types))
        and (p_statuses is null or notice_record.status::text = any(p_statuses))
        and (p_priorities is null or notice_record.priority_code = any(p_priorities))
    ), page as (
      select filtered.*,
        row_number() over(order by
          case when p_sort_ascending then filtered.sort_value end asc,
          case when not p_sort_ascending then filtered.sort_value end desc,
          case when p_sort_ascending then filtered.id end asc,
          case when not p_sort_ascending then filtered.id end desc) page_row
      from filtered
      where cursor_sort_value is null
        or (p_sort_ascending and (filtered.sort_value, filtered.id) > (cursor_sort_value, cursor_id))
        or (not p_sort_ascending and (filtered.sort_value, filtered.id) < (cursor_sort_value, cursor_id))
      order by
        case when p_sort_ascending then filtered.sort_value end asc,
        case when not p_sort_ascending then filtered.sort_value end desc,
        case when p_sort_ascending then filtered.id end asc,
        case when not p_sort_ascending then filtered.id end desc
      limit p_limit + 1
    )
    select coalesce(jsonb_agg(app_private.superadmin_notice_json(page.notice_row)
      order by
        case when p_sort_ascending then page.sort_value end asc,
        case when not p_sort_ascending then page.sort_value end desc,
        case when p_sort_ascending then page.id end asc,
        case when not p_sort_ascending then page.id end desc)
      filter(where page.page_row <= p_limit), '[]'::jsonb),
      count(*) > p_limit
    into items, has_more from page;

    if has_more then
      select page.sort_value, page.updated_at, page.id into next_row
      from (
        select filtered.*,
          row_number() over(order by
            case when p_sort_ascending then filtered.sort_value end asc,
            case when not p_sort_ascending then filtered.sort_value end desc,
            case when p_sort_ascending then filtered.id end asc,
            case when not p_sort_ascending then filtered.id end desc) page_row
        from (
          select notice_record.*,
            app_private.superadmin_notice_sort_value(notice_record, p_sort_column) as sort_value
          from public.platform_notices notice_record
          where (p_search is null or notice_record.title ilike '%' ||
              replace(replace(btrim(p_search), '%', '\%'), '_', '\_') || '%' escape '\')
            and (p_types is null or notice_record.notice_type::text = any(p_types))
            and (p_statuses is null or notice_record.status::text = any(p_statuses))
            and (p_priorities is null or notice_record.priority_code = any(p_priorities))
        ) filtered
        where cursor_sort_value is null
          or (p_sort_ascending and (filtered.sort_value, filtered.id) > (cursor_sort_value, cursor_id))
          or (not p_sort_ascending and (filtered.sort_value, filtered.id) < (cursor_sort_value, cursor_id))
      ) page
      where page.page_row = p_limit;
    end if;

    return jsonb_build_object('ok', true, 'data', jsonb_build_object(
      'items', items,
      'sort_column', p_sort_column,
      'sort_ascending', p_sort_ascending,
      'cursor_reset', cursor_reset,
      'next_cursor_fingerprint', case when has_more then fingerprint else null end,
      'next_cursor_sort_value', case when has_more then next_row.sort_value else null end,
      'next_cursor_occurred_at', case when has_more then next_row.updated_at else null end,
      'next_cursor_id', case when has_more then next_row.id else null end), 'error', null);
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.read', 'notice.directory', error_code, correlation_id);
  end;
end
$$;

-- Only the three functions this migration creates are re-ACLed. A wildcard
-- revoke over every superadmin_notice_% function would strip EXECUTE from
-- detail, audience options, save, publish and change status, which
-- 20260901185008_superadmin_internal_notices_v2.sql granted and the Superadmin
-- client already depends on. superadmin_notice_error and
-- superadmin_notice_denied are replaced above, and create or replace keeps
-- their existing privileges, so they stay out of this loop as well.
do $acl$
declare function_record regprocedure;
begin
  for function_record in
    select procedure_record.oid::regprocedure
    from pg_proc procedure_record
    join pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where (namespace_record.nspname = 'app_private'
      and procedure_record.proname in (
        'superadmin_notice_sort_value', 'superadmin_notice_cursor_fingerprint'))
      or (namespace_record.nspname = 'public'
      and procedure_record.proname = 'superadmin_notice_directory_v2')
  loop
    execute format('alter function %s owner to postgres', function_record);
    execute format('revoke all on function %s from public, anon, authenticated, service_role',
      function_record);
  end loop;
end
$acl$;

grant execute on function public.superadmin_notice_directory_v2(
  text[], text, text[], text[], timestamptz, uuid, integer,
  text, boolean, text, text) to authenticated;

-- Reproduced verbatim from 20260901185008_superadmin_internal_notices_v2.sql.
-- Grants are idempotent, so this asserts the surviving contracts rather than
-- changing them, and it repairs any environment where an earlier draft of this
-- candidate had already run the wildcard revoke.
grant execute on function public.superadmin_notice_detail_v2(uuid) to authenticated;
grant execute on function public.superadmin_notice_audience_options_v2(
  text, text, uuid[], text, text, integer) to authenticated;
grant execute on function public.superadmin_notice_save_draft_v2(
  uuid, uuid, bigint, jsonb) to authenticated;
grant execute on function public.superadmin_notice_publish_v2(uuid, uuid, bigint) to authenticated;
grant execute on function public.superadmin_notice_change_status_v2(
  uuid, uuid, bigint, text, text) to authenticated;

commit;
