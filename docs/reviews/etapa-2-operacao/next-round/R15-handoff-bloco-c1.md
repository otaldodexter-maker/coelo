---
title: "R15 — handoff do Bloco C1 (Chat multi-anexo E3 e \"ver como\" B9)"
source: "R15-prompts.md (Prompt C1); R15-execucao-paralela.md; ADR 0041 B9; ADR 0042 E3; R14-handoff-sessao-6.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — handoff do Bloco C1

Worktree `C:\Users\adrie\Documents\Coelo.worktrees\r15-bloco-c1`, branch
`r15/bloco-c1`, servidor QA `127.0.0.1:3016`, CDP `9416`, perfis
`%TEMP%\coelo-r15-c1-chrome` (publicações) e `%TEMP%\coelo-r15-c1-chrome-principal`,
espelho `Coelo-backups/mirror-r15-c1` (`coelo_mirror_r15_c1`, portas 623xx, restaurado do
dump `schema-producao-20260917-r15-c1-before.sql`, SHA-256 `c87f4d67…`, + catálogos de
produção), evidências em `docs/reviews/evidence/etapa-2/r15-bloco-c1/`.

## Reivindicações

| Tela | action_ids / Owner items | Desde | Situação |
|---|---|---|---|
| Coelo (Principal) › Conversas › thread › anexos (`/communication/conversations`) | `chat.attach`, `owner.r12-52` (E3) | 17/09 08:50 BRT | **fechada** 10:05 BRT |
| Principal hospedado › "ver como" / Para você / Editar perfil | `principal.for-you`, `principal.profile-edit`, H02 (B9) | 17/09 08:50 BRT | **fechada** 12:15 BRT |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| d27a829db | E3 local-green: migration `20260917120000_chat_attachment_batch_v2` + pgTAP 51/51 (v1 28/28, lote 67 9/9 no espelho), Edge `chat-media` em lote (deno 7/7), FE lote (`ChatAttachmentBatchRepository`, `SuperadminChatBatchUploadDialog`, chat 254/254), spec 058. Nenhum estado alterado. | — | specs/058; r15-bloco-c1/pgtap-*.txt |
| 57ffe51e8 + c0482aedd | **lote 76** em produção (`20260917120000`, ledger reparado) + Edge `chat-media` implantada; rota real `qa-r06-publicacoes`: `chat.attach` local-green/local-green/pending-verification → **verified/done/verified-e2e** | `owner.r12-52` → **done** | r15-bloco-c1/chat-attach-e3-20260917.md + deltas-chat-attach-20260917.json + capturas/ |
| 6e9234c87 | B9 local-green: migration `20260917130000_principal_for_you_reader_v1` (**lote 77**, aplicada pelo rito) + pgTAP 21/21; FE: `PrincipalGlobalHeader.contextLabel` + avatar do contexto após "Ver como" (sem faixa), `PrincipalForYouReader` (`list_my_principal_for_you`) na página/router, H02 ligado no `PrincipalProfileEditPage`; spec 059. Nenhum estado alterado. | — | specs/059; r15-bloco-c1/pgtap-principal_for_you_reader_v1-mirror-20260917.txt |
| (este commit) | rota real `qa-r06-principal`: `principal.for-you` verified/blocked-decision/pending-verification → **verified/done/verified-e2e**; `principal.profile-edit` local-green/blocked-decision/pending-verification → **verified/done/verified-e2e** | — (B9 não tem `owner.r12-*` próprio) | r15-bloco-c1/principal-b9-20260917.md + deltas-principal-b9-20260917.json + capturas/ |

## Avisos para as outras sessões e para a coordenadora

- **Lote 76 em produção (17/09 ~10:00 BRT)**: `20260917120000_chat_attachment_batch_v2` —
  altera `app_private.superadmin_chat_error` (código novo `CHAT_ATTACHMENT_DISCARD_INVALID`),
  `superadmin_chat_attachment_expire_v1`, `superadmin_chat_thread_v2` (só anexos `ready`, ordem
  por `position`) e cria `prepare_v2`/`finalize_v2`/`discard_v1` + coluna
  `chat_attachment_metadata.position`. `prepare_v1`/`finalize_v1` intactas.
