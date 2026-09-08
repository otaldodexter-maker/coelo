-- F-READ01. New read-only SAI boundary; legacy Forms commands remain unchanged.
begin;

do $preflight$
declare argument_probe jsonb;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'F-READ01 must be applied as postgres';
  end if;
  if pg_catalog.to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or pg_catalog.to_regtype('app_private.superadmin_internal_context') is null
    or pg_catalog.to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)') is null
    or pg_catalog.to_regclass('public.forms') is null
    or pg_catalog.to_regclass('public.form_occurrences') is null
    or pg_catalog.to_regclass('public.platform_permissions') is null then
    raise object_not_in_prerequisite_state using message = 'F-READ01 requires the nominal internal Auth and Forms foundation';
  end if;
  if not exists(select 1 from public.platform_permissions where code='forms.read' and status='active') then
    raise object_not_in_prerequisite_state using message = 'F-READ01 requires the active forms.read capability';
  end if;
  argument_probe := app_private.superadmin_internal_error_envelope('SAI_INVALID_ARGUMENT',pg_catalog.gen_random_uuid());
  if argument_probe #>> '{error,code}' is distinct from 'SAI_INVALID_ARGUMENT'
    or argument_probe #>> '{error,http_status}' is distinct from '400' then
    raise object_not_in_prerequisite_state using message = 'F-READ01 requires the SAI_INVALID_ARGUMENT envelope dependency';
  end if;
  if pg_catalog.to_regprocedure('public.superadmin_forms_directory_v2(jsonb)') is not null
    or pg_catalog.to_regprocedure('app_private.superadmin_forms_directory_v2(jsonb)') is not null then
    raise object_not_in_prerequisite_state using message = 'F-READ01 boundary already exists; reconcile the nominal ledger';
  end if;
end
$preflight$;

