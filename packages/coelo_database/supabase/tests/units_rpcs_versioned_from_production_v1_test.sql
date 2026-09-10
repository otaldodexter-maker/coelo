-- Prova de contrato da migration 20260910160000_units_rpcs_versioned_from_production_v1.
-- As 13 RPCs de Unidades que o cliente chama por public existem, sao security definer,
-- executaveis por authenticated e negadas a anon; as versoes app_private ficam sem grant de cliente.
begin;
create extension if not exists pgtap with schema extensions;
select plan(40);

select has_function('public', f, 'public.' || f || ' existe')
from unnest(array[
  'change_unit_handle_for_superadmin',
  'create_unit_for_superadmin',
  'get_unit_form_for_superadmin',
  'list_units_for_superadmin',
  'preview_unit_institution_transfer_for_superadmin',
  'request_unit_type_for_superadmin',
  'superadmin_prepare_unit_identity_upload',
  'superadmin_request_unit_identity_delete',
  'superadmin_unit_identity_download_descriptor',
  'superadmin_unit_import_template',
  'transfer_unit_institution_for_superadmin',
  'unit_directory_filter_options',
  'update_unit_for_superadmin']) as f;

select is(count(*)::int, 13, 'as 13 funcoes public sao security definer')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef and p.proname in (
  'change_unit_handle_for_superadmin','create_unit_for_superadmin','get_unit_form_for_superadmin',
  'list_units_for_superadmin','preview_unit_institution_transfer_for_superadmin',
  'request_unit_type_for_superadmin','superadmin_prepare_unit_identity_upload',
  'superadmin_request_unit_identity_delete','superadmin_unit_identity_download_descriptor',
  'superadmin_unit_import_template','transfer_unit_institution_for_superadmin',
  'unit_directory_filter_options','update_unit_for_superadmin');

select ok(has_function_privilege('authenticated', p.oid, 'execute'), 'authenticated executa public.' || p.proname)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in (
  'change_unit_handle_for_superadmin','create_unit_for_superadmin','get_unit_form_for_superadmin',
  'list_units_for_superadmin','preview_unit_institution_transfer_for_superadmin',
  'request_unit_type_for_superadmin','superadmin_prepare_unit_identity_upload',
  'superadmin_request_unit_identity_delete','superadmin_unit_identity_download_descriptor',
  'superadmin_unit_import_template','transfer_unit_institution_for_superadmin',
  'unit_directory_filter_options','update_unit_for_superadmin')
order by p.proname;

select ok(not has_function_privilege('anon', p.oid, 'execute'), 'anon nao executa public.' || p.proname)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in (
  'change_unit_handle_for_superadmin','create_unit_for_superadmin','get_unit_form_for_superadmin',
  'list_units_for_superadmin','preview_unit_institution_transfer_for_superadmin',
  'request_unit_type_for_superadmin','superadmin_prepare_unit_identity_upload',
  'superadmin_request_unit_identity_delete','superadmin_unit_identity_download_descriptor',
  'superadmin_unit_import_template','transfer_unit_institution_for_superadmin',
  'unit_directory_filter_options','update_unit_for_superadmin')
order by p.proname;

select is(count(*)::int, 0, 'nenhuma versao app_private e executavel por authenticated ou anon')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'app_private'
  and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute'))
  and p.proname in (
  'change_unit_handle_for_superadmin','create_unit_for_superadmin','get_unit_form_for_superadmin',
  'list_units_for_superadmin','request_unit_type_for_superadmin','superadmin_prepare_unit_identity_upload',
  'superadmin_request_unit_identity_delete','superadmin_unit_identity_download_descriptor',
  'superadmin_unit_import_template','transfer_unit_institution_for_superadmin',
  'unit_directory_filter_options','update_unit_for_superadmin');

select * from finish();
rollback;
