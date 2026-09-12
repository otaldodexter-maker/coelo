-- R08 lote 59 — preflight estritamente somente leitura.
-- Não aplica candidato, não escreve ledger e não abre transação mutante.
with targets as (
  select
    to_regprocedure('public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer,text)') old_list,
    to_regprocedure('public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer,text,uuid[],text[],text[],text[])') new_list,
    to_regprocedure('public.superadmin_people_filter_options()') filter_options
), functions as (
  select p.oid, p.proname, p.pronargs, p.pronargdefaults, p.prosecdef,
    p.provolatile, p.proconfig, pg_get_userbyid(p.proowner) owner_name,
    md5(replace(p.prosrc, E'\r\n', E'\n')) body_md5
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('superadmin_people_list', 'superadmin_people_filter_options')
)
select current_timestamp measured_at,
  current_user measured_by,
  (select count(*) from supabase_migrations.schema_migrations
    where version = '20260912143000') ledger_count,
  t.old_list is not null old_signature_present,
  t.new_list is null new_signature_absent,
  t.filter_options is not null filter_options_present,
  (select count(*) from functions where proname = 'superadmin_people_list') list_overload_count,
  (select jsonb_agg(to_jsonb(f) order by f.proname, f.oid) from functions f) function_metadata,
  case when t.old_list is null then null else
    has_function_privilege('authenticated', t.old_list::oid, 'EXECUTE') end old_authenticated_execute,
  case when t.old_list is null then null else
    has_function_privilege('anon', t.old_list::oid, 'EXECUTE') end old_anon_execute,
  case when t.filter_options is null then null else
    has_function_privilege('authenticated', t.filter_options::oid, 'EXECUTE') end options_authenticated_execute,
  case when t.filter_options is null then null else
    has_function_privilege('anon', t.filter_options::oid, 'EXECUTE') end options_anon_execute
from targets t;
