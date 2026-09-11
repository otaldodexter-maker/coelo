begin;

-- A01: nominal read contract only. Keep the spec-039 actor and denial helpers.
create or replace function public.superadmin_activity_directory_v2(
  p_filters jsonb default '{}'::jsonb, p_limit integer default 24,
  p_offset integer default 0, p_sort text default 'name',
  p_sort_ascending boolean default true
) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  result jsonb;
  filters jsonb := '{}'::jsonb;
  dimension text;
  scalar_key text;
  values_json jsonb;
  member jsonb;
  normalized text;
  normalized_values jsonb;
  search_text text;
  code text;
begin
  begin
    select * into strict ctx
      from app_private.activity_v2_require_context('activities.read', null);
    if p_filters is null or jsonb_typeof(p_filters) <> 'object' then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;
    if p_filters - array['search','institution_id','unit_id','group_id','status',
        'institution_ids','unit_ids','group_ids','statuses','origins'] <> '{}'::jsonb
      or p_limit is null or p_limit not between 1 and 100
      or p_offset is null or p_offset < 0
      or p_sort is null or p_sort not in ('name','status','created_at','updated_at')
      or p_sort_ascending is null then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;
    if p_filters ? 'search' and jsonb_typeof(p_filters->'search') not in ('string','null') then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;
    search_text := nullif(btrim(p_filters->>'search'), '');
    if length(coalesce(search_text, '')) > 120 then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;

    -- Validate sequentially before expansion/casts, including normalized UUID
    -- duplicates. Scalar and array forms may not coexist, even if empty.
    foreach dimension in array array['institution_ids','unit_ids','group_ids','statuses','origins'] loop
      scalar_key := case dimension when 'institution_ids' then 'institution_id'
        when 'unit_ids' then 'unit_id' when 'group_ids' then 'group_id'
        when 'statuses' then 'status' else null end;
      values_json := '[]'::jsonb;
      if p_filters ? dimension then
        if scalar_key is not null and p_filters ? scalar_key then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        end if;
        values_json := p_filters->dimension;
        if jsonb_typeof(values_json) is distinct from 'array' then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        end if;
      elsif scalar_key is not null and p_filters ? scalar_key then
        -- Historical scalar null/empty means no filter; array null is invalid.
        if jsonb_typeof(p_filters->scalar_key) not in ('string','null') then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        end if;
        if p_filters->>scalar_key <> '' then
          values_json := jsonb_build_array(p_filters->scalar_key);
        end if;
      end if;
      if jsonb_array_length(values_json) > 100 then
        raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
      end if;
      normalized_values := '[]'::jsonb;
      for member in select value from jsonb_array_elements(values_json) loop
        if jsonb_typeof(member) <> 'string' then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        end if;
        normalized := member#>>'{}';
        if dimension in ('institution_ids','unit_ids','group_ids') then
          normalized := app_private.activity_v2_safe_uuid(normalized)::text;
        elsif dimension = 'statuses' and normalized not in ('draft','active','inactive','suspended','archived') then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        elsif dimension = 'origins' and normalized not in ('institution','unit') then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        end if;
        if normalized_values ? normalized then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        end if;
        normalized_values := normalized_values || jsonb_build_array(normalized);
      end loop;
      filters := filters || jsonb_build_object(dimension, normalized_values);
    end loop;

    with filtered as (
      select a.* from public.activity_definitions a
      where (ctx.scope_kind <> 'institution' or a.institution_id = ctx.scope_institution_id)
        and (filters->'institution_ids' = '[]'::jsonb or filters->'institution_ids' ? a.institution_id::text)
        and (filters->'statuses' = '[]'::jsonb or filters->'statuses' ? a.status::text)
        and (filters->'origins' = '[]'::jsonb or filters->'origins' ? a.origin_scope_kind::text)
        -- strpos makes %, _ and backslash literal, never SQL patterns.
        and (search_text is null or strpos(lower(a.name), lower(search_text)) > 0
          or strpos(lower(coalesce(a.description,'')), lower(search_text)) > 0)
        and (filters->'unit_ids' = '[]'::jsonb or exists (
          select 1 from public.activity_unit_links ul
          where ul.activity_id = a.id and ul.institution_id = a.institution_id
            and ul.status = 'active' and filters->'unit_ids' ? ul.unit_id::text))
        and (filters->'group_ids' = '[]'::jsonb or exists (
          select 1 from public.activity_group_links gl
          where gl.activity_id = a.id and gl.institution_id = a.institution_id
            and gl.status = 'active' and filters->'group_ids' ? gl.group_id::text))
    ), ordered as (
      select f.*, row_number() over (order by
        case when p_sort = 'name' and p_sort_ascending then f.name end asc,
        case when p_sort = 'name' and not p_sort_ascending then f.name end desc,
        case when p_sort = 'status' and p_sort_ascending then f.status::text end asc,
        case when p_sort = 'status' and not p_sort_ascending then f.status::text end desc,
        case when p_sort = 'created_at' and p_sort_ascending then f.created_at end asc,
        case when p_sort = 'created_at' and not p_sort_ascending then f.created_at end desc,
        case when p_sort = 'updated_at' and p_sort_ascending then f.updated_at end asc,
        case when p_sort = 'updated_at' and not p_sort_ascending then f.updated_at end desc,
        f.id asc) as ordinal
      from filtered f
    ), page as (
      select * from ordered order by ordinal limit p_limit offset p_offset
    ), projected as (
      select p.ordinal, jsonb_build_object(
        'id',p.id,'activity_id',p.id,'institution_id',p.institution_id,
        'institution_name',i.public_name,'name',p.name,'status',p.status,
        'description',p.description,'origin_scope_kind',p.origin_scope_kind,
        'distribution_scope',p.distribution_scope,'governance_kind',p.governance_kind,
        'handle_stem',p.handle_stem,'canonical_handle',p.canonical_handle,
        'management_version',p.management_version,'icon_key',p.identity_icon,
        'initials',p.identity_initials,'created_at',p.created_at,'updated_at',p.updated_at,
        'active_unit_count',jsonb_array_length(units.items),'unit_count',jsonb_array_length(units.items),
        'active_group_count',jsonb_array_length(groups.items),'group_count',jsonb_array_length(groups.items),
        'linked_units',units.items,'linked_groups',groups.items) as item
      from page p join public.institutions i on i.id = p.institution_id
      cross join lateral (
        select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'institution_id',u.institution_id,
          'name',u.name) order by u.name,u.id),'[]'::jsonb) as items
        from public.activity_unit_links ul join public.units u
          on u.id = ul.unit_id and u.institution_id = p.institution_id
        where ul.activity_id = p.id and ul.institution_id = p.institution_id and ul.status = 'active'
      ) units
      cross join lateral (
        select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'unit_id',g.unit_id,
          'name',g.name,'unit_name',u.name) order by g.name,g.id),'[]'::jsonb) as items
        from public.activity_group_links gl join public.groups g
          on g.id = gl.group_id and g.unit_id = gl.unit_id and g.institution_id = p.institution_id
        join public.units u on u.id = g.unit_id and u.institution_id = p.institution_id
        where gl.activity_id = p.id and gl.institution_id = p.institution_id and gl.status = 'active'
      ) groups
    )
    select jsonb_build_object('items',coalesce(jsonb_agg(item order by ordinal),'[]'::jsonb),
      'total',(select count(*) from filtered),'limit',p_limit,'offset',p_offset)
    into result from projected;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code,''),'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    return app_private.activity_v2_denied_envelope('activities.read','activity.directory',code,
      correlation,case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null end);
  end if;
  -- Audit failure must propagate: do not place this append inside the read
  -- exception block or return any data before the append succeeds.
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'activities.read',ctx.aal,'activity.directory','success'::public.audit_outcome,null::text,
    correlation,case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null::uuid end,
    null::text,null::uuid,jsonb_build_object('row_count',jsonb_array_length(result->'items')));
  return app_private.activity_v2_success_envelope(
    result || jsonb_build_object('correlation_id',correlation));
