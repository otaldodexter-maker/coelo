---
source: "Sessão B da R15 (Fable 5.1), 17/09/2026; ADR 0041 D3; R14 Sessão 1 (attendance-create-20260915.md); atividade QA R15 (atividade-qa-r15-criacao-20260917.md)"
status: evidence
lifecycle: current
generated_at: 2026-09-17
action_id: "attendance.create"
---

# Assiduidade › Nova chamada — contexto **Atividade** com atividade real (`owner.r12-05`), 17/09/2026

Ambiente: produção; build QA `r15/bloco-b` em `127.0.0.1:3015`, Chrome CDP 9435, sessão `qa-r06-operacoes@coelo.me`.
Corpos das RPCs capturados por CDP. Massa: atividade "QA R15 Atividade Assiduidade" `1bd6bc74-d0bd-4a9b-af89-7c51347d18c0`
(active, turma `368a5cea…` em modo `all`), criada pela tela nesta sessão.

| Passo | Resultado |
|---|---|
| `/attendance/new`: Instituição QA R04 Cuidado › Unidade QA R04 › Turma QA R04 Estrutura › **Contexto = Atividade** | campo "Atividade na turma" aparece com **"QA R15 Atividade Assiduidade"** (captura 01) — o contexto Atividade passou a ser exercitável (na R14 a única atividade elegível tinha escopo inconsistente) |
| **Lançar chamada** | `attendance_reserve_idempotency_key` (`create_call`, escopo com `activity_id 1bd6bc74…`) → `superadmin_attendance_create_call(p_activity_id 1bd6bc74…, p_session_date 2026-09-17)` → **`{"id":"bcd47ba2-d660-471c-98a8-a4bec63c6462","status":"open","version":1,"activity_id":"1bd6bc74…","activity_name":"QA R15 Atividade Assiduidade","participants":[],"routine_source":"none"}`**; `superadmin_attendance_call_detail` relê o mesmo registro |
| Reload de `/attendance/calls/bcd47ba2…` | captura 02 (carga completa da rota) |
| Negativa do contexto Atividade | **não executada** (prazo do Owner, 16:20) |

## Achado

A chamada em contexto Atividade nasce com **`participants: []`** embora a turma tenha 3 crianças ativas (QA R04 +
Criança 1 e 2 da massa QA R15) e a atividade esteja em modo "Toda a turma" (`participation_mode = all`, sem linhas em
`activity_group_participants`). Hipótese (não verificada): a RPC de criação deriva os participantes de
`activity_group_participants` e ignora o modo `all`. Isso também impede `owner.r12-08` (≥ 2 alunos) no contexto
Atividade; no contexto Turma a massa (3 crianças) já permite a prova — não exercitada por prazo.

## Separação FE / BE / E2E

`attendance.create` mantém FE verified / BE done / **verified-e2e** (contexto Turma, R14). `owner.r12-05` avança
(seleção + criação + reload do contexto Atividade provados em produção) mas **continua partial**: negativa não
executada e `participants []` a esclarecer (ADR 0041 D3).
