-- E1-P0-RLS01: Auth-only baseline plus the nominal three-table RLS hardening.
-- All fixtures, role memberships and probe-only grants roll back below.
-- Public v2 wrapper ACL repairs and nullable private-helper inputs are separate work.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create temporary table p0_tables(name text primary key);
insert into p0_tables values
  ('access_profile_catalog_versions'),
  ('access_profile_command_receipts'),
  ('access_profile_command_receipts_v2');

select ok((select rolbypassrls from pg_roles where rolname='postgres'),
  'the existing postgres function owner has BYPASSRLS; FORCE does not constrain it');
select is(pg_get_userbyid(relation.relowner),'postgres',target.name||' retains its postgres owner')
from p0_tables target join pg_class relation
  on relation.oid=to_regclass('app_private.'||target.name) order by target.name;
select ok(relation.relrowsecurity,target.name||' enables RLS')
from p0_tables target join pg_class relation
  on relation.oid=to_regclass('app_private.'||target.name) order by target.name;
select ok(relation.relforcerowsecurity,target.name||' forces RLS')
from p0_tables target join pg_class relation
  on relation.oid=to_regclass('app_private.'||target.name) order by target.name;
select is((select count(*) from pg_policies policy
  where policy.schemaname='app_private' and policy.tablename=target.name),0::bigint,
  target.name||' remains deny-by-default with no policies') from p0_tables target order by target.name;
select ok(not exists(select 1 from (values('anon'),('authenticated')) client(role_name)
  cross join (values('SELECT'),('INSERT'),('UPDATE'),('DELETE')) operation(privilege)
  where has_table_privilege(client.role_name,'app_private.'||target.name,operation.privilege)),
  target.name||' retains no direct client DML privileges') from p0_tables target order by target.name;

create temporary table p0_private_functions(signature text primary key);
insert into p0_private_functions values
  ('app_private.access_profile_replay(uuid,uuid,text,jsonb)'),
  ('app_private.access_profile_store_receipt(uuid,uuid,text,jsonb,jsonb)'),
  ('app_private.bump_access_profile_catalog_version()');
select ok(procedure.prosecdef and pg_get_userbyid(procedure.proowner)='postgres'
    and coalesce(procedure.proconfig,'{}'::text[]) @> array['search_path=""']::text[],
  expected.signature||' retains postgres SECURITY DEFINER with empty search_path')
from p0_private_functions expected join pg_proc procedure on procedure.oid=expected.signature::regprocedure
order by expected.signature;
select ok(not exists(select 1 from (values('anon'),('authenticated'),('service_role')) client(role_name)
  where has_function_privilege(client.role_name,expected.signature,'EXECUTE')),
  expected.signature||' retains no client or service execution grant')
from p0_private_functions expected order by expected.signature;
select ok((select procedure.prosecdef and pg_get_userbyid(procedure.proowner)='postgres'
    from pg_proc procedure where procedure.oid=
      'public.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)'::regprocedure)
  and has_function_privilege('authenticated',
    'public.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)','EXECUTE')
  and not has_function_privilege('anon',
    'public.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)','EXECUTE'),
  'the legacy v1 consumer retains its guarded authenticated SECURITY DEFINER gateway');

-- Capture errors as data so an expected RED never aborts the remainder of the file.
-- This test helper is SECURITY INVOKER and actually switches to the tested role.
create function pg_temp.p0_execute_as(p_role text,p_statement text)
returns table(affected_rows bigint,error_code text,error_message text)
language plpgsql security invoker as $probe$
begin
  begin
    execute format('set local role %I',p_role);
    execute p_statement;
    get diagnostics affected_rows=row_count;
    execute 'reset role';
    return next;
  exception when others then
    get stacked diagnostics error_code=returned_sqlstate,error_message=message_text;
    execute 'reset role';
    affected_rows:=null;
    return next;
  end;
end
$probe$;
create temporary table p0_attempts(
  name text primary key,affected_rows bigint,error_code text,error_message text);
create temporary table p0_receipt_results(name text primary key,body jsonb);
grant select,insert on p0_receipt_results to authenticated;

