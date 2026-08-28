begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='internal institution list migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
    ) is null
    or to_regclass('public.institution_directory') is null then
    raise object_not_in_prerequisite_state using
      message='internal Auth and institution directory dependencies are required';
  end if;
end
$preflight$;

create or replace function app_private.superadmin_internal_error_envelope(
  p_code text,p_correlation_id uuid
) returns jsonb
language sql
immutable
security invoker
set search_path=''
as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object('code',case when p_code in(
      'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE',
      'SAI_INVALID_ARGUMENT') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID')
          then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='SAI_INVALID_ARGUMENT' then 'Revise os dados enviados.'
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE')
          then 'O estado mudou. Recarregue e tente novamente.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%'
          then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code='SAI_INVALID_ARGUMENT' then 400
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then 409
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$$;

revoke all on function app_private.superadmin_internal_error_envelope(text,uuid)
  from public,anon,authenticated,service_role;

create function app_private.superadmin_institution_filter_array_v2(
  p_filters jsonb,
  p_key text,
  p_max_items integer,
  p_allowed text[],
  p_require_uuid boolean
) returns text[]
language plpgsql
immutable
security definer
set search_path=''
as $$
declare
  result_values text[];
begin
  if not p_filters ? p_key then
    return '{}'::text[];
  end if;
  if pg_catalog.jsonb_typeof(p_filters->p_key)<>'array'
    or pg_catalog.jsonb_array_length(p_filters->p_key)>p_max_items then
    raise invalid_parameter_value using
      message='invalid institution filter',detail='SAI_INVALID_ARGUMENT';
  end if;
  if exists(
    select 1
    from pg_catalog.jsonb_array_elements(p_filters->p_key) element(value)
    where pg_catalog.jsonb_typeof(value)<>'string'
      or pg_catalog.btrim(value#>>'{}')=''
      or pg_catalog.octet_length(value#>>'{}')>240
  ) then
    raise invalid_parameter_value using
      message='invalid institution filter',detail='SAI_INVALID_ARGUMENT';
  end if;

  select coalesce(
    pg_catalog.array_agg(pg_catalog.btrim(value#>>'{}') order by ordinal),
    '{}'::text[])
  into result_values
  from pg_catalog.jsonb_array_elements(p_filters->p_key)
    with ordinality element(value,ordinal);

  if exists(
    select 1 from pg_catalog.unnest(result_values) value
    group by pg_catalog.lower(value) having count(*)>1
  ) or (p_allowed is not null and exists(
    select 1 from pg_catalog.unnest(result_values) value
    where not(value=any(p_allowed))
  )) then
    raise invalid_parameter_value using
      message='invalid institution filter',detail='SAI_INVALID_ARGUMENT';
  end if;

  if p_require_uuid then
    begin
      select coalesce(pg_catalog.array_agg(value::uuid::text order by ordinal),
        '{}'::text[])
      into result_values
      from pg_catalog.unnest(result_values) with ordinality element(value,ordinal);
    exception when invalid_text_representation then
      raise invalid_parameter_value using
        message='invalid institution filter',detail='SAI_INVALID_ARGUMENT';
    end;
    if exists(
      select 1 from pg_catalog.unnest(result_values) value
      group by value having count(*)>1
    ) then
      raise invalid_parameter_value using
        message='invalid institution filter',detail='SAI_INVALID_ARGUMENT';
    end if;
  end if;
  return result_values;
end
$$;

revoke all on function
  app_private.superadmin_institution_filter_array_v2(
    jsonb,text,integer,text[],boolean)
  from public,anon,authenticated,service_role;

create function app_private.superadmin_institution_directory_payload_v2(
  p_filters jsonb,
  p_limit integer,
  p_offset integer,
  p_sort text,
  p_sort_ascending boolean,
  p_scope_kind text,
  p_scope_institution_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  search_value text;
  status_values text[];
  state_values text[];
  city_values text[];
  district_values text[];
  type_values text[];
  plan_value uuid;
  result_payload jsonb;
begin
  if p_filters is null or p_limit is null or p_offset is null
    or p_sort is null or p_sort_ascending is null
    or pg_catalog.jsonb_typeof(p_filters)<>'object'
    or p_filters-array[
      'search','statuses','plan_id','states','cities','districts','type_ids'
    ]::text[]<>'{}'::jsonb
    or pg_catalog.octet_length(p_filters::text)>8192
    or p_limit not between 1 and 100
    or p_offset not between 0 and 10000
    or p_sort not in(
      'public_name','type_name','units_count','groups_count','plan_name','status',
      'contact_email','contact_phone','contact_mobile_phone','primary_domain',
      'street','postal_code','number','complement','district','city','state')
    or p_scope_kind not in('platform','institution')
    or (p_scope_kind='institution' and p_scope_institution_id is null) then
    raise invalid_parameter_value using
      message='invalid institution list argument',detail='SAI_INVALID_ARGUMENT';
  end if;

  if p_filters ? 'search' then
    if pg_catalog.jsonb_typeof(p_filters->'search')<>'string' then
      raise invalid_parameter_value using
        message='invalid institution search',detail='SAI_INVALID_ARGUMENT';
    end if;
    search_value:=pg_catalog.btrim(p_filters->>'search');
    if search_value='' or pg_catalog.char_length(search_value)>200 then
      raise invalid_parameter_value using
        message='invalid institution search',detail='SAI_INVALID_ARGUMENT';
    end if;
  end if;

  status_values:=app_private.superadmin_institution_filter_array_v2(
    p_filters,'statuses',6,
    array['draft','onboarding','active','inactive','suspended','archived'],false);
  state_values:=app_private.superadmin_institution_filter_array_v2(
    p_filters,'states',20,null,false);
  city_values:=app_private.superadmin_institution_filter_array_v2(
    p_filters,'cities',20,null,false);
  district_values:=app_private.superadmin_institution_filter_array_v2(
    p_filters,'districts',20,null,false);
  type_values:=app_private.superadmin_institution_filter_array_v2(
    p_filters,'type_ids',20,null,true);

  if p_filters ? 'plan_id' then
    if pg_catalog.jsonb_typeof(p_filters->'plan_id')<>'string'
      or pg_catalog.btrim(p_filters->>'plan_id')='' then
      raise invalid_parameter_value using
        message='invalid institution plan filter',detail='SAI_INVALID_ARGUMENT';
    end if;
    begin
      plan_value:=pg_catalog.btrim(p_filters->>'plan_id')::uuid;
    exception when invalid_text_representation then
      raise invalid_parameter_value using
        message='invalid institution plan filter',detail='SAI_INVALID_ARGUMENT';
    end;
  end if;

  with filtered as materialized(
    select directory.*
    from public.institution_directory directory
    where (p_scope_kind='platform'
      or directory.id=p_scope_institution_id)
      and (search_value is null or pg_catalog.strpos(
        pg_catalog.lower(directory.search_name),
        pg_catalog.lower(search_value))>0)
      and (pg_catalog.cardinality(status_values)=0
        or directory.status=any(status_values))
      and (plan_value is null or directory.plan_id=plan_value)
      and (pg_catalog.cardinality(state_values)=0
        or pg_catalog.btrim(directory.state)=any(state_values))
      and (pg_catalog.cardinality(city_values)=0
        or pg_catalog.btrim(directory.city)=any(city_values))
      and (pg_catalog.cardinality(district_values)=0
        or pg_catalog.btrim(directory.district)=any(district_values))
      and (pg_catalog.cardinality(type_values)=0
        or directory.institution_type_id=any(type_values::uuid[]))
  ),
  ordered as(
    select filtered.*,
      row_number() over(order by
        case when p_sort='public_name' and p_sort_ascending then public_name end asc nulls last,
        case when p_sort='public_name' and not p_sort_ascending then public_name end desc nulls last,
        case when p_sort='type_name' and p_sort_ascending then type_name end asc nulls last,
        case when p_sort='type_name' and not p_sort_ascending then type_name end desc nulls last,
        case when p_sort='units_count' and p_sort_ascending then units_count end asc nulls last,
        case when p_sort='units_count' and not p_sort_ascending then units_count end desc nulls last,
        case when p_sort='groups_count' and p_sort_ascending then groups_count end asc nulls last,
        case when p_sort='groups_count' and not p_sort_ascending then groups_count end desc nulls last,
        case when p_sort='plan_name' and p_sort_ascending then plan_name end asc nulls last,
        case when p_sort='plan_name' and not p_sort_ascending then plan_name end desc nulls last,
        case when p_sort='status' and p_sort_ascending then status end asc nulls last,
        case when p_sort='status' and not p_sort_ascending then status end desc nulls last,
        case when p_sort='contact_email' and p_sort_ascending then contact_email end asc nulls last,
        case when p_sort='contact_email' and not p_sort_ascending then contact_email end desc nulls last,
        case when p_sort='contact_phone' and p_sort_ascending then contact_phone end asc nulls last,
        case when p_sort='contact_phone' and not p_sort_ascending then contact_phone end desc nulls last,
        case when p_sort='contact_mobile_phone' and p_sort_ascending then contact_mobile_phone end asc nulls last,
        case when p_sort='contact_mobile_phone' and not p_sort_ascending then contact_mobile_phone end desc nulls last,
        case when p_sort='primary_domain' and p_sort_ascending then primary_domain end asc nulls last,
        case when p_sort='primary_domain' and not p_sort_ascending then primary_domain end desc nulls last,
        case when p_sort='street' and p_sort_ascending then street end asc nulls last,
        case when p_sort='street' and not p_sort_ascending then street end desc nulls last,
        case when p_sort='postal_code' and p_sort_ascending then postal_code end asc nulls last,
        case when p_sort='postal_code' and not p_sort_ascending then postal_code end desc nulls last,
        case when p_sort='number' and p_sort_ascending then number end asc nulls last,
        case when p_sort='number' and not p_sort_ascending then number end desc nulls last,
        case when p_sort='complement' and p_sort_ascending then complement end asc nulls last,
        case when p_sort='complement' and not p_sort_ascending then complement end desc nulls last,
        case when p_sort='district' and p_sort_ascending then district end asc nulls last,
        case when p_sort='district' and not p_sort_ascending then district end desc nulls last,
        case when p_sort='city' and p_sort_ascending then city end asc nulls last,
        case when p_sort='city' and not p_sort_ascending then city end desc nulls last,
        case when p_sort='state' and p_sort_ascending then state end asc nulls last,
        case when p_sort='state' and not p_sort_ascending then state end desc nulls last,
        id asc) as row_order
    from filtered
  ),
  page_rows as(
    select * from ordered order by row_order limit p_limit offset p_offset
  )
  select pg_catalog.jsonb_build_object(
    'items',coalesce((select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id',id,'public_name',public_name,'trade_name',trade_name,
        'legal_name',legal_name,'primary_domain',primary_domain,'status',status,
        'institution_type_id',institution_type_id,'type_name',type_name,
        'district',district,'street',street,'number',number,
        'complement',complement,'postal_code',postal_code,'city',city,'state',state,
        'contact_email',contact_email,'contact_phone',contact_phone,
        'contact_mobile_phone',contact_mobile_phone,'plan_id',plan_id,
        'plan_name',plan_name,'units_count',units_count,'groups_count',groups_count)
      order by row_order) from page_rows),'[]'::jsonb),
    'total_count',(select count(*) from filtered),
    'limit',p_limit,'offset',p_offset)
  into result_payload;
  return result_payload;
end
$$;

revoke all on function
  app_private.superadmin_institution_directory_payload_v2(
    jsonb,integer,integer,text,boolean,text,uuid)
  from public,anon,authenticated,service_role;

create function app_private.superadmin_institution_filter_options_payload_v2(
  p_states text[],
  p_cities text[],
  p_scope_kind text,
  p_scope_institution_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  normalized_states text[];
  normalized_cities text[];
  result_payload jsonb;
begin
  if p_states is null or p_cities is null
    or pg_catalog.cardinality(p_states)>20
    or pg_catalog.cardinality(p_cities)>20
    or p_scope_kind not in('platform','institution')
    or (p_scope_kind='institution' and p_scope_institution_id is null)
    or exists(select 1 from pg_catalog.unnest(p_states) value
      where value is null or pg_catalog.btrim(value)=''
        or pg_catalog.octet_length(value)>240)
    or exists(select 1 from pg_catalog.unnest(p_cities) value
      where value is null or pg_catalog.btrim(value)=''
        or pg_catalog.octet_length(value)>240) then
    raise invalid_parameter_value using
      message='invalid institution options argument',detail='SAI_INVALID_ARGUMENT';
  end if;
  select coalesce(pg_catalog.array_agg(pg_catalog.btrim(value)),'{}'::text[])
    into normalized_states from pg_catalog.unnest(p_states) value;
  select coalesce(pg_catalog.array_agg(pg_catalog.btrim(value)),'{}'::text[])
    into normalized_cities from pg_catalog.unnest(p_cities) value;
  if exists(select 1 from pg_catalog.unnest(normalized_states) value
      group by pg_catalog.lower(value) having count(*)>1)
    or exists(select 1 from pg_catalog.unnest(normalized_cities) value
      group by pg_catalog.lower(value) having count(*)>1) then
    raise invalid_parameter_value using
      message='invalid institution options argument',detail='SAI_INVALID_ARGUMENT';
  end if;

  with visible as materialized(
    select directory.* from public.institution_directory directory
    where p_scope_kind='platform' or directory.id=p_scope_institution_id
  ),
  plan_options as(
    select distinct plan_id::text id,plan_name label from visible
    where plan_id is not null and plan_name is not null
  ),type_options as(
    select distinct institution_type_id::text id,type_name label from visible
    where institution_type_id is not null and type_name is not null
  ),state_options as(
    select distinct pg_catalog.btrim(state) id,pg_catalog.btrim(state) label
    from visible where state is not null and pg_catalog.btrim(state)<>''
  ),city_options as(
    select distinct pg_catalog.btrim(city) id,pg_catalog.btrim(city) label
    from visible
    where pg_catalog.cardinality(normalized_states)>0
      and pg_catalog.btrim(state)=any(normalized_states)
      and city is not null and pg_catalog.btrim(city)<>''
  ),district_options as(
    select distinct pg_catalog.btrim(district) id,pg_catalog.btrim(district) label
    from visible
    where pg_catalog.cardinality(normalized_cities)>0
      and pg_catalog.btrim(city)=any(normalized_cities)
      and (pg_catalog.cardinality(normalized_states)=0
        or pg_catalog.btrim(state)=any(normalized_states))
      and district is not null and pg_catalog.btrim(district)<>''
  )
  select pg_catalog.jsonb_build_object(
    'plans',coalesce((select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('id',id,'label',label) order by label,id)
      from plan_options),'[]'::jsonb),
    'types',coalesce((select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('id',id,'label',label) order by label,id)
      from type_options),'[]'::jsonb),
    'states',coalesce((select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('id',id,'label',label) order by label,id)
      from state_options),'[]'::jsonb),
    'cities',coalesce((select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('id',id,'label',label) order by label,id)
      from city_options),'[]'::jsonb),
    'districts',coalesce((select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('id',id,'label',label) order by label,id)
      from district_options),'[]'::jsonb))
  into result_payload;
  return result_payload;
