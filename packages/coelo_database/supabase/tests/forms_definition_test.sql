begin;

create extension if not exists pgtap with schema extensions;

select plan(31);

select has_table('public', 'forms', 'stable form identity');
select has_table('public', 'form_versions', 'immutable form versions');
select has_table('public', 'form_sections', 'normalized ordered sections');
select has_table('public', 'form_items', 'normalized typed items');
select has_table('public', 'form_question_options', 'normalized choice options');
select has_table('public', 'form_question_conditions', 'normalized conditional branches');
select has_table('public', 'form_item_assets', 'definition assets');

select results_eq(
  $$select count(*)::bigint from public.platform_permissions
      where code in (
        'forms.read', 'forms.manage', 'forms.publish', 'forms.manage_applications',
        'forms.monitor', 'forms.responses.read', 'forms.responses.export',
        'forms.transfer_cross_institution', 'forms.anonymous_participation.read',
        'forms.anonymous_participation.export', 'forms.respond'
      ) and status = 'active'$$,
  array[11::bigint],
  'all exact form capabilities exist'
);

select results_eq(
  $$select count(*)::bigint from public.platform_permissions
      where code like 'forms.%' and requires_mfa$$,
  array[0::bigint],
  'forms capabilities never require MFA'
);

select ok(
  (select bool_and(c.relrowsecurity and c.relforcerowsecurity)
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in (
        'forms', 'form_versions', 'form_sections', 'form_items',
        'form_question_options', 'form_question_conditions', 'form_item_assets'
      )),
  'all definition tables force RLS'
);

select ok(
  not has_table_privilege('anon', 'public.forms', 'SELECT')
  and not has_table_privilege('authenticated', 'public.forms', 'SELECT')
  and not has_table_privilege('authenticated', 'public.forms', 'INSERT')
  and not has_table_privilege('authenticated', 'public.form_items', 'UPDATE'),
  'exposed roles have no direct definition grants'
);

select col_type_is('public', 'forms', 'management_version', 'bigint', 'management version is bigint');
select col_type_is('public', 'forms', 'working_version_id', 'uuid', 'working version is explicit');
select col_type_is('public', 'forms', 'published_version_id', 'uuid', 'published version is explicit');

select ok(
  exists(select 1 from pg_constraint where conname = 'forms_identity_mode_ck'),
  'identity mode is constrained'
);
select ok(
  exists(select 1 from pg_constraint where conname = 'form_items_kind_ck'),
  'item kind is constrained'
);
select ok(
  exists(select 1 from pg_constraint where conname = 'form_items_config_ck'),
  'variable item config is constrained'
);
select ok(
  exists(select 1 from pg_constraint where conname = 'form_question_conditions_value_ck'),
  'condition values are constrained'
);

select has_function(
  'app_private',
  'validate_form_definition',
  array['uuid'],
  'relational definition validator exists'
);

select ok(
  pg_get_functiondef('app_private.validate_form_definition(uuid)'::regprocedure)
    like '%quick poll intent requires between 1 and 280 characters%'
  and pg_get_functiondef('app_private.validate_form_definition(uuid)'::regprocedure)
    like '%quick poll requires exactly one question%',
  'quick polls require a short intent and one answerable question at publication'
);
select ok(
  pg_get_functiondef('app_private.validate_form_definition(uuid)'::regprocedure)
    like '%maximum form condition depth is 4%'
  and pg_get_functiondef('app_private.validate_form_definition(uuid)'::regprocedure)
    like '%form condition cycle%'
  and pg_get_functiondef('app_private.validate_form_definition(uuid)'::regprocedure)
    like '%maximum 20 form sections%'
  and pg_get_functiondef('app_private.validate_form_definition(uuid)'::regprocedure)
    like '%maximum 200 form items%',
  'validator declares structural and graph limits'
);

select ok(
  pg_get_functiondef('app_private.form_item_config_valid(text,jsonb)'::regprocedure)
    like '%max_length%'
  and pg_get_functiondef('app_private.form_item_config_valid(text,jsonb)'::regprocedure)
    like '%min_selections%'
  and pg_get_functiondef('app_private.form_item_config_valid(text,jsonb)'::regprocedure)
    like '%min_images%'
  and pg_get_functiondef('app_private.form_item_config_valid(text,jsonb)'::regprocedure)
    like '%scale configuration must be 1-5 or 1-10%'
  and pg_get_functiondef('app_private.validate_form_definition(uuid)'::regprocedure)
    like '%choice item requires between 2 and 50 options%',
  'definition validation allowlists every response bound and requires 2 to 50 choices'
);

select has_index('public', 'form_versions', 'form_versions_form_number_uidx', 'version number is unique');
select has_index('public', 'form_sections', 'form_sections_version_position_uidx', 'section order is unique');
select has_index('public', 'form_items', 'form_items_section_position_uidx', 'item order is unique');
select has_index('public', 'form_question_options', 'form_options_item_position_uidx', 'option order is unique');

select ok(
  exists(
    select 1 from pg_constraint
     where conrelid = 'public.form_question_conditions'::regclass
       and contype = 'f'
       and confrelid = 'public.form_items'::regclass
  ),
  'conditions use relational item foreign keys'
);

select ok(
  not exists(
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name in ('forms', 'form_versions')
       and column_name in ('definition_json', 'document_json', 'form_json')
  ),
  'the definition is not stored as one JSON document'
);

select ok(
  exists(select 1 from pg_indexes where schemaname = 'public' and indexname = 'forms_institution_status_updated_cursor_idx'),
  'directory cursor has a composite index'
);

select ok(
  exists(select 1 from pg_indexes where schemaname = 'public' and indexname = 'form_versions_form_id_idx')
  and exists(select 1 from pg_indexes where schemaname = 'public' and indexname = 'form_sections_version_id_idx')
  and exists(select 1 from pg_indexes where schemaname = 'public' and indexname = 'form_items_version_id_idx'),
  'definition foreign keys are indexed'
);

select ok(
  (select proconfig @> array['search_path=""'] from pg_proc where oid = 'app_private.validate_form_definition(uuid)'::regprocedure),
  'private validator fixes an empty search path'
);

select * from finish();

rollback;
