begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select has_column('public', 'person_avatar_assets', 'storage_provider',
  'avatar catalog declares its storage provider');
select has_column('public', 'person_avatar_assets', 'tenant_id',
  'avatar catalog records the owning tenant');
select col_not_null('public', 'person_avatar_assets', 'storage_provider',
  'provider is mandatory');
select ok(exists (select 1 from pg_constraint where conname =
  'person_avatar_assets_r2_tenant_check'),
  'new R2 assets require an owning tenant');
select has_function('public', 'superadmin_account_avatar_prepare_v1',
  array['uuid', 'uuid', 'text', 'text', 'bigint', 'text'],
  'prepare is versioned and request-bound');
select has_function('public', 'superadmin_account_avatar_authorize_finalize_v1',
  array['uuid'], 'finalize authorization is server-side');
select has_function('public', 'superadmin_account_avatar_finalize_v1',
  array['uuid', 'uuid', 'bigint', 'text'], 'finalize is service-role only');
select has_function('public', 'superadmin_account_avatar_authorize_read_v1',
  array['uuid'], 'read authorization is server-side');
select has_function('public', 'superadmin_account_avatar_remove_v1',
  array['uuid'], 'removal is server-side');
select has_function('public', 'superadmin_account_avatar_expire_v1',
  array['integer'], 'expired tickets are cleaned by a worker');
select function_privs_are('public', 'superadmin_account_avatar_finalize_v1',
  array['uuid', 'uuid', 'bigint', 'text'], 'service_role', array['EXECUTE'],
  'client cannot finalize directly');
select function_privs_are('public', 'superadmin_account_avatar_authorize_read_v1',
  array['uuid'], 'authenticated', array['EXECUTE'],
  'authenticated can request an authorized read');
select ok(to_regclass('app_private.superadmin_account_avatar_tickets') is not null,
  'private avatar tickets are not exposed');

select * from finish();
rollback;