end
$$;

revoke all on function
  app_private.superadmin_institution_filter_options_payload_v2(text[],text[],text,uuid)
  from public,anon,authenticated,service_role;

create function public.superadmin_institution_directory_v2(
  p_filters jsonb default '{}'::jsonb,
  p_limit integer default 50,
  p_offset integer default 0,
  p_sort text default 'public_name',
  p_sort_ascending boolean default true
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid:=gen_random_uuid();
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('platform.read');
    if context_record.platform_role_code not in('owner','operations','auditor') then
      raise insufficient_privilege using
        message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    response_data:=app_private.superadmin_institution_directory_payload_v2(
      p_filters,p_limit,p_offset,p_sort,p_sort_ascending,
      context_record.scope_kind::text,context_record.scope_institution_id);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail='SAI_INVALID_ARGUMENT'
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.read','institution.list',error_code,correlation_id,
      case when context_record.scope_kind='institution'
        then context_record.scope_institution_id end);
    return app_private.superadmin_internal_error_envelope(error_code,correlation_id);
  end if;
  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,context_record.internal_auth_link_id,
    context_record.internal_membership_id,context_record.session_id,
    'platform.read',context_record.aal,'institution.list','success',null,
    correlation_id,case when context_record.scope_kind='institution'
      then context_record.scope_institution_id end);
  return pg_catalog.jsonb_build_object('ok',true,'data',response_data,'error',null);