create function app_private.superadmin_forms_directory_v2(p_query jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := pg_catalog.gen_random_uuid();
  error_code text;
  result jsonb;
  page_limit integer := 25;
  institution_filter uuid;
  search_text text;
  statuses text[] := '{}';
  operational_statuses text[] := '{}';
  kinds text[] := '{}';
  starts_on date;
  ends_on date;
  cursor_updated timestamptz;
  cursor_id uuid;
  field_name text;
  allowed_values text[];
  values_array text[];
begin
  -- The guard must run before any cast or query derived from client input.
  select * into strict ctx from app_private.require_superadmin_internal_context('forms.read');
  if ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
    or (ctx.scope_kind='institution' and ctx.scope_institution_id is null)
    or ctx.aal is null or ctx.aal not in ('aal1','aal2') then
    raise insufficient_privilege using detail = 'SAI_INTERNAL_CONTEXT_DENIED';
  end if;

  if p_query is null or pg_catalog.jsonb_typeof(p_query) <> 'object'
    or pg_catalog.octet_length(p_query::text) > 16384
    or p_query - array['institution_id','search','statuses','operational_statuses','kinds',
      'starts_on_or_after','ends_on_or_before','cursor_updated_at','cursor_id','limit'] <> '{}'::jsonb then
    raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
  end if;
  if p_query ? 'limit' then
    if pg_catalog.jsonb_typeof(p_query->'limit') is distinct from 'number'
      or p_query->>'limit' !~ '^[0-9]{1,3}$' then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
    page_limit := (p_query->>'limit')::integer;
    if page_limit not between 1 and 100 then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
  end if;

  foreach field_name in array array['institution_id','search','starts_on_or_after','ends_on_or_before','cursor_updated_at','cursor_id'] loop
    if p_query ? field_name and p_query->field_name <> 'null'::jsonb
      and pg_catalog.jsonb_typeof(p_query->field_name) <> 'string' then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
  end loop;
  if p_query->>'institution_id' is not null then
    if p_query->>'institution_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
    institution_filter := (p_query->>'institution_id')::uuid;
  end if;
  search_text := p_query->>'search';
  if pg_catalog.char_length(search_text) > 500 then
    raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
  end if;
  search_text := nullif(search_text,'');
  -- Search is literal, not a client-authored LIKE pattern.
  search_text := pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(search_text,'\','\\'),'%','\%'),'_','\_');

  foreach field_name in array array['statuses','operational_statuses','kinds'] loop
    if not (p_query ? field_name) then continue; end if;
    if pg_catalog.jsonb_typeof(p_query->field_name) is distinct from 'array' then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
    allowed_values := case field_name
      when 'statuses' then array['draft','published','archived']
      when 'operational_statuses' then array['draft','scheduled','active','closed','archived']
      else array['form','quick_poll'] end;
    if pg_catalog.jsonb_array_length(p_query->field_name) > pg_catalog.cardinality(allowed_values)
      or exists(select 1 from pg_catalog.jsonb_array_elements(p_query->field_name) entry
        where pg_catalog.jsonb_typeof(entry) <> 'string' or not ((entry #>> '{}')=any(allowed_values))) then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
    select coalesce(pg_catalog.array_agg(entry),'{}'::text[]) into values_array
      from pg_catalog.jsonb_array_elements_text(p_query->field_name) entry;
    case field_name
      when 'statuses' then statuses := values_array;
      when 'operational_statuses' then operational_statuses := values_array;
      else kinds := values_array;
    end case;
  end loop;

  foreach field_name in array array['starts_on_or_after','ends_on_or_before'] loop
    if p_query->>field_name is not null and p_query->>field_name !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
  end loop;
  starts_on := (p_query->>'starts_on_or_after')::date;
  ends_on := (p_query->>'ends_on_or_before')::date;
  if starts_on > ends_on then
    raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
  end if;
  if ((p_query->>'cursor_updated_at') is null) <> ((p_query->>'cursor_id') is null) then
    raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
  end if;
  if p_query->>'cursor_id' is not null then
    if p_query->>'cursor_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or p_query->>'cursor_updated_at' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ](0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]{1,6})?(Z|[+-](0[0-9]|1[0-5]):[0-5][0-9])$' then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
    cursor_id := (p_query->>'cursor_id')::uuid;
    cursor_updated := (p_query->>'cursor_updated_at')::timestamptz;
    if not pg_catalog.isfinite(cursor_updated) then
      raise invalid_parameter_value using detail = 'SAI_INVALID_ARGUMENT';
    end if;
  end if;

  with scoped as materialized (
    select f.id,f.institution_id,f.title,f.kind,f.status,f.identity_mode,f.updated_at,f.management_version
    from public.forms f
    where (ctx.scope_kind='platform' or (ctx.scope_kind='institution' and f.institution_id=ctx.scope_institution_id))
      and (institution_filter is null or f.institution_id=institution_filter)
      and (search_text is null or f.title ilike '%'||search_text||'%' escape '\')
      and (pg_catalog.cardinality(statuses)=0 or f.status=any(statuses))
      and (pg_catalog.cardinality(kinds)=0 or f.kind=any(kinds))
  ), operational as (
    select scoped.*,
      case when scoped.status='archived' then 'archived'
        when scoped.status='draft' then 'draft'
        when coalesce(windows.is_active,false) then 'active'
        when coalesce(windows.is_scheduled,false) then 'scheduled'
        else 'closed' end as operational_status
    from scoped
    left join lateral (
      select pg_catalog.bool_or(o.status in ('scheduled','open') and o.opens_at<=pg_catalog.now() and o.closes_at>pg_catalog.now()) as is_active,
        pg_catalog.bool_or(o.status in ('scheduled','open') and o.opens_at>pg_catalog.now()) as is_scheduled
      from public.form_occurrences o where o.form_id=scoped.id and o.institution_id=scoped.institution_id
    ) windows on true
    where (starts_on is null or exists(select 1 from public.form_occurrences o
      where o.form_id=scoped.id and o.institution_id=scoped.institution_id and o.opens_at::date>=starts_on))
      and (ends_on is null or exists(select 1 from public.form_occurrences o
      where o.form_id=scoped.id and o.institution_id=scoped.institution_id and o.closes_at::date<=ends_on))
  ), page as materialized (
    select operational.* from operational
    where (pg_catalog.cardinality(operational_statuses)=0 or operational_status=any(operational_statuses))
      and (cursor_updated is null or (updated_at,id)<(cursor_updated,cursor_id))
    order by updated_at desc,id desc limit page_limit+1
  ), visible as materialized (
    select * from page order by updated_at desc,id desc limit page_limit
  )
  select pg_catalog.jsonb_build_object(
    'items',coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',id,'title',title,'kind',kind,'status',status,'operational_status',operational_status,
      'identity_mode',identity_mode,'updated_at',updated_at,'management_version',management_version
    ) order by updated_at desc,id desc),'[]'::jsonb),
    'has_more',(select count(*)>page_limit from page),
    'next_cursor',case when (select count(*)>page_limit from page) then
      (select pg_catalog.jsonb_build_object('updated_at',updated_at,'id',id) from visible order by updated_at,id limit 1)
      else null end
  ) into result from visible;
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
exception
  when invalid_parameter_value or invalid_text_representation or datetime_field_overflow or invalid_datetime_format or numeric_value_out_of_range then
    return app_private.superadmin_internal_error_envelope('SAI_INVALID_ARGUMENT',correlation);
  when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
end
$function$;

create function public.superadmin_forms_directory_v2(p_query jsonb default '{}'::jsonb)
returns jsonb language sql stable security definer set search_path='' as $function$
  select app_private.superadmin_forms_directory_v2(p_query);
$function$;

alter function app_private.superadmin_forms_directory_v2(jsonb) owner to postgres;
alter function public.superadmin_forms_directory_v2(jsonb) owner to postgres;
revoke all on function app_private.superadmin_forms_directory_v2(jsonb) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_forms_directory_v2(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_forms_directory_v2(jsonb) to authenticated;

comment on function public.superadmin_forms_directory_v2(jsonb) is
  'F-READ01 internal Superadmin directory; forms.read and real internal scope before keyset pagination. Does not confer authoring, response or media permissions.';
commit;
