---
title: "R15 Bloco C1 — Principal hospedado (B9): ver como, Para você e Editar perfil na rota real"
source: "ADR 0041 B9; ADR 0037; ADR 0038 H02; ADR 0042 E9; spec 059; migration 20260917130000_principal_for_you_reader_v1 (lote 77); R15-prompts.md (Prompt C1)"
status: "verified"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# Principal hospedado — B9 (`principal.for-you`, `principal.profile-edit`) — 17/09/2026

Ambiente: produção Supabase (`evvbomzejfijozbtgvpt`); build `flutter build web --release -t
test_driver/qa_main.dart --dart-define-from-file=.env.local
--dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true` da worktree `r15-bloco-c1` em `6e9234c87`
(sem o import removido depois), servido por `serve.py` em `127.0.0.1:3016`; Chrome CDP `9416`
(SwiftShader, perfil `%TEMP%\coelo-r15-c1-chrome-principal`); sessão `qa-r06-principal@coelo.me`
(Owner com dois vínculos institucionais: A = `QA R04 Cuidado (sintetico)` `d0c40000…0001`,
B = `QA R04 Instituicao Sintetica` `9f040000…0010`; `list_my_principal_contexts` lido na
abertura). Massa: aviso `for_you` `QA R15 Para voce (sintetico)` (`f7ae82a4`, audiência =
instituição A, `important`, `all`) criado e publicado por PostgREST com `qa-r06-publicacoes`
(`superadmin_notice_save_draft_v2` + `superadmin_notice_publish_v2`); antes dele não havia
nenhum `highlight/content_card/for_you` em produção.

## Backend em produção (lote 77)

- `20260917130000_principal_for_you_reader_v1.sql`: `public.list_my_principal_for_you(text,uuid,
  integer)` — ator por `auth.uid()`, vínculo ativo próprio (`p_membership_id` opcional; alheio ou
  inexistente → lista vazia), tipos `highlight/content_card/for_you`, `status='active'`, destino
  na allowlist, vigência, audiência (`audience_json` + `notice_rules` como exclusão), itens no
  envelope de `app_private.superadmin_notice_json`. Espelho `mirror-r15-c1`: pgTAP
  `principal_for_you_reader_v1_test.sql` 21/21 (log nesta pasta); dump prévio
  `Coelo-backups/schema-producao-20260917-r15-c1-b9-before.sql` (SHA-256 `66f8bacc…`, já com os
  lotes 75 e 76); `supabase db query --linked -f` + `migration repair --status applied
  20260917130000`; ledger remoto listado; verificação pós-aplicação: função presente, `anon` sem
  execute, `authenticated` com execute.
- Prova por PostgREST (`qa-r06-principal`): `list_my_principal_for_you('web')` → 1 item
  (`QA R15 Para voce (sintetico)`, `for_you`, `active`); com `p_membership_id` = vínculo A → o
  mesmo item; = vínculo B → `[]`; vínculo inexistente → `[]`; `p_target_device='desktop'` →
  `400 22023 invalid_for_you_target_device`.

## Rota real

