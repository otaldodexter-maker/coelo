-- Fixture funcional auxiliar do candidato H28 20260912143000.
-- Executar somente após o candidato, em banco local descartável; rollback total.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values ('a2800000-0000-4000-8000-000000000001','authenticated','authenticated','h28-actor@invalid.test',now(),now(),now(),'{}','{}');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('a2800000-0000-4000-8000-000000000011','adult','H28','Actor','H28 Actor','active'),
 ('a2800000-0000-4000-8000-000000000041','adult','H28','Only B','H28 Only B','active'),
 ('a2800000-0000-4000-8000-000000000042','adult','H28','Mixed','H28 Mixed','active'),
 ('a2800000-0000-4000-8000-000000000043','adult','H28','Professional','H28 Professional','active'),
 ('a2800000-0000-4000-8000-000000000044','child','H28','Child','H28 Child','active'),
 ('a2800000-0000-4000-8000-000000000045','adult','H28','Revoked','H28 Revoked','active');
insert into public.person_auth_links(person_id,auth_user_id,status)
values ('a2800000-0000-4000-8000-000000000011','a2800000-0000-4000-8000-000000000001','active');
insert into public.platform_roles(id,code,name,max_scope_kind,status)
values ('a2800000-0000-4000-8000-000000000021','h28_people_reader','H28 People Reader','platform','active');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select 'a2800000-0000-4000-8000-000000000021',id,'allow','active'
from public.platform_permissions where code='people.read';
insert into public.platform_memberships(person_id,role_id,status,scope_kind)
values ('a2800000-0000-4000-8000-000000000011','a2800000-0000-4000-8000-000000000021','active','platform');

-- O bypass é restrito à montagem rollback-only; a RPC roda com triggers normais.
set local session_replication_role='replica';
insert into public.institutions(id,public_name,legal_name,slug,status) values
 ('a2800000-0000-4000-8000-000000000101','H28 Escola A','H28 Escola A','h28-escola-a','active'),
 ('a2800000-0000-4000-8000-000000000102','H28 Escola B','H28 Escola B','h28-escola-b','active');
insert into public.units(id,institution_id,name,slug,unit_type_id,unit_type_other_description,handle,status) values
 ('a2800000-0000-4000-8000-000000000111','a2800000-0000-4000-8000-000000000101','H28 Unidade A','h28-unidade-a',(select id from public.unit_types where status='active' order by id limit 1),'Fixture H28','h28.unidade.a','active'),
 ('a2800000-0000-4000-8000-000000000112','a2800000-0000-4000-8000-000000000102','H28 Unidade B','h28-unidade-b',(select id from public.unit_types where status='active' order by id limit 1),'Fixture H28','h28.unidade.b','active');
insert into public.unit_addresses(unit_id,state,city,district,street,number,status) values
 ('a2800000-0000-4000-8000-000000000111','SP','São Paulo','Centro','Rua A','1','active'),
 ('a2800000-0000-4000-8000-000000000112','RJ','Rio de Janeiro','Copacabana','Rua B','2','active');
insert into public.groups(id,institution_id,unit_id,name,group_type,handle,status) values
 ('a2800000-0000-4000-8000-000000000121','a2800000-0000-4000-8000-000000000101','a2800000-0000-4000-8000-000000000111','H28 Turma A1','class','h28.turma.a1','active'),
 ('a2800000-0000-4000-8000-000000000122','a2800000-0000-4000-8000-000000000102','a2800000-0000-4000-8000-000000000112','H28 Turma B','class','h28.turma.b','active'),
 ('a2800000-0000-4000-8000-000000000123','a2800000-0000-4000-8000-000000000101','a2800000-0000-4000-8000-000000000111','H28 Turma A2','class','h28.turma.a2','active');
insert into public.institution_roles(id,institution_id,code,name,is_system,status,max_scope_kind) values
 ('a2800000-0000-4000-8000-000000000131',null,'h28-global-a','H28 Global A',false,'active','institution'),
 ('a2800000-0000-4000-8000-000000000132',null,'h28-global-b','H28 Global B',false,'active','institution');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
 ('a2800000-0000-4000-8000-000000000141','a2800000-0000-4000-8000-000000000041','a2800000-0000-4000-8000-000000000102','h28-global-b','active','institution'),
 ('a2800000-0000-4000-8000-000000000142','a2800000-0000-4000-8000-000000000042','a2800000-0000-4000-8000-000000000101','h28-global-a','active','institution'),
 ('a2800000-0000-4000-8000-000000000143','a2800000-0000-4000-8000-000000000042','a2800000-0000-4000-8000-000000000102','h28-global-b','active','institution'),
 ('a2800000-0000-4000-8000-000000000144','a2800000-0000-4000-8000-000000000043','a2800000-0000-4000-8000-000000000101','h28-global-a','active','institution'),
 ('a2800000-0000-4000-8000-000000000145','a2800000-0000-4000-8000-000000000045','a2800000-0000-4000-8000-000000000101','h28-global-a','active','institution');
