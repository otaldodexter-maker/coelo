begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok(to_regprocedure('app_private.reconcile_unit_import_export_function_acl()') is not null,
  'the forward-only ACL reconciler exists');

with required(signature) as(values
  ('app_private.assert_import_export_hub_actor()'),
  ('app_private.can_access_import_export_job(text)'),
  ('app_private.import_export_job_direction(text)'),
  ('app_private.import_export_job_domain(text)'),
  ('app_private.import_export_job_payload(uuid)'),
  ('app_private.superadmin_import_export_catalog()'),
  ('app_private.superadmin_list_import_export_jobs(text[],text[],timestamptz,uuid,integer)'),
  ('app_private.superadmin_get_import_export_job(uuid)'),
  ('app_private.superadmin_create_import_export_job(text,text,text,text,uuid)'),
  ('app_private.superadmin_import_export_upload_contract(uuid)'),
  ('app_private.superadmin_confirm_import_export_job(uuid,uuid)'),
  ('app_private.superadmin_retry_import_export_job(uuid,uuid)'),
  ('app_private.superadmin_request_import_export(text,text,jsonb,jsonb,uuid)')
) select ok(to_regprocedure(signature) is not null,'required local profile object exists: '||signature)
from required;

with candidates(signature) as(values
  ('app_private.assert_import_export_hub_actor()'),
  ('app_private.can_access_import_export_job(text)'),
  ('app_private.import_export_job_direction(text)'),
  ('app_private.import_export_job_domain(text)'),
  ('app_private.import_export_job_payload(uuid)'),
  ('app_private.superadmin_import_export_catalog()'),
  ('app_private.superadmin_list_import_export_jobs(text[],text[],timestamptz,uuid,integer)'),
  ('app_private.superadmin_get_import_export_job(uuid)'),
  ('app_private.superadmin_create_import_export_job(text,text,text,text,uuid)'),
  ('app_private.superadmin_import_export_upload_contract(uuid)'),
  ('app_private.superadmin_confirm_import_export_job(uuid,uuid)'),
  ('app_private.superadmin_retry_import_export_job(uuid,uuid)'),
  ('app_private.superadmin_request_import_export(text,text,jsonb,jsonb,uuid)')
),present as(select signature,to_regprocedure(signature) oid from candidates
  where to_regprocedure(signature) is not null)
select ok(not has_function_privilege('anon',oid,'execute')
    and not has_function_privilege('authenticated',oid,'execute')
    and not has_function_privilege('service_role',oid,'execute')
    and not exists(select 1 from pg_proc procedure_record,
      lateral aclexplode(coalesce(procedure_record.proacl,acldefault('f',procedure_record.proowner))) acl
      where procedure_record.oid=present.oid and acl.grantee=0 and acl.privilege_type='EXECUTE'),
  'private hub function has no non-owner execution path: '||signature) from present;

with gateways(signature) as(values
  ('public.superadmin_import_export_catalog()'),
  ('public.superadmin_list_import_export_jobs(text[],text[],timestamptz,uuid,integer)'),
  ('public.superadmin_get_import_export_job(uuid)'),
  ('public.superadmin_create_import_export_job(text,text,text,text,uuid)'),
  ('public.superadmin_import_export_upload_contract(uuid)'),
  ('public.superadmin_confirm_import_export_job(uuid,uuid)'),
  ('public.superadmin_retry_import_export_job(uuid,uuid)'),
  ('public.superadmin_request_import_export(text,text,jsonb,jsonb,uuid)')
),present as(select signature,to_regprocedure(signature) oid from gateways)
select ok(oid is not null and has_function_privilege('authenticated',oid,'execute')
    and not has_function_privilege('anon',oid,'execute')
    and not has_function_privilege('service_role',oid,'execute'),
  'hub gateway is authenticated-only: '||signature) from present;

create temporary table expected_unit_private(signature text primary key) on commit drop;
insert into expected_unit_private values
  ('app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)'),
  ('app_private.superadmin_materialize_unit_export_from_edge(uuid)'),
  ('app_private.superadmin_unit_export_page_v2(uuid,bigint,integer)'),
  ('app_private.superadmin_complete_unit_file_job(uuid,text,text,text,bigint,text,integer)'),
  ('app_private.unit_file_job_payload(uuid)'),
  ('app_private.assert_unit_file_access(text,uuid)'),
  ('app_private.superadmin_unit_import_template()'),
  ('app_private.superadmin_create_unit_import_job(text,text,text,uuid)'),
  ('app_private.superadmin_preview_unit_import(uuid,uuid,jsonb,jsonb)'),
  ('app_private.superadmin_confirm_unit_import(uuid,uuid)'),
  ('app_private.superadmin_retry_unit_import(uuid,uuid)'),
  ('app_private.superadmin_request_unit_export(text,jsonb,jsonb,uuid)'),
  ('app_private.superadmin_unit_export_page(uuid,text,uuid,integer)'),
  ('app_private.superadmin_fail_unit_file_job(uuid,text,uuid)'),
  ('app_private.superadmin_get_unit_file_job(uuid)');

