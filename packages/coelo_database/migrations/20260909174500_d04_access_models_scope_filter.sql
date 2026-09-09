-- D04 nominal READ correction: retain scalar/null compatibility and filter
-- selected model scopes as a server-side union before cursor pagination.
-- No public signature, authorization helper, write, owner or grant changes.
begin;

create temporary table d04_access_models_scope_acl on commit drop as
select oid,proowner,proacl,prosecdef,provolatile,proconfig
from pg_catalog.pg_proc
where oid='app_private.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure;

do $$
begin
  if not exists(select 1 from d04_access_models_scope_acl
    where proowner='postgres'::regrole and prosecdef and provolatile='s') then
    raise exception 'D04 model scope cursor provenance mismatch';
  end if;
  if pg_catalog.has_function_privilege('authenticated',
    'app_private.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)','execute') then
    raise exception 'D04 model scope private cursor unexpectedly exposed';
  end if;
end
$$;

create or replace function app_private.superadmin_access_profile_models_cursor(
  p_query text default null,
  p_domain text default null,
  p_status text default null,
  p_scope text default null,
  p_limit integer default 25,
  p_after_name text default null,
  p_after_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  size_no integer:=least(greatest(coalesce(p_limit,25),1),100);
  scope_values text[];
  allowed_scopes text[];
  result jsonb;
begin
  perform app_private.access_profile_require_model_action(p_domain,'read',false);
  if p_domain not in('platform','institution','principal')
    or char_length(coalesce(p_query,''))>120
    or char_length(coalesce(p_scope,''))>120
    or (p_status is not null and p_status not in('active','inactive'))
    or (p_after_name is null)<>(p_after_id is null) then
    raise invalid_parameter_value using message='invalid access model query';
  end if;
  if p_scope is not null then
    scope_values:=pg_catalog.string_to_array(p_scope,',');
    allowed_scopes:=case p_domain
      when 'platform' then array['platform','institution']::text[]
      when 'institution' then array['institution','unit','group']::text[]
      else array['child_context']::text[] end;
    if pg_catalog.cardinality(scope_values)=0
      or not scope_values <@ allowed_scopes then
      raise invalid_parameter_value using message='invalid access model scope filter';
    end if;
  end if;
  with rows as (
    select model.id,model.domain,model.code,model.name,model.description,
      model.status::text,model.max_scope_kind,model.version,model.is_system,
      case model.domain
        when 'platform' then (select count(*) from public.access_profile_template_platform_permissions item where item.template_id=model.id)
        when 'institution' then (select count(*) from public.access_profile_template_institution_permissions item where item.template_id=model.id)
        else (select count(*) from public.access_profile_template_principal_capabilities item where item.template_id=model.id)
      end::integer capability_count
    from public.access_profile_templates model
    where model.domain=p_domain
      and (nullif(btrim(p_query),'') is null or model.name ilike '%'||btrim(p_query)||'%')
      and (p_status is null or model.status::text=p_status)
      and (scope_values is null or model.max_scope_kind=any(scope_values))
      and (p_after_name is null or (lower(model.name),model.id)>(lower(p_after_name),p_after_id))
  ), page as (
    select * from rows order by lower(name),id limit size_no+1
  )
  select jsonb_build_object(
    'items',coalesce(jsonb_agg(to_jsonb(page) order by lower(name),id)
      filter(where row_number<=size_no),'[]'::jsonb),
    'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',name,'id',id)
        from page order by lower(name),id offset size_no-1 limit 1) end
  ) into result
  from (select page.*,row_number() over(order by lower(name),id) row_number from page) page;
  return result;
end
$$;

do $$
begin
  if exists(select 1 from d04_access_models_scope_acl before
    join pg_catalog.pg_proc after on after.oid=before.oid
    where (before.proowner,before.proacl,before.prosecdef,before.provolatile,before.proconfig)
      is distinct from
      (after.proowner,after.proacl,after.prosecdef,after.provolatile,after.proconfig)) then
    raise exception 'D04 model scope cursor changed owner, ACL or execution metadata';
  end if;
end
$$;
commit;
