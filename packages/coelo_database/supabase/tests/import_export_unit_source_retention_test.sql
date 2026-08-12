begin;
select plan(3);

select has_function('app_private', 'attest_unit_import_file_retention', array[]::text[]);
select ok(
  exists(
    select 1
    from pg_trigger trigger_record
    join pg_class relation_record on relation_record.oid = trigger_record.tgrelid
    join pg_namespace namespace_record on namespace_record.oid = relation_record.relnamespace
    where namespace_record.nspname = 'public'
      and relation_record.relname = 'import_files'
      and trigger_record.tgname = 'import_files_attest_unit_source'
      and not trigger_record.tgisinternal
  ),
  'attested Unit source files receive a retention trigger'
);
select ok(
  not has_function_privilege('authenticated', 'app_private.attest_unit_import_file_retention()', 'EXECUTE'),
  'source-attestation trigger is never callable by browser roles'
);

select * from finish();
rollback;
