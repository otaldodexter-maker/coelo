---
title: "R14 — handoff da Sessão 10 (Assiduidade › Histórico e snapshot de rotina, FE+BE local)"
source: "Sessão 10 da R14 (Opus 5, frontend+backend), 16/09/2026; briefing comum da coordenadora; ADR 0041 B2/B3/B8; R14-pendencias.md; specs/052; docs/reviews/evidence/etapa-2/r14-sessao-10/"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — handoff da Sessão 10

Worktree `Coelo.worktrees\r14-assiduidade-historico`, branch `r14/assiduidade-historico`
(base `dev` `e6b8d6f63`). Trabalho **local**: nenhuma escrita em produção, nenhuma rota real
(incidente PostgREST 504 `PGRST003`), nenhum estado por `action_id` alterado. Espelho próprio
`coelo_mirror_r14_historico` (Docker, portas 620xx, `Coelo-backups/mirror-r14-historico`),
restaurado do dump de schema de 16/09 (SHA-256 `f1f677ca…`), sem erros.

## Reivindicações

- Acompanhamento › Assiduidade › Histórico (`/attendance/history`, nova) — `owner.r12-04`.
- Assiduidade › Chamada (detalhe) e `superadmin_attendance_complete_call`/`call_detail` —
  `owner.r12-06` (fatia 2, em curso).
- Rotina diária › Diretório: só a remoção da aba Lançamentos (`daily-routine.list`); as demais
  mudanças do diretório (cards, Arquivar — C3/B1) são da Sessão 9.

## Fatias entregues

| SHA | Fatia | action_ids → estados | Owner items | Evidência |
|---|---|---|---|---|
| (fatia 1) | B2 — Histórico de chamadas + retirada de Lançamentos do diretório de Rotina | nenhum estado alterado (`attendance.dashboard`, `daily-routine.list`, `daily-routine.publish` seguem como no corte) | `owner.r12-04` → `partial` / FE local-green / BE local-green / E2E pendente | `r14-sessao-10/attendance-history-20260916.md`; spec 052 |

Artefatos da fatia 1: `specs/052-superadmin-attendance-history-and-routine-snapshot.md`;
`packages/coelo_database/migrations/20260916180000_attendance_call_history_v1.sql` (copiada
para o espelho CLI, ignorado pelo Git); pgTAP
`packages/coelo_database/supabase/tests/attendance_call_history_v1_test.sql` (44/44 no espelho);
FE `attendance_history_page.dart`, `attendance_history_controller.dart`, domínio/repositório de
Assiduidade, rota `attendance-history`, folha de menu "Histórico"; testes novos e ajustados
(280 verdes; 10 goldens pré-existentes, C1, não regravados).

## Avisos para as outras sessões e para a coordenadora

1. **Migration nova, não aplicada**: `20260916180000_attendance_call_history_v1` (leitura pura;
   não altera tabelas nem funções existentes). Aplicar pelo rito depois do incidente e depois de
   `20260916154500` (D3) — ordem canônica por carimbo. Sem ela, `/attendance/history` responde
   "Histórico indisponível"/erro de RPC inexistente na produção.
2. **Lançamentos (D7)**: a aba saiu de `/daily-routine`; `daily-routine.publish` agora vive em
   `/attendance/history?segment=launches` (lista + Publicar em rascunho). Quem provar
   `daily-routine.publish` na rota real deve usar esse caminho. Sessão 9 (`r14/visual-arquivar`)
   toca o mesmo `daily_routine_pages.dart`: conflito provável nas abas `SuperadminUnderlineTabs`
   (removi só a terceira aba) e em `_createLaunch` (novo `onLaunchCreated`).
3. `RoutineDirectoryItem` ganhou `applicationId` (lançamentos); `AttendanceCall` ganhou `routine`
   (`AttendanceRoutineRef`); o repositório de Assiduidade mapeia `PT409` → conflito (OQ-047).
4. Goldens de Assiduidade/Rotina continuam falhando por deriva do cabeçalho (C1); a remoção da aba
   muda os 3 goldens do diretório de Rotina (já vermelhos). Não regravei.
5. Spec numerada **052** (051 era a maior em `dev` e em todas as `origin/r14/*` em 16/09 18:00 UTC).
   Se a Sessão 9 criou 052, renumerar a minha para 053 na integração (referências: spec 052 em
   `R14-pendencias.md` linha r12-04, evidência e handoff).

## Sobra para a R15 (sugestão)

- Prova E2E de `/attendance/history` (`qa-r06-operacoes`): rota normal, filtros, cursor, abrir
  detalhe, reload e negativa por PostgREST (`superadmin_attendance_call_history_v1` com
  `p_institution_id` alheio → 0 itens; identidade sem `attendance.read` → 403 `42501`).
- Decisão de composição: Publicar lançamento no Histórico (atual) ou de volta em Rotinas
  (spec 052 §3) — sem impacto de contrato.
- Busca textual no Histórico (a RPC não recebe `p_search`; o Owner pediu "filtragem simples").

## Bloqueios

| Gate | Causa classificada | Detalhe |
|---|---|---|
| E2E `owner.r12-04` | ambiente (incidente PostgREST 504) + rito de produção não executado nesta sessão | migration validada só no espelho; rota real não aberta |
| Goldens de Assiduidade/Rotina | decisão (C1: regravar só após estabilizar o cabeçalho) | 10 falhas idênticas na base `e6b8d6f63` |

## Contadores

`node docs/reviews/validate-trackers.cjs` → PASS `{"actions":232,"families":39,"frontendCompleted":189,
"backendCompleted":171,"e2eCompleted":162,"activeE2E":186}` — inalterados (FE 189/232, BE 171/219,
E2E 162/186, Owner 21/53). `sync-r12-owner-records.cjs`: 53 linhas projetadas.
