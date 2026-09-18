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
| (nenhuma — Sessão 1 encerrada em 15/09 ~11:50 BRT; Blocos A e B fechados; Perfis de acesso liberado para a sessão do Bloco C) | — | — |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| 7782dc6a9 | circulars.attach FE verified, E2E verified-e2e (Circulares 11/11) | — | r14-sessao-1/circulars-attach-20260915.md |
| dd2c945f3 | agenda.request FE verified, E2E verified-e2e (Agenda 7/7); correção FE em supabase_agenda_repository.dart | owner.r12-42 done | r14-sessao-1/agenda-request-20260915.md |
| a3fd542b7 | attendance.create FE verified, E2E verified-e2e (Assiduidade 5/5) | r12-05, r12-06, r12-08 → partial com achados | r14-sessao-1/attendance-create-20260915.md |
| d09da7ead | daily-routine.apply FE verified, E2E verified-e2e (Rotina 5/5); correção FE em supabase_routine_repository.dart (HH:MM) | — | r14-sessao-1/daily-routine-apply-20260915.md |
| 821e18b11 | acontece.create FE verified, E2E verified-e2e (Acontece 4/4) | — | r14-sessao-1/acontece-create-20260915.md |
| 8b99d9a06 | shell.switch-context FE verified (flutter-only; Shell 5/5) | — | r14-sessao-1/shell-switch-context-20260915.md |
| d5f8bbe70 | activities.list + activities.publish FE verified, E2E verified-e2e (Atividades 7/7); correção FE em supabase_activity_command_repository.dart (publish chega ao servidor) | owner.r12-03 done | r14-sessao-1/activities-list-publish-20260915.md |
| 3f3579c54 | chat.create-group E2E verified-e2e | — | r14-sessao-1/chat-create-group-20260915.md |
| 95b9f81cb | units.error + units.access-denied FE verified, BE done, E2E verified-e2e (Unidades 10/10) | — | r14-sessao-1/units-error-access-denied-20260915.md |
| a1129b316 | Bloco B (1/2): `apply-tracker-delta.cjs` aceita `escopo` | — | script |
| 169bab03c | Bloco B (2/2): plans.assign, institutions.status, institutions.locations-map, catalog.list/validate/sync/publish → BE e E2E `deferred-post-mvp`, scope `deferred-post-mvp` (E2E ativo 199 → 192; FE 231/BE 224 iguais) | — | r14-sessao-1/deltas-bloco-b-reclassificacao-20260915.json; R14-execucao-paralela.md |
| 98b768526 | child-safety.child FE verified, E2E verified-e2e; child-safety.suspend E2E blocked-backend (504) | r12-12, r12-14 done; r12-15 partial | r14-sessao-1/child-safety-child-20260915.md |
| cad79dd35 | forms.upload + forms.resolve-file FE verified, E2E verified-e2e | — | r14-sessao-1/forms-upload-resolve-20260915.md |
| f041fc731 | invites.list + invites.resend FE verified, E2E verified-e2e (Convites 5/5) — **Bloco A 10/10 fechado** | owner.r12-44, r12-45 done | r14-sessao-1/invites-list-resend-20260915.md |

## Avisos para a outra sessão

- 15/09 ~11:30 BRT: Sessão 1 releu a R14 atualizada em `9d6636115` (current-state, source-of-truth, backlog, R14-pendencias, ADR 0039). Nada do meu escopo toca Planos comerciais, reader de Planos ou `auth.recover/reset`; `plans.assign` já foi diferido no Bloco B.
- **SQL (Sessão 2):** `superadmin_attendance_context_options` devolve em `activities` a atividade `95b98978` (instituição `190dd028`, unidade `f5284f2f`, turma `4214106c`) sem que `institutions`/`units`/`groups` contenham esse escopo; a cascata do cliente nunca oferece "Contexto: Atividade". Detalhe em `r14-sessao-1/attendance-create-20260915.md`. Bloqueia o fechamento de owner.r12-05.
- **SQL (Sessão 2) — bloqueio:** `child_safety_change_lifecycle` responde 504 (timeout) em produção com versão errada (2 tentativas); `child-safety.suspend` e a reprova de `edit` dependem do diagnóstico no espelho. Ver `r14-sessao-1/child-safety-child-20260915.md`. Segurança infantil devolvida ao Bloco C (edit/suspend/create + r12-13/15/16).
- **Contrato (R15):** `superadmin_attendance_call_detail` não expõe rotina vinculada/versão; owner.r12-06 precisa de contrato de leitura.
- Método novo para seletor de arquivo real: `r14-sessao-1/ferramentas/cdp_filechooser.dart` (Page.fileChooserOpened + DOM.setFileInputFiles); serve para Arquivos de Formulários › Upload e Chat › Anexar.

## Sobra para a R15

- Perfis de acesso (access-profiles.create/edit/assign, r12-20 a 27): mapeado, não executado — rota real é `/profiles` (não `/access-profiles`); assign acontece em `/internal-users/:id/edit` (campo "Perfil Superadmin"); fica para a sessão do Bloco C.
- Rotina: `superadmin_routine_application_detail` não expõe o número da versão do modelo; o rótulo "Modelo vinculado · versão N" mostra a revisão da aplicação após o reload (ver `daily-routine-apply-20260915.md`). Contrato antes de mexer no rótulo.
- Formulários: upload em resposta (Galeria/Foto) exige ocorrência aberta e identificada para o Owner sintético — criar massa; ver `forms-upload-resolve-20260915.md`.
- Principal: após "Ver como", o cabeçalho não indica o contexto ativo (UX; decisão de design). Ver `shell-switch-context-20260915.md`.
- owner.r12-05 (contexto Atividade), r12-06 (rotina vinculada na chamada — contrato), r12-08 (massa com ≥2 alunos) — ver avisos acima.

## Contadores

FE 179/231, BE 166/224, E2E 152/192, Owner 15/53 (após invites.list/resend — Bloco A fechado).
