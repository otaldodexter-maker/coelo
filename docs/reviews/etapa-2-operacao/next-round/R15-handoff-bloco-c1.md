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
`r15/bloco-c1`, servidor QA `127.0.0.1:3016`, CDP `9416`, perfil
`%TEMP%\coelo-r15-c1-chrome`, espelho `Coelo-backups/mirror-r15-c1`
(`coelo_mirror_r15_c1`, portas 623xx, restaurado do dump
`schema-producao-20260917-r15-c1-before.sql`, SHA-256 `c87f4d67…`, idêntico ao
dump do Bloco B do mesmo dia), evidências em
`docs/reviews/evidence/etapa-2/r15-bloco-c1/`.

## Reivindicações

| Tela | action_ids / Owner items | Desde |
|---|---|---|
| Coelo (Principal) › Conversas › thread › anexos (`/chat`) | `chat.attach`, `owner.r12-52` (E3) | 17/09 08:50 BRT |
| Principal hospedado › "ver como" / Para você / Editar perfil | `principal.for-you`, `principal.profile-edit`, H02 (B9) | 17/09 08:50 BRT |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| d27a829db | E3 local-green: migration `20260917120000_chat_attachment_batch_v2` + pgTAP 51/51 (v1 28/28, lote 67 9/9 no espelho), Edge `chat-media` em lote (deno 7/7), FE lote (`ChatAttachmentBatchRepository`, `SuperadminChatBatchUploadDialog`, chat 254/254), spec 058. Nenhum estado alterado. | — | specs/058; r15-bloco-c1/pgtap-*.txt |
| (este commit) | **lote 76** aplicado em produção (`20260917120000`, ledger reparado, listado após o `20260917090000` do Bloco B) + Edge `chat-media` implantada; rota real `qa-r06-publicacoes` em 3016: `chat.attach` local-green/local-green/pending-verification → **verified/done/verified-e2e** | `owner.r12-52` → **done** | r15-bloco-c1/chat-attach-e3-20260917.md + deltas-chat-attach-20260917.json + capturas/ |

## Avisos para as outras sessões e para a coordenadora

- **Lote 76 em produção (17/09 ~10:00 BRT)**: `20260917120000_chat_attachment_batch_v2` —
  altera `app_private.superadmin_chat_error` (código novo `CHAT_ATTACHMENT_DISCARD_INVALID`),
  `superadmin_chat_attachment_expire_v1`, `superadmin_chat_thread_v2` (só anexos `ready`, ordem
  por `position`) e cria `prepare_v2`/`finalize_v2`/`discard_v1` + coluna
  `chat_attachment_metadata.position`. `prepare_v1`/`finalize_v1` intactas. Ledger remoto já
  continha `20260917090000` (Bloco B, lote 75) na listagem — numerei o meu como 76; se a ordem
  real de aplicação foi outra, a coordenadora renumera.
- Edge `chat-media` nova em produção: `prepare` com `items[]` → `prepare_v2`; `finalize` →
  `finalize_v2`; ação nova `discard`. O caminho unitário (`prepare` sem `items`) continua para o
  app hospedado antigo.
- Massa: mensagens sintéticas (PNG de cor sólida e PDF "QA R15 sintetico") na conversa
  `Grupo R14 Sessao 1` (`7f54da12`), sem PII; ficam como massa.
- Ferramenta: `qa_login.dart` fala com o VM Service e não funciona no build release; usei
  `cdp_login.dart` (scratchpad) via `window.$flutterDriver` marcando "Manter sessão aberta" —
  sem isso o reload derruba a sessão.

- Espelho `mirror-r15-c1` precisou de catálogos (dump é schema-only): semeados
  por SELECT de produção (`platform_roles/permissions/role_permissions`,
  `global_type_catalogs`, `institution_permissions`, `unit_types`,
  `family_relationship_types`, `guardian_permission_capabilities`,
  `access_profile_template*`, `activity_taxonomies/capabilities`) + pessoa
  técnica Coelo `c0e10000…01` + `alter default privileges … revoke execute on
  functions from anon, authenticated, service_role` (drift local descrito no
  handoff 8 da R14). Suítes base `superadmin_internal_chat_attachments_v1`
  28/28 e `r13/chat-attachment-limit-per-send` 9/9 verdes antes de qualquer
  candidato.

## Bloqueios

(nenhum até agora)

## Sobra

(a preencher)

## Contadores

(a preencher com `validate-trackers` após a última fatia)