insert into public.institution_role_assignments(id,membership_id,role_id,scope_kind,scope_unit_id,scope_group_id,status) values
 ('a2800000-0000-4000-8000-000000000151','a2800000-0000-4000-8000-000000000141','a2800000-0000-4000-8000-000000000132','institution',null,null,'active'),
 ('a2800000-0000-4000-8000-000000000152','a2800000-0000-4000-8000-000000000142','a2800000-0000-4000-8000-000000000131','institution',null,null,'active'),
 ('a2800000-0000-4000-8000-000000000153','a2800000-0000-4000-8000-000000000143','a2800000-0000-4000-8000-000000000132','unit','a2800000-0000-4000-8000-000000000112',null,'active'),
 ('a2800000-0000-4000-8000-000000000154','a2800000-0000-4000-8000-000000000144','a2800000-0000-4000-8000-000000000131','institution',null,null,'active'),
 ('a2800000-0000-4000-8000-000000000155','a2800000-0000-4000-8000-000000000145','a2800000-0000-4000-8000-000000000131','institution',null,null,'active');
insert into public.activity_definitions(id,institution_id,name,origin_scope_kind,created_by_person_id,handle_stem,status)
values ('a2800000-0000-4000-8000-000000000161','a2800000-0000-4000-8000-000000000101','H28 Atividade A','institution','a2800000-0000-4000-8000-000000000011','h28-atividade-a','active');
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,status,participation_mode) values
 ('a2800000-0000-4000-8000-000000000171','a2800000-0000-4000-8000-000000000161','a2800000-0000-4000-8000-000000000101','a2800000-0000-4000-8000-000000000111','a2800000-0000-4000-8000-000000000121','a2800000-0000-4000-8000-000000000011','active','selected'),
 ('a2800000-0000-4000-8000-000000000172','a2800000-0000-4000-8000-000000000161','a2800000-0000-4000-8000-000000000101','a2800000-0000-4000-8000-000000000111','a2800000-0000-4000-8000-000000000123','a2800000-0000-4000-8000-000000000011','active','all');
insert into public.activity_group_assignments(id,activity_group_link_id,institution_id,person_id,membership_id,assignment_role,assigned_by_person_id,status,revoked_at) values
 ('a2800000-0000-4000-8000-000000000181','a2800000-0000-4000-8000-000000000171','a2800000-0000-4000-8000-000000000101','a2800000-0000-4000-8000-000000000043','a2800000-0000-4000-8000-000000000144','instructor','a2800000-0000-4000-8000-000000000011','active',null),
 ('a2800000-0000-4000-8000-000000000182','a2800000-0000-4000-8000-000000000172','a2800000-0000-4000-8000-000000000101','a2800000-0000-4000-8000-000000000043','a2800000-0000-4000-8000-000000000144','instructor','a2800000-0000-4000-8000-000000000011','active',null),
 ('a2800000-0000-4000-8000-000000000183','a2800000-0000-4000-8000-000000000171','a2800000-0000-4000-8000-000000000101','a2800000-0000-4000-8000-000000000045','a2800000-0000-4000-8000-000000000145','instructor','a2800000-0000-4000-8000-000000000011','inactive',now());
