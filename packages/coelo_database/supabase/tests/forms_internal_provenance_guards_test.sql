-- F-AUTHOR03-SAFE. Prepared synthetic rollback-only fixture, NOT executed here.
-- Eng1 runs against the nominal base plus F-AUTHOR01 before/after 054000.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_function('app_private', 'form_assert_distribution_target', array['uuid','uuid','uuid'], 'existing distribution helper present');
select has_function('app_private', 'block_published_form_definition_mutation', array[]::text[], 'existing immutability trigger function present');
select ok(p.prosecdef and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
  and p.proconfig @> array['search_path=""'], p.proname || ' keeps privileged function configuration')
from pg_catalog.pg_proc p
where p.oid in (
  'app_private.form_assert_distribution_target(uuid,uuid,uuid)'::regprocedure,
  'app_private.block_published_form_definition_mutation()'::regprocedure
);
select ok(not pg_catalog.has_function_privilege(role_name, function_name, 'execute'), role_name || ' cannot call private ' || function_name)
from (values ('anon'),('authenticated')) roles(role_name)
cross join (values
  ('app_private.form_assert_distribution_target(uuid,uuid,uuid)'),
  ('app_private.block_published_form_definition_mutation()')
) functions(function_name);
select ok(not pg_catalog.has_function_privilege('service_role', 'app_private.form_assert_distribution_target(uuid,uuid,uuid)', 'execute'), 'service role remains denied at G');

insert into public.institution_types(id,code,name,status) values
 ('8f040000-0000-4000-8000-000000000001','fauthor03-safe','Forms provenance synthetic type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 ('8f040000-0000-4000-8000-000000000010','8f040000-0000-4000-8000-000000000001','Forms provenance A','fauthor03-safe-a','active'),
 ('8f040000-0000-4000-8000-000000000020','8f040000-0000-4000-8000-000000000001','Forms provenance B','fauthor03-safe-b','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8f040000-0000-4000-8000-000000000101','adult','Synthetic','P1','Forms provenance P1','active'),
 ('8f040000-0000-4000-8000-000000000102','adult','Synthetic','P2','Forms provenance P2','active');
insert into app_private.superadmin_internal_identities(id) values
 ('8f040000-0000-4000-8000-000000000201'),
 ('8f040000-0000-4000-8000-000000000202');

-- G unit test only: actor is a real People row, not an internal identity bridge.
-- No wrapper/Auth/session or publishing integration is claimed by this fixture.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r
cross join public.platform_permissions p where r.code='operations' and p.code='forms.manage'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required)
select '8f040000-0000-4000-8000-000000000101',id,'active','institution','8f040000-0000-4000-8000-000000000010',false
from public.platform_roles where code='operations';

create temporary table provenance_cases (
 label text primary key, form_id uuid not null, version_id uuid not null,
 old_state text not null, new_state text not null,
 old_person uuid, old_internal uuid, new_person uuid, new_internal uuid,
 should_succeed boolean not null
);
insert into provenance_cases
select change.label || '-' || transition.old_state,
 pg_catalog.md5('fauthor03-form-' || change.label || '-' || transition.old_state)::uuid,
 pg_catalog.md5('fauthor03-version-' || change.label || '-' || transition.old_state)::uuid,
 transition.old_state, transition.new_state,
 change.old_person, change.old_internal, change.new_person, change.new_internal, change.should_succeed
from (values ('working','published'),('published','superseded')) transition(old_state,new_state)
cross join (values
 ('internal-swap',null::uuid,'8f040000-0000-4000-8000-000000000201'::uuid,null::uuid,'8f040000-0000-4000-8000-000000000202'::uuid,false),
 ('people-to-internal','8f040000-0000-4000-8000-000000000101'::uuid,null::uuid,null::uuid,'8f040000-0000-4000-8000-000000000201'::uuid,false),
 ('internal-to-people',null::uuid,'8f040000-0000-4000-8000-000000000201'::uuid,'8f040000-0000-4000-8000-000000000101'::uuid,null::uuid,false),
 ('people-swap','8f040000-0000-4000-8000-000000000101'::uuid,null::uuid,'8f040000-0000-4000-8000-000000000102'::uuid,null::uuid,false),
 ('internal-preserved',null::uuid,'8f040000-0000-4000-8000-000000000201'::uuid,null::uuid,'8f040000-0000-4000-8000-000000000201'::uuid,true),
 ('people-preserved','8f040000-0000-4000-8000-000000000101'::uuid,null::uuid,'8f040000-0000-4000-8000-000000000101'::uuid,null::uuid,true)
) change(label,old_person,old_internal,new_person,new_internal,should_succeed);

