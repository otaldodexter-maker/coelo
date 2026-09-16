---
source: "Sessão 10 da R14 (Opus 5, frontend+backend, trabalho local), 16/09/2026; ADR 0041 B3; owner.r12-06; OQ-047; specs/052-superadmin-attendance-history-and-routine-snapshot.md §4.2/§5"
status: evidence
lifecycle: current
generated_at: 2026-09-16
---

# Assiduidade › snapshot da rotina na chamada (`owner.r12-06`, ADR 0041 B3) — fatia 2, local (16/09/2026)

Ambiente: **nenhuma escrita em produção**, nenhuma rota real (incidente PostgREST 504). Espelho
próprio `coelo_mirror_r14_historico` (dump de schema de 16/09, SHA-256 `f1f677ca…`), já com
`20260916180000_attendance_call_history_v1` aplicada (fatia 1).

## Recorte

- `attendance.finish` (`superadmin_attendance_complete_call`), `attendance.create`/detalhe
  (`superadmin_attendance_call_detail` via `attendance_call_payload`), Histórico (fatia 1) e a
  família de comandos de Assiduidade (versão defasada → `PT409`, OQ-047).
- Contrato: spec 052 §4.2 (backend) e §5 (detalhe/histórico).

## Backend (espelho) — `20260916183000_attendance_routine_snapshot_v1.sql`

- Colunas em `attendance_sessions`: `routine_snapshot_application_id` (FK `routine_applications`
  `on delete set null`), `routine_snapshot_revision_no`, `routine_snapshot_name`,
  `routine_snapshot_at` + check (colunas de conteúdo só com `routine_snapshot_at`).
- `app_private.attendance_effective_routine(uuid,uuid,uuid,uuid,date)`: aplicação `active` mais
  específica (atividade > turma > unidade > instituição) válida na data; `revision_no` = última
  revisão; `name` = modelo de origem (ou rótulo do escopo). Sem grant a cliente.
- `superadmin_attendance_complete_call`: na **primeira** conclusão grava o snapshot (inclusive
  "sem rotina", com `routine_snapshot_at`); conclusões após reabertura não tocam o snapshot; a
  auditoria leva `scope_id` (rotina aplicada) e `management_version` (revisão) — chaves da
  allowlist de `audit_mask_payload`.
- `attendance_call_payload`: corpo de produção + `routine_snapshot`, `routine_current`,
  `routine_source` (`snapshot | current | none`).
- `superadmin_attendance_call_history_v1`: `routine` = snapshot, senão vigente (`source`).
- `attendance_require_call` e `superadmin_attendance_undo_bulk`: `40001` → **`PT409`** (lote da
  família Assiduidade, OQ-047; nenhuma função da família levanta `40001`).
- Aplicada **2×** no espelho (idempotente).
- pgTAP `attendance_routine_snapshot_v1_test.sql`: **43/43** — esquema/grants/SECURITY DEFINER;
  vigente: turma vence instituição, revisão = última, nome do modelo, turma sem rotina herda a da
  instituição, instituição sem rotina → `null`; fluxo pelas RPCs públicas como `authenticated`:
  criar (aberta → `current`, revisão 2, sem snapshot) → marcar → concluir (`snapshot` app 602
  rev 2 "Rotina Bercario", `recorded_at`, auditoria); nova revisão 3 não altera o snapshot
  (`routine_current` = 3); reabrir + corrigir + concluir preserva revisão e `recorded_at`; legado
  concluído sem snapshot → `current` rev 3; chamada sem rotina concluída → `none` com
  `routine_snapshot_at` (distinto do legado); histórico projeta `snapshot`/`current`/`none`;
  versão defasada → `PT409`.
- Suítes anteriores: `attendance_call_history_v1_test.sql` continua **44/44**;
  `attendance_superadmin_contract_v1_test.sql` atualizada (3 asserções `40001` → `PT409`).
- **Não aplicada em produção**; pendente do rito, após `20260916180000`.

## Front-end (local)

- `AttendanceRoutineRef.sourceLabel(concluded:)`: "registrada na conclusão" (snapshot),
  "rotina vigente" (aberta) ou "rotina atual (não registrada na época)" (concluída/reaberta sem
  snapshot — legado); `isLegacyFor(status)`.
- Detalhe da chamada (`AttendanceCallPage`): bloco "Rotina diária" no cartão de contexto (wide e
  compacto), `Key('attendance-call-routine')`, com nome · vN e o qualificador (legado em destaque).
- Histórico: coluna Rotina mostra o qualificador só no legado.
- Repositório: `PT409` → `AttendanceVersionConflictException` (mantém `40001`).

### Testes

- `flutter analyze --no-fatal-infos`: sem novos avisos.
- Suítes afetadas (`test/features/attendance`, `test/features/daily_routine`, rotas/menu):
  **284 PASS, 10 FAIL — os mesmos 10 goldens pré-existentes** (C1; os goldens do detalhe da
  chamada passam a conter o bloco de rotina e continuarão a exigir regravação depois do cabeçalho).
- Novos: `attendance_call_routine_test.dart` 4/4 (snapshot, aberta, sem rotina, legado);
  `attendance_history_data_test.dart` (decodificação `routine_*`, `PT409`) 5/5;
  `attendance_history_page_test.dart` 7/7 (legado com indicação; aberta sem qualificador).

## Separação FE / BE / E2E

- FE: **local-green**. BE: **local-green** (espelho; não aplicada em produção).
- E2E: **pendente** — concluir uma chamada real após a migration, reler o detalhe
  (`routine_source='snapshot'`), reabrir/concluir e confirmar que o snapshot não muda; negativa de
  versão defasada por PostgREST deve responder **409 `PT409`** (não provar antes do fim do
  incidente: OQ-047).
- Nenhum `action_id` mudou de estado; nenhum delta JSON aplicado.
