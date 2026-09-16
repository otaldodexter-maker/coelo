---
source: "Sessão 10 da R14 (Opus 5, frontend+backend, trabalho local), 16/09/2026; ADR 0041 B2; owner.r12-04; specs/052-superadmin-attendance-history-and-routine-snapshot.md"
status: evidence
lifecycle: current
generated_at: 2026-09-16
---

# Assiduidade › Histórico de chamadas (`owner.r12-04`, ADR 0041 B2) — fatia 1, local (16/09/2026)

Ambiente: **nenhuma escrita em produção** (incidente PostgREST 504 `PGRST003` desde ~12:28 BRT;
rota real não executada). Espelho próprio `coelo_mirror_r14_historico` (Docker, portas 620xx),
restaurado do dump de schema de hoje `schema-producao-20260916-r14-coord-before.sql`
(SHA-256 `f1f677ca9964ef87282b4647e8aa26e52a8237a5e6c9b8f4f8d699a765157b51`), sem erros
de restauração; espelho só com schema (catálogos semeados pela própria suíte pgTAP).

## Recorte

- App `superadmin` › Acompanhamento › Assiduidade › **Histórico** (rota nova `/attendance/history`,
  leitura; action_id de referência `attendance.dashboard`, sem action_id novo).
- Rotina diária › Diretório (`daily-routine.list`): aba **Lançamentos removida**; "Lançar hoje"
  segue na aba Rotinas e leva ao Histórico › Lançamentos de rotina (`daily-routine.publish`
  continua alcançável, agora no Histórico).
- Contrato: `specs/052-superadmin-attendance-history-and-routine-snapshot.md` (§1–§5, §7).

## Backend (espelho) — `20260916180000_attendance_call_history_v1.sql`

- Par `app_private`/`public.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)`:
  escopo do painel (`attendance_dashboard_access` + `attendance_session_in_scope` por linha),
  filtros (instituição/unidade/turma/atividade/situação/período ≤ 366 dias), cursor keyset opaco,
  só agregados (esperados/presentes/ausentes/atrasos/saídas), `routine: null` até a fatia 2.
- Aplicada **2×** no espelho (idempotente): `APPLIED-1` / `APPLIED-2-idempotent`.
- pgTAP `packages/coelo_database/supabase/tests/attendance_call_history_v1_test.sql`:
  **44/44** — grants/ACL (authenticated só no wrapper; anon/service_role negados; SECURITY DEFINER
  com `search_path=''`), ordem por data/criação desc, chaves do item, ausência de dado de criança,
  contagens (3 esperados; 2 presentes = presente + atraso; 1 ausente; 1 atraso), filtros
  (turma 3, instituição B 1, concluídas 3, em andamento 2, hoje 3, 365 dias 6), cursor
  (2+2+1, `has_more`/`next_cursor`, união sem duplicatas), **negativa cross-tenant** (gestor da
  instituição B vê só B; filtro por A devolve 0 sem ampliar escopo), gestor de unidade vê só a
  unidade atribuída, sem permissão → `42501`, responsável familiar → `42501`, anon → `42501`,
  entradas inválidas → `22023` (page_size 0, status desconhecido, cursor malformado, período > 366).
- **Não aplicada em produção** (regra da sessão); pendente do rito
  (`db push --dry-run` → push só desta migration → `migration list` → lote em
  `ordem-de-aplicacao-producao.txt`).

## Front-end (local)

- Domínio: `AttendanceHistoryQuery/Item/PageResult`, `AttendanceRoutineRef` (origem
  `snapshot|current|none`, rótulo "nome · vN" e qualificador "rotina atual (não registrada na
  época)"), interface `AttendanceHistoryRepository`; `AttendanceCall.routine`.
- Repositório Supabase: `fetchHistory` → RPC `superadmin_attendance_call_history_v1`; decodifica
  `routine` do histórico e `routine_source/routine_snapshot/routine_current` do detalhe; mapeia
  `PT409` como conflito de versão (mantém `40001`).
- Tela `AttendanceHistoryPage` (`CoeloAdminDirectory` só tabela, baseline Instituições): filtros
  Instituição › Unidade › Turma › Atividade em cascata (opções de `superadmin_attendance_context_options`),
  Situação, Período; tabela Data, Turma/atividade, Unidade, Quem lançou, Presentes, Ausentes,
  Esperados, Rotina, Situação, Ações (abre `/attendance/calls/:id`); paginação por cursor no rodapé
  (páginas conhecidas não voltam ao servidor); estados carregando/vazio/sem resultados/erro
  (tentar novamente)/indisponível/não autorizado; segmento "Lançamentos de rotina" (lista + Publicar
  só em rascunho, confirmação, recarga após publicar) quando há repositório de rotina.
- Rota `/attendance/history` (`attendance-history`), folha de menu "Histórico" sob Assiduidade
  (sem capability de criação), `_destinationForLocation`/shells de produção e dev.
- Rotina diária: abas `Modelos | Rotinas`; `onLaunchCreated` → Histórico `?segment=launches`.

### Testes (Windows, worktree `r14-assiduidade-historico`)

- `flutter analyze --no-fatal-infos`: sem novos avisos (2 `unused_import` pré-existentes em
  `access_profile_catalog_labels_test.dart`, Sessão 5).
- `flutter test test/features/attendance test/features/daily_routine test/app/router/attendance_routes_test.dart
  test/app/router/daily_routine_routes_test.dart test/app/router/shell_destination_round_trip_source_test.dart
  test/app/router/route_name_uniqueness_test.dart test/app/navigation test/app/router/superadmin_router_test.dart`:
  **280 PASS, 10 FAIL — as 10 falhas são goldens pré-existentes** (mesmas 10 na base `e6b8d6f63`,
  verificado em worktree descartável: `attendance_call_*`/`attendance_new_call_*` e
  `daily_routine_*`, deriva do cabeçalho global, ADR 0041 C1; referências **não** regravadas).
  A remoção da aba altera os 3 goldens do diretório de Rotina (3058 → 3416 px), que já falhavam.
- Novos: `attendance_history_page_test.dart` 7/7, `attendance_history_data_test.dart` 5/5,
  `attendance_routes_test.dart` +3 (rota lista/abre detalhe; indisponível sem fonte; folha do menu),
  `shell_destination_round_trip_source_test.dart` (folha ↔ caso ↔ destino) verde.
- Ajustados: `daily_routine_production_page_test.dart` (só Modelos/Rotinas),
  `daily_routine_create_everywhere_test.dart` (Lançar hoje → `onLaunchCreated`),
  `daily_routine_publish_launch_test.dart` (publicar agora no Histórico; 6/6),
  `superadmin_navigation_test.dart` (hierarquia com "Histórico").

## Separação FE / BE / E2E

- FE: **local-green** (widget, repositório, rota, menu). Sem rota real (incidente).
- BE: **local-green** (migration + pgTAP 44/44 no espelho). Não aplicada em produção.
- E2E: **pendente** — exige aplicação da migration, fim do 504, rota real autenticada
  (`qa-r06-operacoes`), reload e negativa cross-tenant por PostgREST.
- Nenhum `action_id` mudou de estado; nenhum delta JSON aplicado.

## Decisão registrada (spec 052 §3)

"Lançamentos" saiu do diretório de Rotina (B2). Como a aba era a única superfície do comando
certificado `daily-routine.publish` (D7), a lista e o Publicar de rascunho passaram para
Histórico › Lançamentos de rotina; "sem edição" vale para as chamadas. Se o Owner preferir o
segmento somente leitura, o Publicar volta para Rotinas (ajuste de composição).
