-- Prova do candidato 20260911170100_person_handles_v1 (regra do @ para pessoas, Decisao 16).
-- Projeto descartavel LOCAL: fixtures sinteticas em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

create function pg_temp.ph_session(auth_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    case when auth_user is null then ''
      else jsonb_build_object('sub',auth_user,'role','authenticated','aal','aal1')::text end, true)
$$;
create function pg_temp.ph_handle(person uuid) returns text language sql as $$
  select normalized_handle from public.person_handles where person_id=person and status='active' and revoked_at is null
$$;

-- Pessoas: adulto A (Ana Souza), adulto B (Ana Souza, homonimo), crianca C, responsavel P de C,
-- terceiro Q sem vinculo, pessoa de servico S, operador O com people.update.
insert into public.people(id,person_type,first_name,last_name,display_name) values
('a0500000-0000-4000-8000-000000000001','adult','Ana','Souza','Ana Souza'),
('a0500000-0000-4000-8000-000000000002','adult','Ana','Souza','Ana Souza (homonima)'),
('a0500000-0000-4000-8000-000000000003','child','José','Ávila','José Ávila'),
('a0500000-0000-4000-8000-000000000004','adult','Pai','Avila','Pai Avila'),
('a0500000-0000-4000-8000-000000000005','adult','Q','Terceiro','Q Terceiro'),
('a0500000-0000-4000-8000-000000000006','service','Servico','Coelo','Servico Coelo'),
('a0500000-0000-4000-8000-000000000007','adult','Operador','Plataforma','Operador Plataforma');

-- 1-4. nascimento: nome.sobrenome, sufixo em colisao, acento removido, servico fora da ponte sem @
select is(pg_temp.ph_handle('a0500000-0000-4000-8000-000000000001'), 'ana.souza', 'adulto nasce com @nome.sobrenome');
select is(pg_temp.ph_handle('a0500000-0000-4000-8000-000000000002'), 'ana.souza1', 'homonimo recebe sufixo numerico');
select is(pg_temp.ph_handle('a0500000-0000-4000-8000-000000000003'), 'jose.avila', 'crianca nasce com @ sem acentos');
-- Desde 20260911170500 (P46 = A) a pessoa de servico da ponte de ator tem @; fora da ponte continua sem.
select is(pg_temp.ph_handle('a0500000-0000-4000-8000-000000000006'), null, 'pessoa de servico fora da ponte nao recebe @');

