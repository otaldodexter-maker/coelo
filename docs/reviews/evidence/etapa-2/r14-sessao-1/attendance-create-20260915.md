---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md; owner.r12-05/06/08"
status: evidence
generated_at: 2026-09-15
---

# Assiduidade › Nova chamada (`attendance.create`; owner.r12-05, r12-06, r12-08) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `dd2c945f3`,
127.0.0.1:3014, CDP 9414, sessão `qa-r06-publicacoes`, Owner). Contexto: QA R04 Cuidado (sintetico) ›
Unidade QA R04 › Turma QA R04 Estrutura (editada) (`368a5cea`, 1 aluno). Negativas por
`scratchpad/rpc-chain.mjs` (mesma base do `r13-rpc-proof.mjs`, encadeando a reserva de chave).
Capturas em `capturas/attendance-create-*.png`.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| attendance.create | `/attendance/new?institution=d0c40000…0001`: etapa Contexto com Data (hoje), cascata Instituição → Unidade → Turma → Contexto "Turma" pré-resolvida, resumo "Participantes esperados: definidos pelo contexto autorizado" (captura 01) → "Lançar chamada" → etapa Chamada em `/attendance/calls/cd60f2d8…` com "Crianca QA R04" (02). "Presente" + Salvar (03) → "Concluir chamada" → "Resumo da chamada" com "Corrigir chamada" (05). | `attendance_reserve_idempotency_key` + `superadmin_attendance_create_call` → chamada `cd60f2d8-8bc0-4bc1-a5c1-baf0efdca906` (open, v1); `superadmin_attendance_set_participant` → `present` (v2); `superadmin_attendance_complete_call` → `closed` (v3); relidos por `superadmin_attendance_call_detail`/`_directory`. | Carga completa de `/attendance/calls/cd60f2d8…` relê "Presente · 1 marcados · 0 sem marcação" (04). | `superadmin_attendance_create_call` com `p_institution_id` alheia (`…0099`) e chave reservada → `403 42501 attendance call context outside scope`; `call_detail` de id inexistente → `null` (não enumerável). |

## Achados fora do action_id (para a Sessão 2 / R15)

- **Contexto "Atividade" não exercitável com a massa atual (owner.r12-05):** `superadmin_attendance_context_options`
  (`p_date 2026-09-15`, sessões `qa-r06-publicacoes` e `qa-r06-estrutura`) devolve a única atividade
  elegível ("Atividade R05 Estrutura (editada)", `95b98978`, `attendance_required=true`) com
  `institution_id 190dd028`, `unit_id f5284f2f`, `group_id 4214106c`, mas `institutions`/`units`/`groups`
  não contêm esse escopo (só QA R04 Cuidado e QA R04 Instituicao Sintetica). A cascata do cliente filtra a
  atividade pela turma e a opção "Atividade" nunca aparece. É inconsistência de escopo na RPC (SQL) ou de
  massa; não foi alterado nada no cliente.
- **Rotina vinculada não observável (owner.r12-06):** `superadmin_attendance_call_detail` não tem campo de
  rotina/aplicação/versão; a rota de produção também não injeta rotina na `AttendanceCallPage`. A prova de
  "rotina efetiva/versionamento/snapshot no servidor" exige contrato (SQL) — fora do Bloco A.
- **Múltiplos alunos (owner.r12-08):** as duas turmas do escopo têm 1 aluno ou nenhum; exercitar "múltiplos
  alunos/turmas" exige massa (vínculo criança↔turma) que não foi criada nesta fatia.
- Cosmético: após o reload, os chips de "Sentimento" mostraram o glifo de fonte ausente (`▯`) até a fonte de
  emoji carregar (SwiftShader); antes do reload os emojis renderizaram. Sem `action_id` próprio.
- Método: `tap` do driver por `ByValueKey` trava nesta tela (documentado em review-scope); `clickxy` funcionou.
