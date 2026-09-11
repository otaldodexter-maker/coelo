-- Prova do candidato 20260911170200_follow_links_safeupdate_fix_v1.
-- Reproduz a sessao do PostgREST (pg_safeupdate carregado): antes da correcao,
-- Reproduz a sessao do PostgREST (pg_safeupdate carregado): rodar como supabase_admin
-- (psql -U supabase_admin), porque supautils nega 'load' ao postgres comum. Antes da
-- correcao, inserir vinculo de unidade/turma de crianca falha com 21000.
begin;
create extension if not exists pgtap with schema extensions;
load 'safeupdate';
select plan(3);

insert into public.institution_types(id,code,name,status)
values('f1000000-0000-4000-8000-000000000001','f1-type','F1 type','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('f1000000-0000-4000-8000-000000000011','F1 instituicao','f1-x','f1000000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status)
values('f1000000-0000-4000-8000-000000000002','f1-unit-type','F1 unit type','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,handle) values
('f1000000-0000-4000-8000-000000000021','f1000000-0000-4000-8000-000000000011','f1000000-0000-4000-8000-000000000002','F1 unidade','f1-u','f1unitu');
insert into public.groups(id,institution_id,unit_id,name) values
('f1000000-0000-4000-8000-000000000031','f1000000-0000-4000-8000-000000000011','f1000000-0000-4000-8000-000000000021','F1 turma');
insert into public.people(id,person_type,first_name,last_name,display_name) values
('f1000000-0000-4000-8000-000000000041','child','F1','Crianca','F1 crianca'),
('f1000000-0000-4000-8000-000000000042','adult','F1','Responsavel','F1 responsavel');
insert into public.child_contexts(id,child_person_id,institution_id) values
('f1000000-0000-4000-8000-000000000071','f1000000-0000-4000-8000-000000000041','f1000000-0000-4000-8000-000000000011');

select lives_ok($$
  insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
  ('f1000000-0000-4000-8000-000000000081','f1000000-0000-4000-8000-000000000071','f1000000-0000-4000-8000-000000000021','active','f1000000-0000-4000-8000-000000000042',now())
$$, 'com safeupdate carregado, o vinculo de unidade da crianca e aceito (sync do acompanhamento nao apaga sem WHERE)');
select lives_ok($$
  insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
  ('f1000000-0000-4000-8000-000000000091','f1000000-0000-4000-8000-000000000081','f1000000-0000-4000-8000-000000000031','active')
$$, 'vinculo de turma aceito');
select is((select count(*) from public.follow_links where follower_person_id='f1000000-0000-4000-8000-000000000041' and status='active'), 3::bigint,
  'a crianca passa a acompanhar instituicao, unidade e turma');

select * from finish();
rollback;
