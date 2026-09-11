-- MFA fora do MVP (ADR 0034, Decisao 12; decisao do Owner em 10/09/2026, noite).
--
-- Nenhuma capacidade exige segundo fator no MVP, inclusive escrita em dado de
-- crianca. Duas coisas mudam aqui, e so duas:
--
--   1. O catalogo de permissoes (plataforma, instituicao e responsaveis) passa a
--      requires_mfa = false em todas as linhas. Isso alinha o metadado que as
--      telas de Perfis/Modelos e app_private.require_superadmin_internal_context
--      devolvem ao cliente.
--   2. app_private.has_mfa_aal2() e o unico portao por onde toda funcao que hoje
--      nega por AAL2 passa (Pessoas, Perfis/Modelos, Unidades, Rotina,
--      Assiduidade, Seguranca infantil, exportacoes, Cardapios...). No MVP uma
--      sessao autenticada (aal1 ou aal2) satisfaz o portao; sem JWT continua
--      negando. Nao se reescrevem dezenas de funcoes: alinha-se o portao.
--
-- Nao muda: platform_memberships.mfa_required (uma linha em producao) fica
-- como esta; com o portao aceitando aal1 ela deixa de ter efeito. As funcoes
-- que gravam o literal 'aal2' na trilha de auditoria continuam gravando esse
-- literal: pendencia de code review registrada no rastreador de Back-end.
--
-- Reversao (ao reativar a ADR 0019, depois do MVP): trocar a comparacao de
-- has_mfa_aal2() de volta para = 'aal2' e reativar requires_mfa por capacidade.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode = '42501',
      message = 'mfa_fora_do_mvp must run as postgres';
  end if;
  if pg_catalog.to_regprocedure('app_private.has_mfa_aal2()') is null then
    raise exception using errcode = '55000',
      message = 'app_private.has_mfa_aal2() is required';
  end if;
  if pg_catalog.to_regclass('public.platform_permissions') is null
     or pg_catalog.to_regclass('public.institution_permissions') is null
     or pg_catalog.to_regclass('public.guardian_permission_capabilities') is null then
    raise exception using errcode = '55000',
      message = 'permission catalog tables are required';
  end if;
end
$preflight$;

-- 1. Catalogo: nenhuma capacidade exige segundo fator no MVP.
update public.platform_permissions
   set requires_mfa = false, updated_at = now()
 where requires_mfa;

update public.institution_permissions
   set requires_mfa = false, updated_at = now()
 where requires_mfa;

update public.guardian_permission_capabilities
   set requires_mfa = false, updated_at = now()
 where requires_mfa;

-- 2. Portao unico de AAL2: no MVP, sessao autenticada basta.
create or replace function app_private.has_mfa_aal2()
returns boolean
language sql
stable
set search_path to 'public'
as $$
  select coalesce(auth.jwt() ->> 'aal', '') in ('aal1', 'aal2')
$$;

comment on function app_private.has_mfa_aal2() is
  'MVP (ADR 0034, Decisao 12): sessao autenticada aal1 ou aal2 satisfaz o portao. Reverter para = ''aal2'' ao reativar a ADR 0019.';

revoke execute on function app_private.has_mfa_aal2() from public, anon;

commit;
