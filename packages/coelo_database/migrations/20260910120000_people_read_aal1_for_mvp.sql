-- Candidato REVISAVEL, aguardando a decisao AP-D1-AAL do Owner.
--
-- Nao aplicar antes da decisao. Ele afrouxa uma exigencia de MFA em caminho que
-- le dado pessoal de crianca, e isso e decisao de produto e de risco.
--
-- Problema que resolve
-- --------------------
-- app_private.assert_people_permission exige AAL2 para TODOS os codigos que
-- passam por ela, inclusive people.read. Como o MVP roda em AAL1 (MFA fora do
-- escopo, ADR 0034) e app_private.has_mfa_aal2() e uma comparacao literal da
-- claim aal do JWT com 'aal2', o diretorio de Pessoas nao lista em producao:
-- superadmin_people_list nega antes de qualquer consulta.
--
-- Opcao escolhida (C das tres apresentadas)
-- -----------------------------------------
-- Somente people.read passa a aceitar AAL1. Os quatro codigos de ESCRITA que
-- atravessam o mesmo portao -- people.create, people.update,
-- people.memberships.manage e people.child_contexts.manage -- continuam
-- exigindo AAL2.
--
-- A regra e fail-closed por construcao: a excecao e uma igualdade exata com
-- 'people.read', entao qualquer codigo novo que venha a usar este portao
-- continua exigindo AAL2 sem que ninguem precise lembrar de inclui-lo.
--
-- Este e o mesmo desenho que Perfis e Modelos de acesso JA usam em producao:
-- as leituras (superadmin_access_profiles_cursor, superadmin_access_profiles_list,
-- superadmin_access_profile_detail, superadmin_access_profile_models_cursor) nao
-- chamam has_mfa_aal2, e so as mutacoes passam por
-- app_private.access_profile_require_mutation, que exige AAL2. Pessoas e a
-- excecao fora do padrao, nao a regra.
--
-- Ordem na fila
-- -------------
-- Precisa vir DEPOIS de 20260828005000_superadmin_internal_person_detail.sql.
-- O preflight daquela migration exige que people.read esteja com
-- requires_mfa = true no catalogo. Esta migration NAO altera o catalogo -- ela
-- muda so o portao -- justamente para nao invalidar aquele preflight. O carimbo
-- ja garante a ordem, mas a dependencia fica dita.
--
-- Reversao
-- --------
-- Trocar a condicao de volta por `if not (select app_private.has_mfa_aal2())`.
-- Uma linha, sem migracao de dado.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
declare
  gate_record record;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using
      message = 'people AAL policy migration must run as postgres';
  end if;

  if to_regprocedure('app_private.has_mfa_aal2()') is null
     or to_regprocedure('app_private.has_platform_permission(text)') is null then
    raise object_not_in_prerequisite_state using
      message = 'people permission gate dependencies are required';
  end if;

  select procedure_record.*,
    pg_catalog.pg_get_functiondef(procedure_record.oid) as definition
  into gate_record
  from pg_catalog.pg_proc procedure_record
  where procedure_record.oid =
    pg_catalog.to_regprocedure('app_private.assert_people_permission(text)');

  if gate_record.oid is null then
    raise object_not_in_prerequisite_state using
      message = 'people permission gate is missing';
  end if;

  -- Substituir um portao de autorizacao as cegas seria pior que o defeito.
  -- Confere que a forma vigente e a conhecida antes de reescrever.
  if pg_catalog.pg_get_userbyid(gate_record.proowner) <> 'postgres'
     or not gate_record.prosecdef
     or gate_record.provolatile <> 's'
     or not (coalesce(gate_record.proconfig, array[]::text[])
       @> array['search_path=""']::text[]) then
    raise object_not_in_prerequisite_state using
      message = 'people permission gate security metadata drift';
  end if;

  if gate_record.definition !~ 'people permission requires aal2'
     or gate_record.definition !~ 'people permission denied' then
    raise object_not_in_prerequisite_state using
      message = 'people permission gate baseline drift';
  end if;

  if gate_record.definition ~ 'people\.read' then
    raise object_not_in_prerequisite_state using
      message = 'people permission gate already carries a read exception';
  end if;

  if pg_catalog.has_function_privilege(
       'anon', 'app_private.assert_people_permission(text)', 'EXECUTE')
     or pg_catalog.has_function_privilege(
       'authenticated', 'app_private.assert_people_permission(text)', 'EXECUTE') then
    raise object_not_in_prerequisite_state using
      message = 'people permission gate ACL drift';
  end if;
end
$preflight$;

create or replace function app_private.assert_people_permission(
  permission_code text
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
     or not (select app_private.has_platform_permission(permission_code)) then
    raise insufficient_privilege using message = 'people permission denied';
  end if;
  -- MVP, decisao AP-D1-AAL: a leitura do diretorio aceita AAL1. Escrita, nao.
  -- Igualdade exata mantem a regra fail-closed para qualquer codigo novo.
  if permission_code <> 'people.read'
     and not (select app_private.has_mfa_aal2()) then
    raise insufficient_privilege using message = 'people permission requires aal2';
  end if;
end
$$;

revoke execute on function app_private.assert_people_permission(text)
  from public, anon, authenticated;
grant execute on function app_private.assert_people_permission(text)
  to service_role;

commit;
