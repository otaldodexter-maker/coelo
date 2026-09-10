-- Client roles must never own or structurally control application tables.
-- TRUNCATE bypasses row-level policies; REFERENCES and TRIGGER are schema
-- administration privileges and are not required by the Flutter Data API.
alter default privileges for role postgres in schema public
  revoke truncate, references, trigger on tables from anon, authenticated;

do $migration$
declare
  relation record;
begin
  for relation in
    select namespace.nspname as schema_name, class.relname as relation_name
    from pg_catalog.pg_class as class
    join pg_catalog.pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'public'
      and class.relkind in ('r', 'p')
  loop
    execute format(
      'revoke truncate, references, trigger on table %I.%I from anon, authenticated',
      relation.schema_name,
      relation.relation_name
    );
  end loop;
end
$migration$;
