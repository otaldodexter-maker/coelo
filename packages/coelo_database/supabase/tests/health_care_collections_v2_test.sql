-- Prova pgTAP da migration 20260919233000_health_care_collections_v2 (spec 065).
-- Fixture sintética com rollback total (prefixo 9d1): instituição, criança com contexto,
-- admin D (institution_admin → health_care.manage). Cobre: catálogo read-only e por RPC,
-- busca, 'other' exige texto, item desconhecido rejeitado, ordem persistida e reordenação,
-- what_to_do, remoção da lista inativa com justificativa, 101º rejeitado, PT409.
begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

create function pg_temp.f(n integer) returns uuid language sql immutable as $$
  select ('9d100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.f(integer) to authenticated;

select has_table('public','health_care_catalog_items','catalog table exists');
select ok((select relforcerowsecurity from pg_class where oid='public.health_care_catalog_items'::regclass),'catalog forces RLS');
select ok(not has_table_privilege('authenticated','public.health_care_catalog_items','SELECT'),'catalog not readable directly');
select has_column('public','health_care_allergies','catalog_item_id','allergies.catalog_item_id');
select has_column('public','health_care_allergies','position','allergies.position');
select has_column('public','health_care_allergies','what_to_do','allergies.what_to_do');
select has_column('public','health_care_profile_items','position','items.position');
select has_function('public','superadmin_health_care_catalog_v1',array['text','text'],'catalog rpc exists');
select ok(has_function_privilege('authenticated','public.superadmin_health_care_catalog_v1(text,text)','execute')
  and not has_function_privilege('anon','public.superadmin_health_care_catalog_v1(text,text)','execute'),'catalog rpc: authenticated only');
select ok(position('40001' in pg_get_functiondef('app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)'::regprocedure))=0
  and position('PT409' in pg_get_functiondef('app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)'::regprocedure))>0,'stale = PT409, never 40001');

-- fixture ---------------------------------------------------------------------------------------
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institution_types(id,code,name,status) values (pg_temp.f(1),'9d1-type','9d1 type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.f(10),pg_temp.f(1),'9d1 Instituicao','9d1-inst','active','America/Sao_Paulo');
insert into auth.users(id) values (pg_temp.f(101));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f(201),'adult','9d1','Admin D','9d1 Admin D','active'),
 (pg_temp.f(401),'child','9d1','Crianca','9d1 Crianca','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values (pg_temp.f(201),pg_temp.f(101),'active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
 (pg_temp.f(301),pg_temp.f(201),pg_temp.f(10),'institution_admin','active','institution');
insert into public.institution_role_assignments(membership_id,role_id,scope_kind)
select pg_temp.f(301),r.id,'institution' from public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.child_contexts(id,child_person_id,institution_id,status) values (pg_temp.f(411),pg_temp.f(401),pg_temp.f(10),'active');

select set_config('request.jwt.claim.sub', pg_temp.f(101)::text, true);
select set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.f(101)::text, 'role','authenticated','aal','aal2')::text, true);
set local role authenticated;

-- catálogo --------------------------------------------------------------------------------------
select ok(jsonb_array_length(public.superadmin_health_care_catalog_v1('food', null)->'categories') >= 8,'food catalog has categories');
select ok((select bool_and(item->>'id' like 'restriction\_%') from jsonb_array_elements(public.superadmin_health_care_catalog_v1('restriction', null)->'categories') cat,
  jsonb_array_elements(cat->'items') item),'restriction catalog only has restriction items');
select ok(exists(select 1 from jsonb_array_elements(public.superadmin_health_care_catalog_v1('food','amend')->'categories') cat,
  jsonb_array_elements(cat->'items') item where item->>'id'='food_peanut'),'search by term finds peanut');
