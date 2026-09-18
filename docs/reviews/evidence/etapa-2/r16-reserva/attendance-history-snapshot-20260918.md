---
source: "Sessão RESERVA da R16 (Opus 5, coelo-8d), 18/09/2026; R16-prompt-reserva-20260918.md (Bloco 1, D2); R16-levantamento-fechamento-mvp-20260918.md §2.1; ADR 0041 B2/B3; spec 052; migrations 20260916180000 e 20260916183000 (lote 74, em produção desde 16/09)"
status: evidence
lifecycle: current
generated_at: 2026-09-18
owner_items: "owner.r12-04, owner.r12-06"
---

# Assiduidade › Histórico e snapshot de rotina — prova na rota real (18/09/2026)

Ambiente: produção (`evvbomzejfijozbtgvpt`), build QA `apps/superadmin` da worktree `r16-reserva` (`dev` `83d5478bd`,
`flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local
--dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true`), servidor `127.0.0.1:3014`, Chrome CDP `9414`, perfil
`%TEMP%\coelo-r16-reserva-chrome`. Identidade da tela: `qa-r06-operacoes` (Owner, escopo `platform`); leituras de
backend por PostgREST com a sessão da mesma identidade (`packages/coelo_database/scripts/r13-rpc-proof.mjs`) e com
`qa-r15-responsavel` para a negativa. **Nenhum SQL em produção** — D2 é prova, não lote: as migrations
`20260916180000_attendance_call_history_v1` e `20260916183000_attendance_routine_snapshot_v1` estão em produção desde
o lote 74 (16/09 17:40 UTC, ledger 307–309). Capturas em `capturas/attendance-*.png`.

## 1. Massa usada (só tela + RPC com identidade QA; nada fictício novo além da rotina)

| Objeto | Id | Observação |
|---|---|---|
| Rotina aplicada nova (pela tela Rotina diária › Rotinas › Criar rotina › "Modelo R05 rota real (R06)") | `8b317b01-90f1-41e4-8522-46cd1838238f` | escopo `institution` (QA R04 Cuidado `d0c40000-…0001`), **status Ativa**, sem validade/horário, modelo v2. Necessária porque as duas rotinas existentes (`b0005226`, `3d9f0a32`) estão `draft` e `attendance_effective_routine` só considera `status='active'`. Editor permanece em `/daily-routine/new?applicationFrom=…` após "Salvar rotina" (sem feedback nem navegação; resíduo UX, anotado no handoff). |
| Chamada aberta de 17/09 (Turma QA R04 Estrutura (editada), 3 participantes) | `98f6796c-b0fc-4b74-b0e8-34814b5f73f2` | criada em 18/09 00:32 UTC por outra sessão (Operador interno aaddec14); usada para concluir/reabrir/concluir. |
| Chamada legada concluída em 15/09 (antes do lote 74) | `cd60f2d8-8bc0-4bc1-a5c1-baf0efdca906` | sem snapshot → "rotina atual (não registrada na época)". |

## 2. owner.r12-04 — Histórico (`/attendance/history`)

| Passo | Resultado | Captura |
|---|---|---|
| Abrir Acompanhamento › Assiduidade › Histórico | tabela Data / Turma-atividade / Unidade / Quem lançou / Presentes / Ausentes / Esperados…, filtros Instituição, Unidade, Turma, Situação, Período (19/08–18/09), abas Chamadas / Lançamentos de rotina, paginação; 8 chamadas do escopo | `attendance-01-historico.png` |
| Filtro Situação = Em andamento | 3 chamadas (`98f6796c`, `bcd47ba2`, `53006a48`), "Limpar filtros" aparece | `attendance-02-filtro-em-andamento.png` |
| Abrir a linha de 17/09 | navega para `/attendance/calls/98f6796c-…` (detalhe, "Lançar chamada", 3 participantes) | `attendance-03-detalhe-sem-rotina.png` |
| Filtro Situação = Concluídas, depois `reload` da página | 6 concluídas; a de 17/09 já com 2 presentes / 1 ausente / 3 esperados; reload volta ao Histórico com filtros padrão | `attendance-09-historico-concluidas.png`, `attendance-10-historico-reload.png` |
| Cursor (PostgREST `superadmin_attendance_call_history_v1`, `p_page_size=3`) | página 1 `98f6796c, bcd47ba2, cd60f2d8` `has_more=true`, `next_cursor` opaco (base64); página 2 com o cursor: `53006a48, 2b4fa3d6, 0757355f`, `has_more=true` | — |
| Projeção da rotina por linha | concluída em 18/09 → `routine.source = snapshot` (`recorded_at 2026-09-18T14:07:30Z`, application `8b317b01`, revision 2); aberta e legadas → `routine.source = current` | — |
| Negativa: `qa-r15-responsavel` (só responsável, OQ-048) | `superadmin_attendance_call_history_v1` → **403 `42501` "attendance.read required"**; `superadmin_attendance_call_detail(98f6796c)` → `null` (sem vazamento) | — |
| Negativa: instituição fora do escopo / inexistente (`p_institution_id = 9f040000-…0010`, `00000000-…0999`) como `qa-r06-operacoes` | `200 []` — o leitor filtra linha a linha por `attendance_session_in_scope`; a identidade tem escopo `platform`, então a negativa cross-tenant forte é a do responsável acima | — |
| Entrada inválida | `p_status = 'closed'` → **400 `22023` "invalid attendance status"** (aceita só `pending`/`completed`) | — |