| Passo | Resultado observado | Captura |
|---|---|---|
| `/principal-for-you` com o contexto A | cabeçalho do Principal com o avatar da conta (`OD`); card "PARA VOCÊ — QA R15 Para voce (sintetico)" vindo de `list_my_principal_for_you` (rede: `list_my_principal_contexts` → `list_my_principal_for_you` 200; nenhum `superadmin_notice_directory_v2`); "Seu contexto atual: QA R04 Cuidado (sintetico)" | `capturas/principal-20-for-you.png` |
| Reload da rota | mesma leitura e mesmo card após `Page.reload` (a segunda chamada a `list_my_principal_for_you` aparece na rede) | (rede; `…-35-avatar-menu.png` mostra o hub após o reload) |
| "Ver como" (ADR 0041 B9 / ADR 0037) | avatar → menu "Abrir perfil / Ver como" → folha "Ver como" lista A (marcado) e B com `@handle`; escolher B → **só o cabeçalho muda**: nome "QA R04 Instituicao Sintet…" + avatar `QS`; sem faixa "Vendo como"; o hub relê por `list_my_principal_for_you` com o vínculo B (200) e mostra nenhum card (audiência = A) e "Seu contexto atual: QA R04 Instituicao Sintetica" | `…-36-ver-como-sheet.png`, `…-37-ver-como-applied.png`, `…-38-ver-como-hub-b.png` |
| `/principal-profile` → "Editar perfil" | perfil de A com "Editar perfil"; editor abre vazio ("Nenhum conteúdo no Sobre"), com a nota "O Sobre é independente do cadastro oficial…" | `…-23-profile.png`, `…-24-profile-edit.png` |
| Editar perfil: seção de texto | "Adicionar seção" → Texto → "Editar seção" → conteúdo "Sobre editado pela R15 C1 em 17/09 (QA R15, sintetico)." → Aplicar → **Salvar** → `save_profile_about` 200 → re-leitura (`get_profile_about`) → "Sobre salvo." | `…-32-d-filled.png`, `…-33-saved.png` |
| Persistência | `get_profile_about('institution', A)` por PostgREST: página `1d442fc9`, `version` 2, `state` `draft`, seção "Nova seção" com o corpo acima (a versão 1 foi um primeiro save sem seção, quando o clique em "Aplicar" não registrou — o editor exige `Input.insertText` vazio antes de `enter_text`, como já anotado na R13) | (RPC) |

Observações: o `PopupMenuButton` do avatar não aparece nas capturas do SwiftShader mesmo aberto;
o fluxo foi dirigido por `window.$flutterDriver` (`tap ByValueKey principal-context-header-context-avatar`
e `tap ByText "Ver como"`), depois por coordenada na folha. A superfície branca do seletor no
tema claro (ADR 0037) está coberta pelo teste de widget (`context_selector_test`); a rota real
rodou no tema escuro do QA.

## Negativas por PostgREST (`qa-r06-principal`)

| Chamada | Resposta |
|---|---|
| `save_profile_about` para instituição alheia `d0c40000…0099` | `403 42501 insufficient_privilege` |
| `save_profile_about` para A com `p_expected_version = 9999` | `409 PT409 profile about version conflict` (`PROFILE_ABOUT_STALE_VERSION`, lote 75) |
| `get_profile_about` para `…0099` | `null` (não enumerável) |
| `list_my_principal_for_you('web', vínculo de outra pessoa)` | `[]` (pgTAP) / vínculo inexistente `[]` (produção) |

## H02 (ADR 0038)

O consumidor está ligado: `PrincipalProfileEditPage` monta `ProfileAboutOfficialUpdateRequest`
para cada campo divergente, pergunta "Atualizar também no cadastro oficial?" só com
`canUpdateOfficialData` e envia a decisão em `p_official_updates` (testes de widget: com
capacidade → diálogo → "Sim, atualizar" envia o campo; "Agora não" e sem capacidade → Sobre
salvo sozinho). Na rota real a capacidade chega desligada: `superadmin_publication_contexts`
devolve `can_update_profile_about_official_data=false` para `qa-r06-principal` porque o servidor
exige AAL2 e MFA está fora do MVP (ADR 0042 E9); `get_profile_about` não projeta valores
oficiais. O "pedido vai à instituição para aprovar" segue sem contrato (registrar em
`docs/open-questions.md` se o Owner quiser esse fluxo).

## Resultado

- `principal.for-you`: FE `verified`, BE `done` (lote 77), integrado `verified-e2e`.
- `principal.profile-edit`: FE `verified`, BE `done` (contrato existente `get/save_profile_about`
  com PT409 desde o lote 75; consumidor H02 ligado), integrado `verified-e2e`.
- B9 "ver como": só avatar/nome no cabeçalho, sem faixa fixa — provado na rota real.
- Falhas pré-existentes conhecidas na base `57162cee4` (não regressão): goldens de cabeçalho
  (E4: `principal_for_you_preview_golden_test`, `principal_profile_preview_golden_test`,
  `notice_directory_golden_test`) e dois testes de router que esperam a faixa
  `principal-context-selector` (`principal_real_route_test`, `principal_profile_for_you_production_routes_test`).
- Resíduo de massa: aviso `f7ae82a4` (QA R15) e página do Sobre `1d442fc9` (draft) da instituição
  sintética A, sem PII.
