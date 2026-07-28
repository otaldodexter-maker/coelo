-- Institution profile and legal representatives validation.
-- Run after applying 20260728172333_institution_profile_and_legal_representatives.sql.

begin;

do $$
declare
  required_column text;
  required_color text;
  expected_catalog_columns integer;
  actual_catalog_columns integer;
begin
  foreach required_column in array array[
    'tertiary_color',
    'secondary_text_color',
    'tertiary_text_color',
    'profile_bio',
    'profile_links'
  ] loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'institution_branding'
        and column_name = required_column
    ) then
      raise exception 'institution_branding.% is missing', required_column;
    end if;
  end loop;

  foreach required_color in array array[
    'accent_color',
    'secondary_color',
    'tertiary_color',
    'text_color',
    'secondary_text_color',
    'tertiary_text_color',
    'surface_color'
  ] loop
    if not exists (
      select 1
      from pg_constraint
      where conrelid = 'public.institution_branding'::regclass
        and contype = 'c'
        and pg_get_constraintdef(oid) like '%' || required_color || '%'
    ) then
      raise exception 'color constraint is missing for %', required_color;
    end if;
  end loop;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.institution_branding'::regclass
      and conname = 'institution_branding_profile_bio_length_check'
  ) or not exists (
    select 1 from pg_constraint
    where conrelid = 'public.institution_branding'::regclass
      and conname = 'institution_branding_profile_links_check'
  ) then
    raise exception 'branding profile constraints are incomplete';
  end if;

  if to_regprocedure(
    'app_private.institution_profile_links_are_valid(jsonb)'
  ) is null then
    raise exception 'profile links validator is missing';
  end if;

  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'app_private'
      and procedure.proname = 'institution_profile_links_are_valid'
      and (
        procedure.prosecdef
        or not ('search_path=""' = any(coalesce(procedure.proconfig, array[]::text[])))
      )
  ) then
    raise exception 'profile links validator must be invoker-safe with empty search_path';
  end if;

  foreach required_column in array array['website_url', 'whatsapp_number']
  loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'institution_contacts'
        and column_name = required_column
    ) then
      raise exception 'institution_contacts.% is missing', required_column;
    end if;
  end loop;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.institution_contacts'::regclass
      and conname = 'institution_contacts_website_url_length_check'
  ) or not exists (
    select 1 from pg_constraint
    where conrelid = 'public.institution_contacts'::regclass
      and conname = 'institution_contacts_whatsapp_number_e164_check'
  ) then
    raise exception 'website length and WhatsApp E.164 constraints are incomplete';
  end if;

  if to_regclass('public.institution_legal_representatives') is null then
    raise exception 'institution_legal_representatives is missing';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.institution_legal_representatives'::regclass
      and conname = 'institution_legal_representatives_membership_tenant_fkey'
  ) then
    raise exception 'same-tenant membership foreign key is missing';
  end if;

  if to_regprocedure(
    'app_private.validate_institution_legal_representative()'
  ) is null then
    raise exception 'legal representative validator is missing';
  end if;

  if not exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'institution_legal_representatives'
      and relation.relrowsecurity
  ) then
    raise exception 'RLS is not enabled on institution_legal_representatives';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'institution_legal_representatives'
      and roles = array['authenticated']::name[]
      and cmd = 'SELECT'
      and qual like '%has_platform_permission%platform.read%'
  ) then
    raise exception 'platform.read policy is missing';
  end if;

  if has_table_privilege(
       'anon', 'public.institution_legal_representatives', 'SELECT'
     )
     or not has_table_privilege(
       'authenticated', 'public.institution_legal_representatives', 'SELECT'
     )
     or has_table_privilege(
       'authenticated',
       'public.institution_legal_representatives',
       'INSERT,UPDATE,DELETE'
     )
     or not has_table_privilege(
       'service_role',
       'public.institution_legal_representatives',
       'SELECT,INSERT,UPDATE,DELETE'
     ) then
    raise exception 'legal representative grants are invalid';
  end if;

  if not exists (
    select 1 from public.schema_tables
    where schema_name = 'public'
      and table_name = 'institution_legal_representatives'
      and status = 'active'
  ) then
    raise exception 'legal representatives schema table catalog entry is missing';
  end if;

  select count(*)
    into expected_catalog_columns
  from information_schema.columns
  where table_schema = 'public'
    and table_name in (
      'institution_branding',
      'institution_contacts',
      'institution_legal_representatives'
    );

  select count(*)
    into actual_catalog_columns
  from public.schema_columns column_catalog
  join public.schema_tables table_catalog
    on table_catalog.id = column_catalog.schema_table_id
  where table_catalog.schema_name = 'public'
    and table_catalog.table_name in (
      'institution_branding',
      'institution_contacts',
      'institution_legal_representatives'
    )
    and table_catalog.status = 'active'
    and column_catalog.is_active;

  if actual_catalog_columns <> expected_catalog_columns then
    raise exception
      'schema column catalog incomplete: expected %, got %',
      expected_catalog_columns,
      actual_catalog_columns;
  end if;
