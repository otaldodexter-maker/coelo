---
title: "R14 — handoff da Sessão 9 (visual: goldens do cabeçalho, cards de Rotina, Arquivar modelos)"
source: "Sessão 9 da R14 (Opus 5), 16/09/2026; briefing comum da coordenadora; ADR 0041 B1/C1/C3; R14-pendencias.md; docs/reviews/evidence/etapa-2/r14-sessao-9/"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — handoff da Sessão 9

Worktree `Coelo.worktrees\r14-visual-arquivar`, branch `r14/visual-arquivar` (base `dev` `e6b8d6f63`).
Porta 3021 / CDP 9421 reservados, **não usados**: produção em incidente (PostgREST 504 `PGRST003`), toda a
sessão é trabalho local (Flutter, testes, goldens, pgTAP em espelho). Nenhuma escrita em produção; nenhum
estado por `action_id` alterado (nenhum delta aplicado).

## Reivindicações

- Fatia 1 (goldens do cabeçalho global) — entregue.
- Fatia 2 (`owner.r12-01`, cards de Modelos de rotina) — entregue.
- Fatia 3 (`owner.r12-02`, Arquivar modelos de Atividade/Rotina) — entregue (local). Nenhuma tela reivindicada agora.

## Fatias entregues

| SHA | Fatia | action_ids → estados | Owner items | Evidência |
|---|---|---|---|---|
| `cb7a2418e` | Goldens — deriva do cabeçalho global (ADR 0041 C1): causa observada (`3945394f3` trocou `OC`/"Owner Coelo" estáticos por `headerProfile` da sessão; sem host os goldens renderizavam o placeholder `–`/`Conta`, deslocando sino e Bug); estabilização por `SuperadminHeaderProfileScope` + `SuperadminHeaderProfile.preview()` + `test/support/golden_header_profile.dart`; 30 referências regravadas nas três famílias; suítes 30/30 verdes; shell 72/72. | nenhum (golden não promove) | `owner.r12-10` → `partial / FE local-green …`; `owner.r12-11` já done (só citado) | `r14-sessao-9/goldens-cabecalho-global-20260916.md` (+ `capturas/`, `goldens-outras-suites-preexistentes-20260916.tsv`) |
| `d40eeaa75` | `owner.r12-01` — cards de Modelos de rotina (ADR 0041 C3): `CoeloAdminCardGrid` público em coelo_ui_admin (grade de altura uniforme extraída do composto), "Efetivo: —", Arquivar em todos/Restaurar no arquivado (callbacks `onArchive`/`onRestore`); widget test 4/4, pasta 119/119, goldens do diretório regravados. | nenhum | `owner.r12-01` → `partial / FE local-green …` | `r14-sessao-9/daily-routine-cards-r12-01-20260916.md` |
| `dd72abb88` | `owner.r12-02` — B1 Arquivar/Restaurar modelos de Atividade e Rotina: `specs/054-archive-activity-routine-models.md`; migration `20260916193000_archive_models_v1.sql` + pgTAP `archive_models_v1_test.sql` 63/63 no espelho `coelo_mirror_r14_visual` (**não aplicada em produção**); FE nos dois diretórios (aba/filtro Arquivados, Arquivar/Restaurar com confirmação e recarga, `PT409`/`55000`/`P0002` mapeados); testes de repositório e widget verdes. | nenhum | `owner.r12-02` → `partial / FE local-green + BE local-green (espelho)` | `r14-sessao-9/archive-models-b1-20260916.md` |

## Avisos para as outras sessões e para a coordenadora

1. `SuperadminShell` agora resolve o perfil do cabeçalho em três níveis: parâmetro → host persistente →
   `SuperadminHeaderProfileScope` → placeholder. Produção não muda. Goldens/páginas montadas sem host podem
   envolver a árvore com `withGoldenHeaderProfile` (`apps/superadmin/test/support/golden_header_profile.dart`).
2. 391 goldens em outras 34 suítes do superadmin **já falhavam** antes desta fatia (assinatura do cabeçalho em
   249 deles — 194/3.058/3.068 px — e causas já triadas nos demais). Não regravados: a C1 cobre nominalmente
   Segurança/Perfis/Rotina. Lista completa no TSV da evidência.
3. `entrega-atual.json` e `R12-owner-items.json` mudaram apenas por `sync-r12-owner-records.cjs` (projeção).
4. `CoeloAdminCardGrid` (coelo_ui_admin) é a grade de altura uniforme do composto, agora pública; diretórios que
   ainda montam a própria toolbar podem consumi-la em vez de `Wrap`. O composto delega a ela (158/158).
5. **Coordenadora — aplicação em produção (rito):** `packages/coelo_database/migrations/20260916193000_archive_models_v1.sql`
   (copiada também no espelho CLI da worktree, ignorado pelo Git). Muda `app_private.superadmin_routine_directory`
   (sem `p_status`, arquivados saem da lista padrão de modelos e rotinas aplicadas) e adiciona coluna
   `activity_templates.management_version`, 2 tabelas privadas e 5 RPCs novas. pgTAP 63/63 no espelho. Depois de
   aplicar: provar na rota real Atividades › Modelos (aba Arquivados, Arquivar/Restaurar, reload, negativa
   cross-tenant por `P0002`) e Rotina › Modelos (filtro Arquivados, Arquivar/Restaurar, reload) e só então delta.
6. `CoeloAdminDirectoryStatusTab` ganhou `archived('Arquivados')` **fora** da lista padrão (`defaults`); só o
   diretório de modelos de Atividade passa `withArchived`. `RoutineRepositoryFailureKind` ganhou `invalidState`.
7. Pré-existente em `dev`, não corrigido (fora do recorte): `activity_routes_test` "production detail exposes Editar
   atividade" falha porque o botão virou `FilledButton` em `c58ab61ca` e o teste espera `OutlinedButton`.

## Sobra para a R15 (sugestão)

- Aplicar `withGoldenHeaderProfile` às demais suítes administrativas e regravar as que ficarem só com a
  assinatura do cabeçalho, com autorização explícita do Owner (estende a C1). Inclui `activity_golden_test`, cujo
  `activity_directory_models_light_1440` agora também carrega a aba Arquivados desta fatia.
- Restaurar de rotinas aplicadas (`application`) e o alinhamento de `save_application` a `PT409` (OQ-047): spec de
  ciclo de vida da R15 (OQ-033).
- Atualizar o teste `activity_routes_test` ("Editar atividade") para o `FilledButton` de `c58ab61ca`.

## Bloqueios

- ambiente: rota real indisponível (PostgREST 504 `PGRST003`) — nenhuma prova FE/E2E na rota real nesta sessão.
- rito/permissão: aplicação de `20260916193000_archive_models_v1` em produção fica para a coordenadora (a fatia não
  autorizava escrita em produção); gate: E2E de `owner.r12-02` nos dois diretórios.
- ambiente (espelho): testes pgTAP pré-existentes das duas famílias falham na fixture antiga (FK `follow_links` da
  pessoa técnica; ACL do espelho) antes de qualquer função desta fatia — não regressão.

## Contadores

`validate-trackers.cjs`: PASS — FE 189/232, BE 171/219, E2E 162/186 (ativo), Owner 21/53 (inalterados).
