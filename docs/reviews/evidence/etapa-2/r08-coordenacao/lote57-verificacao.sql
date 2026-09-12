-- Pos-aplicacao somente leitura: ledger, FK, trigger e grants.
select current_timestamp as measured_at, version, name
from supabase_migrations.schema_migrations
where version between '20260912140546' and '20260912140549'
order by version;
select confdeltype::text as fk_action, condeferrable
from pg_constraint
where conrelid='public.media_bindings'::regclass and conname='media_bindings_item_id_fkey';
select tgname, tgenabled from pg_trigger
where tgrelid='public.media_assets'::regclass and tgname='form_media_unbind_deleted_question_v1';
select
  has_function_privilege('authenticated','public.superadmin_form_media_authorize_finalize_v2(uuid)','execute') as authenticated_authorize,
  has_function_privilege('authenticated','public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer)','execute') as authenticated_finalize,
  has_function_privilege('service_role','public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer)','execute') as service_finalize,
  has_function_privilege('anon','public.superadmin_form_media_delete_v2(uuid,uuid)','execute') as anon_delete;
select current_timestamp as measured_at,
  (select jsonb_agg(jsonb_build_object('version',version,'name',name) order by version)
   from supabase_migrations.schema_migrations where version between '20260912140546' and '20260912140549') as ledger,
  (select jsonb_build_object('action',confdeltype::text,'deferrable',condeferrable)
   from pg_constraint where conrelid='public.media_bindings'::regclass and conname='media_bindings_item_id_fkey') as fk,
  (select jsonb_build_object('name',tgname,'enabled',tgenabled)
   from pg_trigger where tgrelid='public.media_assets'::regclass and tgname='form_media_unbind_deleted_question_v1') as trigger;
