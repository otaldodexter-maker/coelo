begin;
select plan(18);

select results_eq(
  $$select count(*)::bigint
    from public.activity_templates
    where scope_kind = 'platform' and status = 'active'$$,
  array[40::bigint],
  'platform catalog contains exactly 40 active templates'
);
select results_eq(
  $$select count(*)::bigint
    from public.activity_templates
    where scope_kind = 'platform' and status = 'active'
      and code in (
        'coral','fotografia','ceramica','futebol','basquete','volei',
        'handebol','atletismo','ginastica','frances','libras','matematica',
        'fisica','quimica','biologia','astronomia','cultura-maker',
        'alfabetizacao','educacao-financeira'
      )$$,
  array[19::bigint],
  'all 19 expansion templates are seeded'
);
select results_eq(
  $$select count(*)::bigint
    from public.activity_templates template
    join public.activity_taxonomies subtype on subtype.id = template.taxonomy_id
    where template.scope_kind = 'platform'
      and template.status = 'active'
      and subtype.code in (
        'natacao','futebol','futsal','matematica','fisica'
      )$$,
  array[5::bigint],
  'required swimming football futsal mathematics and physics models exist'
);
select results_eq(
  $$select count(distinct category.code)::bigint
    from public.activity_templates template
    join public.activity_taxonomies subtype on subtype.id = template.taxonomy_id
    join public.activity_taxonomies category on category.id = subtype.parent_id
    where template.scope_kind = 'platform'
      and template.status = 'active'
      and category.status = 'active'$$,
  array[11::bigint],
  'templates cover every curated category that has concrete subtypes'
);
select results_eq(
  $$select name
    from public.activity_taxonomies
    where taxonomy_kind = 'category'
      and code in ('ciencias-exatas', 'ciencias-naturais')
      and status = 'active'
    order by code$$,
  array['Ciências exatas'::text, 'Ciências naturais'::text],
  'exact and natural sciences are first-class filter labels'
);
select results_eq(
  $$select subtype.code || ':' || category.code
    from public.activity_taxonomies subtype
    join public.activity_taxonomies category on category.id = subtype.parent_id
    where subtype.code in (
      'matematica','fisica','quimica','biologia','astronomia',
      'robotica','programacao','cultura-maker','ciencias-experimentais'
    )
    order by subtype.code$$,
  array[
    'astronomia:ciencias-naturais'::text,
    'biologia:ciencias-naturais'::text,
    'ciencias-experimentais:ciencias-tecnologia'::text,
    'cultura-maker:ciencias-tecnologia'::text,
    'fisica:ciencias-exatas'::text,
    'matematica:ciencias-exatas'::text,
    'programacao:ciencias-tecnologia'::text,
    'quimica:ciencias-exatas'::text,
    'robotica:ciencias-tecnologia'::text
  ],
  'science and technology templates map to coherent filter categories'
);
select is(
  (select count(*) from public.activity_templates
    where scope_kind = 'platform' and status = 'active'),
  (select count(distinct lower(name)) from public.activity_templates
    where scope_kind = 'platform' and status = 'active'),
  'active platform template names are not duplicated'
);
select has_index(
  'public', 'activity_templates',
  'activity_templates_platform_active_name_uidx',
  'platform active template names are protected from duplicates'
);
select is_empty(
  $$select template.id
    from public.activity_templates template
    left join public.activity_taxonomies subtype
      on subtype.id = template.taxonomy_id
     and subtype.taxonomy_kind = 'subtype'
     and subtype.status = 'active'
    left join public.activity_taxonomies category
      on category.id = subtype.parent_id
     and category.taxonomy_kind = 'category'
     and category.status = 'active'
    where template.scope_kind = 'platform'
      and template.status = 'active'
      and (subtype.id is null or category.id is null)$$,
  'every active platform template belongs to an active subtype and category'
);
select has_function(
  'public', 'superadmin_activity_template_options', array['uuid'],
  'template options RPC remains available'
);
select function_privs_are(
  'public', 'superadmin_activity_template_options', array['uuid'],
  'authenticated', array['EXECUTE'],
  'authenticated receives only RPC execution privilege'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_activity_template_options(uuid)'::regprocedure
  ) like '%''description'',template.description%'
  and pg_get_functiondef(
    'app_private.superadmin_activity_template_options(uuid)'::regprocedure
  ) like '%''scope_kind'',template.scope_kind%'
  and pg_get_functiondef(
    'app_private.superadmin_activity_template_options(uuid)'::regprocedure
  ) like '%''governance_kind'',template.governance_kind%'
  and pg_get_functiondef(
    'app_private.superadmin_activity_template_options(uuid)'::regprocedure
  ) like '%''taxonomy_id'',coalesce(taxonomy.parent_id,taxonomy.id)%'
  and pg_get_functiondef(
    'app_private.superadmin_activity_template_options(uuid)'::regprocedure
  ) like '%''subtype_id'',case when taxonomy.taxonomy_kind=''subtype''%',
  'template options preserve the canonical client shape'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_activity_template_options(uuid)'::regprocedure
  ) like '%template.scope_kind=''platform''%'
  and pg_get_functiondef(
    'app_private.superadmin_activity_template_options(uuid)'::regprocedure
  ) like '%template.institution_id=p_institution_id%',
  'template options include platform models and scope institutional copies'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure
  ) like '%p_payload?''template_id''%'
  and pg_get_functiondef(
    'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure
  ) like '%source_template.template_payload%'
  and pg_get_functiondef(
    'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure
  ) like '%template_record.scope_kind=''platform''%',
  'create-from-template remains one authorized aggregate upsert'
);

