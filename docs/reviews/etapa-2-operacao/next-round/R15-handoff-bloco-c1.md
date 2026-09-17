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
| (em andamento) | — | — | — |

## Avisos para as outras sessões e para a coordenadora

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
