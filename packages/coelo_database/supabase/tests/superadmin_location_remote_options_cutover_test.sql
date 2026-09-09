-- Candidate regression, isolated serialized local Eng1 replay only.
-- Temporarily restores the exact observed legacy body INSIDE this rolled-back
-- transaction to compare real authorized calls against the exact patched body.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,pg_catalog;
create temporary table loc_options_cutover_evidence(
 snapshot_hash_ok boolean, original_remote_count integer, fixed_remote_count integer,
 canonical_count integer, drift_count integer, duplicate_count integer,
 exact_remaining_bytes boolean, no_catalog_reference boolean, no_students boolean,
 same_other_filters boolean, metadata_acl_ok boolean);
create temporary table loc_options_test_definitions(before_definition text,after_definition text);
do $comparison$
declare
 snapshot jsonb := $snapshot${"definition":"CREATE OR REPLACE FUNCTION app_private.superadmin_get_activity_form_options(p_institution_id uuid)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE SECURITY DEFINER\n SET search_path TO ''\nAS $function$\r\ndeclare result jsonb;\r\nbegin\r\n if (select auth.uid()) is null or\r\n    not app_private.has_platform_permission('activities.read') then\r\n  raise insufficient_privilege using message='activities.read required';\r\n end if;\r\n if p_institution_id is not null and not exists(select 1 from public.institutions institution\r\n   where institution.id=p_institution_id) then\r\n  raise no_data_found using message='institution not found';\r\n end if;\r\n select jsonb_build_object(\r\n  'institutions',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',institution.id,'name',institution.public_name) order by institution.public_name)\r\n    from public.institutions institution\r\n    where p_institution_id is null or institution.id=p_institution_id),'[]'::jsonb),\r\n  'units',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',unit.id,'institution_id',unit.institution_id,'name',unit.name) order by unit.name)\r\n    from public.units unit where (p_institution_id is null\r\n      or unit.institution_id=p_institution_id) and unit.status<>'archived'),'[]'::jsonb),\r\n  'locations',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',location.id,'unit_id',location.unit_id,'name',location.name) order by location.name)\r\n    from public.activity_locations location where (p_institution_id is null\r\n      or location.institution_id=p_institution_id) and location.status='active'),'[]'::jsonb),\r\n  'groups',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',group_record.id,'unit_id',group_record.unit_id,'name',group_record.name,\r\n    'participant_count',(select count(*) from public.child_group_links child_link\r\n      where child_link.group_id=group_record.id and child_link.status='active'))\r\n    order by group_record.name) from public.groups group_record\r\n    where (p_institution_id is null or group_record.institution_id=p_institution_id)\r\n     and group_record.status<>'archived'),'[]'::jsonb),\r\n  'professionals',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'membership_id',membership.id,'person_id',person.id,'name',person.display_name,\r\n    'role',membership.role_code) order by person.display_name)\r\n    from public.institution_memberships membership\r\n    join public.people person on person.id=membership.person_id\r\n    where (p_institution_id is null or membership.institution_id=p_institution_id)\r\n     and membership.status='active' and membership.revoked_at is null\r\n     and person.person_type<>'child' and person.status='active'),'[]'::jsonb),\r\n  'taxonomy',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',category.id,'label',category.name,'is_other',category.code='outros',\r\n    'subtypes',coalesce((select jsonb_agg(jsonb_build_object(\r\n      'id',subtype.id,'label',subtype.name) order by subtype.sort_order,subtype.name)\r\n      from public.activity_taxonomies subtype where subtype.parent_id=category.id\r\n       and subtype.status='active'),'[]'::jsonb))\r\n    order by category.sort_order,category.name)\r\n    from public.activity_taxonomies category\r\n    where category.taxonomy_kind='category' and category.status='active'),'[]'::jsonb),\r\n  'templates',coalesce((select jsonb_agg(jsonb_build_object(\n    'id',template.id,'name',template.name,\n    'description',template.description,\n    'scope_kind',template.scope_kind,\n    'institution_id',template.institution_id,\n    'governance_kind',template.governance_kind,\n    'taxonomy_id',coalesce(taxonomy.parent_id,taxonomy.id),\n    'subtype_id',case when taxonomy.taxonomy_kind='subtype' then taxonomy.id end)\r\n    order by template.name)\r\n    from public.activity_templates template\r\n    join public.activity_taxonomies taxonomy on taxonomy.id=template.taxonomy_id\r\n    where template.status='active' and (template.scope_kind='platform'\r\n      or template.institution_id=p_institution_id)),'[]'::jsonb)\r\n ) into result;\r\n return result;\r\nend $function$\n","definition_md5_raw":"65fe6408f0f2c6b0c1c9d71a809f2d80"}$snapshot$::jsonb;
 original_pattern text := $original$'locations',coalesce\(\(select jsonb_agg\(jsonb_build_object\([[:space:]]*'id',location.id,'unit_id',location.unit_id,'name',location.name\) order by location.name\).*?and location.institution_id=p_institution_id and location.status='active'\),'\[\]'::jsonb\)$original$;
 fixed_pattern text := $pattern$'locations',coalesce\(\(select jsonb_agg\(jsonb_build_object\([[:space:]]*'id',location\.id,'unit_id',location\.unit_id,'name',location\.name\) order by location\.name\)[[:space:]]*from public\.activity_locations location where \(p_institution_id is null[[:space:]]*or location\.institution_id=p_institution_id\) and location\.status='active'\),'\[\]'::jsonb\)$pattern$;
 canonical_fragment text := $canonical$'locations',coalesce((select jsonb_agg(jsonb_build_object(
    'id',location.id,'unit_id',location.unit_id,'name',location.name) order by location.name)
    from public.activity_locations location where p_institution_id is not null
      and location.institution_id=p_institution_id and location.status='active'),'[]'::jsonb)$canonical$;
 original_count integer; fixed_count integer; canonical_count integer; drift_count integer; duplicate_count integer;
 expected_definition text; actual_definition text; function_record record;
