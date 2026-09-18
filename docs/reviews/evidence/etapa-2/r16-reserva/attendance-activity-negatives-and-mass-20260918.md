---
source: "Sessão RESERVA da R16 (Opus 5, coelo-8d), 18/09/2026; R16-prompt-reserva-20260918.md (Bloco 2, D4); ADR 0041 D3/D6; ADR 0044 (participants-vazio: atividade sem participantes é válida); r15-bloco-b/attendance-contexto-atividade-20260917.md"
status: evidence
lifecycle: current
generated_at: 2026-09-18
updated_at: 2026-09-18
owner_items: "owner.r12-05, owner.r12-08"
---

# Assiduidade › contexto Atividade (negativas) e massa ≥2 alunos (18/09/2026)

Ambiente: produção (`evvbomzejfijozbtgvpt`); PostgREST com a sessão de `qa-r06-operacoes` (script de prova no
scratchpad da sessão: reserva `attendance_reserve_idempotency_key` + `superadmin_attendance_create_call`, mesmo
contrato que a tela usa). Nenhum SQL em produção nesta parte. Nenhuma chamada foi criada (todas as tentativas negadas).

## 1. owner.r12-05 — negativas do contexto Atividade

| Caso | Payload | Resultado |
|---|---|---|
| Atividade inexistente | turma `368a5cea` (QA R04), `p_activity_id = 00000000-…0404` | **403 `42501` "attendance call activity outside scope"** |
| Atividade inelegível (existe, mas vinculada a outra turma) | turma `1a247741` (QA R06 Transferencia), atividade `1bd6bc74` (vinculada só à turma `368a5cea`) | **403 `42501` "attendance call activity outside scope"** |
| Instituição alheia declarada (`p_institution_id = 9f040000-…0010`) com turma e atividade reais | turma `368a5cea`, atividade `1bd6bc74` | **403 `42501` "attendance call context outside scope"** (instituição/unidade vêm da turma; payload discordante é negado antes da atividade) |

Histórico/diretório após as negativas: nenhuma chamada nova (a chave reservada não gerou sessão). O `participants []`
da chamada `bcd47ba2` em contexto Atividade (17/09) fica explicado pelo contrato: em contexto Atividade os esperados
derivam de `activity_group_participants` ativos (não da turma); a atividade "QA R15 Atividade Assiduidade" não tem
participantes explícitos → 0 esperados. A Mesa R16 (ADR 0044) já decidiu que atividade sem participantes é válida
(`participants-vazio` reprovado com nota). Caminho feliz do contexto Atividade já `verified` em 17/09 (R15 B).

**Resultado:** `owner.r12-05` → **done** (FE verified 17/09; BE done; E2E verified-e2e com negativas em produção).

## 2. owner.r12-08 — massa ≥2 alunos, múltiplas turmas, rotina vinculada

- **Turma QA R04 Estrutura (editada)** (`368a5cea`, Unidade QA R04): 3 crianças ativas (Crianca QA R04 + "QA R15
  Crianca 1/2", fixture AP-1 do lote 80) e rotina vinculada `8b317b01` (ativada em 18/09, ver
  `attendance-history-snapshot-20260918.md`). Provado em 18/09 na chamada `98f6796c`: "Marcar todos restantes como
  presentes" (3), Falta em uma criança e Salvar (`attendance.mark`), Concluir (`attendance.finish`), reabrir e concluir
  de novo; Histórico com 2 presentes / 1 ausente / 3 esperados.
- **Turma QA R06 Transferencia** (`1a247741`, Unidade QA R05 Transferencia): 0 alunos → a prova "múltiplas turmas"
  depende da fixture `20260918123000_qa_r15_attendance_group_fixture_v1` (função privada
  `app_private.seed_qa_r15_attendance_group_fixture_v1`, cria "QA R15 Crianca 3/4" com contexto, vínculo de unidade
  **ativo** e vínculo de turma; idempotente; fail-closed a `qa-r04-*`/turma "QA"/nomes "QA R15"), pgTAP
  `qa_r15_attendance_group_fixture_v1_test` **16/16** no espelho `mirror-r16-reserva`, aplicada 2× sem erro. Execução em
  produção = lote 82 item c (autorização nominal D4). A prova de `attendance.correct` (Corrigir chamada concluída) e da
  segunda turma é registrada na seção 3 após o lote.

## 3. Após o lote 82 (a preencher)

_(pendente)_