-- Exercise the authenticated RPC path with transaction-local authorization
-- helpers. Rollback restores the production helpers and removes fixtures.
create or replace function app_private.current_person_id()
returns uuid language sql stable security definer set search_path = ''
as $$select '32000000-0000-4000-8000-000000000001'::uuid$$;
create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer set search_path = ''
as $$select permission_code like 'activities.%'$$;
create or replace function app_private.has_mfa_aal2()
returns boolean language sql stable security definer set search_path = ''
as $$select true$$;

insert into public.people(
  id, person_type, first_name, last_name, display_name
) values (
  '32000000-0000-4000-8000-000000000001', 'adult',
  'Catalog', 'Tester', 'Catalog Tester'
);
insert into public.institutions(id, public_name, slug, status, created_by)
values (
  '32000000-0000-4000-8000-000000000002',
  'Template Test Institution', 'template-test-institution', 'active',
  '32000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '32000000-0000-4000-8000-000000000099', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"32000000-0000-4000-8000-000000000099","aal":"aal2","role":"authenticated"}',
  true
);
select is(
  jsonb_array_length(
    public.superadmin_activity_template_options(null)->'templates'
  ),
  40,
  'authenticated template options returns the complete platform catalog'
);
select lives_ok(
  $call$
    select public.superadmin_upsert_activity(
      jsonb_build_object(
        'institution_id', '32000000-0000-4000-8000-000000000002',
        'template_id', (
          select id::text from public.activity_templates
          where scope_kind = 'platform' and code = 'fisica'
        ),
        'name', 'Física aplicada',
        'description', '',
        'taxonomy_id', (
          select id::text from public.activity_taxonomies where code = 'fisica'
        ),
        'governance_kind', 'optional',
        'status', 'draft',
        'unit_ids', '[]'::jsonb,
        'group_ids', '[]'::jsonb
      ),
      '32000000-0000-4000-8000-000000000003'
    )
  $call$,
  'create from a platform template succeeds in one aggregate RPC'
);
select results_eq(
  $$select count(*)::bigint
    from public.activity_definitions activity
    join public.activity_templates template on template.id = activity.template_id
    where activity.institution_id = '32000000-0000-4000-8000-000000000002'
      and activity.name = 'Física aplicada'
      and template.code = 'fisica'$$,
  array[1::bigint],
  'template provenance and explicit name override are persisted'
);
select lives_ok(
  $call$
    select public.superadmin_upsert_activity(
      jsonb_build_object(
        'institution_id', '32000000-0000-4000-8000-000000000002',
        'template_id', (
          select id::text from public.activity_templates
          where scope_kind = 'platform' and code = 'fisica'
        ),
        'name', 'Física aplicada',
        'description', '',
        'taxonomy_id', (
          select id::text from public.activity_taxonomies where code = 'fisica'
        ),
        'governance_kind', 'optional',
        'status', 'draft',
        'unit_ids', '[]'::jsonb,
        'group_ids', '[]'::jsonb
      ),
      '32000000-0000-4000-8000-000000000003'
    )
  $call$,
  'create-from-template idempotency replay returns the existing result'
);
reset role;

select * from finish();
rollback;
