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
--     or one issued for another scope fails without returning rows.
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

    with filtered as (
      select notice_record.*,
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
          filtered.id desc) page_row
      from filtered
      where cursor_sort_value is null
        or (p_sort_ascending and (filtered.sort_value, filtered.id) > (cursor_sort_value, cursor_id))
        or (not p_sort_ascending and (filtered.sort_value, filtered.id) < (cursor_sort_value, cursor_id))
      order by
        case when p_sort_ascending then filtered.sort_value end asc,
        case when not p_sort_ascending then filtered.sort_value end desc,
        filtered.id desc
      limit p_limit + 1
    )
    select coalesce(jsonb_agg(app_private.superadmin_notice_json(page)
      order by
        case when p_sort_ascending then page.sort_value end asc,
        case when not p_sort_ascending then page.sort_value end desc,
        page.id desc) filter(where page.page_row <= p_limit), '[]'::jsonb),
      count(*) > p_limit
    into items, has_more from page;

    if has_more then
      select page.sort_value, page.updated_at, page.id into next_row
      from (
        select filtered.*,
          row_number() over(order by
            case when p_sort_ascending then filtered.sort_value end asc,
            case when not p_sort_ascending then filtered.sort_value end desc,
            filtered.id desc) page_row
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

do $acl$
declare function_record regprocedure;
begin
  for function_record in
    select procedure_record.oid::regprocedure
    from pg_proc procedure_record
    join pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where (namespace_record.nspname = 'app_private'
      and procedure_record.proname like 'superadmin_notice_%')
      or (namespace_record.nspname = 'public'
      and procedure_record.proname like 'superadmin_notice_%_v2')
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

commit;