create temporary table expected_unit_public(signature text primary key, allowed_role text) on commit drop;
insert into expected_unit_public values
  ('public.superadmin_unit_import_template()','authenticated'),
  ('public.superadmin_get_unit_file_job(uuid)','authenticated'),
  ('public.superadmin_confirm_unit_import(uuid,uuid)','authenticated'),
  ('public.superadmin_retry_unit_import(uuid,uuid)','authenticated'),
  ('public.superadmin_create_unit_import_job(text,text,text,uuid)','authenticated'),
  ('public.superadmin_request_unit_export(text,jsonb,jsonb,uuid)','authenticated'),
  ('public.superadmin_unit_export_page_v2(uuid,bigint,integer)','authenticated'),
  ('public.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)','service_role'),
  ('public.superadmin_materialize_unit_export_from_edge(uuid)','service_role'),
  ('public.superadmin_complete_unit_file_job(uuid,text,text,text,bigint,text,integer)','service_role'),
  ('public.superadmin_fail_unit_file_job(uuid,text,uuid)','service_role'),
  ('public.superadmin_preview_unit_import(uuid,uuid,jsonb,jsonb)','none'),
  ('public.superadmin_unit_export_page(uuid,text,uuid,integer)','none');

do $fixtures$
declare signature text;
begin
  for signature in select expected_unit_private.signature from expected_unit_private loop
    if to_regprocedure(signature) is null then
      execute format('create function %s returns void language sql security definer set search_path='''' as ''select''',signature);
    end if;
    execute format('grant execute on function %s to public,anon,authenticated,service_role',signature);
  end loop;
  for signature in select expected_unit_public.signature from expected_unit_public loop
    if to_regprocedure(signature) is null then
      execute format('create function %s returns void language sql security definer set search_path='''' as ''select''',signature);
    end if;
    execute format('grant execute on function %s to public,anon,authenticated,service_role',signature);
  end loop;
  if to_regprocedure('app_private.enforce_unit_branding_identity_ownership()') is null then
    execute 'create function app_private.enforce_unit_branding_identity_ownership() returns trigger language plpgsql security definer set search_path='''' as ''begin return new; end''';
  end if;
  if to_regprocedure('app_private.superadmin_fail_unit_file_job(uuid,text)') is null then
    execute 'create function app_private.superadmin_fail_unit_file_job(uuid,text) returns void language sql security definer set search_path='''' as ''select''';
  end if;
  if to_regprocedure('public.superadmin_fail_unit_file_job(uuid,text)') is null then
    execute 'create function public.superadmin_fail_unit_file_job(uuid,text) returns void language sql security definer set search_path='''' as ''select''';
  end if;
  grant execute on function app_private.enforce_unit_branding_identity_ownership(),
    app_private.superadmin_fail_unit_file_job(uuid,text),
    public.superadmin_fail_unit_file_job(uuid,text)
    to public,anon,authenticated,service_role;
end
$fixtures$;

select app_private.reconcile_unit_import_export_function_acl();
select lives_ok('select app_private.reconcile_unit_import_export_function_acl()',
  'ACL reconciliation is idempotent');

with present as(select signature,to_regprocedure(signature) oid from expected_unit_private)
select ok(not has_function_privilege('anon',oid,'execute')
    and not has_function_privilege('authenticated',oid,'execute')
    and not has_function_privilege('service_role',oid,'execute')
    and not exists(select 1 from pg_proc procedure_record,
      lateral aclexplode(coalesce(procedure_record.proacl,acldefault('f',procedure_record.proowner))) acl
      where procedure_record.oid=present.oid and acl.grantee=0 and acl.privilege_type='EXECUTE')
    and (select proowner='postgres'::regrole and prosecdef
          and coalesce(proconfig,'{}'::text[]) @> array['search_path=""']::text[]
         from pg_proc where pg_proc.oid=present.oid),
  'Unit private implementation is owner-only and hardened: '||signature) from present;

with present as(select signature,allowed_role,to_regprocedure(signature) oid from expected_unit_public)
select ok(oid is not null
    and has_function_privilege('authenticated',oid,'execute')=(allowed_role='authenticated')
    and has_function_privilege('service_role',oid,'execute')=(allowed_role='service_role')
    and not has_function_privilege('anon',oid,'execute')
    and not exists(select 1 from pg_proc procedure_record,
      lateral aclexplode(coalesce(procedure_record.proacl,acldefault('f',procedure_record.proowner))) acl
      where procedure_record.oid=present.oid and acl.grantee=0 and acl.privilege_type='EXECUTE'),
  'Unit public gateway has the exact non-owner role: '||signature||' -> '||allowed_role) from present;

