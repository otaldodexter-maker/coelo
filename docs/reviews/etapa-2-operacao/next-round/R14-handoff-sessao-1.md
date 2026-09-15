---
title: "R14 — handoff da Sessão 1 (Blocos A e B)"
source: "R14-execucao-paralela.md; R14-pendencias.md; inventario-etapa-2.json"
status: "active"
lifecycle: "current"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
audience: "team"
---

# R14 — handoff da Sessão 1

Sessão 1 (Opus 5), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r14-ab`, branch
`r14/bloco-ab`, servidor `127.0.0.1:3014`, Chrome CDP `9414`. Base: `origin/dev 0c8add8a7`.
Só a Sessão 1 escreve aqui. Cada fatia provada vai para `dev` por rebase + push.

## Reivindicações

| Tela | action_ids | Desde |
|---|---|---|
| Shell › Troca de contexto | shell.switch-context | 2026-09-15 |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| 7782dc6a9 | circulars.attach FE verified, E2E verified-e2e (Circulares 11/11) | — | r14-sessao-1/circulars-attach-20260915.md |
| dd2c945f3 | agenda.request FE verified, E2E verified-e2e (Agenda 7/7); correção FE em supabase_agenda_repository.dart | owner.r12-42 done | r14-sessao-1/agenda-request-20260915.md |
| a3fd542b7 | attendance.create FE verified, E2E verified-e2e (Assiduidade 5/5) | r12-05, r12-06, r12-08 → partial com achados | r14-sessao-1/attendance-create-20260915.md |
| d09da7ead | daily-routine.apply FE verified, E2E verified-e2e (Rotina 5/5); correção FE em supabase_routine_repository.dart (HH:MM) | — | r14-sessao-1/daily-routine-apply-20260915.md |
| (próximo) | acontece.create FE verified, E2E verified-e2e (Acontece 4/4) | — | r14-sessao-1/acontece-create-20260915.md |

## Avisos para a outra sessão

- **SQL (Sessão 2):** `superadmin_attendance_context_options` devolve em `activities` a atividade `95b98978` (instituição `190dd028`, unidade `f5284f2f`, turma `4214106c`) sem que `institutions`/`units`/`groups` contenham esse escopo; a cascata do cliente nunca oferece "Contexto: Atividade". Detalhe em `r14-sessao-1/attendance-create-20260915.md`. Bloqueia o fechamento de owner.r12-05.
- **Contrato (R15):** `superadmin_attendance_call_detail` não expõe rotina vinculada/versão; owner.r12-06 precisa de contrato de leitura.
- Método novo para seletor de arquivo real: `r14-sessao-1/ferramentas/cdp_filechooser.dart` (Page.fileChooserOpened + DOM.setFileInputFiles); serve para Arquivos de Formulários › Upload e Chat › Anexar.

## Sobra para a R15

- Rotina: `superadmin_routine_application_detail` não expõe o número da versão do modelo; o rótulo "Modelo vinculado · versão N" mostra a revisão da aplicação após o reload (ver `daily-routine-apply-20260915.md`). Contrato antes de mexer no rótulo.
- owner.r12-05 (contexto Atividade), r12-06 (rotina vinculada na chamada — contrato), r12-08 (massa com ≥2 alunos) — ver avisos acima.

## Contadores

FE 169/231, BE 164/224, E2E 142/199, Owner 10/53 (após acontece.create).
