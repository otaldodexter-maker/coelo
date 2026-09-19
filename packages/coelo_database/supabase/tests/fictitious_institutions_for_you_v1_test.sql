-- Prova pgTAP da migration 20260920090000 (F12: três instituições fictícias validam o "Para você").
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select is((select count(*) from public.institutions where id::text like 'f1c7%' and status='active'),3::bigint,'three fictitious institutions');
select is((select count(*) from public.units where institution_id::text like 'f1c7%'),6::bigint,'two units each');
select is((select count(*) from public.groups where institution_id::text like 'f1c7%'),12::bigint,'four groups each');
select is((select count(*) from public.institution_memberships where institution_id::text like 'f1c7%' and role_code='guardian' and scope_kind='group'),12::bigint,'four guardians each, scoped to a group');
select is((select count(*) from public.child_group_links l join public.child_unit_links u on u.id=l.child_unit_link_id where u.id::text like 'f1c7%' and l.status='active'),18::bigint,'six children in groups each');
select is((select count(*) from public.guardian_links where id::text like 'f1c7%' and status='active'),24::bigint,'mother and father per linked child');

-- responsável 4 do Horizonte Azul (Maternal I, sede) e responsável 4 do Jardim das Cores
insert into auth.users(id) values ('f1c7f000-0000-4000-8000-000000000101'),('f1c7f000-0000-4000-8000-000000000102');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('f1c71000-0000-4000-8000-000400000004','f1c7f000-0000-4000-8000-000000000101','active'),
 ('f1c72000-0000-4000-8000-000400000004','f1c7f000-0000-4000-8000-000000000102','active');

select set_config('request.jwt.claim.sub','f1c7f000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','f1c7f000-0000-4000-8000-000000000101','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select is((select count(*) from jsonb_array_elements(public.list_my_principal_for_you('all',null,50)#>'{data,items}') i where i->>'id' like 'f1c79%'),4::bigint,'Horizonte guardian sees platform+institution+unit+group');
reset role;
select set_config('request.jwt.claim.sub','f1c7f000-0000-4000-8000-000000000102',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','f1c7f000-0000-4000-8000-000000000102','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select is((select count(*) from jsonb_array_elements(public.list_my_principal_for_you('all',null,50)#>'{data,items}') i where i->>'id' like 'f1c79%'),1::bigint,'Jardim guardian sees only the platform one');
select is((select count(*) from public.list_my_principal_contexts()),1::bigint,'Jardim guardian has one Principal context');
reset role;

select * from finish();
rollback;