-- Separate forms avoid working-version uniqueness masking the target guard.
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,
 created_by_person_id,updated_by_person_id,created_by_internal_identity_id,updated_by_internal_identity_id)
select form_id,'8f040000-0000-4000-8000-000000000010','form','identified','person',label,
 old_person,old_person,old_internal,old_internal from provenance_cases;
insert into public.form_versions(id,form_id,version_number,state,created_by_person_id,created_by_internal_identity_id,published_at)
select version_id,form_id,1,old_state,old_person,old_internal,
 case when old_state='published' then timestamptz '2026-09-08 00:00:00+00' else null end
from provenance_cases;

select is((select count(*) from provenance_cases),12::bigint,'twelve independent valid transition cases');
select ok(not exists(select 1 from provenance_cases c where
 (c.old_person is null) = (c.old_internal is null) or (c.new_person is null) = (c.new_internal is null)),
 'both original and replacement creators satisfy XOR');
select ok(not exists(select 1 from provenance_cases c where
 (c.new_person is not null and not exists(select 1 from public.people p where p.id=c.new_person))
 or (c.new_internal is not null and not exists(select 1 from app_private.superadmin_internal_identities i where i.id=c.new_internal))),
 'all replacement creator FKs exist before testing');

select lives_ok(
 format('select app_private.form_assert_distribution_target(%L::uuid,%L::uuid,%L::uuid)',
  '8f040000-0000-4000-8000-000000000101',form_id,'8f040000-0000-4000-8000-000000000010'),
 'G accepts matching target with actual forms.manage membership')
from provenance_cases where label='people-preserved-working';
select throws_ok(
 format('select app_private.form_assert_distribution_target(%L::uuid,%L::uuid,%L::uuid)',
  '8f040000-0000-4000-8000-000000000101',form_id,'8f040000-0000-4000-8000-000000000020'),
 '22023','form and institution must match','G rejects wrong institution before permission')
from provenance_cases where label='people-preserved-working';
select throws_ok(
 format('select app_private.form_assert_distribution_target(%L::uuid,%L::uuid,%L::uuid)',
  '8f040000-0000-4000-8000-000000000102',form_id,'8f040000-0000-4000-8000-000000000010'),
 '42501','form distribution institution unavailable','G still requires forms.manage')
from provenance_cases where label='people-preserved-working';

create temporary table provenance_before as
select c.label,pg_catalog.to_jsonb(v) snapshot from provenance_cases c
join public.form_versions v on v.id=c.version_id;
create temporary table provenance_results(label text primary key,actual_sqlstate text);
do $attempts$
declare c record; fault text;
begin
  for c in select * from provenance_cases order by label loop
    begin
      update public.form_versions
      set state=c.new_state,
          published_at=case when c.old_state='working' then timestamptz '2026-09-08 00:00:00+00' else published_at end,
          created_by_person_id=c.new_person,
          created_by_internal_identity_id=c.new_internal
      where id=c.version_id;
      fault:='NO_EXCEPTION';
    exception when others then
      fault:=sqlstate;
    end;
    insert into provenance_results values(c.label,fault);
  end loop;
end
$attempts$;

select is(r.actual_sqlstate,case when c.should_succeed then 'NO_EXCEPTION' else '42501' end,
 c.label || ' exact result for valid state transition')
from provenance_cases c join provenance_results r using(label) order by c.label;
select is(pg_catalog.to_jsonb(v),b.snapshot,c.label || ' denial rolls back state, published_at and both creators')
from provenance_cases c join provenance_before b using(label)
join public.form_versions v on v.id=c.version_id where not c.should_succeed order by c.label;
select ok(v.state=c.new_state
 and v.created_by_person_id is not distinct from c.old_person
 and v.created_by_internal_identity_id is not distinct from c.old_internal
 and v.published_at=timestamptz '2026-09-08 00:00:00+00',
 c.label || ' legitimate transition preserves provenance')
from provenance_cases c join public.form_versions v on v.id=c.version_id
where c.should_succeed order by c.label;

select * from finish();
rollback;
