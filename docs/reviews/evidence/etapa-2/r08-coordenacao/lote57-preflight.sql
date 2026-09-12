-- Somente metadados e contagens; nenhuma credencial ou dado pessoal.
select current_timestamp as measured_at,
  current_user as actor,
  to_regprocedure('app_private.form_replace_working_definition(uuid,jsonb)') is not null as replace_definition_exists,
  to_regprocedure('public.superadmin_form_media_authorize_finalize_v2(uuid)') is not null as authorize_finalize_exists,
  (select count(*) from supabase_migrations.schema_migrations
    where version between '20260912140546' and '20260912140549') as existing_package_ledger,
  (select count(*) from public.media_bindings b join public.media_assets a on a.id=b.media_asset_id
    where b.purpose='question-image' and a.catalog_kind='form-image'
      and a.media_purpose='question-image' and a.status='deleted') as terminal_bindings_to_reconcile,
  (select confdeltype::text from pg_constraint
    where conrelid='public.media_bindings'::regclass and conname='media_bindings_item_id_fkey') as current_fk_action;
