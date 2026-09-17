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
| `4e96c8840` | B6 — pessoa sem conta (spec 062): migration + pgTAP 40/40 + Edge `child-safety-media` (deno 6/6) | BE validado no espelho; Edge não implantada | idem |
| `1a43b0435` | B6 FE — cadastro no wizard, upload do documento pelo gateway, `authorized_person_id` no comando | local-green (safety 196/196) | idem |
| `13f4a8c9b` | r12-38 — Cardápios imagem R2 (spec 063): migration + pgTAP 26/26, Edge `meal-plan-media` (7/7) + ramo R2 no cleanup, adapter FE pelo gateway (9/9), envio habilitado nas rotas produtivas, prévia após reload | local-green; não aplicada/implantada | idem |
| (este commit) | Fatia 4 — specs decididas sem prova: 064 perfil transversal/funcionário no Principal (OQ-044, r12-19/23, `draft-for-review`), 065 Perfis de cuidado §5 (r12-29/30), 066 ciclo de vida OQ-033 (+ `institutions.status`), 067 Locais OQ-034, 068 perfis oficiais OQ-032 (`draft-for-review`, lista a escolher), 069 Avisos H08/H13/H23 | só spec; nenhuma migration/tela | — |

Nenhum delta JSON aplicado; `validate-trackers` PASS com os contadores do corte.

## Bloqueios

| Gate | Causa | Detalhe |
|---|---|---|
| Aplicar `20260917160000`, `20260917170000` e `20260917180000` em produção; deploy `child-safety-media`, `meal-plan-media`, `meal-plan-image-cleanup` | **ambiente (permissão do executor)** | `supabase db query --linked -f` negado pelo classificador ("Production Deploy"); não contornado. Rito e ordem completos na evidência; lote sugerido **77**. O Owner decide como entram. |
| E2E `owner.r12-17` / `owner.r12-18` | ambiente (depende da aplicação) + massa `QA R15` (Bloco B) | tela preparada; nada certificado |
| E2E `owner.r12-38` (`meal-plans.create/edit/publish/model-edit`) | ambiente (depende da aplicação + deploy) | adapter e rotas prontos; nada certificado; as 4 ações seguem verified-e2e (sem regressão local) |
| Goldens `meal_plan_pages_golden_test` (5 do diretório) | deriva do cabeçalho (E4), já falham em `dev` | não regravados nesta sessão |

## Avisos

1. Alguém renumerou, na minha worktree, `specs/055` → `061` e a migration
   `20260917103000` → `20260917160000` (09:02–09:12); adotei os nomes finais e
   as referências internas estão consistentes.
2. Bloco B aplicou OQ-047 como lote 75 (PT409 em 126 RPCs); as minhas migrations
   não tocam funções alteradas por ele (`child_safety_request_authorization` não
   tinha 40001).
3. Regra durável (ADR 0041): CPF nunca em claro → busca por CPF só com o número
   completo (HMAC). Registrado nas specs 061/062.
4. Cardápios: ativos legados (`supabase_mvp`) seguem lidos pelo caminho v1 só no
   servidor; o cliente novo lê pelo gateway (409 `legacy_storage_asset` para
   legado; hoje não há ativos legados em produção, pois o envio estava desabilitado).
5. Bloco B (OQ-047, lote 75) já cobriu `serialization_failure` nas famílias; as
   minhas migrations não contêm 40001 (postcheck).
6. Numeração das specs da fatia 4 (064–069) passa da faixa 061–064 informada pela
   coordenadora; nenhuma colisão em `origin/r15/bloco-a|b|c1` na hora do commit.
   Renumerar na integração se outra sessão reservar 065+.
7. Espelho `coelo_mirror_r15_c2` parado ao fim (`supabase stop`); a pasta
   `Coelo-backups/mirror-r15-c2` e o dump prévio permanecem para reexecutar os
   três pgTAP (`docker exec -i supabase_db_coelo_mirror_r15_c2 psql … -f -`).
8. Porta 3017/CDP 9417 não foram usados: nenhuma tela foi executada na rota real
   (todas as provas dependem da aplicação em produção).

## Contadores

`validate-trackers` PASS `{"actions":232,"frontendCompleted":189,"backendCompleted":172,"e2eCompleted":162,"activeE2E":186}` — inalterados.