begin
 select count(*) into original_count from regexp_matches(snapshot->>'definition',original_pattern,'gs');
 select count(*) into fixed_count from regexp_matches(snapshot->>'definition',fixed_pattern,'gs');
 select count(*) into canonical_count from regexp_matches(canonical_fragment,fixed_pattern,'gs');
 select count(*) into drift_count from regexp_matches(replace(snapshot->>'definition',
   'or location.institution_id=p_institution_id','or true'),fixed_pattern,'gs');
 select count(*) into duplicate_count from regexp_matches((snapshot->>'definition')||(snapshot->>'definition'),fixed_pattern,'gs');
 expected_definition := regexp_replace(snapshot->>'definition',fixed_pattern,$replacement$'locations','[]'::jsonb$replacement$,'gs');
 select p.* into function_record from pg_proc p where oid=to_regprocedure('app_private.superadmin_get_activity_form_options(uuid)');
 actual_definition := pg_get_functiondef(function_record.oid);
 insert into loc_options_test_definitions values(snapshot->>'definition',actual_definition);
 insert into loc_options_cutover_evidence values(
  md5(snapshot->>'definition')='65fe6408f0f2c6b0c1c9d71a809f2d80',
  original_count,fixed_count,canonical_count,drift_count,duplicate_count,
  actual_definition=expected_definition,
  position('public.activity_locations' in actual_definition)=0,
  position('''students''' in actual_definition)=0,
  position('public.units unit where (p_institution_id is null' in actual_definition)>0
   and position('where (p_institution_id is null or group_record.institution_id=p_institution_id)' in actual_definition)>0
   and position('where (p_institution_id is null or membership.institution_id=p_institution_id)' in actual_definition)>0,
  pg_get_userbyid(function_record.proowner)='postgres' and function_record.prosecdef
   and function_record.provolatile='s' and function_record.proconfig=array['search_path=""']::text[]
   and not exists(select 1 from aclexplode(coalesce(function_record.proacl,acldefault('f',function_record.proowner))) a
    where a.grantee<>function_record.proowner));
end
$comparison$;
set local search_path=public,extensions,pg_catalog;
select extensions.plan(18);
select extensions.ok(coalesce(snapshot_hash_ok,false),'exact remote snapshot raw pin') from loc_options_cutover_evidence;
select extensions.is(original_remote_count,0,'old canonical pattern demonstrably misses remote snapshot') from loc_options_cutover_evidence;
select extensions.is(fixed_remote_count,1,'new narrow pattern matches remote exactly once') from loc_options_cutover_evidence;
select extensions.is(canonical_count,0,'canonical alternate is not silently accepted') from loc_options_cutover_evidence;
select extensions.is(drift_count,0,'changed predicate is rejected') from loc_options_cutover_evidence;
select extensions.is(duplicate_count,2,'duplicate block cannot satisfy exactly-one gate') from loc_options_cutover_evidence;
select extensions.ok(coalesce(exact_remaining_bytes,false),'every non-location definition byte preserved') from loc_options_cutover_evidence;
select extensions.ok(coalesce(no_catalog_reference,false),'legacy options no longer query location catalog') from loc_options_cutover_evidence;
select extensions.ok(coalesce(no_students,false),'students is not restored') from loc_options_cutover_evidence;
select extensions.ok(coalesce(same_other_filters,false),'other ORNULL filters unchanged') from loc_options_cutover_evidence;
select extensions.ok(coalesce(metadata_acl_ok,false),'private options metadata and ACL preserved') from loc_options_cutover_evidence;

