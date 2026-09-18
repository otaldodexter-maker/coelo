---
title: "Assiduidade › Histórico de chamadas e snapshot da rotina na chamada"
source: "decisions/0041-owner-decisions-r14-mesa-20260916.md (B2, B3); docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md (owner.r12-04, owner.r12-06); specs/020-superadmin-attendance-prototype.md; specs/021-superadmin-daily-routine-prototype.md; packages/coelo_database/migrations/20260911220100_attendance_superadmin_contract_v1.sql; docs/open-questions.md (OQ-047)"
status: "approved-contract; implementação local R14 Sessão 10"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-18"
audience: "team"
---

# Assiduidade › Histórico de chamadas e snapshot da rotina (ADR 0041 B2/B3)

Spec curta de contrato. Ela não certifica implementação: os estados por
`action_id` e os Owner items só mudam com evidência (FE/BE/E2E separados).

## 1. Objetivo

- **B2 (`owner.r12-04`)**: uma tela própria **Acompanhamento › Assiduidade ›
  Histórico** lista as chamadas lançadas no escopo do ator, com filtros
  simples, e abre o detalhe já existente. "Lançamentos" deixa de ser uma aba
  do diretório de Rotina diária.
- **B3 (`owner.r12-06`)**: a chamada aberta segue a **rotina vigente** da
  turma/atividade; ao concluir, a chamada grava um **snapshot** (rotina +
  versão + nome). Histórico e detalhe mostram sempre o snapshot; reabrir para
  corrigir presença não o altera; chamadas concluídas antes do snapshot
  mostram a rotina vigente com a indicação "rotina atual (não registrada na
  época)".

## 2. Superfícies

| Rota | Tela | action_ids | Mudança |
|---|---|---|---|
| `/attendance/history` (nome `attendance-history`) | Assiduidade › Histórico | `attendance.dashboard` (leitura; nenhum action_id novo) | nova |
| `/attendance/calls/:callId` | Detalhe da chamada | `attendance.finish`, `attendance.correct` | mostra rotina (snapshot/atual) |
| `/daily-routine` | Rotina diária › Diretório | `daily-routine.list`, `daily-routine.publish` | abas só `Modelos` e `Rotinas`; "Lançar hoje" continua na aba Rotinas |

Menu: `Acompanhamento › Assiduidade` ganha o filho `Histórico` (sem
capability extra além da leitura já exigida pelo painel). O item
`attendance-history` aparece ao lado de `Nova chamada`.

## 3. Lançamentos de rotina (D7) — onde ficam

A aba "Lançamentos" do diretório de Rotina era a única superfície do comando
`daily-routine.publish` (D7: criar rascunho de hoje → publicar). O Owner
pediu que ela saia do diretório e que as chamadas lançadas fiquem no
Histórico. Para não perder o comando certificado:

- **Rotinas › "Lançar hoje"** cria o rascunho do dia (como hoje) e, em vez de
  trocar para a aba removida, leva para **Histórico › Lançamentos de rotina**.
- **Histórico** tem dois segmentos lineares (`pattern.directory-linear-tabs`):
  `Chamadas` (padrão) e `Lançamentos de rotina`. O segundo lista os
  lançamentos do escopo (data, rotina, situação, versão) e oferece
  **Publicar** apenas em rascunho — é o mesmo comando D7, não edição de
  chamada. Nenhuma outra ação de escrita existe na tela.
- "Sem edição nessa tela" (B2) vale para as chamadas: presença, conclusão,
  reabertura e correção continuam exclusivas do detalhe da chamada.

**Decidido em 18/09/2026** (Owner delegou a decisão à Sessão RESERVA da R16):
**Publicar lançamento fica no Histórico › Lançamentos de rotina**, como
implementado e provado na rota real — é a única superfície do comando
`daily-routine.publish` certificado, e devolvê-lo a Rotinas seria ajuste de
composição sem ganho para a operação. O segmento continua sendo a única ação
de escrita do Histórico; chamadas seguem editáveis só no detalhe (B2).

## 4. Backend

### 4.1 `superadmin_attendance_call_history_v1` (B2)

`public.superadmin_attendance_call_history_v1(p_institution_id uuid,
p_unit_id uuid, p_group_id uuid, p_activity_id uuid, p_start date,
p_end date, p_status text, p_cursor text, p_page_size integer) returns jsonb`,
wrapper `security definer` com `search_path=''`, `revoke all` de
`public/anon/authenticated/service_role` e `grant execute` só a
`authenticated`; lógica em `app_private.superadmin_attendance_call_history_v1`
sem grant a cliente. Segue o mesmo escopo do painel/diretório:
`app_private.attendance_dashboard_access()` (guardian e sem leitura → `42501`)
e `app_private.attendance_session_in_scope(access, session)` por linha.

- Filtros: instituição/unidade/turma/atividade (interseção com o escopo, nunca
  ampliação), período (`p_start..p_end`, padrão últimos 30 dias, máximo 366
  dias), `p_status in ('pending','completed')` (pending = draft/open/reopened;
  completed = closed/corrected). Cancelada nunca aparece.
- Paginação por cursor keyset `(session_date desc, created_at desc, id desc)`;
  `p_cursor` opaco (base64 de `session_date|created_at|id`), `p_page_size`
  1..100 (padrão 20). Resposta: `{items, next_cursor, has_more, page_size}`.