select is((select count(*) from expected_unit_private),15::bigint,
  'the functional private Unit ACL profile has the remote set cardinality');
select is((select count(*) from expected_unit_public),13::bigint,
  'the public Unit ACL profile has the remote set cardinality');
select is(
  (select array_agg(signature order by signature collate "C") from expected_unit_private),
  (select array_agg(format('%I.%I(%s)',namespace_record.nspname,procedure_record.proname,
      replace(oidvectortypes(procedure_record.proargtypes),' ','')) order by
      format('%I.%I(%s)',namespace_record.nspname,procedure_record.proname,
        replace(oidvectortypes(procedure_record.proargtypes),' ','')) collate "C")
   from pg_proc procedure_record
   join pg_namespace namespace_record on namespace_record.oid=procedure_record.pronamespace
   where namespace_record.nspname='app_private'
     and procedure_record.proname in (
       select split_part(split_part(signature,'(',1),'.',2) from expected_unit_private
     )
     and format('%I.%I(%s)',namespace_record.nspname,procedure_record.proname,
       replace(oidvectortypes(procedure_record.proargtypes),' ','')) not in (
       'app_private.superadmin_fail_unit_file_job(uuid,text)',
       'app_private.enforce_unit_branding_identity_ownership()',
       'app_private.attest_unit_import_file_retention()'
     )),
  'the functional private Unit catalog has no missing or extra overloads');
select is(
  (select array_agg(signature order by signature collate "C") from expected_unit_public),
  (select array_agg(format('%I.%I(%s)',namespace_record.nspname,procedure_record.proname,
      replace(oidvectortypes(procedure_record.proargtypes),' ','')) order by
      format('%I.%I(%s)',namespace_record.nspname,procedure_record.proname,
        replace(oidvectortypes(procedure_record.proargtypes),' ','')) collate "C")
   from pg_proc procedure_record
   join pg_namespace namespace_record on namespace_record.oid=procedure_record.pronamespace
   where namespace_record.nspname='public'
     and procedure_record.proname in (
       select split_part(split_part(signature,'(',1),'.',2) from expected_unit_public
     )
     and format('%I.%I(%s)',namespace_record.nspname,procedure_record.proname,
       replace(oidvectortypes(procedure_record.proargtypes),' ',''))
       <>'public.superadmin_fail_unit_file_job(uuid,text)'),
  'the public Unit catalog has no missing or extra functional overloads');
select ok(not has_function_privilege('anon','app_private.enforce_unit_branding_identity_ownership()','execute')
    and not has_function_privilege('authenticated','app_private.enforce_unit_branding_identity_ownership()','execute')
    and not has_function_privilege('service_role','app_private.enforce_unit_branding_identity_ownership()','execute'),
  'the Unit branding trigger helper is denied outside the functional 15-function set');
select ok(not has_function_privilege('anon','app_private.superadmin_fail_unit_file_job(uuid,text)','execute')
    and not has_function_privilege('authenticated','app_private.superadmin_fail_unit_file_job(uuid,text)','execute')
    and not has_function_privilege('service_role','app_private.superadmin_fail_unit_file_job(uuid,text)','execute')
    and not has_function_privilege('anon','public.superadmin_fail_unit_file_job(uuid,text)','execute')
    and not has_function_privilege('authenticated','public.superadmin_fail_unit_file_job(uuid,text)','execute')
    and not has_function_privilege('service_role','public.superadmin_fail_unit_file_job(uuid,text)','execute'),
  'legacy two-argument failure overloads remain deny-only');

grant usage on schema app_private to authenticated;
set local role authenticated;
select throws_ok(
  $$select app_private.superadmin_materialize_unit_export_from_edge(
    '00000000-0000-0000-0000-000000000001'::uuid)$$,
  '42501',null,'authenticated cannot call the private materializer by UUID');
select throws_ok(
  $$select app_private.superadmin_unit_export_page_v2(
    '00000000-0000-0000-0000-000000000001'::uuid,0,1)$$,
  '42501',null,'authenticated cannot call the private export page by UUID');
select throws_ok(
  $$select app_private.superadmin_fail_unit_file_job(
    '00000000-0000-0000-0000-000000000001'::uuid,'failure',
    '00000000-0000-0000-0000-000000000002'::uuid)$$,
  '42501',null,'authenticated cannot call the private failure worker by UUID');
reset role;

select * from finish();
rollback;