-- Equivalent eligible data in A/B; no permission helper or wrapper is mocked.
-- Real legacy platform Owner: this is preservation evidence, NOT internal-realm E2E.
insert into public.institution_types(id,code,name,status) values
 ('b2000000-0000-4000-8000-000000000001','loc-options-fixture','Loc options fixture','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id)
 select ('b2100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'Loc options '||n,'loc-options-'||n,'active','b2000000-0000-4000-8000-000000000001'
 from generate_series(1,2) n;
insert into public.units(id,institution_id,name,slug,status,institution_type_id)
 select ('b2200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('b2100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'Equivalent unit '||n,'loc-options-unit','active','b2000000-0000-4000-8000-000000000001'
 from generate_series(1,2) n;
insert into public.groups(id,institution_id,unit_id,name,status)
 select ('b2300000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('b2100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('b2200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Equivalent group '||n,'active'
 from generate_series(1,2) n;
insert into public.people(id,person_type,first_name,last_name,display_name)
 select ('b2400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'adult','Synthetic','Options','Equivalent professional '||n from generate_series(1,3) n;
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind)
 select ('b2500000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('b2400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('b2100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'teacher','active','institution'
 from generate_series(1,2) n;
insert into public.activity_locations(id,institution_id,unit_id,name,status,
 scope_kind,kind,visibility,created_by_person_id)
 select ('b2600000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('b2100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('b2200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'Equivalent location '||n,'active','unit','internal','team','b2400000-0000-4000-8000-000000000003'
 from generate_series(1,2) n;
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
 values('b2700000-0000-4000-8000-000000000001','authenticated','authenticated',
 'loc-options-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id,status)
 values('b2400000-0000-4000-8000-000000000003','b2700000-0000-4000-8000-000000000001','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind)
 select 'b2400000-0000-4000-8000-000000000003',id,'active','platform'
 from public.platform_roles where code='owner' and status='active';

create temporary table loc_options_expected(scope integer,key text,identity_key text,id text);
insert into loc_options_expected
 select n,v.key,v.identity_key,v.prefix||lpad(n::text,12,'0')
 from generate_series(1,2) n cross join (values
  ('units','id','b2200000-0000-4000-8000-'),
  ('groups','id','b2300000-0000-4000-8000-'),
  ('professionals','membership_id','b2500000-0000-4000-8000-'),
  ('locations','id','b2600000-0000-4000-8000-')) v(key,identity_key,prefix);
create temporary table loc_options_results(phase text,scope integer,body jsonb,primary key(phase,scope));
grant select,insert on loc_options_results to authenticated;
do $before$ begin
 execute (select before_definition from loc_options_test_definitions);
end $before$;
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','b2700000-0000-4000-8000-000000000001','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
insert into loc_options_results values
 ('before',0,public.superadmin_get_activity_form_options(null)),
 ('before',1,public.superadmin_get_activity_form_options('b2100000-0000-4000-8000-000000000001')),
 ('before',2,public.superadmin_get_activity_form_options('b2100000-0000-4000-8000-000000000002'));
reset role;
do $after$ begin
 execute (select after_definition from loc_options_test_definitions);
end $after$;
set local role authenticated;
insert into loc_options_results values
 ('after',0,public.superadmin_get_activity_form_options(null)),
 ('after',1,public.superadmin_get_activity_form_options('b2100000-0000-4000-8000-000000000001')),
 ('after',2,public.superadmin_get_activity_form_options('b2100000-0000-4000-8000-000000000002'));
reset role;
select extensions.is((select count(*) from loc_options_expected e join loc_options_results r
 on r.phase='before' and r.scope=0
 where r.body->e.key @> jsonb_build_array(jsonb_build_object(e.identity_key,e.id))),8::bigint,
 'NULL institution exposes both eligible fixture rows in all four original arrays');
select extensions.is((select count(*) from loc_options_expected e join loc_options_results r
 on r.phase='before' and r.scope=e.scope where e.scope=1
 and jsonb_array_length(r.body->e.key)=1
 and r.body->e.key @> jsonb_build_array(jsonb_build_object(e.identity_key,e.id))),4::bigint,
 'explicit institution A returns only A fixture row in each original array');
select extensions.is((select count(*) from loc_options_expected e join loc_options_results r
 on r.phase='before' and r.scope=e.scope where e.scope=2
 and jsonb_array_length(r.body->e.key)=1
 and r.body->e.key @> jsonb_build_array(jsonb_build_object(e.identity_key,e.id))),4::bigint,
 'explicit institution B returns only B fixture row in each original array');
select extensions.is((select count(*) from loc_options_results b join loc_options_results a
 on a.scope=b.scope and a.phase='after' where b.phase='before'
 and b.body-'locations'=a.body-'locations'),3::bigint,
 'NULL/A/B preserve every non-location response field against identical data');
select extensions.is((select count(*) from loc_options_results
 where phase='after' and body->'locations'='[]'::jsonb),3::bigint,
 'NULL/A/B locations closed to empty array after cutover');
select extensions.is((select count(*) from loc_options_results
 where jsonb_typeof(body)='object' and not(body ? 'students')),6::bigint,
 'students KEY ABSENT in every before/after response, never an empty restored key');
select extensions.is(md5(pg_get_functiondef('app_private.superadmin_get_activity_form_options(uuid)'::regprocedure)),
 '2486e539f723d3f61cd9f29984efcbb2','exact post-cutover definition restored after behavioral comparison');
select * from extensions.finish();
rollback;
