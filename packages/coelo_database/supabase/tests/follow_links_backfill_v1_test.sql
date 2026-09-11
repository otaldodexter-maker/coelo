-- Prova do candidato 20260910171500_follow_links_backfill_v1 (D1, complemento).
-- Projeto descartavel LOCAL: fixtures sinteticas em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into public.institution_types(id,code,name,status)
values('d1500000-0000-4000-8000-000000000001','d15-type','D15 type','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('d1500000-0000-4000-8000-000000000011','D15 instituicao','d15-x','d1500000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name) values
('d1500000-0000-4000-8000-000000000041','child','D15','Crianca','D15 crianca'),
('d1500000-0000-4000-8000-000000000042','adult','D15','Responsavel','D15 responsavel');
insert into public.guardian_links(guardian_person_id,child_person_id,relation_type,relationship_type_id) values
('d1500000-0000-4000-8000-000000000042','d1500000-0000-4000-8000-000000000041','father',
 (select id from public.family_relationship_types where code='father'));

-- Simula um contexto anterior ao 171100: desliga o gatilho, cadastra, religa.
alter table public.child_contexts disable trigger zz_follow_links_sync;
insert into public.child_contexts(id,child_person_id,institution_id) values
('d1500000-0000-4000-8000-000000000071','d1500000-0000-4000-8000-000000000041','d1500000-0000-4000-8000-000000000011');
alter table public.child_contexts enable trigger zz_follow_links_sync;

select is((select count(*) from public.follow_links where source_child_context_id='d1500000-0000-4000-8000-000000000071'), 0::bigint,
  'contexto anterior ao pacote nao tem acompanhamento');
select ok(app_private.follow_links_backfill_all() >= 1, 'o backfill percorre os contextos existentes');
select is((select count(*) from public.follow_links where source_child_context_id='d1500000-0000-4000-8000-000000000071' and status='active'), 2::bigint,
  'apos o backfill, crianca e responsavel acompanham a instituicao');
select lives_ok($$select app_private.follow_links_backfill_all()$$, 'rodar de novo nao falha');
select is((select count(*) from public.follow_links where source_child_context_id='d1500000-0000-4000-8000-000000000071' and status='active'), 2::bigint,
  'rodar de novo nao duplica');

select * from finish();
rollback;
