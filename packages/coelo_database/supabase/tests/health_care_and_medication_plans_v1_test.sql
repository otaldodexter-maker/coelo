-- Perfis de cuidado e Planos de medicacao: contrato da fundacao.
begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

-- --------------------------------------------------------------------------
-- Estrutura
-- --------------------------------------------------------------------------

select has_table('public','health_care_profiles','perfil de cuidado por contexto infantil');
select has_table('public','health_care_profile_items','itens do catalogo de cuidado');
select has_table('public','health_care_allergies','alergias e restricoes');
select has_table('public','health_care_profile_revisions','trilha com justificativa');
select has_table('public','medication_plans','identidade do plano de medicacao');
select has_table('public','medication_plan_versions','versoes imutaveis do plano');
select has_table('public','medication_plan_schedules','horarios do plano');
select has_table('public','medication_plan_evidence','evidencia de administracao');
select has_table('app_private','health_care_command_receipts','recibos de comando');

-- Um contexto infantil tem no maximo um perfil de cuidado.
select col_is_unique('public','health_care_profiles',array['child_context_id'],
  'perfil e unico por contexto infantil');

select results_eq(
  $$select count(*)::bigint from public.platform_permissions
     where code in ('health_care.read','health_care.manage','medication.read',
       'medication.manage','medication.record_evidence') and status='active'$$,
  array[5::bigint],
  'as cinco capacidades existem'
);

select ok(
  (select bool_and(requires_mfa) from public.platform_permissions
   where code in ('health_care.manage','medication.manage','medication.record_evidence')),
  'escrita de dado de saude carrega o portao de MFA no metadado'
);

-- --------------------------------------------------------------------------
-- Autorizacao
-- --------------------------------------------------------------------------

-- A regra que separa esta familia do resto do Superadmin: leitura geral de
-- plataforma nao alcanca dado de saude de crianca.
select ok(
  pg_get_functiondef(
    'app_private.health_care_scope_allowed(text,uuid,uuid,uuid,uuid)'::regprocedure)
    not like '%platform.read%',
  'platform.read nao alcanca saude de crianca'
);

select ok(
  (select bool_and(relation.relrowsecurity and relation.relforcerowsecurity)
   from pg_class relation
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'
     and relation.relname in (
       'health_care_profiles','health_care_profile_items','health_care_allergies',
       'health_care_profile_revisions','medication_plans','medication_plan_versions',
       'medication_plan_schedules','medication_plan_evidence')),
  'toda tabela exposta forca RLS'
);

select ok(
  not exists (
    select 1
    from (values
      ('health_care_profiles'),('health_care_profile_items'),
      ('health_care_allergies'),('health_care_profile_revisions'),
      ('medication_plans'),('medication_plan_versions'),
      ('medication_plan_schedules'),('medication_plan_evidence')
    ) as target(name)
    cross join (values ('INSERT'),('UPDATE'),('DELETE')) as operation(name)
    where has_table_privilege('authenticated','public.'||target.name, operation.name)
  ),
  'o navegador nao escreve direto em nenhuma tabela da familia'
);

select ok(
  not exists (
    select 1
    from (values
      ('health_care_profiles'),('health_care_allergies'),
      ('medication_plans'),('medication_plan_evidence')
    ) as target(name)
    where has_table_privilege('anon','public.'||target.name,'SELECT')
  ),
  'anonimo nao le nada da familia'
);

select ok(
  not has_table_privilege('anon','app_private.health_care_command_receipts','SELECT')
  and not has_table_privilege('authenticated',
    'app_private.health_care_command_receipts','SELECT'),
  'os recibos ficam fora do alcance do cliente'
);

-- --------------------------------------------------------------------------
-- Comandos
-- --------------------------------------------------------------------------

select has_function('public','superadmin_health_care_save_profile',
  array['uuid','uuid','bigint','jsonb'], 'perfil e salvo por comando versionado');
select has_function('public','superadmin_medication_plan_save',
  array['uuid','uuid','bigint','jsonb'], 'plano e salvo por comando versionado');
select has_function('public','superadmin_medication_plan_record_evidence',
  array['uuid','uuid','jsonb'], 'evidencia tem comando proprio, separado de editar');

-- A instituicao do agregado vem do contexto infantil, nunca do payload: aceitar
-- a instituicao enviada pelo cliente permitiria anexar a crianca de um tenant a
-- um perfil de outro.
select ok(
  pg_get_functiondef(
    'app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%health_care_child_institution%'
  and pg_get_functiondef(
    'app_private.superadmin_medication_plan_save(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%health_care_child_institution%',
  'a instituicao e derivada do contexto infantil nos dois comandos'
);

select ok(
  pg_get_functiondef(
    'app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%justification required%',
  'mudanca de perfil de cuidado exige justificativa'
);

select ok(
  pg_get_functiondef(
    'app_private.superadmin_medication_plan_save(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%review_status = ''invalidated''%',
  'nova versao invalida a aprovacao anterior'
);

select ok(
  pg_get_functiondef(
    'app_private.superadmin_medication_plan_record_evidence(uuid,uuid,jsonb)'::regprocedure)
    not like '%update public.medication_plan_versions%'
  and pg_get_functiondef(
    'app_private.superadmin_medication_plan_record_evidence(uuid,uuid,jsonb)'::regprocedure)
    not like '%management_version = management_version%',
  'registrar evidencia nao edita o plano nem move sua versao'
);

select ok(
  not has_function_privilege('anon',
    'public.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)','EXECUTE')
  and not has_function_privilege('anon',
    'public.superadmin_medication_plan_record_evidence(uuid,uuid,jsonb)','EXECUTE')
  and has_function_privilege('authenticated',
    'public.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)','EXECUTE'),
  'comandos sao de sessao autenticada'
);

-- O cliente identifica a crianca pela pessoa. Resolver isso no servidor evita
-- que o payload escolha o contexto de outro tenant, e evita que o servidor
-- adivinhe quando a mesma pessoa tem vinculo em mais de uma instituicao:
-- adivinhar seria escrever dado de saude no lugar errado.
select is(
  app_private.health_care_resolve_child_context(
    null, '10000000-0000-4000-8000-0000000000aa'::uuid, null),
  null,
  'pessoa sem contexto ativo nao resolve'
);

select ok(
  pg_get_functiondef(
    'app_private.health_care_resolve_child_context(uuid,uuid,uuid)'::regprocedure)
    like '%coalesce(candidates, 0) <> 1%',
  'pessoa com mais de um contexto no escopo pedido nao resolve por adivinhacao'
);

select ok(
  pg_get_functiondef(
    'app_private.health_care_resolve_child_context(uuid,uuid,uuid)'::regprocedure)
    like '%child_row.child_person_id = p_child_person_id%'
  and pg_get_functiondef(
    'app_private.health_care_resolve_child_context(uuid,uuid,uuid)'::regprocedure)
    like '%child_row.institution_id = p_institution_id%',
  'contexto explicito ainda e conferido contra a pessoa e a instituicao pedidas'
);

set local role anon;
select throws_ok(
  $call$select public.superadmin_health_care_profile_detail(
    '10000000-0000-4000-8000-000000000001'::uuid)$call$,
  '42501', null, 'anonimo nao sonda ids de perfil de cuidado'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000099',true);
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000099","aal":"aal1","role":"authenticated"}',true);
select throws_ok(
  $call$select public.superadmin_medication_plan_directory(
    null,null,null,null,null,20,0)$call$,
  '42501','authentication required',
  'sessao sem pessoa mapeada nao lista planos'
);

reset role;
select * from finish();
rollback;
