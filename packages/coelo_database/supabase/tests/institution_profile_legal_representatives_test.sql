begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select has_column(
  'public', 'institution_branding', 'profile_links',
  'institution_branding exposes profile_links'
);
select has_column(
  'public', 'institution_contacts', 'whatsapp_number',
  'institution_contacts exposes whatsapp_number'
);
select has_table(
  'public', 'institution_legal_representatives',
  'normalized legal representatives table exists'
);
select has_pk(
  'public', 'institution_legal_representatives',
  'legal representatives has a primary key'
);
select has_function(
  'app_private',
  'institution_profile_links_are_valid',
  array['jsonb'],
  'profile link validator exists'
);
select has_function(
  'app_private',
  'validate_institution_legal_representative',
  array[]::text[],
  'adult legal representative validator exists'
);
select policies_are(
  'public',
  'institution_legal_representatives',
  array['institution_legal_representatives_platform_read'],
  'legal representatives exposes only the platform read policy'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.institution_legal_representatives'::regclass
      and conname =
        'institution_legal_representatives_membership_tenant_fkey'
      and pg_get_constraintdef(oid)
        like '%(membership_id, institution_id, person_id)%'
  ),
  'composite membership key blocks cross-tenant representative links'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.institution_branding'::regclass
      and conname = 'institution_branding_profile_links_check'
  ),
  'branding profile links are protected by a check constraint'
);
select has_check(
  'public',
  'institution_contacts',
  'institution_contacts_website_url_length_check',
  'website URL is length constrained'
);
select has_check(
  'public',
  'institution_contacts',
  'institution_contacts_whatsapp_number_e164_check',
  'WhatsApp number uses E.164'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.institution_legal_representatives',
    'INSERT,UPDATE,DELETE'
  ),
  'authenticated cannot mutate legal representatives'
);
select ok(
  has_table_privilege(
    'service_role',
    'public.institution_legal_representatives',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'service_role owns the mutation surface'
);
select ok(
  exists (
    select 1 from public.schema_tables
    where schema_name = 'public'
      and table_name = 'institution_legal_representatives'
      and status = 'active'
  ),
  'legal representatives is cataloged'
);

select * from finish();
rollback;
