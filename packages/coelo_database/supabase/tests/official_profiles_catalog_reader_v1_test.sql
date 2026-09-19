-- Prova pgTAP da migration 20260920080000 (spec 068: carga do catálogo + leitor do Principal).
-- Fixture com rollback total (prefixo 9f2): uma responsável com login e vínculo, uma publicação
-- do coelo e uma do coelo.educa, uma só de instituição alheia.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

create function pg_temp.f(n integer) returns uuid language sql immutable as $$
  select ('9f200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.f(integer) to authenticated;

-- carga
select is((select count(*) from public.official_profiles where status='active'
  and handle in ('coelo','coelo.alimentacao','coelo.educa','coelo.cuidado','coelo.brincar')),5::bigint,'five active official profiles loaded');
select is((select count(*) from public.official_profiles where mandatory),1::bigint,'only coelo is mandatory');
select ok((select bool_and(p.person_type='service') from public.official_profiles o join public.people p on p.id=o.person_id),'every official profile is backed by a service person');
select ok(app_private.is_reserved_handle('coelo.brincar') and app_private.is_reserved_handle('coelo.escola'),'handles reserved (including future ones)');
select ok(not exists(select 1 from public.follow_links where follower_person_id in (select person_id from public.official_profiles where handle<>'coelo') and status='active'),'new service people do not follow anyone');
select has_function('public','principal_official_profiles_v1',array['text'],'reader exists');

-- fixture
insert into public.institution_types(id,code,name,status) values (pg_temp.f(1),'qa-9f2','QA 9f2','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 (pg_temp.f(10),'QA 9f2 A','qa-9f2-a','active',pg_temp.f(1)),
 (pg_temp.f(20),'QA 9f2 B','qa-9f2-b','active',pg_temp.f(1));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f(61),'adult','QA 9f2','Resp','QA 9f2 Resp','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 (pg_temp.f(101),'authenticated','authenticated','9f2@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(auth_user_id,person_id,status) values (pg_temp.f(101),pg_temp.f(61),'active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,scope_kind) values
 (pg_temp.f(71),pg_temp.f(61),pg_temp.f(10),'guardian','institution');
select app_private.official_profiles_backfill_follows_v1();

insert into public.platform_notices(id,notice_type,status,title,body_text,starts_at,priority_code,audience_json,target_device,published_at,official_profile_id) values
 (pg_temp.f(201),'for_you','active','Novidade Coelo','corpo',now()-interval '1 hour','routine','{"rules":[{"dimension":"platform","select_all":true}]}','all',now(),
   (select id from public.official_profiles where handle='coelo')),
 (pg_temp.f(202),'for_you','active','Sono do bebê','corpo',now()-interval '1 hour','routine','{"rules":[{"dimension":"platform","select_all":true}]}','all',now(),
   (select id from public.official_profiles where handle='coelo.educa')),
 (pg_temp.f(203),'for_you','active','Só instituição B','corpo',now()-interval '1 hour','routine',
   jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','institution','select_all',false,'target_ids',jsonb_build_array(pg_temp.f(20))))),'all',now(),
   (select id from public.official_profiles where handle='coelo.educa'));

-- ator
select set_config('app.educa_person', (select person_id::text from public.official_profiles where handle='coelo.educa'), true);
select set_config('request.jwt.claim.sub', pg_temp.f(101)::text, true);
select set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.f(101)::text, 'role','authenticated','aal','aal1')::text, true);
set local role authenticated;
create temporary table r(label text primary key, body jsonb not null);
insert into r values ('catalog', public.principal_official_profiles_v1(null));
select is((select jsonb_array_length(body#>'{data,profiles}') from r where label='catalog'),5,'catalog lists the five active profiles');
select is((select body#>'{data,profiles}'->0->>'handle' from r where label='catalog'),'coelo','coelo comes first');
select ok((select bool_and((p->>'following')::boolean) from r, jsonb_array_elements(body#>'{data,profiles}') p where label='catalog'),'actor follows every official after backfill');
insert into r values ('educa', public.principal_official_profiles_v1('coelo.educa'));
select is((select body#>>'{data,profile,display_name}' from r where label='educa'),'Coelo Educa','profile by handle');
select is((select jsonb_array_length(body#>'{data,items}') from r where label='educa'),1,'only the visible publication of that author');
select is((select body#>'{data,items}'->0->>'title' from r where label='educa'),'Sono do bebê','item is the platform-wide one');
select throws_ok($$select public.principal_official_profiles_v1('coelo.escola')$$,'P0002',null,'unknown handle raises');
-- deixar de seguir o Educa muda following
select lives_ok(format($$select public.follow_set('person','%s',false)$$,current_setting('app.educa_person')),'unfollow educa');
select is((select body#>>'{data,profile,following}' from public.principal_official_profiles_v1('coelo.educa') b(body)),'false','following reflects the unfollow');
reset role;

select * from finish();
rollback;