select is(public.superadmin_health_care_catalog_v1('guidance', null)#>>'{other,id}','other','other is virtual in every collection');
select throws_ok($$select public.superadmin_health_care_catalog_v1('medication', null)$$,'22023',null,'unknown collection rejected');

-- criar perfil com alimentos, restrições e orientações ---------------------------------------------
create temporary table r(label text primary key, body jsonb);
insert into r values ('created', public.superadmin_health_care_save_profile(pg_temp.f(701), null, 0, jsonb_build_object(
  'child_context_id', pg_temp.f(411), 'justification','spec 065 prova',
  'allergies', jsonb_build_array(
    jsonb_build_object('allergy_type','food','catalog_item_id','food_peanut','what_to_do','Chamar a família e observar.'),
    jsonb_build_object('allergy_type','food','catalog_item_id','food_milk'),
    jsonb_build_object('allergy_type','food','catalog_item_id','other','other_text','Farinha de mandioca'),
    jsonb_build_object('allergy_type','restriction','catalog_item_id','restriction_latex','what_to_do','Lavar a pele e avisar a coordenação.'),
    jsonb_build_object('allergy_type','restriction','catalog_item_id','restriction_no_pork')),
  'items', jsonb_build_array(
    jsonb_build_object('catalog_item_id','guidance_asd'),
    jsonb_build_object('catalog_item_id','other','other_text','Prefere sentar perto da janela')))));
select is((select body->>'management_version' from r where label='created'),'0','profile created (version 0)');
select is((select string_agg(label, ' | ' order by position) from public.health_care_allergies where profile_id=(select (body->>'id')::uuid from r where label='created')),
  'Amendoim | Leite de vaca | Farinha de mandioca | Látex | Sem carne suína','labels from catalog/other in persisted order');
select is((select what_to_do from public.health_care_allergies where profile_id=(select (body->>'id')::uuid from r where label='created') and catalog_item_id='food_peanut'),
  'Chamar a família e observar.','what_to_do persisted');
select is((select jsonb_agg(item->>'label' order by (item->>'position')::int) from jsonb_array_elements(public.superadmin_health_care_profile_detail((select (body->>'id')::uuid from r where label='created'))->'items') item)::text,
  '["Transtorno do espectro autista (TEA)", "Prefere sentar perto da janela"]','detail exposes guidance labels in order');

-- validações -----------------------------------------------------------------------------------
select throws_ok(format($$select public.superadmin_health_care_save_profile('%s', '%s', 0, '{"justification":"x","allergies":[{"allergy_type":"food","catalog_item_id":"other"}]}')$$,
  pg_temp.f(702), (select body->>'id' from r where label='created')),'22023',null,'other without text rejected');
select throws_ok(format($$select public.superadmin_health_care_save_profile('%s', '%s', 0, '{"justification":"x","allergies":[{"allergy_type":"food","catalog_item_id":"restriction_latex"}]}')$$,
  pg_temp.f(703), (select body->>'id' from r where label='created')),'22023',null,'item from another collection rejected');
select throws_ok(format($$select public.superadmin_health_care_save_profile('%s', '%s', 7, '{"justification":"x"}')$$,
  pg_temp.f(704), (select body->>'id' from r where label='created')),'PT409',null,'stale version = PT409');

-- reordenar e remover ----------------------------------------------------------------------------
insert into r values ('reordered', public.superadmin_health_care_save_profile(pg_temp.f(705), (select (body->>'id')::uuid from r where label='created'), 0, jsonb_build_object(
  'justification','reordenar', 'allergies', (
    select jsonb_agg(jsonb_build_object('id', a.id, 'allergy_type', a.allergy_type) order by a.position desc)
    from public.health_care_allergies a where a.profile_id=(select (body->>'id')::uuid from r where label='created') and a.catalog_item_id <> 'food_milk'))));
select is((select string_agg(label, ' | ' order by position) from public.health_care_allergies where profile_id=(select (body->>'id')::uuid from r where label='created') and active),
  'Sem carne suína | Látex | Farinha de mandioca | Amendoim','reverse order persisted, removed one gone from active list');
select ok((select not active and inactivation_reason='reordenar' and status='history' from public.health_care_allergies
  where profile_id=(select (body->>'id')::uuid from r where label='created') and catalog_item_id='food_milk'),'removed allergy inactivated with justification');

-- limite 100 -------------------------------------------------------------------------------------
select throws_ok(format($$select public.superadmin_health_care_save_profile('%s', '%s', 1, jsonb_build_object('justification','limite','items',
  (select jsonb_agg(jsonb_build_object('catalog_item_id','other','other_text','item '||n)) from generate_series(1,101) n)))$$,
  pg_temp.f(706), (select body->>'id' from r where label='created')),'23514',null,'101st guidance rejected');
select is((select management_version from public.health_care_profiles where id=(select (body->>'id')::uuid from r where label='created')),1::bigint,'failed save left version untouched');

reset role;
select * from finish();
rollback;
