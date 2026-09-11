-- P7 (ADR 0034, Decisao 12; decisao do Owner em 10/09/2026, noite):
-- "todos podem mexer mediante perfis e permissoes, de plataforma ou de
-- instituicao". app_private.has_platform_permission passa a considerar a
-- membership por instituicao.
--
-- Problema que resolve
-- --------------------
-- Em producao, app_private.has_platform_permission(text) so enxerga
-- public.platform_memberships com scope_kind = 'platform'. Uma pessoa cujo
-- vinculo com a plataforma e restrito a uma instituicao (scope_kind =
-- 'institution', scope_institution_id preenchido, papel com
-- max_scope_kind = 'institution') nunca recebe permissao alguma, por mais
-- que o perfil dela conceda. Isso contradiz a Decisao 12.
--
-- O que muda, e so isso
-- ---------------------
-- 1. Nova sobrecarga app_private.has_platform_permission(permission_code text,
--    institution_id uuid). Com institution_id nulo, qualquer membership ativa
--    (de plataforma ou de instituicao) conta. Com institution_id informado, a
--    membership de plataforma continua valendo e a membership de instituicao
--    so vale para aquela instituicao: e a negativa cross-tenant que as RPCs
--    que conhecem a instituicao devem usar.
-- 2. app_private.has_platform_permission(text) vira um delegado para a forma
--    de dois argumentos com institution_id nulo. Os 188 chamadores da
--    baseline e as 69 policies continuam com a mesma assinatura e a mesma ACL.
--
-- O que nao muda
-- --------------
-- Deny-by-default: sem membership ativa, sem papel ativo ou sem concessao,
-- a resposta continua false. deny continua vencendo allow. Overrides por
-- membership (platform_member_permission_overrides) continuam valendo,
-- inclusive para memberships de instituicao. Memberships invited, suspended
-- e revoked continuam fora. A resolucao do ator do realm interno v2
-- (identidades sem person_auth_links) NAO entra aqui: e pacote do
-- coordenador em candidatos/coordenador, como combinado na R04.
--
-- Reversao: recriar a forma de um argumento com o corpo da baseline
-- (filtro scope_kind = 'platform') e dropar a sobrecarga (text, uuid).

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
declare
  gate_record record;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using
      message = 'has_platform_permission migration must run as postgres';
  end if;

  if to_regclass('public.platform_memberships') is null
     or to_regclass('public.platform_member_permission_overrides') is null
     or to_regclass('public.platform_role_permissions') is null
     or to_regclass('public.platform_permissions') is null
     or to_regclass('public.platform_roles') is null
     or to_regprocedure('app_private.current_person_id()') is null then
    raise object_not_in_prerequisite_state using
      message = 'permission catalog dependencies are required';
  end if;

  if to_regprocedure('app_private.has_platform_permission(text,uuid)') is not null then
    raise object_not_in_prerequisite_state using
      message = 'has_platform_permission(text,uuid) already exists: package already applied';
  end if;

  select procedure_record.*,
    pg_catalog.pg_get_functiondef(procedure_record.oid) as definition
  into gate_record
  from pg_catalog.pg_proc procedure_record
  where procedure_record.oid =
    pg_catalog.to_regprocedure('app_private.has_platform_permission(text)');

  if gate_record.oid is null then
    raise object_not_in_prerequisite_state using
      message = 'has_platform_permission(text) is missing';
  end if;

  -- Substituir um portao de autorizacao as cegas seria pior que o defeito.
  if pg_catalog.pg_get_userbyid(gate_record.proowner) <> 'postgres'
     or not gate_record.prosecdef
     or gate_record.provolatile <> 's' then
    raise object_not_in_prerequisite_state using
      message = 'has_platform_permission security metadata drift';
  end if;

  if gate_record.definition !~ 'membership\.scope_kind=''platform'''
     or gate_record.definition !~ 'platform_member_permission_overrides' then
    raise object_not_in_prerequisite_state using
      message = 'has_platform_permission baseline drift';
  end if;
end
$preflight$;

create function app_private.has_platform_permission(
  permission_code text,
  institution_id uuid
)
returns boolean
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
as $$
  with memberships as (
    select membership.id, membership.role_id
    from public.platform_memberships membership
    join public.platform_roles role_record on role_record.id = membership.role_id
    where membership.person_id = app_private.current_person_id()
      and membership.status = 'active' and membership.revoked_at is null
      and role_record.status = 'active'
      and (
        (membership.scope_kind = 'platform' and membership.scope_institution_id is null)
        or (
          membership.scope_kind = 'institution'
          and membership.scope_institution_id is not null
          and (institution_id is null or membership.scope_institution_id = institution_id)
        )
      )
  ), target as (
    select id from public.platform_permissions
    where code = permission_code and status = 'active'
  ), effects as (
    select grant_record.effect from memberships
    join public.platform_role_permissions grant_record
      on grant_record.role_id = memberships.role_id
     and grant_record.status = 'active' and grant_record.revoked_at is null
    join target on target.id = grant_record.permission_id
    union all
    select override_record.effect from memberships
    join public.platform_member_permission_overrides override_record
      on override_record.membership_id = memberships.id
     and override_record.status = 'active'
     and (override_record.starts_at is null or override_record.starts_at <= now())
     and (override_record.expires_at is null or override_record.expires_at > now())
    join target on target.id = override_record.permission_id
  )
  select exists(select 1 from effects where effect = 'allow')
     and not exists(select 1 from effects where effect = 'deny')
$$;

create or replace function app_private.has_platform_permission(
  permission_code text
)
returns boolean
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
as $$
  select app_private.has_platform_permission(permission_code, null::uuid)
$$;

-- Mesma ACL da forma de um argumento em producao: postgres e authenticated
-- (as policies RLS avaliam a funcao como authenticated); anon e public fora.
revoke all on function app_private.has_platform_permission(text, uuid) from public, anon;
grant execute on function app_private.has_platform_permission(text, uuid) to authenticated;
revoke all on function app_private.has_platform_permission(text) from public, anon;
grant execute on function app_private.has_platform_permission(text) to authenticated;

comment on function app_private.has_platform_permission(text, uuid) is
  'P7 (ADR 0034, Decisao 12): permissao por papel de plataforma, contando memberships de plataforma e de instituicao; com institution_id, a membership de instituicao so vale para aquela instituicao. Deny vence allow; sem membership ativa, false.';
comment on function app_private.has_platform_permission(text) is
  'Delegado de has_platform_permission(text, null): qualquer membership ativa (plataforma ou instituicao) conta.';

commit;
