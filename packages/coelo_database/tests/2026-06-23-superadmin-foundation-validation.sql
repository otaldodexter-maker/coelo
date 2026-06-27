-- Superadmin Foundation v1 validation queries.
-- Run after applying 20260623191021_superadmin_foundation_v1.sql.

select count(*) as coelo_public_tables,
       count(*) filter (where c.relrowsecurity) as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname not like 'pg_%'
  and c.relname not like 'schema_migrations';

select schemaname, count(*) as policy_count
from pg_policies
where schemaname = 'public'
group by schemaname;

select routine_schema, routine_name
from information_schema.routines
where routine_schema = 'app_private'
  and routine_name in ('current_person_id', 'has_mfa_aal2', 'has_platform_permission')
order by routine_name;

select (select count(*) from public.platform_roles) as platform_roles,
       (select count(*) from public.platform_permissions) as platform_permissions,
       (select count(*) from public.platform_role_permissions) as role_permissions,
       (select count(*) from public.schema_tables) as schema_tables,
       (select count(*) from public.schema_columns) as schema_columns;