- **Lote 77 em produção (17/09 ~11:20 BRT)**: `20260917130000_principal_for_you_reader_v1` —
  cria `public.list_my_principal_for_you(text,uuid,integer)` (só isso; nada alterado).
- Edge `chat-media` nova em produção: `prepare` com `items[]` → `prepare_v2`; `finalize` →
  `finalize_v2`; ação nova `discard`. O caminho unitário (`prepare` sem `items`) continua para o
  app hospedado antigo.
- Massa (sem PII): mensagens sintéticas (PNG de cor sólida e PDF "QA R15 sintetico") na conversa
  `Grupo R14 Sessao 1` (`7f54da12`); aviso `for_you` `QA R15 Para voce (sintetico)` (`f7ae82a4`,
  audiência = instituição `d0c40000…0001`, `active`); página do Sobre `1d442fc9` (draft) da
  mesma instituição. Todos ficam como massa.
- Espelho `mirror-r15-c1` precisou de catálogos (dump é schema-only): semeados por SELECT de
  produção (`platform_roles/permissions/role_permissions`, `global_type_catalogs`,
  `institution_permissions`, `unit_types`, `family_relationship_types`,
  `guardian_permission_capabilities`, `access_profile_template*`, `activity_taxonomies/
  capabilities`) + pessoa técnica Coelo `c0e10000…01` + `alter default privileges … revoke
  execute on functions from anon, authenticated, service_role` (drift do handoff 8 da R14).
- Ferramentas: `qa_login.dart` fala com o VM Service e não funciona no build release; usei
  `cdp_login.dart` (scratchpad) via `window.$flutterDriver`, marcando "Manter sessão aberta" —
  sem isso o reload derruba a sessão. `PopupMenuButton` do avatar não aparece nas capturas do
  SwiftShader mesmo aberto; `driver tap ByValueKey/ByText` funciona para menu e folha; campos de
  texto exigem `Input.insertText` vazio antes de `enter_text` (nota da R13 confirmada).
- Falhas pré-existentes confirmadas na base `57162cee4` (worktree descartável): goldens de
  cabeçalho (E4) em `principal_for_you_preview_golden_test`, `principal_profile_preview_golden_test`
  e `notice_directory_golden_test`; testes de router `principal_real_route_test` ("offers the
  profile selector (P28)") e `principal_profile_for_you_production_routes_test` ("page bar is
  the only one") que esperam a faixa `principal-context-selector` (não montada desde a R14).
  Não regravei goldens nesta fatia.
- `unnecessary_import` apontado pela coordenadora (foundation.dart em
  `principal_runtime_context_route.dart`) removido neste commit.

## Bloqueios

- Nenhum de sessão/massa/RPC/ambiente. Decisão (não bloqueante): H02 "pedido vai à instituição
  para aprovar" (ADR 0038) não tem contrato; a capacidade `update_official_data` exige AAL2 e
  MFA está fora do MVP (E9) — o consumidor ficou ligado e desligado por capacidade.

## Sobra

- Fatia 3 opcional (`momentos.*` do Bloco A) não iniciada: não combinada pelo handoff A antes do
  fim desta sessão.
- E4: regravar os goldens de cabeçalho das suítes do Principal/avisos (diff isolado só nas
  iniciais do avatar) — quem consolidar as regravações pode incluir estas.
- Owner (se quiser): decidir o fluxo de aprovação institucional do H02 e se `get_profile_about`
  deve projetar os valores oficiais (sugestões) para o editor.

## Contadores

`node docs/reviews/validate-trackers.cjs` após a última fatia: PASS — actions 232,
FE 191/232, BE 175/219, E2E **165/186** ativo (corte de abertura 162; +3 por este bloco:
`chat.attach`, `principal.for-you`, `principal.profile-edit`); Owner: `owner.r12-52` done.
