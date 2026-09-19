-- Prova pgTAP da migration 20260920081000 (spec 068: backfill cobre a pessoa-ator do operador interno).
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users(id) values ('9f300000-0000-4000-8000-000000000101');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9f300000-0000-4000-8000-000000000201','service','Operador','9f3','Operador 9f3','active');
insert into app_private.superadmin_internal_identities(id) values ('9f300000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f300000-0000-4000-8000-000000000501','9f300000-0000-4000-8000-000000000301','9f300000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_actor_people(internal_identity_id,person_id) values
 ('9f300000-0000-4000-8000-000000000301','9f300000-0000-4000-8000-000000000201');

select ok(app_private.official_profiles_backfill_follows_v1() >= 4,'backfill follows the officials for the internal actor person');
select is((select count(*) from public.follow_links f join public.official_profiles o on o.person_id=f.target_id
  where f.follower_person_id='9f300000-0000-4000-8000-000000000201' and f.status='active'),
  (select count(*) from public.official_profiles where status='active'),'actor follows every active official');
select is(app_private.official_profiles_backfill_follows_v1(),0,'idempotent');
select ok(not exists(select 1 from public.follow_links where follower_person_id in
  (select person_id from public.official_profiles) and origin='official_auto'),'official persons never follow each other');

select * from finish();
rollback;
