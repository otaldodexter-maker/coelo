-- LOCAL CANDIDATE ONLY: selected/executed by the serialized replay owner.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_function('public','superadmin_location_create_v2',array['jsonb','uuid']);
select has_function('public','superadmin_location_detail_v2',array['uuid']);
select has_function('public','superadmin_location_directory_v2',
  array['text','uuid','uuid','text','integer','integer']);
select has_column('public','activity_locations','scope_kind',
  'catalog stores its explicit owner scope');
select has_column('public','activity_locations','created_by_internal_identity_id',
  'catalog stores the internal creator provenance');
select ok(not has_table_privilege('authenticated','public.activity_locations','SELECT'),
  'authenticated cannot read the catalog directly');
select ok(not has_table_privilege('anon','public.activity_locations','SELECT'),
  'anonymous cannot read the catalog');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='public.activity_locations'::regclass),'catalog remains RLS forced');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='app_private.superadmin_location_create_receipts'::regclass),
  'receipt is RLS forced');
select ok(not has_table_privilege('authenticated',
  'app_private.superadmin_location_create_receipts','SELECT'),'receipt is private');
select ok(not has_function_privilege('authenticated',
  'app_private.superadmin_location_normalize_v2(jsonb)','EXECUTE'),
  'normalizer helper has no client execution');

create temporary table location_candidate_payload(value jsonb);
insert into location_candidate_payload values(jsonb_build_object(
  'scope_kind','institution','institution_id','10000000-0000-4000-8000-000000000001',
  'unit_id',null,'name','  Sala  ','description',null,'kind','internal',
  'floor',null,'address',null,'visibility','team'));

select is(app_private.superadmin_location_normalize_v2(value)->>'name','Sala',
  'name is trimmed') from location_candidate_payload;
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value-'kind' from location_candidate_payload))$$,'22023',null,
  'kind cannot be inferred');
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value-'visibility' from location_candidate_payload))$$,'22023',null,
  'visibility cannot be inferred');
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value||'{"created_by_person_id":"10000000-0000-4000-8000-000000000001"}' from location_candidate_payload))$$,
  '22023',null,'client cannot choose an author');
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value||jsonb_build_object('name',repeat('x',121)) from location_candidate_payload))$$,
  '22023',null,'name limit is 120');
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value||jsonb_build_object('description',repeat('x',501)) from location_candidate_payload))$$,
  '22023',null,'description limit is 500');
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value||jsonb_build_object('floor',repeat('x',121)) from location_candidate_payload))$$,
  '22023',null,'floor candidate limit is 120');
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value||'{"kind":"external"}' from location_candidate_payload))$$,
  '22023',null,'external location requires its own address');
select lives_ok($$select app_private.superadmin_location_normalize_v2(
  (select value||'{"kind":"external","address":{"country":"Brasil"}}' from location_candidate_payload))$$,
  'minimal canonical address accepts Brasil without inventing street requirement');
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value||'{"address":{"country":"Brasil","postal_code":"01001-000"}}' from location_candidate_payload))$$,
  '22023',null,'postal code uses the existing unmasked eight-digit contract');
select throws_ok($$select app_private.superadmin_location_normalize_v2(
  (select value||'{"scope_kind":"unit"}' from location_candidate_payload))$$,
  '22023',null,'unit owner requires a unit id');

select ok(pg_get_functiondef('app_private.activity_management_payload(uuid)'::regprocedure)
  !~ 'public.activity_locations','legacy payload does not discover catalog rows');
select ok(pg_get_functiondef('app_private.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)'::regprocedure)
  !~ 'public.activity_locations','legacy directory location_names does not discover rows');
select ok(pg_get_functiondef('app_private.superadmin_get_activity_form_options(uuid)'::regprocedure)
  !~ 'public.activity_locations','legacy options do not discover rows');
select ok(not has_function_privilege('authenticated',
  'public.superadmin_create_activity_locations(uuid,uuid[],text,uuid)','EXECUTE'),
  'legacy writer is not available to authenticated');
select throws_ok($$select app_private.superadmin_create_activity_locations(null,null,null,null)$$,
  '42501',null,'legacy helper cannot replay or write');

select set_config('request.jwt.claims','{}',true);
create temporary table location_no_session_responses(seq integer primary key,body jsonb);
grant insert on location_no_session_responses to authenticated;
set local role authenticated;
insert into location_no_session_responses values
  (1,public.superadmin_location_detail_v2('10000000-0000-4000-8000-000000000001')),
  (2,public.superadmin_location_directory_v2('institution',
    '10000000-0000-4000-8000-000000000001',null,null,24,0)),
  (3,public.superadmin_location_create_v2('{}','10000000-0000-4000-8000-000000000002'));
reset role;
select is((select body#>>'{error,code}' from location_no_session_responses where seq=1),
  'SAI_AUTH_REQUIRED','detail requires validated session');
select is((select body#>>'{error,code}' from location_no_session_responses where seq=2),
  'SAI_AUTH_REQUIRED','directory requires validated session');
select is((select body#>>'{error,code}' from location_no_session_responses where seq=3),
  'SAI_AUTH_REQUIRED','create authenticates before processing payload');

select * from finish();
rollback;
