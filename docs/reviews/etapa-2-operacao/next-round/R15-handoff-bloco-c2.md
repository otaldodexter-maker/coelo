---
title: "R15 — handoff do Bloco C2 (B5 busca de pessoa, B6 pessoa sem conta, r12-38 Cardápios R2)"
source: "R15-prompts.md (Prompt C2); ADR 0041 B5/B6; ADR 0032; R15-pendencias.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — handoff do Bloco C2

Worktree `C:\Users\adrie\Documents\Coelo.worktrees\r15-bloco-c2`, branch
`r15/bloco-c2` (base `dev` `57162cee4`). Porta 3017 / CDP 9417 reservados
(nenhuma tela executada ainda). Espelho `coelo_mirror_r15_c2` (624xx) restaurado
do dump `schema-producao-20260917-r15-c2-before.sql` (SHA-256 `c87f4d67…`).

## Reivindicações

- Segurança da criança › wizard Criar/Editar (`child-safety.create/edit`) — apenas o
  campo de pessoa autorizada (B5/B6); o Bloco B mantém `edit/suspend` e a massa.
- Cardápios (`meal-plans.create/edit/publish/model-edit`) — imagem R2 (r12-38), a seguir.

## Fatias entregues

| SHA | Fatia | Estado | Evidência |
|---|---|---|---|
| `650297873` | B5 — `superadmin_person_search_v1` (spec 061) + FE do wizard | migration validada no espelho (pgTAP 33/33), FE local-green (safety 192/192, analyze limpo); **não aplicada em produção** | `r15-bloco-c2/person-search-and-person-without-account-20260917.md` |
| (este commit) | B6 — pessoa sem conta (spec 062): migration + pgTAP 40/40 + Edge `child-safety-media` (deno 6/6) | BE validado no espelho; Edge não implantada; FE em andamento | idem |

Nenhum delta JSON aplicado; `validate-trackers` PASS com os contadores do corte.

## Bloqueios

| Gate | Causa | Detalhe |
|---|---|---|
| Aplicar `20260917160000` e `20260917170000` em produção; deploy `child-safety-media` | **ambiente (permissão do executor)** | `supabase db query --linked -f` negado pelo classificador ("Production Deploy"); não contornado. Rito e ordem completos na evidência; lote sugerido **77**. O Owner decide como entram. |
| E2E `owner.r12-17` / `owner.r12-18` | ambiente (depende da aplicação) + massa `QA R15` (Bloco B) | tela preparada; nada certificado |

## Avisos

1. Alguém renumerou, na minha worktree, `specs/055` → `061` e a migration
   `20260917103000` → `20260917160000` (09:02–09:12); adotei os nomes finais e
   as referências internas estão consistentes.
2. Bloco B aplicou OQ-047 como lote 75 (PT409 em 126 RPCs); as minhas migrations
   não tocam funções alteradas por ele (`child_safety_request_authorization` não
   tinha 40001).
3. Regra durável (ADR 0041): CPF nunca em claro → busca por CPF só com o número
   completo (HMAC). Registrado nas specs 061/062.

## Contadores

`validate-trackers` PASS `{"actions":232,"frontendCompleted":189,"backendCompleted":172,"e2eCompleted":162,"activeE2E":186}` — inalterados.