end
$$;

create function public.superadmin_institution_filter_options_v2(
  p_states text[] default '{}'::text[],
  p_cities text[] default '{}'::text[]
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid:=gen_random_uuid();
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('platform.read');
    if context_record.platform_role_code not in('owner','operations','auditor') then
      raise insufficient_privilege using
        message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    response_data:=app_private.superadmin_institution_filter_options_payload_v2(
      p_states,p_cities,context_record.scope_kind::text,context_record.scope_institution_id);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail='SAI_INVALID_ARGUMENT'
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.read','institution.filter_options',error_code,correlation_id,
      case when context_record.scope_kind='institution'
        then context_record.scope_institution_id end);
    return app_private.superadmin_internal_error_envelope(error_code,correlation_id);
  end if;
  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,context_record.internal_auth_link_id,
    context_record.internal_membership_id,context_record.session_id,
    'platform.read',context_record.aal,'institution.filter_options','success',null,
    correlation_id,case when context_record.scope_kind='institution'
      then context_record.scope_institution_id end);
  return pg_catalog.jsonb_build_object('ok',true,'data',response_data,'error',null);
end
$$;

revoke all on function public.superadmin_institution_directory_v2(
  jsonb,integer,integer,text,boolean)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_institution_filter_options_v2(text[],text[])
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_institution_directory_v2(
  jsonb,integer,integer,text,boolean) to authenticated;
grant execute on function public.superadmin_institution_filter_options_v2(text[],text[])
  to authenticated;

commit;
