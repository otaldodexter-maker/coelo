-- Schema boundaries and catalog validation.
-- Run after applying the schema-boundaries/catalog migration.

select nspname as required_schema
from pg_namespace
where nspname in ('public', 'app_private', 'audit', 'analytics')
order by nspname;

select table_schema, table_name
from information_schema.tables
where table_type = 'BASE TABLE'
  and (
    (table_schema = 'audit' and table_name in ('audit_logs', 'support_session_actions'))
    or (table_schema = 'analytics' and table_name in ('analytics_events', 'notice_events', 'usage_counters', 'usage_snapshots'))
  )
order by table_schema, table_name;

select table_schema, table_name
from information_schema.tables
where table_type = 'BASE TABLE'
  and table_schema = 'public'
  and table_name in ('audit_logs', 'support_session_actions', 'analytics_events', 'notice_events', 'usage_counters', 'usage_snapshots');

select grantee, table_schema, table_name, privilege_type
from information_schema.role_table_grants
where table_schema in ('audit', 'analytics')
  and grantee in ('anon', 'authenticated')
order by table_schema, table_name, grantee, privilege_type;

with expected_tables as (
  select table_schema, table_name
  from information_schema.tables
  where table_type = 'BASE TABLE'
    and table_schema in ('public', 'audit', 'analytics')
    and table_name <> 'schema_migrations'
),
catalog_tables as (
  select schema_name as table_schema, table_name
  from public.schema_tables
  where status = 'active'
)
select et.table_schema, et.table_name
from expected_tables et
left join catalog_tables ct
  on ct.table_schema = et.table_schema
 and ct.table_name = et.table_name
where ct.table_name is null
order by et.table_schema, et.table_name;

with expected_columns as (
  select c.table_schema, c.table_name, c.column_name
  from information_schema.columns c
  join information_schema.tables t
    on t.table_schema = c.table_schema
   and t.table_name = c.table_name
   and t.table_type = 'BASE TABLE'
  where c.table_schema in ('public', 'audit', 'analytics')
    and c.table_name <> 'schema_migrations'
),
catalog_columns as (
  select st.schema_name as table_schema, st.table_name, sc.column_name
  from public.schema_columns sc
  join public.schema_tables st on st.id = sc.schema_table_id
  where st.status = 'active'
    and sc.is_active = true
)
select ec.table_schema, ec.table_name, ec.column_name
from expected_columns ec
left join catalog_columns cc
  on cc.table_schema = ec.table_schema
 and cc.table_name = ec.table_name
 and cc.column_name = ec.column_name
where cc.column_name is null
order by ec.table_schema, ec.table_name, ec.column_name;
