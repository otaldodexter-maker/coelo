-- Prova do candidato 20260911170400_people_list_segment_v1 (abas do diretorio de Pessoas no servidor).
-- Projeto descartavel LOCAL: fixtures sinteticas em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

-- Ator com people.read (plataforma).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values ('a0700000-0000-4000-8000-000000000001','authenticated','authenticated','r05-seg-actor@invalid.test',now(),now(),now(),'{}','{}');
insert into public.people(id,person_type,first_name,last_name,display_name) values
('a0700000-0000-4000-8000-000000000011','adult','Ator','Seg','SEG ator'),
('a0700000-0000-4000-8000-000000000012','adult','Equipe','Seg','SEG equipe'),
('a0700000-0000-4000-8000-000000000013','adult','Responsavel','Seg','SEG responsavel'),
('a0700000-0000-4000-8000-000000000014','child','Crianca','Seg','SEG crianca'),
('a0700000-0000-4000-8000-000000000015','adult','Duplo','Seg','SEG duplo');
insert into public.person_auth_links(person_id,auth_user_id)
values ('a0700000-0000-4000-8000-000000000011','a0700000-0000-4000-8000-000000000001');
insert into public.platform_roles(id,code,name,max_scope_kind)
values ('a0700000-0000-4000-8000-000000000021','qa_r05_seg_reader','SEG leitor','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'a0700000-0000-4000-8000-000000000021',id,'allow' from public.platform_permissions where code='people.read';
insert into public.platform_memberships(person_id,role_id,status,scope_kind)
values ('a0700000-0000-4000-8000-000000000011','a0700000-0000-4000-8000-000000000021','active','platform');
-- Instituicao, membership institucional (equipe e duplo) e vinculo de responsavel (responsavel e duplo).
insert into public.institutions(id,public_name,slug,status)
values ('a0700000-0000-4000-8000-000000000031','Escola SEG','escola-seg-r05','active');
insert into public.institution_roles(id,institution_id,code,name,max_scope_kind)
values ('a0700000-0000-4000-8000-000000000041','a0700000-0000-4000-8000-000000000031','seg_role','SEG papel','institution');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status) values
('a0700000-0000-4000-8000-000000000051','a0700000-0000-4000-8000-000000000012','a0700000-0000-4000-8000-000000000031','seg_role','active'),
('a0700000-0000-4000-8000-000000000052','a0700000-0000-4000-8000-000000000015','a0700000-0000-4000-8000-000000000031','seg_role','active');
insert into public.guardian_links(guardian_person_id,child_person_id,relation_type,relationship_type_id) values
('a0700000-0000-4000-8000-000000000013','a0700000-0000-4000-8000-000000000014','mother',(select id from public.family_relationship_types where code='mother')),
('a0700000-0000-4000-8000-000000000015','a0700000-0000-4000-8000-000000000014','father',(select id from public.family_relationship_types where code='father'));

select set_config('request.jwt.claims',
  jsonb_build_object('sub','a0700000-0000-4000-8000-000000000001','role','authenticated','aal','aal1')::text, true);

create function pg_temp.seg_names(seg text) returns text[] language sql as $$
  select coalesce(array_agg(item->>'display_name' order by item->>'display_name'), array[]::text[])
  from jsonb_array_elements(public.superadmin_people_list(p_search => 'SEG', p_segment => seg, p_limit => 20)->'items') item
$$;

select is(pg_temp.seg_names('all'), array['SEG ator','SEG crianca','SEG duplo','SEG equipe','SEG responsavel'], 'all lista as 5 pessoas SEG');
select is(pg_temp.seg_names('children'), array['SEG crianca'], 'children = tipo crianca');
select is(pg_temp.seg_names('guardians'), array['SEG duplo','SEG responsavel'], 'guardians = vinculo de responsavel ativo');
select is(pg_temp.seg_names('institutional_team'), array['SEG duplo','SEG equipe'], 'institutional_team = membership institucional ativa');
select is(pg_temp.seg_names('dual_profile'), array['SEG duplo'], 'dual_profile = responsavel e equipe');
select is((select count(*) from jsonb_array_elements(public.superadmin_people_list(p_search => 'SEG', p_limit => 20)->'items')), 5::bigint,
  'sem p_segment (default all) o contrato antigo continua valendo');
select throws_ok($$select public.superadmin_people_list(p_segment => 'invalido')$$, '22023', 'invalid segment', 'segmento fora da allowlist e recusado');
select is((select count(*) from pg_proc where proname='superadmin_people_list' and pronamespace='public'::regnamespace), 1::bigint,
  'uma unica sobrecarga de superadmin_people_list');

select * from finish();
rollback;
