-- Assiduidade: prova da correcao de autorizacao da OQ-040 e da chave de
-- idempotencia gerada pelo banco (D11).
begin;

create extension if not exists pgtap with schema extensions;

select plan(23);

-- --------------------------------------------------------------------------
-- Parte 1: ler deixou de alcancar gerir
-- --------------------------------------------------------------------------

-- Antes, platform.read era a primeira condicao do OR e valia mesmo com
-- require_manage verdadeiro. Agora ele so aparece dentro do ramo de leitura,
-- isto e, depois da abertura do case. Comparar as posicoes prova exatamente
-- isso, sem depender de espaco em branco.
select ok(
  strpos(
    pg_get_functiondef(
      'app_private.can_access_attendance_child(uuid,uuid,uuid,uuid,uuid,boolean)'::regprocedure),
    'has_platform_permission(''platform.read'')'
  ) > strpos(
    pg_get_functiondef(
      'app_private.can_access_attendance_child(uuid,uuid,uuid,uuid,uuid,boolean)'::regprocedure),
    'case when require_manage'
  ),
  'platform.read so aparece dentro do ramo de leitura'
);

select ok(
  pg_get_functiondef(
    'app_private.can_access_attendance_child(uuid,uuid,uuid,uuid,uuid,boolean)'::regprocedure)
    like '%case when require_manage%'
    and pg_get_functiondef(
    'app_private.can_access_attendance_child(uuid,uuid,uuid,uuid,uuid,boolean)'::regprocedure)
    like '%has_platform_permission(''attendance.manage'')%',
  'o ramo de gestao exige capacidade de gestao, nao leitura de plataforma'
);

select ok(
  not exists (
    select 1 from pg_policy policy_row
    join pg_class relation on relation.oid = policy_row.polrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'attendance_sessions','attendance_expected_participants')
      and policy_row.polcmd = '*'
  ),
  'nenhuma policy FOR ALL sobrou em sessoes ou participantes esperados'
);

select is(
  (select count(*)::bigint from pg_policy policy_row
   join pg_class relation on relation.oid = policy_row.polrelid
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'
     and relation.relname = 'attendance_sessions'),
  4::bigint,
  'sessoes tem uma policy por operacao'
);

select is(
  (select count(*)::bigint from pg_policy policy_row
   join pg_class relation on relation.oid = policy_row.polrelid
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'
     and relation.relname = 'attendance_expected_participants'),
  4::bigint,
  'participantes esperados tem uma policy por operacao'
);

select ok(
  (select pg_get_expr(policy_row.polqual, policy_row.polrelid)
   from pg_policy policy_row
   join pg_class relation on relation.oid = policy_row.polrelid
   where relation.relname = 'attendance_sessions'
     and policy_row.polname = 'attendance_sessions_delete') like '%true)%',
  'a policy de DELETE de sessoes exige o ramo de gestao'
);

select ok(
  (select bool_and(relation.relrowsecurity and relation.relforcerowsecurity)
   from pg_class relation
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'
     and relation.relname like 'attendance\_%'
     and relation.relkind = 'r'),
  'todas as tabelas de assiduidade forcam RLS'
);

-- --------------------------------------------------------------------------
-- Parte 2: chave de idempotencia do servidor
-- --------------------------------------------------------------------------

select has_table('app_private','attendance_idempotency_reservations',
  'a reserva de chave existe');

select has_function('public','attendance_reserve_idempotency_key',
  array['text','uuid','bigint','jsonb'], 'o cliente pede a chave ao banco');

select ok(
  not has_function_privilege('anon',
    'public.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)','EXECUTE')
  and has_function_privilege('authenticated',
    'public.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)','EXECUTE')
  and not has_function_privilege('anon',
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)','EXECUTE')
  and not has_function_privilege('authenticated',
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)','EXECUTE'),
  'so o wrapper publico e chamavel, e so por sessao autenticada'
);

select ok(
  not has_table_privilege('anon',
    'app_private.attendance_idempotency_reservations','SELECT')
  and not has_table_privilege('authenticated',
    'app_private.attendance_idempotency_reservations','SELECT'),
  'a reserva nunca e legivel pelo navegador'
);

