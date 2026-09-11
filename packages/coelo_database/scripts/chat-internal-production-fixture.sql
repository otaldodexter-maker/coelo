-- Fixture SINTETICA para a prova em producao do chat interno (Rodada 4).
-- Producao nao tem instituicao, vinculo nem responsavel; Criar grupo exige
-- pessoas com vinculo real na instituicao. Este arquivo cria o minimo, com
-- UUIDs fixos e nomes marcados "QA R04", para o coordenador aplicar com
-- `supabase db query --linked -f` antes da prova e remover com
-- chat-internal-production-cleanup.sql depois. Nenhum dado pessoal real.
begin;

insert into public.institutions(id, public_name, slug, status, institution_type_id)
select '9f040000-0000-4000-8000-000000000010', 'QA R04 Instituicao Sintetica', 'qa-r04-chat',
  'active', (select id from public.institution_types where status = 'active' order by code limit 1)
on conflict (id) do nothing;

insert into public.people(id, person_type, first_name, last_name, display_name, status) values
 ('9f040000-0000-4000-8000-000000000061', 'adult', 'QA R04', 'Profissional', 'QA R04 Profissional', 'active'),
 ('9f040000-0000-4000-8000-000000000062', 'adult', 'QA R04', 'Responsavel', 'QA R04 Responsavel', 'active'),
 ('9f040000-0000-4000-8000-000000000064', 'child', 'QA R04', 'Crianca', 'QA R04 Crianca', 'active')
on conflict (id) do nothing;

insert into public.institution_memberships(id, person_id, institution_id, role_code) values
 ('9f040000-0000-4000-8000-000000000071', '9f040000-0000-4000-8000-000000000061',
  '9f040000-0000-4000-8000-000000000010', 'teacher')
on conflict (id) do nothing;

insert into public.family_relationship_types(id, code, name)
values ('9f040000-0000-4000-8000-000000000090', 'qa_r04_responsavel', 'QA R04 Responsavel')
on conflict (id) do nothing;

insert into public.guardian_links(id, guardian_person_id, child_person_id, relation_type, relationship_type_id)
values ('9f040000-0000-4000-8000-000000000081', '9f040000-0000-4000-8000-000000000062',
  '9f040000-0000-4000-8000-000000000064', 'responsavel', '9f040000-0000-4000-8000-000000000090')
on conflict (id) do nothing;

insert into public.child_contexts(id, child_person_id, institution_id)
values ('9f040000-0000-4000-8000-000000000091', '9f040000-0000-4000-8000-000000000064',
  '9f040000-0000-4000-8000-000000000010')
on conflict (id) do nothing;

commit;

-- Prova: bash packages/coelo_database/scripts/Invoke-ChatInternalProductionProof.sh \
--   --institution 9f040000-0000-4000-8000-000000000010 \
--   --members 9f040000-0000-4000-8000-000000000061,9f040000-0000-4000-8000-000000000062