end $$;

create function public.superadmin_activity_filter_options_v2()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  result jsonb;
  code text;
begin
  begin
    select * into strict ctx from app_private.activity_v2_require_context('activities.read',null);
    with institutions as (
      select i.id,i.public_name from public.institutions i
      where i.deleted_at is null
        and (ctx.scope_kind <> 'institution' or i.id = ctx.scope_institution_id)
    ), units as (
      select u.id,u.institution_id,u.name from public.units u
      join institutions i on i.id = u.institution_id
      where u.status <> 'archived'
    ), groups as (
      select g.id,g.unit_id,g.name from public.groups g
      join units u on u.id = g.unit_id and u.institution_id = g.institution_id
      where g.status <> 'archived'
    )
    select jsonb_build_object(
      'institutions',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',public_name)
        order by public_name,id),'[]'::jsonb) from institutions),
      'units',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name,'parent_id',institution_id)
        order by name,id),'[]'::jsonb) from units),
      'groups',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name,'parent_id',unit_id)
        order by name,id),'[]'::jsonb) from groups)) into result;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code,''),'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    return app_private.activity_v2_denied_envelope('activities.read','activity.filter_options',code,
      correlation,case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null end);
  end if;
  -- The collection audit contains counts only, never filters or row payloads.
  -- Keep the append outside the exception block so an audit failure aborts.
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'activities.read',ctx.aal,'activity.filter_options','success'::public.audit_outcome,null::text,
    correlation,case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null::uuid end,
    null::text,null::uuid,jsonb_build_object('row_count',
      jsonb_array_length(result->'institutions') + jsonb_array_length(result->'units')
      + jsonb_array_length(result->'groups')));
  return app_private.activity_v2_success_envelope(
    result || jsonb_build_object('correlation_id',correlation));
end $$;

alter function public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean) owner to postgres;
alter function public.superadmin_activity_filter_options_v2() owner to postgres;
revoke all on function public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_activity_filter_options_v2()
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean) to authenticated;
grant execute on function public.superadmin_activity_filter_options_v2() to authenticated;

commit;