-- Dedicated legacy actors never share auth identities with the internal realm.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('e1010000-0000-4000-8000-000000000001','authenticated','authenticated',
   'e1-p0-actor-a@invalid.test',now(),now(),now(),'{}','{}'),
  ('e1010000-0000-4000-8000-000000000002','authenticated','authenticated',
   'e1-p0-actor-b@invalid.test',now(),now(),now(),'{}','{}');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('e1020000-0000-4000-8000-000000000001','adult','Synthetic','Actor A','Synthetic Actor A','active'),
  ('e1020000-0000-4000-8000-000000000002','adult','Synthetic','Actor B','Synthetic Actor B','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('e1020000-0000-4000-8000-000000000001','e1010000-0000-4000-8000-000000000001','active'),
  ('e1020000-0000-4000-8000-000000000002','e1010000-0000-4000-8000-000000000002','active');
insert into public.platform_roles(id,code,name,status,max_scope_kind) values
  ('e1030000-0000-4000-8000-000000000001','e1-p0-full-authority','Synthetic full authority','active','platform'),
  ('e1030000-0000-4000-8000-000000000002','e1-p0-disposable-profile','Synthetic disposable profile','active','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select 'e1030000-0000-4000-8000-000000000001',id,'allow','active'
from public.platform_permissions where status='active';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required) values
  ('e1020000-0000-4000-8000-000000000001','e1030000-0000-4000-8000-000000000001','active','platform',true),
  ('e1020000-0000-4000-8000-000000000002','e1030000-0000-4000-8000-000000000001','active','platform',true);

-- Each statement trigger must update only its own catalog domain, even for zero rows.
create temporary table p0_catalog_snapshot as
  select domain,version from app_private.access_profile_catalog_versions;
select is((select count(*) from p0_catalog_snapshot),3::bigint,'all three catalog domains exist');
update public.platform_permissions set code=code where false;
select ok(not exists(select 1 from p0_catalog_snapshot snapshot
  full join app_private.access_profile_catalog_versions catalog using(domain)
  where catalog.version is distinct from snapshot.version+case when domain='platform' then 1 else 0 end),
  'platform statement trigger increments only the platform catalog through FORCE RLS');
update p0_catalog_snapshot snapshot set version=catalog.version
from app_private.access_profile_catalog_versions catalog where catalog.domain=snapshot.domain;
update public.institution_permissions set code=code where false;
select ok(not exists(select 1 from p0_catalog_snapshot snapshot
  full join app_private.access_profile_catalog_versions catalog using(domain)
  where catalog.version is distinct from snapshot.version+case when domain='institution' then 1 else 0 end),
  'institution statement trigger increments only the institution catalog through FORCE RLS');
update p0_catalog_snapshot snapshot set version=catalog.version
from app_private.access_profile_catalog_versions catalog where catalog.domain=snapshot.domain;
update public.guardian_permission_capabilities set code=code where false;
select ok(not exists(select 1 from p0_catalog_snapshot snapshot
  full join app_private.access_profile_catalog_versions catalog using(domain)
  where catalog.version is distinct from snapshot.version+case when domain='principal' then 1 else 0 end),
  'Principal statement trigger increments only the Principal catalog through FORCE RLS');

-- Private v2 helpers are tested as their owner; this is not a public-wrapper E2E proof.
select lives_ok($$select app_private.access_profile_store_receipt(
  'e1040000-0000-4000-8000-000000000001','e1020000-0000-4000-8000-000000000001',
  'create','{"fixture":"v2"}'::jsonb,'{"fixture_result":"stored"}'::jsonb)$$,
  'the v2 store helper writes a receipt through FORCE RLS');
insert into p0_receipt_results values('v2',app_private.access_profile_replay(
  'e1040000-0000-4000-8000-000000000001','e1020000-0000-4000-8000-000000000001',
  'create','{"fixture":"v2"}'::jsonb));
select ok((select body='{"fixture_result":"stored","replayed":true}'::jsonb
  from p0_receipt_results where name='v2'),'v2 replay returns the same result with the replay marker');
select is((select count(*) from app_private.access_profile_command_receipts_v2
  where request_id='e1040000-0000-4000-8000-000000000001'),1::bigint,'v2 replay does not duplicate its receipt');
select ok(app_private.access_profile_replay('e1040000-0000-4000-8000-000000000099',
  'e1020000-0000-4000-8000-000000000001','create','{}'::jsonb) is null,
  'a missing v2 request has no replay result');
select throws_ok($$select app_private.access_profile_replay(
  'e1040000-0000-4000-8000-000000000001','e1020000-0000-4000-8000-000000000002',
  'create','{"fixture":"v2"}'::jsonb)$$,'42501','idempotency receipt actor mismatch',
  'actor B cannot replay actor A v2 receipt');
select throws_ok($$select app_private.access_profile_replay(
  'e1040000-0000-4000-8000-000000000001','e1020000-0000-4000-8000-000000000001',
  'update','{"fixture":"v2"}'::jsonb)$$,'22023','idempotency key reused',
  'v2 replay rejects a different non-null command');
select throws_ok($$select app_private.access_profile_replay(
  'e1040000-0000-4000-8000-000000000001','e1020000-0000-4000-8000-000000000001',
  'create','{"fixture":"different"}'::jsonb)$$,'22023','idempotency key reused',
  'v2 replay rejects a different non-null payload');
select throws_ok($$select app_private.access_profile_replay(null,
  'e1020000-0000-4000-8000-000000000001','create','{}'::jsonb)$$,
  '22023','request id required','v2 replay rejects a null request ID');

-- The remaining v1 consumer is delete_and_reassign; save now delegates to v2.
select set_config('request.jwt.claim.sub','e1010000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims',
  '{"sub":"e1010000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}',true);
insert into p0_attempts select 'v1-first',attempt.* from pg_temp.p0_execute_as('authenticated',$$
  insert into p0_receipt_results values('v1-first',public.superadmin_access_profile_delete_and_reassign(
    'e1050000-0000-4000-8000-000000000001','platform',
    'e1030000-0000-4000-8000-000000000002',1,null,'Synthetic RLS01 receipt proof'))$$) attempt;
select is((select error_code from p0_attempts where name='v1-first'),null::text,
  'authorized v1 deletion succeeds through the existing authenticated gateway');
select is((select count(*) from public.platform_roles
  where id='e1030000-0000-4000-8000-000000000002'),0::bigint,'v1 deletes the disposable profile');
select is((select count(*) from app_private.access_profile_command_receipts
  where request_id='e1050000-0000-4000-8000-000000000001'),1::bigint,'v1 persists one receipt');
select is((select count(*) from audit.audit_logs
  where object_id='e1030000-0000-4000-8000-000000000002'
    and action_code='membership_changed'),1::bigint,'v1 persists one audit event');
insert into p0_attempts select 'v1-repeat',attempt.* from pg_temp.p0_execute_as('authenticated',$$
  insert into p0_receipt_results values('v1-repeat',public.superadmin_access_profile_delete_and_reassign(
    'e1050000-0000-4000-8000-000000000001','platform',
    'e1030000-0000-4000-8000-000000000002',1,null,'Synthetic RLS01 receipt proof'))$$) attempt;
select is((select error_code from p0_attempts where name='v1-repeat'),null::text,'v1 repeats without deleting twice');
select ok((select first_result.body=repeat_result.body from p0_receipt_results first_result
  cross join p0_receipt_results repeat_result where first_result.name='v1-first' and repeat_result.name='v1-repeat'),
  'v1 replay returns exactly the stored result');
insert into p0_attempts select 'v1-payload',attempt.* from pg_temp.p0_execute_as('authenticated',$$
  select public.superadmin_access_profile_delete_and_reassign(
    'e1050000-0000-4000-8000-000000000001','platform',
    'e1030000-0000-4000-8000-000000000002',1,null,'Changed synthetic reason')$$) attempt;
select is((select error_code from p0_attempts where name='v1-payload'),'23505',
  'v1 rejects the same request with a different payload before repeating effects');
insert into p0_attempts select 'v1-null-request',attempt.* from pg_temp.p0_execute_as('authenticated',$$
  select public.superadmin_access_profile_delete_and_reassign(null,'platform',
    'e1030000-0000-4000-8000-000000000002',1,null,'Synthetic RLS01 receipt proof')$$) attempt;
select is((select error_code from p0_attempts where name='v1-null-request'),'22023','v1 rejects a null request ID');
insert into app_private.access_profile_command_receipts(request_id,actor_person_id,command_kind,request_json,result_json)
values('e1050000-0000-4000-8000-000000000002','e1020000-0000-4000-8000-000000000001',
  'save','{}','{"must_not_replay":true}');
insert into p0_attempts select 'v1-command',attempt.* from pg_temp.p0_execute_as('authenticated',$$
  select public.superadmin_access_profile_delete_and_reassign(
    'e1050000-0000-4000-8000-000000000002','platform',
    'e1030000-0000-4000-8000-000000000002',1,null,'Synthetic RLS01 receipt proof')$$) attempt;
select is((select error_code from p0_attempts where name='v1-command'),'P0002',
  'v1 does not replay a save receipt through delete_and_reassign');
select set_config('request.jwt.claim.sub','e1010000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims',
  '{"sub":"e1010000-0000-4000-8000-000000000002","aal":"aal2","role":"authenticated"}',true);
insert into p0_attempts select 'v1-actor-b',attempt.* from pg_temp.p0_execute_as('authenticated',$$
  select public.superadmin_access_profile_delete_and_reassign(
    'e1050000-0000-4000-8000-000000000001','platform',
    'e1030000-0000-4000-8000-000000000002',1,null,'Synthetic RLS01 receipt proof')$$) attempt;
select is((select error_code from p0_attempts where name='v1-actor-b'),'P0002',
  'authorized actor B receives missing profile rather than actor A stored v1 result');
select is((select count(*) from audit.audit_logs where object_id='e1030000-0000-4000-8000-000000000002'
  and action_code='membership_changed'),1::bigint,'v1 replay and negatives create no additional audit events');
select is((select count(*) from app_private.access_profile_command_receipts
  where request_id='e1050000-0000-4000-8000-000000000001'),1::bigint,'v1 replay and negatives preserve the single original receipt');

-- Last stage: a RED may update/delete the synthetic rows, so positives run first.
create role coelo_e1_p0_rls_probe nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
grant coelo_e1_p0_rls_probe to postgres;
grant usage on schema app_private to coelo_e1_p0_rls_probe;
grant select,insert,update,delete on app_private.access_profile_catalog_versions,
  app_private.access_profile_command_receipts,app_private.access_profile_command_receipts_v2
  to coelo_e1_p0_rls_probe;
select ok((select not rolcanlogin and not rolsuper and not rolbypassrls and not rolinherit
    from pg_roles where rolname='coelo_e1_p0_rls_probe')
  and not exists(select 1 from pg_auth_members membership
    where membership.member='coelo_e1_p0_rls_probe'::regrole),
  'the RLS probe has no login, bypass, superuser power or inherited role');
select ok(has_schema_privilege('coelo_e1_p0_rls_probe','app_private','USAGE')
  and not exists(select 1 from (values('SELECT'),('INSERT'),('UPDATE'),('DELETE')) operation(privilege)
    where not has_table_privilege('coelo_e1_p0_rls_probe','app_private.'||target.name,operation.privilege)),
  target.name||' grants temporary probe DML so ACL cannot explain the RLS denial') from p0_tables target order by target.name;

create temporary table p0_operations(table_name text,operation text,statement text,primary key(table_name,operation));
insert into p0_operations
select name,'SELECT','select * from app_private.'||quote_ident(name) from p0_tables
union all select name,'UPDATE','update app_private.'||quote_ident(name)||
  case when name='access_profile_catalog_versions' then ' set version=version' else ' set result_json=result_json' end from p0_tables
union all select name,'DELETE','delete from app_private.'||quote_ident(name) from p0_tables;
insert into p0_operations values
  ('access_profile_catalog_versions','INSERT',$$insert into app_private.access_profile_catalog_versions(domain,version) values('platform',1)$$),
  ('access_profile_command_receipts','INSERT',$$insert into app_private.access_profile_command_receipts(
    request_id,actor_person_id,command_kind,request_json,result_json) values(
    'e1060000-0000-4000-8000-000000000001','e1020000-0000-4000-8000-000000000001','save','{}','{}')$$),
  ('access_profile_command_receipts_v2','INSERT',$$insert into app_private.access_profile_command_receipts_v2(
    request_id,actor_person_id,command_kind,request_hash,result_json) values(
    'e1060000-0000-4000-8000-000000000002','e1020000-0000-4000-8000-000000000001','create',
    decode(repeat('00',32),'hex'),'{}')$$);

-- Real client operations must still fail before any temporary probe can alter data.
insert into p0_attempts
select client.role_name||':'||operation.table_name||':'||operation.operation,attempt.*
from (values('anon'),('authenticated')) client(role_name) cross join p0_operations operation
cross join lateral pg_temp.p0_execute_as(client.role_name,operation.statement) attempt;
select is(attempt.error_code,'42501',attempt.name||' remains denied by the existing client ACL')
from p0_attempts attempt where attempt.name like 'anon:%' or attempt.name like 'authenticated:%' order by attempt.name;

-- Sequence SELECT/UPDATE/DELETE/INSERT explicitly so baseline DELETE cannot mask INSERT RED.
do $run_probe$
declare operation record;
begin
  for operation in select * from p0_operations
    order by table_name,case p0_operations.operation when 'SELECT' then 1 when 'UPDATE' then 2 when 'DELETE' then 3 else 4 end
  loop
    if operation.table_name='access_profile_catalog_versions' and operation.operation='INSERT' then
      -- All legal domains are seeded. Free one key as the BYPASSRLS owner so
      -- this INSERT tests RLS with a valid row, never a duplicate primary key.
      delete from app_private.access_profile_catalog_versions where domain='platform';
    end if;
    insert into p0_attempts
    select 'probe:'||operation.table_name||':'||operation.operation,attempt.*
    from pg_temp.p0_execute_as('coelo_e1_p0_rls_probe',operation.statement) attempt;
  end loop;
end
$run_probe$;
select ok(attempt.error_code is null and attempt.affected_rows=0,
  attempt.name||' sees/changes zero rows because of RLS, despite explicit DML grants')
from p0_attempts attempt where attempt.name like 'probe:%' and attempt.name not like '%:INSERT' order by attempt.name;
select is(attempt.error_code,'42501',attempt.name||' is rejected by RLS despite explicit INSERT grant')
from p0_attempts attempt where attempt.name like 'probe:%:INSERT' order by attempt.name;
select ok(current_user='postgres','every probe restores the original postgres execution role');

select * from finish();
rollback;
