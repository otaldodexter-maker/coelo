begin;

do $guard$
begin
  if current_user <> 'postgres' then
    raise exception using
      errcode = '42501',
      message = 'safe replay preflight must run as postgres';
  end if;
end
$guard$;

alter default privileges for role postgres
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema app_private
  revoke execute on functions from public, anon, authenticated, service_role;

create function public.pre_group_execute_probe()
returns integer language sql set search_path = '' as $$ select 1 $$;
create function app_private.pre_group_execute_probe()
returns integer language sql set search_path = '' as $$ select 1 $$;

do $assertion$
declare
  probe regprocedure;
  role_name text;
begin
  foreach probe in array array[
    'public.pre_group_execute_probe()'::regprocedure,
    'app_private.pre_group_execute_probe()'::regprocedure
  ] loop
    foreach role_name in array array['anon', 'authenticated', 'service_role'] loop
      if pg_catalog.has_function_privilege(role_name, probe, 'EXECUTE') then
        raise exception using
          errcode = '42501',
          message = 'safe replay function execute preflight failed';
      end if;
    end loop;

    if exists (
      select 1
      from pg_catalog.pg_proc p
      cross join lateral pg_catalog.aclexplode(
        coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
      ) a
      where p.oid = probe
        and a.grantee = 0
        and a.privilege_type = 'EXECUTE'
    ) then
      raise exception using
        errcode = '42501',
        message = 'safe replay PUBLIC execute preflight failed';
    end if;
  end loop;
end
$assertion$;

drop function public.pre_group_execute_probe();
drop function app_private.pre_group_execute_probe();

commit;
