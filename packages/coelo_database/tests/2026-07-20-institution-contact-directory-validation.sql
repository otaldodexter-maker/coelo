-- Institution and unit contact directory validation.
-- Run after applying the institution-contact refinement migration.

begin;

do $$
declare
  current_table text;
  foreign_key_delete_action "char";
begin
  foreach current_table in array array['institution_contacts', 'unit_contacts']
  loop
    if to_regclass(format('public.%I', current_table)) is null then
      raise exception 'public.% is missing', current_table;
    end if;

    if exists (
      select required.column_name
      from unnest(array[
        'email', 'phone', 'mobile_phone', 'status', 'created_at', 'updated_at'
      ]) required(column_name)
      except
      select column_name
      from information_schema.columns
      where table_schema = 'public'
        and table_name = current_table
    ) then
      raise exception 'contact columns are incomplete on public.%', current_table;
    end if;

    if not exists (
      select 1
      from pg_constraint
      where conrelid = format('public.%I', current_table)::regclass
        and contype = 'p'
    ) then
      raise exception 'public.% must allow at most one contact row per owner', current_table;
    end if;

    select confdeltype
    into foreign_key_delete_action
    from pg_constraint
    where conrelid = format('public.%I', current_table)::regclass
      and contype = 'f';

    if foreign_key_delete_action is distinct from 'c' then
      raise exception 'public.% foreign key must cascade on delete', current_table;
    end if;

    if not exists (
      select 1
      from pg_class relation
      join pg_namespace namespace on namespace.oid = relation.relnamespace
      where namespace.nspname = 'public'
        and relation.relname = current_table
        and relation.relrowsecurity
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
       or has_table_privilege(
         'authenticated',
         format('public.%I', current_table),
         'INSERT,UPDATE,DELETE'
       ) then
      raise exception 'explicit grants are invalid on public.%', current_table;
    end if;

    if not exists (
      select 1
      from public.schema_tables
      where schema_name = 'public'
        and table_name = current_table
        and status = 'active'
    ) then
      raise exception 'schema catalog entry is missing for public.%', current_table;
    end if;
  end loop;

  if exists (
    select required.column_name
    from unnest(array[
      'district', 'contact_email', 'contact_phone', 'contact_mobile_phone'
    ]) required(column_name)
    except
    select column_name
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'institution_directory'
  ) then
    raise exception 'institution_directory contact columns are incomplete';
  end if;

  if to_regclass('public.institution_directory_locations') is null then
    raise exception 'institution_directory_locations is missing';
  end if;

  foreach current_table in array array[
    'institution_directory', 'institution_directory_locations'
  ]
  loop
    if not exists (
      select 1
      from pg_class relation
      join pg_namespace namespace on namespace.oid = relation.relnamespace
      where namespace.nspname = 'public'
        and relation.relname = current_table
        and relation.relkind = 'v'
        and 'security_invoker=true' = any(coalesce(relation.reloptions, array[]::text[]))
    ) then
      raise exception 'public.% must be a security_invoker view', current_table;
    end if;

    if has_table_privilege('anon', format('public.%I', current_table), 'SELECT')
       or not has_table_privilege('authenticated', format('public.%I', current_table), 'SELECT') then
      raise exception 'view grants are invalid on public.%', current_table;
    end if;
  end loop;
end $$;

do $$
declare
  institution_id uuid;
  unit_id uuid;
  rejected boolean;
begin
  insert into public.institutions(public_name, legal_name, slug)
  values (
    'Instituicao contato validacao',
    'Instituicao contato validacao LTDA',
    'institution-contact-directory-validation'
  )
  returning id into institution_id;

  insert into public.units(institution_id, name, slug)
  values (institution_id, 'Unidade contato validacao', 'unit-contact-validation')
  returning id into unit_id;

  insert into public.institution_contacts(
    institution_id,
    email,
    phone,
    mobile_phone
  ) values (
    institution_id,
    'contato@instituicao.test',
    '+55 11 3333-4444',
    '+55 11 99999-8888'
  );

  insert into public.unit_contacts(unit_id, email)
  values (unit_id, 'unidade@instituicao.test');

  begin
    insert into public.institution_contacts(institution_id, email)
    values (institution_id, 'duplicado@instituicao.test');
    rejected := false;
  exception when unique_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'duplicate institution contact was accepted';
  end if;

  begin
    insert into public.unit_contacts(unit_id, phone)
    values (unit_id, ' ');
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'blank unit phone was accepted';
  end if;

  begin
    insert into public.unit_contacts(unit_id, email)
    values (gen_random_uuid(), 'invalid-unit@instituicao.test');
    rejected := false;
  exception when foreign_key_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'invalid unit contact reference was accepted';
  end if;

  begin
    insert into public.institution_contacts(institution_id, email)
    values (gen_random_uuid(), 'invalid-institution@instituicao.test');
    rejected := false;
  exception when foreign_key_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'invalid institution contact reference was accepted';
  end if;
end $$;

rollback;
