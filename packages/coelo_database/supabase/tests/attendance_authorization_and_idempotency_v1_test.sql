-- Assiduidade: prova da correcao de autorizacao da OQ-040 e da chave de
-- idempotencia gerada pelo banco (D11).
begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

-- --------------------------------------------------------------------------
-- Parte 1: ler deixou de alcancar gerir
-- --------------------------------------------------------------------------

select ok(
  pg_get_functiondef(
    'app_private.can_access_attendance_child(uuid,uuid,uuid,uuid,uuid,boolean)'::regprocedure)
    not like '%select%app_private.has_platform_permission(''platform.read'')%or%app_private.has_context_permission%',
  'platform.read nao e mais a primeira condicao incondicional'
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
  array['text','uuid','bigint'], 'o cliente pede a chave ao banco');

select ok(
  not has_function_privilege('anon',
    'public.attendance_reserve_idempotency_key(text,uuid,bigint)','EXECUTE')
  and has_function_privilege('authenticated',
    'public.attendance_reserve_idempotency_key(text,uuid,bigint)','EXECUTE')
  and not has_function_privilege('anon',
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint)','EXECUTE')
  and not has_function_privilege('authenticated',
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint)','EXECUTE'),
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
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint)'::regprocedure)
    like '%authentication required%',
  'sessao ausente recebe negativa antes de qualquer escrita'
);

select ok(
  pg_get_functiondef(
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint)'::regprocedure)
    like '%digest :=%p_command%'
  and pg_get_functiondef(
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint)'::regprocedure)
    not like '%p_intent_digest%',
  'o digest da intencao e montado no servidor, nunca recebido do cliente'
);

select ok(
  pg_get_functiondef(
    'app_private.attendance_reserve_idempotency_key(text,uuid,bigint)'::regprocedure)
    like '%on conflict (actor_person_id, command, intent_digest) do update%',
  'a mesma intencao devolve sempre a mesma chave'
);

set local role anon;
select throws_ok(
  $call$select public.attendance_reserve_idempotency_key('create_call',null,null)$call$,
  '42501', null, 'anonimo nao reserva chave'
);

reset role;
select * from finish();
rollback;