**Decisão pendente do Owner (não tomada aqui):** onde fica "Publicar lançamento" (spec 052 §3: no Histórico ›
Lançamentos de rotina ou de volta em Rotinas). A aba "Lançamentos de rotina" existe no Histórico; nada foi alterado.

## 3. owner.r12-06 — snapshot de rotina na conclusão

| Passo | Resultado | Captura |
|---|---|---|
| Detalhe da chamada aberta antes da rotina ativa | "Rotina diária: Sem rotina vinculada" | `attendance-03-detalhe-sem-rotina.png` |
| Após ativar a rotina `8b317b01` pela tela | "Modelo R05 rota real (R06) · v2 — rotina vigente" (aberta = vigente) | `attendance-04-detalhe-rotina-vigente.png` |
| "Marcar todos restantes como presentes" → 3 marcados; Crianca 2 → Falta → Salvar | 2 presentes, 1 falta (Crianca QA R04, QA R15 Crianca 1 presentes; QA R15 Crianca 2 falta) | `attendance-05-tres-participantes-marcados.png` |
| "Concluir chamada" | rodapé passa a "Corrigir chamada"; `call_detail`: `status closed`, `version 4`, `routine_source snapshot`, `routine_snapshot {name "Modelo R05 rota real (R06)", revision_no 2, application_id 8b317b01, recorded_at 2026-09-18T14:07:30.009926Z}` | `attendance-06-concluida.png` |
| `reload` do detalhe | "Modelo R05 rota real (R06) · v2 — **registrada na conclusão**" | `attendance-07-reload-registrada-na-conclusao.png` |
| Reabrir (PostgREST `superadmin_attendance_reopen_call`, `p_expected_version 4`, motivo "R16 RESERVA prova snapshot preservado") → concluir de novo pela tela | 200 `reopened` v5 → tela "Concluir chamada" → `closed` **v6** com o **mesmo** `routine_snapshot.recorded_at 14:07:30.009926Z` (snapshot nasce na primeira conclusão e não é reescrito, ADR 0041 B3) | — |
| Legado (`cd60f2d8`, concluída 15/09, sem snapshot) | "Modelo R05 rota real (R06) · v2 — **rotina atual (não registrada na época)**" | `attendance-08-legado-rotina-atual.png` |
| Versão defasada: `superadmin_attendance_reopen_call(98f6796c, p_expected_version 1)` | **409 `PT409` "attendance call version conflict"**, sem mutação (detalhe segue v5/v6) | — |
| `superadmin_attendance_complete_call` direto por PostgREST com chave nova | 400 `22023` "attendance idempotency key not reserved" — a conclusão exige a chave reservada pela tela (contrato existente); por isso a reconclusão foi pela tela | — |

## 4. Resultado

- `owner.r12-04` → **done** (Histórico provado na rota real: lista, filtros, cursor, detalhe, reload, negativas; decisão
  de "Publicar lançamento" continua com o Owner).
- `owner.r12-06` → **done** (snapshot na primeira conclusão, preservado em reabrir/concluir, legado sinalizado, PT409).
- Nenhum `action_id` muda de estado (todos já `verified-e2e`); nenhum delta de inventário.
- Efeito na massa de produção: rotina `8b317b01` ativa (escopo instituição QA R04 Cuidado); chamada `98f6796c` concluída
  (v6, 2 presentes / 1 falta, snapshot). Prefixo QA preservado (a rotina herda o nome do modelo "Modelo R05 rota real
  (R06)", já sintético).
