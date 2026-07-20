-- Institution directory schema validation.
-- Run after applying the institution-directory migration.

begin;

do $$
declare
  expected_columns constant text[] := array[
    'country', 'state', 'city', 'district', 'street', 'number',
    'complement', 'postal_code', 'status', 'created_at', 'updated_at'
  ];
  current_table text;
  foreign_key_delete_action "char";
begin
  if to_regclass('public.institution_types') is null
     or to_regclass('public.institution_addresses') is null
     or to_regclass('public.unit_addresses') is null then
    raise exception 'institution directory tables are missing';
  end if;

  if not exists (
    select 1
    from information_schema.columns column_record
    where column_record.table_schema = 'public'
      and column_record.table_name = 'institutions'
      and column_record.column_name = 'institution_type_id'
      and column_record.is_nullable = 'YES'
  ) then
    raise exception 'institutions.institution_type_id must exist and be nullable';
  end if;

  foreach current_table in array array['institution_addresses', 'unit_addresses']
  loop
    if exists (
      select unnest(expected_columns)
      except
      select column_name
      from information_schema.columns column_record
      where column_record.table_schema = 'public'
        and column_record.table_name = current_table
    ) then
      raise exception 'address columns are incomplete on public.%', current_table;
    end if;
  end loop;

  if (select count(*) from public.institution_types) <> 0 then
    raise exception 'institution_types must start empty';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.institution_addresses'::regclass
      and contype = 'p'
  ) or not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.unit_addresses'::regclass
      and contype = 'p'
  ) then
    raise exception 'each institution and unit must have at most one address';
  end if;

  select confdeltype
  into foreign_key_delete_action
  from pg_constraint
  where conrelid = 'public.institution_addresses'::regclass
    and contype = 'f';

  if foreign_key_delete_action is distinct from 'c' then
    raise exception 'institution address must cascade when its institution is deleted';
  end if;

  select confdeltype
  into foreign_key_delete_action
  from pg_constraint
  where conrelid = 'public.unit_addresses'::regclass
    and contype = 'f';

  if foreign_key_delete_action is distinct from 'c' then
    raise exception 'unit address must cascade when its unit is deleted';
  end if;

  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'institutions'
      and indexdef like '%institution_type_id%'
  ) then
    raise exception 'institution type foreign key index is missing';
  end if;

  foreach current_table in array array['institution_addresses', 'unit_addresses']
  loop
    if not exists (
      select 1
      from pg_indexes
      where schemaname = 'public'
        and tablename = current_table
        and indexdef like '%state%'
        and indexdef like '%city%'
    ) then
      raise exception 'state/city index is missing on public.%', current_table;
    end if;
  end loop;

  foreach current_table in array array['institution_types', 'institution_addresses', 'unit_addresses']
  loop
    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = current_table
        and c.relrowsecurity
    ) then
      raise exception 'RLS is not enabled on public.%', current_table;
    end if;

    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = current_table
        and roles = array['authenticated']::name[]
        and cmd = 'SELECT'
        and qual like '%has_platform_permission%platform.read%'
    ) then
      raise exception 'platform.read policy is missing on public.%', current_table;
    end if;

    if has_table_privilege('anon', format('public.%I', current_table), 'SELECT')
       or not has_table_privilege('authenticated', format('public.%I', current_table), 'SELECT')
       or has_table_privilege('authenticated', format('public.%I', current_table), 'INSERT,UPDATE,DELETE') then
      raise exception 'explicit grants are invalid on public.%', current_table;
    end if;
  end loop;

  if to_regclass('public.institution_directory') is null then
    raise exception 'institution_directory view is missing';
  end if;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'institution_directory'
      and c.relkind = 'v'
      and 'security_invoker=true' = any(coalesce(c.reloptions, array[]::text[]))
  ) then
    raise exception 'institution_directory must be a security_invoker view';
  end if;

  if has_table_privilege('anon', 'public.institution_directory', 'SELECT')
     or not has_table_privilege('authenticated', 'public.institution_directory', 'SELECT') then
    raise exception 'institution_directory grants are invalid';
  end if;

  if exists (
    select required.column_name
    from unnest(array[
      'id', 'public_name', 'trade_name', 'legal_name', 'primary_domain',
      'status', 'institution_type_id', 'type_name', 'city', 'state',
      'plan_id', 'plan_name', 'units_count', 'groups_count', 'search_name'
    ]) required(column_name)
    except
    select column_name
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'institution_directory'
  ) then
    raise exception 'institution_directory columns are incomplete';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'institution_directory'
      and column_name in ('document_ref', 'document_type')
  ) then
    raise exception 'institution_directory must not expose document_ref';
  end if;
end $$;

do $$
declare
  institution_id uuid;
  unit_id uuid;
  rejected boolean;
begin
  begin
    insert into public.institution_types(code, name) values (' ', 'Tipo invalido');
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'blank institution type code was accepted';
  end if;

  insert into public.institutions(public_name, legal_name, slug)
  values ('Instituicao de validacao', 'Instituicao de validacao LTDA', 'institution-directory-validation')
  returning id into institution_id;

  insert into public.units(institution_id, name, slug)
  values (institution_id, 'Unidade de validacao', 'unidade-validacao')
  returning id into unit_id;

  insert into public.institution_addresses(institution_id, state, city)
  values (institution_id, 'SP', 'Sao Paulo');

  begin
    insert into public.institution_addresses(institution_id, state, city)
    values (institution_id, 'SP', 'Sao Paulo');
    rejected := false;
  exception when unique_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'duplicate legal address was accepted';
  end if;

  insert into public.unit_addresses(unit_id, state, city)
  values (unit_id, 'SP', 'Sao Paulo');

  begin
    insert into public.unit_addresses(unit_id, state, city)
    values (unit_id, 'SP', 'Sao Paulo');
    rejected := false;
  exception when unique_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'duplicate unit address was accepted';
  end if;

  begin
    insert into public.institution_addresses(institution_id, state, city)
    values (gen_random_uuid(), 'SP', 'Sao Paulo');
    rejected := false;
  exception when foreign_key_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'invalid institution address reference was accepted';
  end if;

  begin
    insert into public.unit_addresses(unit_id, state, city)
    values (gen_random_uuid(), 'SP', 'Sao Paulo');
    rejected := false;
  exception when foreign_key_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'invalid unit address reference was accepted';
  end if;
end $$;

rollback;
