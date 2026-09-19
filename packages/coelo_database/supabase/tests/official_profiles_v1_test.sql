-- Prova pgTAP das migrations 20260920002500/003000 (spec 068, perfis oficiais).
-- Fixture com rollback total (prefixo 9f1): duas pessoas com login (R e S), um oficial extra
-- não obrigatório (Coelo Educa) além do `coelo` obrigatório já carregado.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

create function pg_temp.f(n integer) returns uuid language sql immutable as $$
  select ('9f100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.f(integer) to authenticated;

select has_table('public','official_profiles','official_profiles exists');
select ok((select relforcerowsecurity from pg_class where oid='public.official_profiles'::regclass),'official_profiles forces RLS');
select ok(not has_table_privilege('authenticated','public.official_profiles','SELECT'),'catalog is RPC-only');
select ok(exists(select 1 from public.official_profiles where handle='coelo' and mandatory and status='active'
  and person_id='c0e10000-0000-4000-8000-000000000001'),'coelo is the mandatory official profile');
select ok(exists(select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='follow_origin' and e.enumlabel='official_auto'),'follow_origin has official_auto');
select has_column('public','platform_notices','official_profile_id','notices carry official_profile_id');
select has_function('public','superadmin_official_profiles_list_v1',array[]::text[],'list rpc exists');

-- fixture
insert into auth.users(id) values (pg_temp.f(101)),(pg_temp.f(102));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f(201),'adult','9f1','Responsavel R','9f1 Responsavel R','active'),
 (pg_temp.f(202),'adult','9f1','Responsavel S','9f1 Responsavel S','active'),
 (pg_temp.f(203),'service','Coelo','Educa','Coelo Educa','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.f(201),pg_temp.f(101),'active'),(pg_temp.f(202),pg_temp.f(102),'active');
insert into public.official_profiles(id,person_id,handle,display_name,mandatory,sort_order)
 values (pg_temp.f(301),pg_temp.f(203),'coelo.educa','Coelo Educa',false,1);

-- backfill
-- O gatilho global já segue `coelo` (origin manual) ao criar o login; o backfill cobre o resto.
select ok(app_private.official_profiles_backfill_follows_v1() >= 2,'backfill creates the missing follows');
select is((select count(*) from public.follow_links f join public.official_profiles o on o.person_id=f.target_id where f.follower_person_id=pg_temp.f(201) and f.target_kind='person' and f.status='active'),2::bigint,'R follows both officials');
select is(app_private.official_profiles_backfill_follows_v1(),0,'backfill is idempotent');

-- R não consegue deixar de seguir o Coelo; consegue deixar o Educa; backfill não recria
select set_config('request.jwt.claim.sub', pg_temp.f(101)::text, true);
select set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.f(101)::text, 'role','authenticated','aal','aal1')::text, true);
set local role authenticated;
select throws_ok($$select public.follow_set('person','c0e10000-0000-4000-8000-000000000001',false)$$,'22023',null,'cannot unfollow mandatory Coelo');
select lives_ok(format($$select public.follow_set('person','%s',false)$$, pg_temp.f(203)),'can unfollow a non-mandatory official');
select is((select count(*) from public.follow_links where follower_person_id=pg_temp.f(201) and target_id=pg_temp.f(203) and status='active'),0::bigint,'Educa follow revoked');
reset role;
select is(app_private.official_profiles_backfill_follows_v1(),0,'backfill respects the revoked follow');

-- novo login → próximo backfill segue os dois
insert into auth.users(id) values (pg_temp.f(103));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values (pg_temp.f(204),'adult','9f1','Novo','9f1 Novo','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values (pg_temp.f(204),pg_temp.f(103),'active');
select is((select count(*) from public.follow_links f join public.official_profiles o on o.person_id=f.target_id where f.follower_person_id=pg_temp.f(204) and f.status='active') + app_private.official_profiles_backfill_follows_v1(),2::bigint,'new account ends up following every active official');

-- publicação atribuída ao perfil oficial: json expõe author
insert into public.platform_notices(notice_type,status,title,body_text,starts_at,official_profile_id,priority_code,audience_json,audience_label)
 values ('for_you','active','Novidade do app','Versão nova disponível.',now()-interval '1 minute',
   (select id from public.official_profiles where handle='coelo'),'routine','{"rules":[{"dimension":"platform","select_all":true}]}','Toda a plataforma')
 returning id \gset n_
select is((select app_private.superadmin_notice_json(n)#>>'{author,handle}' from public.platform_notices n where n.id=:'n_id'),'coelo','notice json exposes the official author');
select is((select app_private.superadmin_notice_json(n)#>>'{author,mandatory}' from public.platform_notices n where n.id=:'n_id'),'true','author carries mandatory flag');
select ok(position('official_profile_id' in pg_get_functiondef('public.superadmin_notice_save_draft_v2(uuid,uuid,bigint,jsonb)'::regprocedure))>0,'save_draft persists official_profile_id');

select * from finish();
rollback;