select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class relation
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'app_private'
     and relation.relname = 'attendance_idempotency_reservations'),
  'a reserva forca RLS'
);

select ok(
  pg_get_functiondef(
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)'::regprocedure)
    like '%authentication required%',
  'sessao ausente recebe negativa antes de qualquer escrita'
);

select ok(
  pg_get_functiondef(
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)'::regprocedure)
    like '%app_private.attendance_intent_digest(%'
  and pg_get_functiondef(
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)'::regprocedure)
    not like '%p_intent_digest%',
  'o digest da intencao e montado no servidor, nunca recebido do cliente'
);

-- --------------------------------------------------------------------------
-- A semantica de intencao, que antes vivia no cliente Flutter
-- --------------------------------------------------------------------------

-- Criar chamada e o unico comando sem agregado e sem versao esperada. Se a
-- intencao dele nao fosse descrita pelo contexto, duas chamadas diferentes do
-- mesmo profissional receberiam a mesma chave, que e pior do que nao ter chave.
select is(
  app_private.attendance_intent_digest('create_call', null, null,
    '{"institution_id":"institution-1","unit_id":"unit-1","group_id":"group-1",
      "activity_id":"activity-1","session_date":"2026-08-10"}'::jsonb),
  app_private.attendance_intent_digest('create_call', null, null,
    '{"institution_id":"institution-1","unit_id":"unit-1","group_id":"group-1",
      "activity_id":"activity-1","session_date":"2026-08-10"}'::jsonb),
  'repetir a mesma criacao e uma intencao repetida, nao duas chamadas'
);

select isnt(
  app_private.attendance_intent_digest('create_call', null, null,
    '{"institution_id":"institution-1","unit_id":"unit-1","group_id":"group-1",
      "activity_id":"activity-1","session_date":"2026-08-10"}'::jsonb),
  app_private.attendance_intent_digest('create_call', null, null,
    '{"institution_id":"institution-1","unit_id":"unit-1","group_id":"group-2",
      "activity_id":"activity-1","session_date":"2026-08-10"}'::jsonb),
  'outra turma e outra chamada'
);

select isnt(
  app_private.attendance_intent_digest('create_call', null, null,
    '{"institution_id":"institution-1","unit_id":"unit-1","group_id":"group-1",
      "activity_id":"activity-1","session_date":"2026-08-10"}'::jsonb),
  app_private.attendance_intent_digest('create_call', null, null,
    '{"institution_id":"institution-1","unit_id":"unit-1","group_id":"group-1",
      "activity_id":"activity-1","session_date":"2026-08-11"}'::jsonb),
  'outro dia e outra chamada'
);

-- Depois que a chamada avanca, a intencao antiga deixou de existir.
select isnt(
  app_private.attendance_intent_digest('complete_call',
    '10000000-0000-4000-8000-000000000001'::uuid, 3, null),
  app_private.attendance_intent_digest('complete_call',
    '10000000-0000-4000-8000-000000000001'::uuid, 4, null),
  'versao esperada diferente e intencao diferente'
);

select throws_ok(
  $call$select app_private.attendance_intent_digest('create_call', null, null, null)$call$,
  '22023', 'attendance call scope required',
  'criar chamada sem contexto e recusado em vez de virar chave generica'
);

select throws_ok(
  $call$select app_private.attendance_intent_digest('complete_call', null, 1, null)$call$,
  '22023', 'attendance aggregate required',
  'comando sobre chamada existente exige o agregado'
);

select throws_ok(
  $call$select app_private.attendance_intent_digest('drop_everything', null, null, null)$call$,
  '22023', 'invalid attendance command',
  'comando fora da lista e recusado'
);

select ok(
  pg_get_functiondef(
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)'::regprocedure)
    like '%on conflict (actor_person_id, command, intent_digest) do update%',
  'a mesma intencao devolve sempre a mesma chave'
);

set local role anon;
select throws_ok(
  $call$select public.attendance_reserve_idempotency_key('create_call',null,null,null)$call$,
  '42501', null, 'anonimo nao reserva chave'
);

reset role;
select * from finish();
rollback;