insert into public.child_contexts(id,child_person_id,institution_id,status)
values ('a2800000-0000-4000-8000-000000000191','a2800000-0000-4000-8000-000000000044','a2800000-0000-4000-8000-000000000101','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at)
values ('a2800000-0000-4000-8000-000000000192','a2800000-0000-4000-8000-000000000191','a2800000-0000-4000-8000-000000000111','active','a2800000-0000-4000-8000-000000000011',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status)
values ('a2800000-0000-4000-8000-000000000193','a2800000-0000-4000-8000-000000000192','a2800000-0000-4000-8000-000000000121','active');
insert into public.activity_group_participants(id,activity_group_link_id,child_group_link_id,status,added_by_person_id)
values ('a2800000-0000-4000-8000-000000000194','a2800000-0000-4000-8000-000000000171','a2800000-0000-4000-8000-000000000193','active','a2800000-0000-4000-8000-000000000011');
set local session_replication_role='origin';

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','a2800000-0000-4000-8000-000000000001','role','authenticated','aal','aal2')::text,true);

create function pg_temp.h28_result(extra jsonb) returns jsonb language plpgsql as $$
begin
  return public.superadmin_people_list(
    p_search => coalesce(extra->>'search','H28'), p_limit => 50,
    p_segment => coalesce(extra->>'segment','all'),
    p_institution_ids => coalesce(array(select jsonb_array_elements_text(extra->'institutions')::uuid),array[]::uuid[]),
    p_unit_ids => coalesce(array(select jsonb_array_elements_text(extra->'units')::uuid),array[]::uuid[]),
    p_group_ids => coalesce(array(select jsonb_array_elements_text(extra->'groups')::uuid),array[]::uuid[]),
    p_contextual_roles => coalesce(array(select jsonb_array_elements_text(extra->'roles')),array[]::text[]),
    p_activity_ids => coalesce(array(select jsonb_array_elements_text(extra->'activities')::uuid),array[]::uuid[]),
    p_state_codes => coalesce(array(select jsonb_array_elements_text(extra->'states')),array[]::text[]),
    p_municipality_ids => coalesce(array(select jsonb_array_elements_text(extra->'municipalities')),array[]::text[]),
    p_neighborhood_ids => coalesce(array(select jsonb_array_elements_text(extra->'neighborhoods')),array[]::text[]));
end $$;

select ok(not pg_temp.h28_result('{"institutions":["a2800000-0000-4000-8000-000000000101"]}')#>'{items}'
  @> '[{"id":"a2800000-0000-4000-8000-000000000041"}]', 'pessoa somente B não aparece em A');
select throws_ok($$select pg_temp.h28_result('{"institutions":["a2800000-0000-4000-8000-000000000101"],"units":["a2800000-0000-4000-8000-000000000112"]}')$$,
 '23514','unit filter crosses institution selection','unidade B é recusada sob instituição A');
select throws_ok($$select pg_temp.h28_result('{"institutions":["a2800000-0000-4000-8000-000000000101"],"groups":["a2800000-0000-4000-8000-000000000122"]}')$$,
 '23514','group filter crosses selected context','turma B é recusada sob instituição A');
select is((pg_temp.h28_result('{"search":"H28 Mixed","institutions":["a2800000-0000-4000-8000-000000000101"],"roles":["h28-global-b"]}')->>'total_count')::int,0,
 'pessoa A+B não combina instituição A com papel exclusivo da linha B');
select is((select array_agg(item->>'display_name' order by item->>'display_name')
 from jsonb_array_elements(pg_temp.h28_result('{"activities":["a2800000-0000-4000-8000-000000000161"]}')->'items') item),
 array['H28 Child','H28 Professional'], 'atividade inclui somente profissional e criança elegíveis');
select ok(not pg_temp.h28_result('{"activities":["a2800000-0000-4000-8000-000000000161"]}')#>'{items}'
 @> '[{"id":"a2800000-0000-4000-8000-000000000045"}]', 'assignment inativo/revogado não entra');
select is((pg_temp.h28_result('{"search":"H28 Professional","segment":"institutional_team","activities":["a2800000-0000-4000-8000-000000000161"],"states":["SP"],"municipalities":["São Paulo"],"neighborhoods":["Centro"]}')->>'total_count')::int,1,
 'atividade, localidade e segmento compõem na mesma linha');
select is((pg_temp.h28_result('{"search":"H28 Professional","activities":["a2800000-0000-4000-8000-000000000161"]}')->>'total_count')::int,1,
 'duas atribuições da mesma pessoa não duplicam total_count');
select ok((select exists(select 1 from jsonb_array_elements(item->'memberships') m
 where m->>'role_name'='H28 Global A') and exists(select 1 from jsonb_array_elements(item->'memberships') m
 where m->>'activity_id'='a2800000-0000-4000-8000-000000000161' and m->>'activity_name'='H28 Atividade A')
 from jsonb_array_elements(pg_temp.h28_result('{"search":"H28 Professional"}')->'items') item
 where item->>'id'='a2800000-0000-4000-8000-000000000043'),
 'payload preserva nome do papel global e atividade');
select ok(public.superadmin_people_filter_options() ?& array['activities','states','municipalities','neighborhoods'],
 'filter_options expõe as quatro coleções novas sob people.read AAL2');

select * from finish();
rollback;