-- sessoes
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('a0500000-0000-4000-8000-000000000011','authenticated','authenticated','ph-a@invalid.test',now(),now(),now(),'{}','{}'),
('a0500000-0000-4000-8000-000000000014','authenticated','authenticated','ph-p@invalid.test',now(),now(),now(),'{}','{}'),
('a0500000-0000-4000-8000-000000000015','authenticated','authenticated','ph-q@invalid.test',now(),now(),now(),'{}','{}'),
('a0500000-0000-4000-8000-000000000017','authenticated','authenticated','ph-o@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id) values
('a0500000-0000-4000-8000-000000000001','a0500000-0000-4000-8000-000000000011'),
('a0500000-0000-4000-8000-000000000004','a0500000-0000-4000-8000-000000000014'),
('a0500000-0000-4000-8000-000000000005','a0500000-0000-4000-8000-000000000015'),
('a0500000-0000-4000-8000-000000000007','a0500000-0000-4000-8000-000000000017');
insert into public.guardian_links(guardian_person_id,child_person_id,relation_type,relationship_type_id) values
('a0500000-0000-4000-8000-000000000004','a0500000-0000-4000-8000-000000000003','father',
 (select id from public.family_relationship_types where code='father'));
insert into public.platform_roles(id,code,name,max_scope_kind) values
('a0500000-0000-4000-8000-000000000101','ph_operator','PH operador','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'a0500000-0000-4000-8000-000000000101',id,'allow' from public.platform_permissions where code in ('people.read','people.update');
insert into public.platform_memberships(person_id,role_id,status,scope_kind) values
('a0500000-0000-4000-8000-000000000007','a0500000-0000-4000-8000-000000000101','active','platform');

-- 5. anonimo nao consulta disponibilidade
select pg_temp.ph_session(null);
select throws_ok($$select public.superadmin_person_handle_availability('qualquer')$$, '42501',
  'person handle permission denied', 'anonimo nao verifica disponibilidade');

-- 6-9. disponibilidade (sessao de A)
select pg_temp.ph_session('a0500000-0000-4000-8000-000000000011');
select is(public.superadmin_person_handle_availability('@Coelo')->'data'->>'reason', 'reserved', 'coelo e reservado');
select is(public.superadmin_person_handle_availability('ab')->'data'->>'reason', 'invalid_format', 'menos de 3 caracteres e invalido');
select is(public.superadmin_person_handle_availability('ana.souza1')->'data'->>'reason', 'taken', '@ de outra pessoa esta tomado');
select is((public.superadmin_person_handle_availability('ana.souza','a0500000-0000-4000-8000-000000000001')->'data'->>'available')::boolean, true,
  'o proprio @ conta como disponivel para a propria pessoa');

-- 10-11. leitura: a propria pessoa le; terceiro sem people.read nao le
select is(public.superadmin_person_handle_get('a0500000-0000-4000-8000-000000000001')->'data'->>'handle', 'ana.souza', 'a propria pessoa le o seu @');
select pg_temp.ph_session('a0500000-0000-4000-8000-000000000015');
select throws_ok($$select public.superadmin_person_handle_get('a0500000-0000-4000-8000-000000000001')$$, '42501',
  'person handle permission denied', 'terceiro sem vinculo nem people.read nao le o @ de outra pessoa');
select throws_ok($$select public.superadmin_person_handle_set(gen_random_uuid(),'a0500000-0000-4000-8000-000000000001','outro.nome','teste')$$, '42501',
  'person handle permission denied', 'terceiro nao troca o @ de outra pessoa');

-- 13-16. troca pela propria pessoa, com ledger e trava de 30 dias
select pg_temp.ph_session('a0500000-0000-4000-8000-000000000011');
select is(public.superadmin_person_handle_set(gen_random_uuid(),'a0500000-0000-4000-8000-000000000001','@Ana_Nova','prefiro assim')->'data'->>'handle',
  'ana_nova', 'a propria pessoa troca o @ (normalizado, sem @ e em minusculas)');
select is((select count(*) from app_private.person_identity_correction_ledger
  where person_id='a0500000-0000-4000-8000-000000000001' and correction_kind='handle' and old_value='ana.souza' and new_value='ana_nova' and change_reason='prefiro assim'), 1::bigint,
  'ledger registra a troca com valor anterior, novo e motivo');
select throws_ok($$select public.superadmin_person_handle_set(gen_random_uuid(),'a0500000-0000-4000-8000-000000000001','ana.denovo','de novo')$$, '22023',
  'person handle unavailable', 'segunda troca dentro de 30 dias e negada (cooldown)');
select is(public.superadmin_person_handle_get('a0500000-0000-4000-8000-000000000001')->'data'->>'can_change_at' > now()::text, true,
  'can_change_at fica no futuro apos a troca');
-- 17. @ liberado pode ser reaproveitado por outra pessoa
select is(public.superadmin_person_handle_availability('ana.souza')->'data'->>'reason', 'ok', 'o @ antigo volta a ficar disponivel');

-- 18-19. responsavel ve e edita o @ da crianca; troca para @ tomado e negada
select pg_temp.ph_session('a0500000-0000-4000-8000-000000000014');
select is(public.superadmin_person_handle_get('a0500000-0000-4000-8000-000000000003')->'data'->>'can_edit', 'true', 'responsavel ve e pode editar o @ da crianca');
select throws_ok($$select public.superadmin_person_handle_set(gen_random_uuid(),'a0500000-0000-4000-8000-000000000003','ana.souza1','tomado')$$, '22023',
  'person handle unavailable', 'troca para @ tomado e negada');
select is(public.superadmin_person_handle_set(gen_random_uuid(),'a0500000-0000-4000-8000-000000000003','ze.avila','apelido')->'data'->>'handle',
  'ze.avila', 'responsavel troca o @ da crianca');

-- 21-22. operador com people.update troca o @ de qualquer pessoa; motivo obrigatorio
select pg_temp.ph_session('a0500000-0000-4000-8000-000000000017');
select is(public.superadmin_person_handle_set(gen_random_uuid(),'a0500000-0000-4000-8000-000000000005','q.novo','correcao pelo superadmin')->'data'->>'handle',
  'q.novo', 'operador com people.update troca o @ de terceiro');
select throws_ok($$select public.superadmin_person_handle_set(gen_random_uuid(),'a0500000-0000-4000-8000-000000000005','q.outro','')$$, '22023',
  'request id and reason are required', 'motivo e obrigatorio');

select * from finish();
rollback;
