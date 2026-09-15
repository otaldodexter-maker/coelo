begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(6);

insert into auth.users(id) values
  ('c2100000-0000-4000-8000-000000000001'),
  ('c2100000-0000-4000-8000-000000000002');
insert into public.people(id,person_type,first_name,last_name,display_name,status)
values
  ('c2200000-0000-4000-8000-000000000001','adult','Agora','Autor A','Agora Autor A','active'),
  ('c2200000-0000-4000-8000-000000000002','adult','Agora','Ator B','Agora Ator B','active');
insert into public.person_auth_links(person_id,auth_user_id,status)
values
  ('c2200000-0000-4000-8000-000000000001','c2100000-0000-4000-8000-000000000001','active'),
  ('c2200000-0000-4000-8000-000000000002','c2100000-0000-4000-8000-000000000002','active');
insert into public.institutions(id,public_name,legal_name,slug,status)
values
  ('c2300000-0000-4000-8000-000000000001','Agora A','Agora A','agora-cross-a','active'),
  ('c2300000-0000-4000-8000-000000000002','Agora B','Agora B','agora-cross-b','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind)
values
  ('c2400000-0000-4000-8000-000000000001','c2200000-0000-4000-8000-000000000001','c2300000-0000-4000-8000-000000000001','teacher','active','institution'),
  ('c2400000-0000-4000-8000-000000000002','c2200000-0000-4000-8000-000000000002','c2300000-0000-4000-8000-000000000002','teacher','active','institution');
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id)
values
  ('c2400000-0000-4000-8000-000000000001','now.publications.remove','allow','institution','fixture','active','c2200000-0000-4000-8000-000000000001'),
  ('c2400000-0000-4000-8000-000000000002','now.publications.remove','allow','institution','fixture','active','c2200000-0000-4000-8000-000000000002');
insert into public.now_publications(
  id,institution_id,author_person_id,author_membership_id,caption,status,publish_at,published_at,expires_at,management_version)
values (
  'c2500000-0000-4000-8000-000000000001','c2300000-0000-4000-8000-000000000001',
  'c2200000-0000-4000-8000-000000000001','c2400000-0000-4000-8000-000000000001',
  'Cross tenant target','published',now(),now(),now()+interval '1 hour',2
);

select set_config('request.jwt.claim.sub','c2100000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c2100000-0000-4000-8000-000000000002','role','authenticated','aal','aal1'
)::text,true);
set local role authenticated;
select throws_ok($$select public.remove_now_publication(
  'c2600000-0000-4000-8000-000000000001',
  'c2500000-0000-4000-8000-000000000001',2,'cross tenant attempt'
)$$,'42501',null,'tenant B cannot remove tenant A publication');
reset role;

select is((select status::text from public.now_publications
  where id='c2500000-0000-4000-8000-000000000001'),'published',
  'cross-tenant denial preserves publication status');
select is((select management_version from public.now_publications
  where id='c2500000-0000-4000-8000-000000000001'),2::bigint,
  'cross-tenant denial preserves management version');
select is((select removed_at from public.now_publications
  where id='c2500000-0000-4000-8000-000000000001'),null::timestamptz,
  'cross-tenant denial does not materialize removal');
select is((select count(*)::bigint from app_private.now_publication_audit
  where publication_id='c2500000-0000-4000-8000-000000000001'
    and event_code='publication_removed'),0::bigint,
  'cross-tenant denial creates no successful removal audit');
select is((select count(*)::bigint from app_private.now_media_purge_jobs
  where publication_id='c2500000-0000-4000-8000-000000000001'),0::bigint,
  'cross-tenant denial creates no purge job');

select * from extensions.finish();
rollback;
