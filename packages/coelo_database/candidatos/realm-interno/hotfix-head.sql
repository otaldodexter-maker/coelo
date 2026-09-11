-- R06 realm-interno (1b): HOTFIX do 20260912210000 aplicado em producao no lote 50
-- (20:12) na versao da rev 40. Aquela versao definia o escopo do espelho so
-- sobre instituicoes ATIVAS, e a reconciliacao desativou as memberships de
-- espelho de PLATAFORMA na instituicao em rascunho qa-r04-escola (7 linhas
-- medidas as 20:18: os qa-r06-* do lote 49), quebrando o padrao do lote 27/P42.
--
-- O que este pacote faz (idempotente):
--   1. instala a versao final (rev 42) de superadmin_internal_actor_scope_targets
--      (devolve institution_status; escopo sem filtro de status) e do sync
--      (reconcilia so FORA do escopo; insere so em instituicoes ativas);
--   2. reativa as memberships de espelho desativadas pela reconciliacao da
--      versao anterior: status inactive, revoked_at nas ultimas 24 h, pessoa de
--      servico e instituicao dentro do escopo da versao final.
-- has_platform_permission(text,uuid) do 20260912210000 nao muda.
-- Reversao: recriar as funcoes como em 20260912210000 (versao aplicada).

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$
begin
  if to_regprocedure('app_private.superadmin_internal_actor_scope_targets()') is null then
    raise object_not_in_prerequisite_state using message = 'internal_actor_scope_root_v1 (20260912210000) e pre-requisito';
  end if;
end $$;

