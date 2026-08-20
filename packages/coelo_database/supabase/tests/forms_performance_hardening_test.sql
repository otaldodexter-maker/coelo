begin;

select plan(8);

select ok(
  exists(select 1 from pg_extension where extname = 'pg_trgm'),
  'pg_trgm is installed for bounded form title search'
);

select ok(
  to_regclass('public.forms_title_trgm_idx') is not null
  and pg_get_indexdef('public.forms_title_trgm_idx'::regclass)
        like '%USING gin (lower(title) gin_trgm_ops)%',
  'form title contains search has a functional trigram GIN index'
);

select ok(
  not exists (
    select 1
      from pg_constraint constraint_row
      join pg_class table_row on table_row.oid = constraint_row.conrelid
      join pg_namespace schema_row on schema_row.oid = table_row.relnamespace
     where constraint_row.contype = 'f'
       and (table_row.relname = 'forms' or table_row.relname like 'form\_%' escape '\')
       and not exists (
         select 1
           from pg_index index_row
          where index_row.indrelid = constraint_row.conrelid
            and index_row.indisvalid
            and (index_row.indkey::smallint[])[0:cardinality(constraint_row.conkey) - 1]
                = constraint_row.conkey
       )
  ),
  'every Forms foreign key has a valid left-prefix index'
);

select ok(
  pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    not like '%join lateral%',
  'form_list does not execute an occurrence aggregate per form row'
);

select ok(
  pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%occurrence_windows as (%'
  and pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%group by candidate.id%'
  and pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%bool_or(%opens_at <= now()%closes_at > now()%'
  and pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%lower(form_row.title) like%lower(app_private.form_escape_like%'
  and pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%forms.read%',
  'form_list batches occurrence windows and keeps guarded trigram title search'
);

select ok(
  to_regclass('public.people_display_name_cursor_idx') is not null
  and pg_get_indexdef('public.people_display_name_cursor_idx'::regclass)
        like '%(lower(display_name), id)%',
  'monitor people cursor has a stable functional label and id index'
);

select ok(
  pg_get_functiondef('app_private.form_list_monitor_people(jsonb)'::regprocedure)
    like '%monitor_candidates as (%'
  and pg_get_functiondef('app_private.form_list_monitor_people(jsonb)'::regprocedure)
    like '%cursor_label%'
  and pg_get_functiondef('app_private.form_list_monitor_people(jsonb)'::regprocedure)
    like '%forms.monitor%'
  and pg_get_functiondef('app_private.form_list_monitor_people(jsonb)'::regprocedure)
    like '%form_row.institution_id = occurrence_row.institution_id%',
  'monitor people materializes cursor labels only inside a tenant-bound guarded query'
);

select ok(
  to_regclass('app_private.form_monitor_people_projection') is null
  and not exists (
    select 1
      from information_schema.columns
     where table_schema in ('public', 'app_private')
       and table_name like 'form\_monitor\_%' escape '\'
       and column_name in ('display_name', 'cursor_label')
  ),
  'monitor cursor hardening does not persist or expose duplicated people PII'
);

select * from finish();
rollback;