- Item (só agregados, nenhum dado de criança): `id, session_date,
  institution_id/name, unit_id/name, group_id/name, activity_id/name,
  context, responsible, status, expected, present, absent, late,
  early_departures, official_records, can_open, routine`
  (`routine` conforme 4.2; `null` até a migration B3).
- Entrada inválida → `22023`; sem sessão → `42501`.

### 4.2 Snapshot da rotina (B3)

Colunas novas em `public.attendance_sessions` (forward-only, nulas para o
legado): `routine_snapshot_application_id uuid` (FK `routine_applications`
`on delete set null`), `routine_snapshot_revision_no integer`,
`routine_snapshot_name text`, `routine_snapshot_at timestamptz`.

- `app_private.attendance_effective_routine(p_institution_id, p_unit_id,
  p_group_id, p_activity_id, p_date) returns jsonb`: a aplicação de rotina
  `active` mais específica que cobre o contexto na data (atividade > turma >
  unidade > instituição; `valid_from/valid_until` nulos = sem limite), com
  `application_id`, `revision_no` (última `routine_application_revisions`,
  0 se nenhuma), `name` (nome do modelo de origem; sem modelo, rótulo do
  escopo) e `scope_kind`. `null` quando não há rotina vigente.
- `superadmin_attendance_complete_call` (mesma assinatura): na **primeira**
  conclusão (`routine_snapshot_at is null`) grava o snapshot da rotina vigente
  na data da chamada e `routine_snapshot_at = now()` mesmo sem rotina (para
  distinguir "concluída sem rotina" de legado). Conclusões após reabertura
  **não** tocam o snapshot. Reabrir e corrigir também não.
- `app_private.attendance_call_payload` (detalhe e todos os comandos) passa a
  expor, além das chaves atuais:
  - `routine_snapshot`: `{application_id, revision_no, name, recorded_at}` ou
    `null`;
  - `routine_current`: resultado de `attendance_effective_routine` na data da
    chamada ou `null`;
  - `routine_source`: `snapshot` (concluída com snapshot), `none` (concluída
    sem rotina vigente na época), `current` (aberta/reaberta ou legado sem
    `routine_snapshot_at`).
- Histórico: `routine = {source, application_id, revision_no, name,
  recorded_at}` com a mesma regra (`snapshot` → snapshot; senão rotina
  vigente com `source='current'`; `none` quando não há nada).
- Versão defasada: a família de Assiduidade passa a sinalizar conflito com
  SQLSTATE `PT409` (HTTP 409, sem retentativa pelo PostgREST), substituindo o
  `40001` de `app_private.attendance_require_call` e de
  `superadmin_attendance_undo_bulk` (OQ-047, lote por família). O repositório
  Flutter mapeia `PT409` e mantém `40001` por compatibilidade.

## 5. Front-end

- Histórico: família administrativa, baseline **Instituições** via
  `CoeloAdminDirectory` (toolbar com filtros `Instituição`, `Unidade`,
  `Turma`, `Período`; segmento linear `Chamadas | Lançamentos de rotina`;
  tabela `CoeloAdminResizableTable` com Data, Turma/atividade, Quem lançou,
  Presentes, Ausentes, Rotina, Situação, Ações; paginação por cursor no
  rodapé — sem seletor de itens por página). Sem toggle de cards e sem Criar
  (tela de consulta). Estados: carregando, vazio, sem resultados, erro com
  tentar novamente, não autorizado.
- Clicar na linha/ação abre `/attendance/calls/:id` (detalhe existente).
- Detalhe da chamada: bloco "Rotina diária" no cabeçalho de contexto com o
  nome + versão e a origem: "registrada na conclusão", "rotina atual (não
  registrada na época)" ou "sem rotina vinculada".
- Opções de filtro vêm de `superadmin_attendance_context_options` (já
  existente, mesma cascata da Nova chamada).
- Rotina diária: abas `Modelos` e `Rotinas`; "Lançar hoje" → cria e navega
  para o Histórico › Lançamentos de rotina.

## 6. Fora de escopo

Edição de presença no Histórico; exportação (ADR 0031/0034); notificações;
alteração das RPCs de dashboard; retroalimentar snapshot em chamadas legadas;
qualquer aplicação em produção nesta sessão (incidente PostgREST 504; migrations
ficam versionadas e pendentes de aplicação pelo rito).

## 7. Testes exigidos

- pgTAP (espelho): grants/ACL do wrapper; escopo por instituição/unidade/
  atribuições; filtros; cursor; negativa cross-tenant (ator da instituição B
  não vê chamadas de A e não amplia escopo por filtro); guardian → 42501;
  snapshot gravado na primeira conclusão; reabrir + concluir preserva;
  legado sem `routine_snapshot_at` → `routine_source='current'`; conflito de
  versão → `PT409`.
- Flutter: testes de widget da tela (estados, filtros, abrir detalhe,
  paginação por cursor, segmento de lançamentos com Publicar só em rascunho),
  decodificação do repositório (histórico e `routine_*` no detalhe, `PT409`),
  diretório de Rotina sem a aba e com "Lançar hoje" redirecionando, rota nova
  no router e no menu.

## 8. Aceite

FE `local-green` e BE `local-green` (espelho) nesta sessão; `verified`/`done`
e `verified-e2e` exigem rota real autenticada em produção após a aplicação
das migrations e o fim do incidente 504 — ver `R14-handoff-sessao-10.md`.