end $$;

do $$
declare
  institution_a uuid;
  institution_b uuid;
  adult_person uuid;
  other_adult_person uuid;
  child_person uuid;
  membership_a uuid;
  membership_b uuid;
  rejected boolean;
begin
  insert into public.institutions(public_name, legal_name, slug)
  values ('Representantes A', 'Representantes A LTDA', 'representatives-validation-a')
  returning id into institution_a;

  insert into public.institutions(public_name, legal_name, slug)
  values ('Representantes B', 'Representantes B LTDA', 'representatives-validation-b')
  returning id into institution_b;

  insert into public.people(
    person_type, first_name, last_name, display_name, date_of_birth
  ) values (
    'adult', 'Pessoa', 'Adulta', 'Pessoa Adulta',
    current_date - interval '30 years'
  ) returning id into adult_person;

  insert into public.people(
    person_type, first_name, last_name, display_name, date_of_birth
  ) values (
    'child', 'Pessoa', 'Menor', 'Pessoa Menor',
    current_date - interval '10 years'
  ) returning id into child_person;

  insert into public.people(
    person_type, first_name, last_name, display_name, date_of_birth
  ) values (
    'adult', 'Outra', 'Pessoa Adulta', 'Outra Pessoa Adulta',
    current_date - interval '35 years'
  ) returning id into other_adult_person;

  insert into public.institution_memberships(
    person_id, institution_id, role_code
  ) values (adult_person, institution_a, 'legal_representative')
  returning id into membership_a;

  insert into public.institution_memberships(
    person_id, institution_id, role_code
  ) values (other_adult_person, institution_b, 'legal_representative')
  returning id into membership_b;

  insert into public.institution_legal_representatives(
    institution_id, person_id, membership_id
  ) values (institution_a, adult_person, membership_a);

  begin
    insert into public.institution_legal_representatives(
      institution_id, person_id, membership_id
    ) values (institution_a, other_adult_person, membership_b);
    rejected := false;
  exception when foreign_key_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'cross-tenant membership was accepted';
  end if;

  insert into public.institution_memberships(
    person_id, institution_id, role_code
  ) values (child_person, institution_a, 'legal_representative')
  returning id into membership_b;

  begin
    insert into public.institution_legal_representatives(
      institution_id, person_id, membership_id
    ) values (institution_a, child_person, membership_b);
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'minor legal representative was accepted';
  end if;

  begin
    insert into public.institution_branding(
      institution_id, accent_color
    ) values (institution_b, 'orange');
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'invalid branding color was accepted';
  end if;

  begin
    insert into public.institution_branding(
      institution_id, profile_links
    ) values (
      institution_b,
      '[{"label":"Site","url":"javascript:alert(1)"}]'::jsonb
    );
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'unsafe profile URL was accepted';
  end if;

  insert into public.institution_contacts(institution_id, website_url)
  values (institution_a, 'https://coelo.me');

  begin
    update public.institution_contacts
    set whatsapp_number = '+55 (11) 99999-8888'
    where institution_id = institution_a;
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'non-E.164 WhatsApp number was accepted';
  end if;

  begin
    update public.institution_contacts
    set website_url = 'https://' || repeat('a', 2048)
    where institution_id = institution_a;
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'oversized website URL was accepted';
  end if;
end $$;

rollback;
