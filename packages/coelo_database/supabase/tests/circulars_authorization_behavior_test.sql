begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('97000000-0000-4000-8000-000000000001','Circular Tenant A','Circular Tenant A','circular-tenant-a','active'),
  ('97000000-0000-4000-8000-000000000002','Circular Tenant B','Circular Tenant B','circular-tenant-b','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('97100000-0000-4000-8000-000000000001','adult','Guardian','Allowed','Guardian Allowed','active'),
  ('97100000-0000-4000-8000-000000000002','adult','Guardian','Foreign','Guardian Foreign','active'),
  ('97100000-0000-4000-8000-000000000003','child','Child','A','Child A','active');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
  ('97200000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000003','97000000-0000-4000-8000-000000000001','active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,status) values
  ('97300000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000003','responsavel','active');
insert into public.guardian_context_permissions(guardian_link_id,child_context_id,can_view,status) values
  ('97300000-0000-4000-8000-000000000001','97200000-0000-4000-8000-000000000001',true,'active');

select is(app_private.circular_person_matches_scope(
  '97100000-0000-4000-8000-000000000001','guardian',
  row('97400000-0000-4000-8000-000000000001','97500000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000001','families','institution',null,null,null)::public.circular_audience_rules
),true,'Guardian with an active child permission can read the matching institution scope');
select is(app_private.circular_person_matches_scope(
  '97100000-0000-4000-8000-000000000001','guardian',
  row('97400000-0000-4000-8000-000000000002','97500000-0000-4000-8000-000000000002','97000000-0000-4000-8000-000000000002','families','institution',null,null,null)::public.circular_audience_rules
),false,'Guardian child permission never crosses tenants');
select is(app_private.circular_person_matches_scope(
  '97100000-0000-4000-8000-000000000002','guardian',
  row('97400000-0000-4000-8000-000000000003','97500000-0000-4000-8000-000000000003','97000000-0000-4000-8000-000000000001','families','institution',null,null,null)::public.circular_audience_rules
),false,'Another guardian cannot inherit a child context by guessed identifiers');

select * from finish();
rollback;
