-- LOCAL CANDIDATE ONLY: selected/executed by the serialized replay owner.
-- Covers 20260908190646_superadmin_locations_update_status_v2.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- The package adds two commands and nothing else the client can reach.
select has_function('public','superadmin_location_update_v2',array['uuid','jsonb','bigint','uuid']);
select has_function('public','superadmin_location_set_status_v2',array['uuid','text','bigint','uuid']);
select has_function('app_private','superadmin_location_locked_v2',
  array['app_private.superadmin_internal_context','uuid']);
select has_function('app_private','superadmin_location_name_available_v2',
  array['uuid','text','uuid','uuid','text']);
select ok(has_function_privilege('authenticated',
  'public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)','EXECUTE'),
  'the edit command is reachable by a client');
select ok(has_function_privilege('authenticated',
  'public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)','EXECUTE'),
  'the status command is reachable by a client');
select ok(not has_function_privilege('authenticated',
  'app_private.superadmin_location_locked_v2(app_private.superadmin_internal_context,uuid)','EXECUTE'),
  'the locking helper has no client execution');
select ok(not has_function_privilege('authenticated',
  'app_private.superadmin_location_name_available_v2(uuid,text,uuid,uuid,text)','EXECUTE'),
  'the name helper has no client execution');
select ok(not has_function_privilege('anon',
  'public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)','EXECUTE'),
  'an anonymous caller cannot edit');
select ok(not has_function_privilege('anon',
  'public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)','EXECUTE'),
  'an anonymous caller cannot change status');
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in(
    'superadmin_location_update_v2','superadmin_location_set_status_v2')),2,
  'each command has exactly one signature');

-- Both commands run as their definer with an empty search path.
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in('public','app_private')
    and p.proname in('superadmin_location_update_v2','superadmin_location_set_status_v2',
      'superadmin_location_locked_v2','superadmin_location_name_available_v2')
    and p.prosecdef and p.proconfig @> array['search_path=""']),4,
  'every added function is definer with a pinned empty search path');

-- The receipt is private state, never a readable table.
select has_table('app_private'::name,'superadmin_location_write_receipts'::name);
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='app_private.superadmin_location_write_receipts'::regclass),
  'the write receipt is RLS forced');
select ok(not has_table_privilege('authenticated',
  'app_private.superadmin_location_write_receipts','SELECT'),'the write receipt is private');
select ok(not has_table_privilege('service_role',
  'app_private.superadmin_location_write_receipts','SELECT'),'not even service_role reads the receipt');
select is((select count(*)::integer from pg_constraint
  where conrelid='app_private.superadmin_location_write_receipts'::regclass and contype='c'
    and pg_get_constraintdef(oid)
      =$def$CHECK ((operation = ANY (ARRAY['update'::text, 'status'::text])))$def$),1,
  'a receipt only records the two verbs this package defines');
select is((select count(*)::integer from pg_constraint
  where conrelid='app_private.superadmin_location_write_receipts'::regclass and contype='c'
    and pg_get_constraintdef(oid)=$def$CHECK ((octet_length(request_hash) = 32))$def$),1,
  'a receipt carries a full request digest');

-- No competing catalog is introduced: the existing table keeps its exact shape.
select is((select count(*)::integer from pg_attribute
  where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped),16,
  'the catalog still has the columns the create package left');
select ok(not has_table_privilege('authenticated','public.activity_locations','UPDATE'),
  'a client still cannot write the catalog directly');
select ok(not has_table_privilege('service_role','public.activity_locations','UPDATE'),
  'service_role still cannot write the catalog directly');
select is((select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and c.relname ~ '^(superadmin_)?locations?$'),0,
  'the package created no second location table');

-- The availability helper mirrors both partial unique indexes.
create temporary table location_write_seed(kind text primary key, id uuid);
do $seed$
declare seed_institution uuid; seed_unit uuid;
begin
  select i.id into seed_institution from public.institutions i where i.deleted_at is null limit 1;
  if seed_institution is null then return; end if;
  select u.id into seed_unit from public.units u
    where u.institution_id=seed_institution and u.status<>'archived' limit 1;
  insert into location_write_seed values('institution',seed_institution),('unit',seed_unit);
end
$seed$;

select ok(app_private.superadmin_location_name_available_v2(
    null,'institution',(select id from location_write_seed where kind='institution'),null,
    'Nome que nao existe no catalogo'),
  'a free name is available')
  where exists(select 1 from location_write_seed where kind='institution' and id is not null);

-- Deny by default: without an internal context no command does anything.
create temporary table location_write_responses(seq integer primary key, body jsonb);
grant insert on location_write_responses to authenticated;
set local role authenticated;
insert into location_write_responses values
  (1,public.superadmin_location_update_v2('10000000-0000-4000-8000-000000000001',
     jsonb_build_object('scope_kind','institution',
       'institution_id','10000000-0000-4000-8000-000000000001','unit_id',null,'name','Sala',
       'description',null,'kind','internal','floor',null,'address',null,'visibility','team'),
     1,'10000000-0000-4000-8000-000000000002')),
  (2,public.superadmin_location_set_status_v2('10000000-0000-4000-8000-000000000001','archived',1,
     '10000000-0000-4000-8000-000000000003')),
  -- A malformed request must still authenticate before it is judged malformed.
  (3,public.superadmin_location_update_v2(null,'{}'::jsonb,null,null)),
  (4,public.superadmin_location_set_status_v2(null,'nao-existe',null,null));
reset role;
select is((select body#>>'{error,code}' from location_write_responses where seq=1),
  'SAI_AUTH_REQUIRED','editing requires a validated session');
select is((select body#>>'{error,code}' from location_write_responses where seq=2),
  'SAI_AUTH_REQUIRED','changing status requires a validated session');
select is((select body#>>'{error,code}' from location_write_responses where seq=3),
  'SAI_AUTH_REQUIRED','the edit authenticates before it reads the payload');
select is((select body#>>'{error,code}' from location_write_responses where seq=4),
  'SAI_AUTH_REQUIRED','the status change authenticates before it reads the argument');
select is((select count(*)::integer from location_write_responses where body->>'ok'<>'false'),0,
  'no unauthenticated call reported success');
select is((select count(*)::integer from app_private.superadmin_location_write_receipts),0,
  'no unauthenticated call left a receipt');

select * from finish();
rollback;
