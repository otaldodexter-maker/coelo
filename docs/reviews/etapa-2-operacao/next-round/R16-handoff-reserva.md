---
title: "R16 — handoff da Sessão RESERVA (D2, D4, D5, D6, D7 do Owner em 18/09)"
source: "R16-prompt-reserva-20260918.md; R16-levantamento-fechamento-mvp-20260918.md §4; R16-pendencias.md; ADR 0041 (D6, E7), 0042, 0044; ordem-de-aplicacao-producao.txt"
status: "active"
lifecycle: "current"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
audience: "team"
---

# R16 — handoff da Sessão RESERVA

Sessão Claude `coelo-8d` (Opus 5), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r16-reserva`, branch
`r16/reserva-20260918` (base `dev` `83d5478bd`). Servidor QA `127.0.0.1:3014`, Chrome CDP `9414`, perfil
`%TEMP%\coelo-r16-reserva-chrome`; espelho `coelo_mirror_r16_reserva` (`Coelo-backups/mirror-r16-reserva`, portas 627xx)
restaurado do dump novo `Coelo-backups/schema-producao-20260918-r16-reserva-before.sql` (SHA-256
`9bb98a47de15de866c8cd59a4ee646134f67034bb4a3bac7fde1a1a6f02aa243`, 4.344.291 bytes, tirado 18/09 ~10:55 BRT; ACL fiel:
`anon` executa 0 funções em `public`, catálogo 136 permissões). Só esta sessão escreve aqui; a coordenadora integra por
cherry-pick. Sessões pares identificadas por `ListAgents` antes da worktree: `coelo-85` (coordenadora, `dev`, sem porta)
e `coelo-2b` (coordenadora da execução de 17/09, encerrada; sem worktree).

## Fato corrigido (primeira passagem)

As migrations `20260916180000`, `20260916183000` e `20260916190000` estão em produção desde o lote 74. As linhas de
`owner.r12-04`, `r12-06` e `r12-33` em `R16-pendencias.md` foram corrigidas (r12-04/06 → `done` com a prova; r12-33
com o texto "aplicada no lote 74" e o gate da v2).

## Fatias entregues

| Bloco | Commit (branch `r16/reserva-20260918`) | Conteúdo |
|---|---|---|
| 1 (D2) — r12-04 Histórico, r12-06 snapshot | `0612a70fe` | Prova na rota real 3014 com `qa-r06-operacoes`: evidência `docs/reviews/evidence/etapa-2/r16-reserva/attendance-history-snapshot-20260918.md` (+10 capturas). `owner.r12-04` e `owner.r12-06` → `done`; Owner 41/53. Sem SQL em produção. |
| 1 (D2) — r12-33 sino v2 (preparação) | `0612a70fe` | `packages/coelo_database/migrations/20260918120000_medication_in_app_notifications_v2.sql` (E7 = b + `recipients-bug` nos dois leitores de destinatários) + `supabase/tests/medication_in_app_notifications_v2_test.sql` **27/27**; v1 alinhada ao contrato novo **29/29**; `unit_care_policies_notifications_v1` 20/20; `health_care_and_medication_plans_v1` 28/30 (15 e 16 pré-existentes, idênticas antes/depois). Migration aplicada 2× no espelho sem erro (idempotente). **Aplicação em produção e prova do sino ficam para o lote 82** (rito ao fim dos blocos 1–4, item a). |

| 2 (D4) — r12-05 negativas; r12-08 fixture (preparação) | (este) | `owner.r12-05` → `done` (três negativas 403 42501 por PostgREST; evidência `attendance-activity-negatives-and-mass-20260918.md`). Fixture `20260918123000_qa_r15_attendance_group_fixture_v1` (função privada, 2 crianças "QA R15 Crianca 3/4" na Turma QA R06 Transferencia) + pgTAP **16/16**, aplicada 2× no espelho. Execução em produção e prova de r12-08 (correct + segunda turma) ficam para o lote 82 (item c). Owner 42/53. |

## Avisos para a coordenadora

1. **Massa de produção alterada só pela tela/RPC com identidade QA (sem SQL):** rotina aplicada `8b317b01-90f1-41e4-8522-46cd1838238f`
   (escopo instituição QA R04 Cuidado, **Ativa**, modelo "Modelo R05 rota real (R06)" v2) — necessária porque as duas
   rotinas existentes estão `draft` e o snapshot só considera `active`; chamada `98f6796c` de 17/09 concluída (v6, 2
   presentes / 1 falta, snapshot revisão 2). Nada fictício novo além da rotina.
2. **Massa ≥2 alunos já existe:** a Turma QA R04 Estrutura (editada) `368a5cea…` tem 3 crianças ativas (Crianca QA R04 +
   "QA R15 Crianca 1/2" da fixture AP-1, lote 80) e agora rotina vinculada. O Bloco 2 (D4) reavalia se a fixture (item c
   do lote 82) ainda é necessária — provavelmente só para "múltiplas turmas".
3. **Decisão do Owner pendente (não tomada):** "Publicar lançamento" no Histórico › Lançamentos de rotina ou de volta em
   Rotinas (spec 052 §3).
4. **Resíduos UX sem action_id (não corrigidos):** editor de Rotina aplicada permanece em `/daily-routine/new?applicationFrom=…`
   após "Salvar rotina", sem feedback (a rotina é criada; um segundo clique não duplicou); `superadmin_attendance_complete_call`
   por PostgREST sem a chave reservada pela tela → 22023 (contrato existente, não defeito).
5. **Ambiente:** `qa_drive.dart texts` trava em `get_diagnostics_tree` (conhecido); direção por `cdp_sem.dart clickxy`
   + captura; semântica Flutter não expõe nós no build QA. Cópia local de `cdp_sem.dart` ganhou um comando `wheel`
   (rolagem) — no scratchpad, não no repositório.
6. Os três arquivos não rastreados da coordenadora (`R16-prompt-reserva-20260918.md`, `R16-levantamento-…`,
   `MVP-definicao-…`) foram copiados para a worktree só para leitura e **não** entram nos meus commits.

## Bloqueios

- Nenhum até o fim do Bloco 1.

## Sobra / próximo

- Bloco 2 (D4), Bloco 3 (D5), Bloco 4 (D6), Bloco 5 (D7), lote 82 (a–d) e prova do sino (r12-33) e de close/reopen (r12-49).

## Contadores

`node docs/reviews/validate-trackers.cjs` **PASS** — FE 199/199, BE 186/186, E2E 186/186; Owner **42/53** (r12-04, r12-05, r12-06 `done`).
