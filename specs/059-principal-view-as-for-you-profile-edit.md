---
title: "059 — Principal hospedado: \"ver como\" no cabeçalho, leitor Para você e Editar perfil (B9)"
source: "ADR 0041 B9; ADR 0037 (Principal hospedado, seletor branco); ADR 0038 H02; ADR 0042 E9 (MFA fora do MVP); plans/2026-09-09-principal-for-you-read-rpc.sql; R14-sessao-1/shell-switch-context-20260915.md"
status: "approved"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# 059 — Principal hospedado: "ver como", Para você e Editar perfil

## Objetivo e escopo

Fechar as duas ações do Principal desbloqueadas pela decisão B9: `principal.for-you`
(leitor com o contexto real do responsável) e `principal.profile-edit` (escritor do
Sobre do próprio contexto, com o consumidor de atualização oficial H02 ligado).
Fora de escopo: nome/avatar da conta (já cobertos por `account.profile`, ADR 0041
A3 e R14), aprovação institucional do pedido oficial (sem contrato), MFA (E9).

## "Ver como" (ADR 0041 B9, ADR 0037)

- O cabeçalho do Principal só troca **avatar e nome**: sem escolha explícita mostra
  a conta autenticada; após "Ver como" mostra as iniciais e o nome do contexto
  escolhido (ou "N perfis" na seleção múltipla). Não existe faixa fixa "Vendo
  como" (`PrincipalContextSelectorBar` continua sem montagem).
- O seletor abre pelo avatar superior direito, com superfície branca
  (`CoeloPalette.neutral0`) no tema claro, sem hover cinza, e Aplicar/Cancelar
  na seleção múltipla. A escolha é preferência de sessão, não autorização.
- Chave do nome: `principal-context-header-context-label`.

## Para você (`principal.for-you`)

- Migration `20260917130000_principal_for_you_reader_v1.sql` (lote 77):
  `public.list_my_principal_for_you(p_target_device text, p_membership_id uuid
  default null, p_limit integer default 50) returns jsonb` — ator por
  `auth.uid()` → `app_private.person_id_for_auth_user`; só vínculos ativos da
  própria pessoa (id alheio/inexistente → lista vazia); tipos `highlight`,
  `content_card`, `for_you` (nunca popup/notice/critical_notice); `status =
  'active'`; destino na allowlist `all|web|mobile|tablet` (fora dela →
  `22023 invalid_for_you_target_device`); vigência; audiência de
  `audience_json` (papel, dimensão/`target_ids`/`select_all`, `excluded_ids`;
  exclusão vence; `notice_rules` só como exclusão). Itens no envelope de
  `app_private.superadmin_notice_json` (`{ok, data:{items:[…]}}`).
- FE: `PrincipalForYouReader.readForYou({membershipId})` implementado por
  `SupabaseNoticeRepository` (destino `web` no navegador); a página lê pelo
  leitor com o vínculo do contexto ativo e mantém a projeção local como segunda
  barreira. O diretório administrativo fica apenas para fixtures/legado.
- pgTAP `principal_for_you_reader_v1_test.sql` (21): grants, sem sessão, papel,
  dimensões, exclusão, cross-tenant, destino, vigência, limite, vínculo alheio.

## Editar perfil (`principal.profile-edit`, H02)

- O Sobre do contexto ativo continua em `get_profile_about`/`save_profile_about`
  (versão otimista `profile_about_pages.version`; versão defasada → `PT409`
  após o lote 75).
- H02 (ADR 0038): a página constrói `ProfileAboutOfficialUpdateRequest` para
  cada campo do Sobre que diverge do cadastro oficial e, quando
  `canUpdateOfficialData`, pergunta "Atualizar também no cadastro oficial?"
  (`profile-about-official-update-dialog`); a decisão viaja em
  `p_official_updates` (auditado e validado no servidor). Sem a capacidade não
  há pergunta e o Sobre é salvo sozinho.
- Limite conhecido: `profiles.about.update_official_data` exige AAL2 no servidor
  e MFA está fora do MVP (E9), então a capacidade chega desligada no MVP;
  `get_profile_about` ainda não projeta os valores oficiais (sugestões vazias).
  O "pedido vai à instituição para aprovar" da ADR 0038 segue sem contrato
  (registrar em `docs/open-questions.md` se o Owner quiser o fluxo de aprovação).

## Verificação

- FE: `context_selector_test` (troca de avatar/nome, sem faixa), leitor
  (`supabase_principal_for_you_reader_test`), página (`reader` vence o
  diretório), Editar perfil (diálogo H02 com/sem capacidade, "Agora não").
- Rota real com `qa-r06-principal`: Para você com o aviso `QA R15 Para voce
  (sintetico)` (audiência = instituição QA R04) e reload; Editar perfil: Sobre
  salvo/relido; negativas por PostgREST (perfil alheio → 403; versão defasada →
  PT409). Falhas pré-existentes conhecidas (base `57162cee4`): goldens de
  cabeçalho (E4) e os testes de router que esperam a faixa `principal-context-selector`.
