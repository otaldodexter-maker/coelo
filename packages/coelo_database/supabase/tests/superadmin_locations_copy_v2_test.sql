-- LOCAL CANDIDATE ONLY: selected/executed by the serialized replay owner.
-- Covers 20260908190648_superadmin_locations_copy_v2.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_function('public','superadmin_location_copy_v2',
  array['uuid','text','uuid','uuid','text','uuid']);
select ok(has_function_privilege('authenticated',
  'public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)','EXECUTE'),
  'the copy command is reachable by a client');
select ok(not has_function_privilege('anon',
  'public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)','EXECUTE'),
  'an anonymous caller cannot copy');
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='superadmin_location_copy_v2'),1,
  'the copy command has exactly one signature');
select ok((select p.prosecdef and p.proconfig @> array['search_path=""']
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='superadmin_location_copy_v2'),
  'the copy command is definer with a pinned empty search path');

-- Provenance is internal, so it never widens the catalog and never reaches a client.
select is((select count(*)::integer from pg_attribute
  where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped),16,
  'the copy package did not widen the catalog');
select has_table('app_private'::name,'superadmin_location_copy_lineage'::name);
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='app_private.superadmin_location_copy_lineage'::regclass),
  'the lineage is RLS forced');
select ok(not has_table_privilege('authenticated',
  'app_private.superadmin_location_copy_lineage','SELECT'),'the lineage is private');
select ok(not has_table_privilege('service_role',
  'app_private.superadmin_location_copy_lineage','SELECT'),'not even service_role reads the lineage');
select is((select count(*)::integer from pg_constraint
  where conrelid='app_private.superadmin_location_copy_lineage'::regclass and contype='c'
    and pg_get_constraintdef(oid)=$def$CHECK ((location_id <> source_location_id))$def$),1,
  'a row is never recorded as a copy of itself');
select is((select count(*)::integer from pg_constraint
  where conrelid='app_private.superadmin_location_copy_lineage'::regclass and contype='f'
    and confdeltype='r'),2,
  'lineage keeps its source and its author from being deleted out from under it');

-- The copy joins the receipt lane that the edit package opened; it does not open a second one.
select is((select count(*)::integer from pg_constraint
  where conrelid='app_private.superadmin_location_write_receipts'::regclass and contype='c'
    and pg_get_constraintdef(oid)
      =$def$CHECK ((operation = ANY (ARRAY['update'::text, 'status'::text, 'copy'::text])))$def$),1,
  'the receipt lane now names three verbs and still only named verbs');
select is((select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='app_private' and c.relkind='r'
    and c.relname like 'superadmin_location_%receipts'),1,
  'there is still exactly one write receipt table');

-- Deny by default: without an internal context the copy does nothing.
create temporary table location_copy_responses(seq integer primary key, body jsonb);
grant insert on location_copy_responses to authenticated;
set local role authenticated;
insert into location_copy_responses values
  (1,public.superadmin_location_copy_v2('10000000-0000-4000-8000-000000000001','institution',
     '10000000-0000-4000-8000-000000000001',null,'Copia','10000000-0000-4000-8000-000000000002')),
  -- A malformed request must still authenticate before it is judged malformed.
  (2,public.superadmin_location_copy_v2(null,null,null,null,null,null));
reset role;
select is((select body#>>'{error,code}' from location_copy_responses where seq=1),
  'SAI_AUTH_REQUIRED','copying requires a validated session');
select is((select body#>>'{error,code}' from location_copy_responses where seq=2),
  'SAI_AUTH_REQUIRED','the copy authenticates before it reads its arguments');
select is((select count(*)::integer from location_copy_responses where body->>'ok'<>'false'),0,
  'no unauthenticated call reported success');
select is((select count(*)::integer from app_private.superadmin_location_copy_lineage),0,
  'no unauthenticated call left provenance behind');

select * from finish();
rollback;
