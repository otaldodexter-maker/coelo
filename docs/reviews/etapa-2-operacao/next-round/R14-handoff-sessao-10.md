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
  `owner.r12-06` (fatia 2).
- Rotina diária › Diretório: só a remoção da aba Lançamentos (`daily-routine.list`); as demais
  mudanças do diretório (cards, Arquivar — C3/B1) são da Sessão 9.

## Fatias entregues

| SHA | Fatia | action_ids → estados | Owner items | Evidência |
|---|---|---|---|---|
| `1cdab7d5c` | B2 — Histórico de chamadas + retirada de Lançamentos do diretório de Rotina | nenhum estado alterado (`attendance.dashboard`, `daily-routine.list`, `daily-routine.publish` seguem como no corte) | `owner.r12-04` → `partial` / FE local-green / BE local-green / E2E pendente | `r14-sessao-10/attendance-history-20260916.md`; spec 052 |
| (fatia 2) | B3 — snapshot da rotina na chamada (híbrido) + PT409 na família Assiduidade | nenhum estado alterado (`attendance.finish`/`attendance.create` seguem verified-e2e; contrato ampliado, não provado em produção) | `owner.r12-06` → `partial` / FE local-green / BE local-green / E2E pendente | `r14-sessao-10/attendance-routine-snapshot-20260916.md`; spec 052 §4.2/§5 |

Artefatos da fatia 1: `specs/052-superadmin-attendance-history-and-routine-snapshot.md`;
`packages/coelo_database/migrations/20260916180000_attendance_call_history_v1.sql` (copiada
para o espelho CLI, ignorado pelo Git); pgTAP
`packages/coelo_database/supabase/tests/attendance_call_history_v1_test.sql` (44/44 no espelho);
FE `attendance_history_page.dart`, `attendance_history_controller.dart`, domínio/repositório de
Assiduidade, rota `attendance-history`, folha de menu "Histórico"; testes novos e ajustados
(280 verdes; 10 goldens pré-existentes, C1, não regravados).

Artefatos da fatia 2: `packages/coelo_database/migrations/20260916183000_attendance_routine_snapshot_v1.sql`
(copiada para o espelho CLI); pgTAP `attendance_routine_snapshot_v1_test.sql` (43/43) e
`attendance_superadmin_contract_v1_test.sql` (3 asserções `40001` → `PT409`); FE
`AttendanceRoutineRef.sourceLabel(concluded:)`/`isLegacyFor`, bloco "Rotina diária" no detalhe da
chamada, seeds do fake com rotina, `attendance_call_routine_test.dart` 4/4 (284 verdes no total).

## Avisos para as outras sessões e para a coordenadora

1. **Duas migrations novas, não aplicadas** (ordem por carimbo, depois de `20260916154500` D3):
   `20260916180000_attendance_call_history_v1` (leitura pura) e
   `20260916183000_attendance_routine_snapshot_v1` (colunas de snapshot em `attendance_sessions`,
   `complete_call`/`call_payload`/`require_call`/`undo_bulk`/histórico substituídos; **40001 →
   PT409** na família Assiduidade — a mesma correção da Sessão 8 para child_safety; o FE já mapeia
   os dois códigos). Sem elas, `/attendance/history` responde "Histórico indisponível" e o detalhe
   mostra "Sem rotina vinculada" (chaves ausentes → `none`, sem inventar origem).
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

- Prova E2E de `owner.r12-06`: concluir uma chamada real após as migrations, reler o detalhe
  (`routine_source='snapshot'`), reabrir/corrigir/concluir e confirmar snapshot inalterado; chamada
  antiga (ex. `0757355f`) deve mostrar "rotina atual (não registrada na época)"; negativa de versão
  defasada → 409 `PT409` (só depois do fim do incidente).
- B8 (`owner.r12-33`, sino de Medicação) **não iniciado** nesta sessão (parada por ordem das fatias
  e cota de tempo; nenhum leitor de sino in-app existente foi investigado).
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
| E2E `owner.r12-06` | ambiente (incidente) + rito de produção não executado | idem; negativa PT409 por PostgREST só após OQ-047/reinício da API |
| B8 `owner.r12-33` | sessão (cota/ordem) | não iniciado; linha não alterada |
| Goldens de Assiduidade/Rotina | decisão (C1: regravar só após estabilizar o cabeçalho) | 10 falhas idênticas na base `e6b8d6f63` |

## Contadores

`node docs/reviews/validate-trackers.cjs` → PASS `{"actions":232,"families":39,"frontendCompleted":189,
"backendCompleted":171,"e2eCompleted":162,"activeE2E":186}` — inalterados (FE 189/232, BE 171/219,
E2E 162/186, Owner 21/53). `sync-r12-owner-records.cjs`: 53 linhas projetadas.
