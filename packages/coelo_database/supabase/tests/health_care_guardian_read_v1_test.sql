-- Saude e cuidado: leitura pelo responsavel autorizado (ADR 0034, Decisao 9,
-- opcao 1). O que estas assercoes protegem e o limite da decisao: o
-- responsavel le a propria crianca, e nada alem disso.
begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

select has_function('public','health_care_profile_for_guardian', array['uuid'],
  'o responsavel tem porta propria para o perfil de cuidado');
select has_function('public','medication_plans_for_guardian', array['uuid'],
  'o responsavel tem porta propria para os planos de medicacao');

select ok(
  (select count(*) = 1 from public.guardian_permission_capabilities
   where code = 'view_health_care' and status = 'active'),
  'a capacidade view_health_care existe e esta ativa'
);

-- Somente leitura: o ramo de guardiao so vale para os dois codigos de leitura.
-- Gerir e registrar evidencia continuam exigindo capacidade de plataforma ou
-- contextual.
select ok(
  pg_get_functiondef(
    'app_private.health_care_scope_allowed(text,uuid,uuid,uuid,uuid)'::regprocedure)
    like '%p_permission in (''health_care.read'', ''medication.read'')%',
  'o ramo de guardiao existe so para health_care.read e medication.read'
);

select ok(
  pg_get_functiondef(
    'app_private.health_care_scope_allowed(text,uuid,uuid,uuid,uuid)'::regprocedure)
    like '%guardian_has_capability(p_child_context_id, ''view_health_care'')%',
  'a autorizacao do responsavel passa pela capacidade daquele contexto infantil'
);

-- A decisao nao afrouxou a regra anterior: leitura geral de plataforma continua
-- sem alcancar dado de saude de crianca.
select ok(
  pg_get_functiondef(
    'app_private.health_care_scope_allowed(text,uuid,uuid,uuid,uuid)'::regprocedure)
    not like '%platform.read%',
  'platform.read continua sem alcancar saude de crianca'
);

-- Sem enumeracao: a porta do responsavel exige o contexto infantil e nao aceita
-- busca, filtro nem paginacao. Enumerar e superficie de instituicao.
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('health_care_profile_for_guardian','medication_plans_for_guardian')
     and p.pronargs = 1),
  2,
  'as duas portas do responsavel recebem so o contexto infantil'
);

-- Negativa opaca: crianca inexistente e crianca de outra familia respondem a
-- mesma coisa, senao a resposta confirmaria a existencia da segunda.
select ok(
  pg_get_functiondef(
    'app_private.health_care_profile_for_guardian(uuid)'::regprocedure)
    like '%health care profile unavailable%'
  and pg_get_functiondef(
    'app_private.medication_plans_for_guardian(uuid)'::regprocedure)
    like '%medication plan unavailable%',
  'as duas portas negam de forma opaca'
);

-- Projecao minima: a familia nao recebe a trilha de auditoria da instituicao,
-- nem o registro de quem administrou o medicamento, nem a versao esperada do
-- agregado, que so serviria para uma escrita que o servidor recusaria.
select ok(
  pg_get_functiondef(
    'app_private.health_care_profile_for_guardian(uuid)'::regprocedure)
    not like '%health_care_profile_revisions%'
  and pg_get_functiondef(
    'app_private.health_care_profile_for_guardian(uuid)'::regprocedure)
    not like '%management_version%',
  'o perfil do responsavel nao carrega trilha nem versao esperada'
);

select ok(
  pg_get_functiondef(
    'app_private.medication_plans_for_guardian(uuid)'::regprocedure)
    not like '%medication_plan_evidence%',
  'a familia nao recebe o registro de administracao, que e operacional da instituicao'
);

select ok(
  not has_function_privilege('anon','public.health_care_profile_for_guardian(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.medication_plans_for_guardian(uuid)','EXECUTE')
  and has_function_privilege('authenticated','public.health_care_profile_for_guardian(uuid)','EXECUTE')
  and has_function_privilege('authenticated','public.medication_plans_for_guardian(uuid)','EXECUTE'),
  'as portas sao de sessao autenticada, nunca anonimas'
);

set local role anon;
select throws_ok(
  $call$select public.health_care_profile_for_guardian(
    '10000000-0000-4000-8000-000000000001'::uuid)$call$,
  '42501', null, 'anonimo nao sonda o perfil de nenhuma crianca'
);

reset role;
select * from finish();
rollback;
