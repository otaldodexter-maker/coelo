begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

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
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.institution_contacts'::regclass
      and conname = 'institution_contacts_website_url_length_check'
      and contype = 'c'
  ),
  'website URL is length constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.institution_contacts'::regclass
      and conname = 'institution_contacts_whatsapp_number_e164_check'
      and contype = 'c'
  ),
  'WhatsApp number uses E.164'
);
select has_index(
  'public',
  'institution_legal_representatives',
  'institution_legal_representatives_created_by_idx',
  'created_by foreign key is indexed'
);
select has_index(
  'public',
  'institution_legal_representatives',
  'institution_legal_representatives_primary_active_uidx',
  'only one active primary representative is allowed per institution'
);
select ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and tablename = 'institution_legal_representatives'
      and indexname =
        'institution_legal_representatives_active_person_uidx'
      and indexdef not like '%ends_on IS NULL%'
  ),
  'active representative uniqueness includes future-ended rows'
);
select ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and tablename = 'institution_legal_representatives'
      and indexname =
        'institution_legal_representatives_primary_active_uidx'
      and indexdef not like '%ends_on IS NULL%'
  ),
  'active primary uniqueness includes future-ended rows'
);
select has_trigger(
  'public',
  'institution_memberships',
  'institution_memberships_close_legal_representatives',
  'membership revocation closes legal representative links'
);
select has_trigger(
  'public',
  'people',
  'people_close_incompatible_legal_representatives',
  'person eligibility changes close incompatible representative links'
);
select has_trigger(
  'public',
  'institution_legal_representatives',
  'institution_legal_representatives_touch_updated_at',
  'legal representative updates refresh updated_at'
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
