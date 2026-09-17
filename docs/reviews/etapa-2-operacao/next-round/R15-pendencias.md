---
title: "R15 — fila única consolidada da Etapa 2"
source: "Owner em 2026-09-16 (fechar a R14 e levar tudo o que ficou pendente para a R15; decisions/0042-r14-closure-r15-opening-20260916.md); R14-pendencias.md (congelado; 53 Owner IDs, H02–H28, itens da ADR 0038); inventario-etapa-2.json (estados certificados por action_id); R14-checkpoint-20260916.md; R14-fechamento.md; varredura R01–R14"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — fila única consolidada

> **Este é o único arquivo vivo de pendências da Etapa 2.** `R14-pendencias.md`
> passa a histórico congelado (como R12/R13). A tabela de Owner items abaixo é a
> fonte lida por `sync-r12-owner-records.cjs` (53 linhas, IDs preservados);
> `docs/reviews/inventario-etapa-2.json` continua a fonte dos estados por
> `action_id`. Item `done` fica aqui só para contagem e não volta à execução;
> item `open`/`partial`/bloqueado é a fila. Não criar cópias em outros arquivos.

Contadores certificados pelo inventário e `validate-trackers.cjs` (corte da
coordenadora R15, 17/09/2026, após as integrações do dia): FE 192/232 (82,76%),
BE 173/219 (78,99%), E2E 165/186 (88,71%), Owner 29/53 (54,72%).
Abertura da R15 em 16/09: FE 189/232, BE 172/219, E2E 162/186, Owner 21/53.
Fila: 21 ações não terminais no MVP (24 na abertura, com `auth.recover/reset`
pela E8); meta do Owner: **186/186**, 24 Owner
items abertos/parciais, 19 resíduos H,
2 itens da ADR 0038 e os resíduos operacionais listados abaixo. Nenhum item foi
renumerado; nenhum estado mudou na abertura.

## Abertura (Owner, 16/09/2026 — ADR 0042)

O Owner encerrou a R14 no fim de 16/09 e determinou que **tudo o que ficou
pendente de R01 a R14** seja levado para a R15, para acelerar o fechamento. A
varredura de abertura confirmou que R01–R07 já estavam reduzidas a H02–H28 (R07),
R08–R11 às ações do inventário e aos Owner items herdados da R11 (R12), e
R12/R13 à R14; **nenhum item fora dessas três famílias ficou órfão**, exceto os
resíduos operacionais sem `action_id` registrados na seção própria abaixo. As
dúvidas de abertura foram respondidas pelo Owner no mesmo dia (artefato
`M13t2csojoBnGt4sGWY4QM`, ADR 0042 E1–E7); ver a seção seguinte.

## Mesa R15 — respostas do Owner (16/09, ADR 0042 E1–E7)

- **Produção e permissões resolvidas no mesmo dia**: o Owner liberou a escrita
  em produção para a coordenação; as seis migrations foram aplicadas (lote 74,
  ledger 302–309) e o incidente do PostgREST terminou com a primeira delas
  (`PT409` no lugar de 40001). A API respondeu 401/0,5 s na sondagem seguinte.
- **E1 OQ-047 = A**: migration única 40001 → `PT409` em todas as famílias, com
  pgTAP por família no espelho antes (Bloco B, antes das provas de negativa).
- **E2 massa = A**: responsável + 2 crianças sintéticas vinculadas e 2 usuários
  internos (admin de unidade, educador) no tenant QA R04, prefixo `QA R15`.
- **E3 Chat r12-52 = B**: contrato de vários anexos por mensagem (migration +
  Edge `chat-media` + compositor em lote) — Bloco C, antes da prova de
  `chat.attach`.
- **E4 goldens = A**: regravar todas as suítes com diff só de cabeçalho, uma a
  uma, com registro.
- **E5 ordem = A** (Bloco A → B → C), executada com quatro prompts: coordenadora
  + um por bloco.
- **E8**: reset de senha no MVP, provado com a caixa do Owner (`auth.recover` BE
  done em 16/09); SMTP próprio → Etapa 3. **E9**: MFA fora do MVP
  (`deferred-post-mvp`).
- **E6 = a** (publicar no Histórico); **E7 = b** (responsável recebe o sino em
  atualização e dose — ajustar `20260916190000` por migration v2 + pgTAP + FE
  antes da prova de r12-33).
- Ambiente resolvido (Owner, 16/09): CORS das Edge Functions para `127.0.0.1:3014–3024` aplicado nas seis `*_ALLOWED_ORIGINS` de produção; preflight 200/204 em 3016/3018/3022/3024, 3030 segue 403.

## Ordem de execução proposta (fechar primeiro o que já tem código e só falta prova)

**Bloco A — rota real que ficou pronta na R14 (sem SQL novo; só exige produção respondendo):**
1. Perfis de acesso `access-profiles.edit/assign` + `owner.r12-20/21/22/24/25/26/27` (build e roteiro em `R14-handoff-sessao-5.md`).
2. Instituições `institutions.error/access-denied` (deep link + `cdp_block`).
3. Conta `owner.r12-46` / `account.profile` (foto R2; CORS da porta resolvido em 16/09).
4. Formulários `forms.expire-file/delete-file`, `forms.create/edit` + `owner.r12-39/40`, `forms.location-answer` (roteiro em `R14-handoff-sessao-6.md`).
5. Chat `chat.attach` + `owner.r12-52` — só depois do contrato E3 (Bloco C, item 12a).
6. Momentos `momentos.view/publish/remove` (`momentos.create` se o ambiente permitir; roteiro em `r14-sessao-7/momentos-bloqueado-20260916.md`).
7. `errors.409` (flutter-only, captura na rota real).
8. `auth.recover` / `auth.reset` + `owner.r12-47` (E8): pedir na tela `/recover` do app QA com o e-mail do Owner, abrir o link em `/reset-password` (após o push da allowlist `127.0.0.1:*`), senha nova, nova sessão, expiração/uso único; sem registrar link.

**Bloco B — migrations já aplicadas (lote 74); rota real + OQ-047 sistêmica:**
8. OQ-047 (E1): migration única 40001 → PT409 com pgTAP por família; depois Segurança da criança `child-safety.edit/suspend` + `owner.r12-13/15/16`.
9. Assiduidade contexto Atividade + `owner.r12-05` (criar atividade "QA R15" pela tela se não houver elegível); massa E2 (responsável + 2 crianças, admin/educador) para `owner.r12-08`, `agora.publish` e `owner.r12-33`.
10. `agora.remove` pela tela + negativa D5 (projeção `management_version`/`can_remove` — candidato no handoff 7 — e fixture executada como `postgres`).
11. B2 Histórico (`owner.r12-04`), B3 snapshot (`owner.r12-06`), B8 sino (`owner.r12-33`, com E7: v2 incluindo o responsável), B1 Arquivar (`owner.r12-01/02`): provar na rota real.

**Bloco C — contrato novo, especificar antes:**
12a. E3: vários anexos por mensagem no Chat (migration + Edge `chat-media` + compositor em lote), depois `chat.attach`/r12-52.
12. B5 busca de pessoa autorizada (`owner.r12-17`) e B6 pessoa sem conta (`owner.r12-18`).
13. B9 "ver como" (`principal.for-you`, `principal.profile-edit`).
14. Specs R15 já decididas: perfil transversal/funcionário (OQ-044; `owner.r12-19/23`), Perfis de cuidado §5 (`owner.r12-29/30`), ciclo de vida OQ-033 (inclui `institutions.status`), Locais com mapa por imagem (OQ-034), perfis oficiais (OQ-032).
15. H08/H13/H23 (Avisos: duplicar, CTA, visual) e demais H com gate de medição.
16. `owner.r12-38` Cardápios imagem R2 (migrar adapter para Media Gateway).

**Fora da R15:** SMTP próprio (Etapa 3, E8); MFA ×3 (`deferred-post-mvp`, E9); Planos comerciais e `catalog.*` (V1/V2); H11 autosave (V1); Stream genérico (sem contrato).

## Owner items — abertos/parciais e atualizações da execução (24)


| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-01 | daily-routine.list | partial / FE local-green (S9 16/09): cards sobre `CoeloAdminCardGrid` (grade de altura uniforme extraída do composto para coelo_ui_admin), linha "Efetivo: —" sempre presente e Arquivar em todos os cards (Restaurar no arquivado, B1); teste de widget 4/4 nos três pontos, pasta 119/119, golden regravado após o cabeçalho (C1). / Sem SQL/RPC novo nesta fatia; o efeito de Arquivar/Restaurar depende da fatia B1 (owner.r12-02). / Pendente: rota real (captura 1440 + reload). | docs/reviews/evidence/etapa-2/r14-sessao-9/daily-routine-cards-r12-01-20260916.md; docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-golden-diagnostic-r12.md | Capturar na rota real quando o PostgREST voltar; B1 (r12-02) dá efeito a Arquivar/Restaurar. |
| owner.r12-02 | activities.list, daily-routine.list | partial / FE local-green (S9 16/09): Atividades › Modelos com aba Arquivados, Arquivar/Restaurar com confirmação e recarga (leitor v1); Rotina › Modelos com filtro Arquivados e comandos v1 no router; testes 6/6 + 6/6 + 3 + 1. / BE local-green (espelho): spec 054 + migration `20260916193000_archive_models_v1` (RPCs `superadmin_activity_template_archive_v1/_restore_v1/_directory_v1`, `superadmin_routine_model_archive_v1/_restore_v1`, diretório de Rotina exclui arquivados por padrão; PT409, recibo, auditoria, RLS deny-by-default) + pgTAP 63/63; **não aplicada em produção**. / Pendente: aplicação em produção pelo rito e rota real dos dois diretórios (Arquivar, Restaurar, filtro, reload, negativa). | docs/reviews/evidence/etapa-2/r14-sessao-9/archive-models-b1-20260916.md; specs/054-archive-activity-routine-models.md | Coordenadora: aplicar `20260916183000` pelo rito (espelho verde, dump prévio, dry-run, ledger, lote) e provar na rota real; depois delta FE/BE/E2E. Restaurar de rotinas aplicadas fica para a spec de ciclo de vida (R15). |
| owner.r12-04 | daily-routine.list, attendance.dashboard | partial / FE local-green (Sessão 10, 16/09): tela Acompanhamento › Assiduidade › Histórico em `/attendance/history` (tabela data/turma-atividade/quem lançou/presentes/ausentes/rotina/situação, filtros instituição/unidade/turma/atividade/situação/período, cursor, abre o detalhe; sem edição); aba Lançamentos retirada do diretório de Rotina (Lançar hoje → Histórico › Lançamentos de rotina); 280 testes verdes, 10 goldens pré-existentes (C1). / BE local-green: `20260916180000_attendance_call_history_v1` (leitor por cursor com escopo do painel, só agregados) + pgTAP 44/44 no espelho; NÃO aplicada em produção. / Pendente: aplicar a migration, rota real autenticada, reload e negativa cross-tenant (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/attendance-history-20260916.md; specs/052-superadmin-attendance-history-and-routine-snapshot.md | Aplicar `20260916180000` pelo rito (espelho verde) após o fim do incidente; provar `/attendance/history` com `qa-r06-operacoes`, reload e negativa; decidir se Publicar lançamento fica no Histórico ou volta a Rotinas (spec 052 §3). |
| owner.r12-05 | attendance.create | partial / FE verified (rota real 15/09): cascata Instituição/Unidade/Turma/Contexto com contexto real, data, chamada criada e relida. / BE done; `superadmin_attendance_context_options` devolve a única atividade elegível (95b98978) com escopo 190dd028/f5284f2f/4214106c ausente das listas institutions/units/groups — inconsistência de escopo na RPC ou de massa. / verified-e2e de attendance.create com contexto Turma; contexto Atividade não exercitável. Bloqueio isolado confirmado em `14f6facab`. | docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-context-r12.md; docs/reviews/evidence/etapa-2/r14-coordenacao/attendance-activity-blocked-20260915.md | ADR 0041 D3: autorizada migration forward-only alinhando escopo de activities ao de groups em superadmin_attendance_context_options (espelho + pgTAP antes); depois provar seleção, criação, reload e negativa do contexto Atividade. |
| owner.r12-06 | attendance.create, daily-routine.apply | partial / FE local-green (Sessão 10, 16/09): detalhe da chamada e Histórico mostram a rotina (snapshot "registrada na conclusão"; aberta = vigente; legado concluído sem snapshot = "rotina atual (não registrada na época)"); repositório mapeia PT409; FE verified anterior (wizard sem etapa de rotina) preservado. / BE local-green: `20260916183000_attendance_routine_snapshot_v1` (colunas de snapshot, `attendance_effective_routine`, complete_call grava só na primeira conclusão, call_detail expõe routine_snapshot/routine_current/routine_source, histórico projeta a rotina, 40001 → PT409 na família) + pgTAP 43/43 no espelho; NÃO aplicada em produção. / Pendente: aplicar a migration, concluir/reabrir chamada real, reload do detalhe e negativa 409 PT409 (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/attendance-routine-snapshot-20260916.md; docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; specs/052-superadmin-attendance-history-and-routine-snapshot.md | Aplicar `20260916183000` pelo rito após `20260916180000` e o fim do incidente; provar na rota real: concluir grava snapshot, reabrir/concluir preserva, legado mostra a indicação; negativa de versão defasada responde 409 PT409. |
| owner.r12-08 | attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | partial / FE verified em mark/finish na rota real 15/09 (chamada cd60f2d8: presente salvo, reload, concluída). / Contratos preservados; set_participant v2 e complete_call v3 em produção. / Pendente só a massa: as turmas do escopo têm no máximo 1 aluno; múltiplos alunos/turmas e rotina vinculada não exercitados. | docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-behavior-diagnostic-r12.md | ADR 0041 D6: Owner não autoriza massa fictícia agora; prova com ≥2 alunos fica para depois. Bloqueado por decisão, não por ambiente. |
| owner.r12-10 | child-safety.list | partial / FE local-green (S9 16/09): causa da deriva observada no shell (`3945394f3` trocou a identidade estática por `headerProfile` da sessão; sem host o golden renderizava o placeholder `–`/`Conta`); cabeçalho estabilizado por `SuperadminHeaderProfileScope` + `SuperadminHeaderProfile.preview()` e golden `child_safety_directory_light_1440` regravado (C1), suíte 30/30 verde. / Contrato preservado; nenhum SQL/RPC novo. / Pendente: rota real da tabela e revisão contra a Table canônica. | docs/reviews/evidence/etapa-2/r14-sessao-9/goldens-cabecalho-global-20260916.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-table-golden-diagnostic-r12.md | Revisar a tabela do diretório contra a Table canônica e capturar na rota real quando o PostgREST voltar; golden não certifica aceite. |
| owner.r12-13 | child-safety.create, child-safety.edit | open / Wizard já usa FormFrame, painel único por etapa, grupos e rodapé canônicos; testes funcionais do wizard passam. / Contrato preservado; nenhum SQL/RPC novo. / Visual/E2E pendente para referência, rota normal, escopo e reload. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-composition-r12.md | ADR 0041 D4: autorizados diagnóstico e correção forward-only do 504 de child_safety_change_lifecycle; depois provar create/edit pela rota normal. |
| owner.r12-15 | child-safety.child, child-safety.edit, child-safety.suspend | partial / FE verified no estado suspenso (rota real 15/09): diálogo com identidade, contexto, relação, capacidades, motivo, decisão, situação, validade e só Concluir. / BE: child_safety_change_lifecycle responde 504 (timeout) em produção — bloqueio para Sessão 2 (SQL/espelho). / child verified-e2e; suspend blocked-backend; estados pendente e aprovado-ativo não exercitados. | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-manage-context-r12.md | ADR 0041 D4: autorizados diagnóstico e correção forward-only do 504; depois criar autorização, aprovar e suspender pela tela para fechar r12-15/13/16. |
| owner.r12-16 | child-safety.create | open / FE local-green: stepper bloqueia salto para etapa futura e permite retorno às concluídas; testes do wizard cobrem o fluxo. / Contrato preservado; nenhum SQL/RPC novo. / Pending-verification de rota normal e escopo. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | ADR 0041 D4: depende do 504; depois provar teclado/rota normal sem salto e sem perda de dados. |
| owner.r12-17 | child-safety.create, child-safety.edit | open / Diagnóstico: campo atual ainda aceita identificador/UUID técnico; não existe contrato de busca autorizada por nome, CPF, e-mail ou celular. / Sem alteração backend; não criar busca fake. / Contract decision pending. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | ADR 0041 B5: leitor de busca único (nome/@/e-mail ≥3, celular ≥4, CPF ≥6 dígitos, com ou sem máscara), escopo do ator, auditoria, limite de taxa, resultado minimizado sem CPF; responsável lista crianças vinculadas do escopo. Contrato aprovado; implementar BE + FE. |
| owner.r12-18 | child-safety.create | open / Diagnóstico: pessoa global sem conta e campos mínimos/deduplicação não têm contrato definido. / Nenhuma tabela/RPC criada. / Contract decision pending. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | ADR 0041 B6: pessoa sem conta com CPF obrigatório, documento + imagem (R2 privado) no MVP, celular/e-mail; autorizada só no contexto pedido; pode virar conta depois. Cadastro só após a busca B5 não encontrar. |
| owner.r12-19 | gate/mapeamento pendente | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | ADR 0041 B7: perfil transversal/funcionário no Principal vira spec própria na R15 (OQ-044). Na R14, provar somente o diretório atual (r12-20/21) sem tocar no conflito. |
| owner.r12-20 | access-profiles.list | done / FE verified na rota real (S5 16/09 e Bloco A 17/09): 8 cards após carga completa em 1424×1125 e após salvar edição. / BE inalterado. / E2E: negativa aceita = versão defasada 409 PT409 (lote 75) e capability/instituição inválida 400 22023; perfis Superadmin não têm tenant. | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Resíduo BE (não bloqueia): "Vínculos" conta platform_memberships. |
| owner.r12-21 | access-profiles.detail | done / FE verified na rota real (Bloco A 17/09): detalhe traduzido módulo › tela › ação ("Acessos › Modelos de perfil › Ver"), relido após carga completa com v2 e 2 permissões. / BE inalterado; catálogo em inglês e CardÃ¡pios (resíduo). / E2E verified-e2e via access-profiles.edit. | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Resíduos BE: rótulo "Excluir" × nome "Inativar modelos Admin."; reason mascarado como [redacted] no detalhe. |
| owner.r12-22 | access-profiles.create, access-profiles.edit | done / FE verified: criação (S5) e edição (Bloco A 17/09) sem campo Código; code do servidor preservado ao renomear. / BE done. / E2E verified-e2e: save v1→v2 relido por PostgREST, reload, 409 PT409 em versão defasada. | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). |
| owner.r12-23 | access-profiles.create | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | ADR 0041 B7: transferido para spec própria na R15 (OQ-044). Não executar na R14. |
| owner.r12-24 | access-profiles.create, access-profiles.edit | done / FE verified na rota real (Bloco A 17/09): tooltip de sensibilidade por hover (S5) e por foco de teclado (Tab) em "Excluir" (sensível) e "Criar/Importar" (risco elevado). / BE inalterado. / E2E verified-e2e via access-profiles.edit. | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Resíduo visual: tooltip aberto por foco não fecha quando o foco avança (fica empilhado); corrigir em _PermissionActionCell. |
| owner.r12-25 | access-profiles.create, access-profiles.edit | done / FE verified na rota real (Bloco A 17/09): matriz em 1424 (empilhada por tela, cabeçalho sem estouro) e em 600×900 (stepper à esquerda, sem estouro horizontal, rodapé empilhado); persistência/reload. / BE inalterado. / E2E verified-e2e via access-profiles.edit. | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). |
| owner.r12-26 | access-profiles.edit | done / FE verified na rota real (Bloco A 17/09): Continuar FilledButton laranja preenchido no passo 1 da edição, tema claro; Salvar alterações preenche após motivo. / BE inalterado. / E2E verified-e2e via access-profiles.edit. | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). |
| owner.r12-27 | access-profiles.create, access-profiles.edit | done / FE verified na rota real (Bloco A 17/09): revisão "Acessos › Modelos de perfil › Inativar modelos Admin.", texto configuração × acesso efetivo, vínculos impactados, MFA, motivo obrigatório; salvo sem perder permissões e relido. / BE inalterado. / E2E verified-e2e via access-profiles.edit. | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). |
| owner.r12-29 | health-care.create, health-care.edit, health-care.detail | partial / Sessão D provou em produção a coleção independente de alergias, com IDs, adicionar/remover/reload e compatibilidade legada; pgTAP remoto 6/6 e limite backend de 100, com rejeição do 101º. / BE done. / verified-e2e das ações; aceite central ainda pendente. | docs/reviews/evidence/etapa-2/r14-sessao-2/block-d-20260915.md; docs/reviews/etapa-2-operacao/next-round/R14-handoff-sessao-2.md | ADR 0041 A2/§5: não aceito ainda — Owner quer prova com mais registros e redesenhou o contrato (wizard Alimentos × Restrições, nome de lista categorizada, reordenar, "O que fazer se consumido?"). Spec para R15; coleção + limite 100 já em produção são a base. |
| owner.r12-30 | health-care.create, health-care.edit, health-care.detail | partial / Sessão D provou em produção a coleção independente de orientações, com IDs, adicionar/remover/reload e compatibilidade legada; pgTAP remoto 6/6 e limite backend de 100, com rejeição do 101º. / BE done. / verified-e2e das ações; aceite central ainda pendente. | docs/reviews/evidence/etapa-2/r14-sessao-2/block-d-20260915.md; docs/reviews/etapa-2-operacao/next-round/R14-handoff-sessao-2.md | ADR 0041 A2/§5: idem r12-29 para orientações de cuidado (lista pré-definida, reordenar). Spec para R15. |
| owner.r12-33 | medication.create, medication.edit, medication.detail | partial / FE local-green (Sessão 10, 16/09): sino já lia `context_notification_*`; rótulos para plano criado/atualizado/status e dose registrada (resumo por desfecho). / BE local-green: `20260916190000_medication_in_app_notifications_v1` (destinatários = admins da unidade + educadores da turma, sem responsáveis; editar plano → `medication.plan.updated`; cada dose → `medication.dose.recorded`; `not_tracked` silencia) + pgTAP 29/29 no espelho; criar plano já notificava em produção (trigger existente, audiência mantida); NÃO aplicada em produção. / Pendente: aplicar a migration, editar plano e registrar dose reais e observar o sino com identidade da unidade/educador (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/medication-notifications-20260916.md; specs/053-superadmin-medication-in-app-notifications.md | Aplicar `20260916190000` pelo rito após o incidente; provar o sino na rota real com duas identidades (admin da unidade e educador da turma); sem e-mail/push. |
| owner.r12-38 | meal-plans.create, meal-plans.edit, meal-plans.publish, meal-plans.model-edit | open / FE mantém envio desabilitado. / Adapter composto ainda usa Supabase Storage em upload/leitura, incompatível com R2 privado. / E2E não executado. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | C0 migrar SupabaseMealPlanImageRepository e contratos de vínculo para Media Gateway R2; depois habilitar composição e provar upload/reload/escopo. Não é apenas flag. |
| owner.r12-39 | forms.edit, forms.create | partial / FE local-green: arraste/movimentação e alternativas por botões preservadas. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/forms-editor-r12-39-40.md | Provar save/reload e posição final pela rota normal. |
| owner.r12-40 | forms.edit, forms.create | partial / FE local-green: seção pode ser renomeada por diálogo e o draft é atualizado. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/forms-editor-r12-39-40.md | Provar persistência/reload e nome na prévia pela rota normal. |
| owner.r12-46 | account.profile | partial / FE verified (rota real 14/09): sigla QE→QR salva e relida após reload, celular e cor exibidos. / BE remote-green (lote 63): sigla/cor/celular em produção; foto R2 ausente. / E2E aberto até a foto privada (R2) existir no BE. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Resolver gate SQL; aplicar contrato, implementar foto privada e provar foto/nome/sigla/cor, remover foto, grupos reais, reload e troca de sessão. A confirmação deve atualizar também o avatar global do cabeçalho; rascunho local não pode aparentar sucesso quando o servidor não confirmou. O Celular permanece obrigatório e precisa de máscara/formato de entrada, normalização e prova de valor inválido/válido. Aprovação visual 14/09: A+ — colocar o card "Meu acesso" na mesma linha de "Dados pessoais" com rolagem interna (coelo-ui), depois foto R2. |
| owner.r12-47 | auth.recover, auth.reset | open / Verified histórico; pedido normal e endereço inexistente observados na R11. / Sem mensagem real na caixa acessível; SMTP próprio ausente e redirect local3000 fora da allowlist. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Transferido para Etapa 3 pela ADR 0039; não executar na R14. Quando aberto, obter acesso/configuração de caixa/SMTP/redirect e provar link real, nova senha/sessão, expiração e uso único; preservar credencial QA privada. |
| owner.r12-49 | assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | partial / FE verified em entry/gradebook/detail (rota real 14/09): participante listada, nota 8.5 salva e relida. / BE done em entry/gradebook/detail (lote 63 + save pela tela); close/reopen local-green. / verified-e2e em entry/gradebook/detail; close/reopen pendentes na rota real. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; usar o mesmo diário d2c945d8, lançar/reler nota, fechar/reabrir com versão e provar escopo real. Não duplicar participante, vínculo, configuração ou diário. |
| owner.r12-52 | chat.attach | done / FE verified (rota real 17/09, R15 C1): seletor múltiplo, diálogo de lote com progresso e falha tratada, mosaico 3 e 3+1 (+N), tile único (PDF e imagem), reload. / BE done (lote 76): contrato E3 `superadmin_chat_attachment_prepare_v2`/`finalize_v2`/`discard_v1` — uma mensagem por lote de 1–10, 11º recusado (422), publicação só quando todos terminam; Edge `chat-media` em lote; pgTAP 51/51 + 28/28 + 9/9. / E2E verified-e2e em produção: mídia R2 real, reload por `thread_v2`, negativas 404/422/409 por PostgREST. | docs/reviews/evidence/etapa-2/r15-bloco-c1/chat-attach-e3-20260917.md; specs/058-superadmin-chat-multi-attachment-message.md; docs/reviews/evidence/etapa-2/r12-coordenacao/chat-attach-mosaic-r12.md | Concluído 17/09 (ADR 0042 E3 = B): mosaico alcançável pela rota normal com vários anexos na mesma mensagem. |
| owner.r12-53 | gate/mapeamento pendente | open / Não iniciada; condição de abertura não atendida. / Não iniciado. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Não promover `institutions.status` ou `institutions.locations-map` na R14: estão fora do MVP/escopo ativo. OQ-034 (Locais com mapa por imagem) fica preparado para a R15, sem abrir outro macrotema. |

## Owner items — concluídos (29; não voltam à execução)


| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-34 | meal-plans.model-create, meal-plans.model-edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2; imagem R2 segue em owner.r12-38. |
| owner.r12-35 | meal-plans.model-create, meal-plans.model-edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-36 | meal-plans.create, meal-plans.edit, meal-plans.publish | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-37 | meal-plans.create, meal-plans.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-09 | child-safety.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-directory-diagnostic-r12.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: Owner aprovou o card atual sem campo alerta/restrição (ADR 0041 B4). |
| owner.r12-11 | gate/mapeamento pendente | done / Cards já têm situação + Escopo máximo/Vínculos/Tipo em composição compacta; pages 15/15 PASS. / Contrato preservado; nenhum SQL/RPC novo. / Visual golden pendente de reconciliação; sem action_id novo. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-cards-diagnostic-r12.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: Owner aprovou a composição atual dos cards (ADR 0041 C2); golden regrava com o cabeçalho (C1). |
| owner.r12-03 | activities.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/activities-list-publish-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/activities-list-tabs-r12.md | Concluído 15/09 (rota real, Sessão 1): abas "Modelos de atividade"/"Atividades", busca, filtros, cards/tabela, status, paginação e reload com dados reais; negativa por id inexistente e escopo pgTAP. |
| owner.r12-07 | attendance.mark, attendance.correct, attendance.finish | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-12 | child-safety.child | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-authorization-status-r12.md | Concluído 15/09 (rota real, Sessão 1): tabela distingue "Aprovado · Suspensa" e mantém validade com dados reais; reload e negativa P0002. Golden 1440 permanece em r12-10. |
| owner.r12-14 | child-safety.child | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-relationship-r12.md | Concluído 15/09 (rota real, Sessão 1): mother/father reais exibidos como Mãe/Pai na tabela e no diálogo, em pt-BR, com dados de produção. |
| owner.r12-28 | health-care.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): edição com o nome real da criança (correção 165d3df8c), sinal salvo (version 1→2) e relido após reload. |
| owner.r12-31 | medication.create, medication.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): criação Paracetamol R13 (10 ml, oral, vigência, 08:00, Seg/Qua) e edição da dose 5→7 ml da Dipirona R06, persistidas e relidas. Responsável depende de owner.r12-33 (R14). |
| owner.r12-32 | medication.list, medication.detail, medication.create, medication.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): diretório lista os planos reais por criança com contexto explícito; detalhe/criação/edição provados e relidos. |
| owner.r12-41 | forms.list | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-42 | agenda.request | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/agenda-request-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/agenda-approvals-r12-42.md | Concluído 15/09 (rota real, Sessão 1): tabela canônica, decisão aprovar/recusar com justificativa, histórico em diálogo, reload e negativa; defeito de rótulos pós-decisão corrigido (teste vermelho→verde). Golden de calendário loading dark 375 fica fora deste action_id. |
| owner.r12-43 | chat.open | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-44 | invites.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/invites-list-resend-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/invites-list-table-only-r12.md | Concluído 15/09 (rota real, Sessão 1): tabela-only, busca/filtros/paginação/Novo convite/ações por linha, reload; convite real expirado e renovado na mesma tabela. |
| owner.r12-45 | invites.resend | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/invites-list-resend-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/invites-resend-discovery-r12.md | Concluído 15/09 (rota real, Sessão 1): convite expirado real (emitido com 1 h por RPC autorizada), reenviado uma vez pela tela, link de uso único (mascarado), reload e negativas SAI_INVALID_ARGUMENT/SAI_CONCURRENT_CHANGE; sem SMTP. |
| owner.r12-48 | activities.assessment, activities.publish | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Concluído 14/09 (rota real): rascunho b04c879e carregado e salvo pela tela (version 2→3), reload relê, negativa por id inexistente; activities.publish já era done. Capturas em r13-coordenacao/capturas. |
| owner.r12-50 | groups.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Concluído 14/09 (rota real): /groups com Alunos 1 e Atividades 3 na turma 4214106c, busca "R05" (hotfix lote 64), reload mantém, negativa por instituição alheia. Capturas em r13-coordenacao/capturas. |
| owner.r12-51 | gate/mapeamento pendente | done / Não aplicável. / Done (lote 63, 14/09): quatro candidatos aplicados em produção com dump SHA-256, espelho e pgTAP verdes, ledger 283→287. / Não aplicável. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Owner resolve exigência PITR da R11 versus ADR0034D8; C0 confirma regra vigente, configuração real, backup atualizado e ordem serial antes de aplicar. Transferir rodada não concede exceção ou autorização nova. |

## Resíduos H (herdados de R01–R07) — abertos (19)


| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H02 | noturna/R01 | Atualização oficial a partir do Sobre | Decidido (ADR 0038): conectar no MVP. Próximo gate: consumidor produtivo de ProfileAboutOfficialUpdateRequest e prova na rota normal. |
| H03 | noturna/R01 | Composição das quatro abas de Perfil | Comparar referência vigente e decidir consumidor produtivo. |
| H04 | R02/R07 | Compositor produtivo de Circular e blocos intercalados | Unificar host e provar na rota normal. |
| H07 | noturna/R01 | Hash de edição/revogação sem `conversation_id` | Executar replay/contexto na revisão de segurança. |
| H09 | R04/R06 | Disparo agendado de expiração Agora | Medir trigger real; leitura não basta. |
| H10 | noturna/R01 | Múltiplas regras de audiência em Formulários | Decidido (ADR 0038): preservar todas as regras de audiência. Próximo gate: editor lista/edita regras sem perder as demais + teste. |
| H12 | noturna/R01 | Controles de mínimo/máximo de seleção | Localizar contrato e registrar aceite. |
| H14 | R06 | Sino sem `action_id`/subaceite | Mapear ao action_id-pai sem novo denominador. |
| H16 | R06 | Leitura people-based de cuidado | Provar escopo entre unidades. |
| H18 | R06 | Unicidade global concorrente de `@` | Revisar concorrência entre tabelas. |
| H19 | R06 | Responsável vazio em Medicação | Reproduzir com contexto e destinatário válidos. |
| H20 | R06 | Imagem da dose sem gateway | Localizar consumidor e obter prova específica. |
| H21 | R07 | Limite de texto/rodapé de Circular | Parcial em 14/09: **backend concluído (lote 68)** — `save_draft_v2` e constraint de `circular_revisions` em 4.000 somando blocos de texto; pgTAP 10/10; produção recusa 4.001 (`CIRCULAR_INVALID_INPUT`). Cliente `CircularLimits.bodyCharacters = 4000` (contador já somava blocos). Falta H04: host/rodapé em card/Opções conforme referência e regravação dos goldens web (18 goldens de circular já falhavam antes desta mudança). |
| H22 | noturna/R01 | Descritor privado de Circular | Alinhar à ADR 0032 e provar ausência de bucket público. |
| H24 | noturna/R01 | Rótulos do Sobre | Comparar com referência vigente. |
| H25 | noturna/R01 | Alvo de redimensionamento de tabela | Medir teclado, semântica e toque. |
| H26 | noturna/R01 | Opcional, escala legada e opções vazias | Reconciliar contrato atual por caso. |
| H27 | noturna/R01 | Sinal de atualização de Momentos | Decidido (ADR 0038): saudação por hora do dia; ponto laranja na aba Momentos quando há momento não visto. Próximo gate: implementar no Principal + prova. |
| H28 | R01 | Filtros, avatar e buffers de Pessoas | Rever somente diferenças funcionais persistentes. |

## Resíduos H — transferidos (4: H08/H13/H23 → R15; H11 → V1)


| ID | Origem | Motivo da transferência |
|---|---|---|
| H11 | noturna/R01 | **V1** por decisão do Owner em 16/09 (ADR 0041 B10): autosave de autoria de Formulários sai do MVP sem medir o limiar de 60%; testes locais preservados, nenhum aceite remoto exigido. |
| H08 | R02 | Autorizado pelo Owner em 15/09; falta contrato produtivo do item a duplicar e `action_id`, portanto não inventar RPC, payload ou coluna na R14. |
| H13 | noturna/R01 | Autorizado pelo Owner em 15/09; falta referência produtiva de item relacionado e `action_id` para o CTA. |
| H23 | noturna/R01 | Autorizado pelo Owner em 15/09; implementação visual depende do contrato de Avisos que será definido junto com H08/H13 na R15. |

## Resíduos H — concluídos (4)


| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H05 | noturna/R01 | Denominador histórico de recibos do Chat | Decidido (ADR 0038): recibos contam participantes ativos atuais. Fechado sem mudança; aceite MVP mantido. |
| H06 | noturna/R01 | Revogar em Chat somente leitura | **Concluído em 14/09 (lote 65)**: `superadmin_chat_revoke_message_v2` recusa `CHAT_READ_ONLY` no servidor; pgTAP 14/14 + suíte base 36/36 no espelho; guard presente em produção; negativa `CHAT_NOT_FOUND` por RPC. `chat.revoke` já era verified-e2e; sem delta de estado. |
| H17 | R06 | Papel fixo versus capacidade em cuidado | **Concluído em 14/09 (lote 66)**: capacidade `care_policies.manage` nos catálogos Superadmin (Owner) e Admin (Administrador da instituição); `superadmin_unit_care_policy_set_v1` exige só a capacidade; pgTAP 15/15 + base 20/20; get/set/reload em produção na unidade f5284f2f e negativa por unidade alheia. Sem action_id próprio no inventário (sem tela no cliente); sem delta de estado. |
| H15 | R06 | Atribuição de Plano | **Concluído por decisão de escopo:** `plans.assign` fica fora do MVP; botão e operação permanecem honestamente indisponíveis. |

## Itens da ADR 0038 sem ID H nem Owner item — aberto (1) e transferidos (2)


| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Reader de Planos comerciais no Principal (039) | Transferido para V1/V2 | Não executar na R14; preservar contrato e IDs como preparação futura. `units_with_override` só deve ser calculado quando o Owner abrir o escopo. |
| Local interno em Formulários (IDs fixados na publicação; revisão conserva valor) | Aberto | Verificar contrato atual de `form_publish`/resposta; pacote só se faltar. |
| Auth: localhost na allowlist de redirect (R12-47) | Transferido para Etapa 3 | Não executar na R14; pertence ao contrato futuro de recuperação/reset, com ambiente e prova próprios. |

## Itens da ADR 0038 — concluídos (5)


| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Catálogos globais de tipo (OQ-031) | Concluído 16/09 (aceite do Owner, ADR 0041 A3) | Sessão D aplicou a migration `20260915131500` em produção e confirmou pgTAP remoto 11/11, quatro catálogos com oito entradas e "Outros"; evidência no branch `origin/r14/bloco-cd` (`b135c8f20`). |
| Reader self da Conta (039) | Concluído 16/09 (aceite do Owner, ADR 0041 A3) | Sessão D aplicou a migration `20260915133000` em produção e confirmou pgTAP remoto 6/6, sessão autenticada e ausência de sobrecarga por UUID; evidência no branch `origin/r14/bloco-cd` (`b135c8f20`). |
| Anexos por mensagem no Chat (10 por envio) | **Concluído em 14/09 (lote 67)** | `superadmin_chat_attachment_prepare_v1` recusa o 11º pendente com `CHAT_ATTACHMENT_LIMIT` (422); pgTAP 9/9 + base 28/28; produção: 10 aceitos e 11º recusado na conversa 355a3403 (sintéticos arquivados); cliente mapeia `chat_attachment_limit` (243 testes do chat verdes). |
| Status de Suporte (OQ-028) | **Concluído em 14/09 (lote 69)** | `set_status` grava open/pending/resolved conforme o mapeamento A; trigger mantém `ticket_status` coerente (expired/revoked → Concluído); `closure_reason` em get/list; pgTAP 13/13 + bases 23/23, 28/28, 17/17; produção: chamado 6c5eb791 waiting→pending, completed→resolved. Cliente mostra “Concluído · Expirado/Revogado”. |
| Identidade da mídia do Chat (`asset_id` no envelope) | Concluído 16/09 (OQ-046, lote 72) | `superadmin_chat_thread_v2` devolve `asset_id` em produção (dump de 16/09); Edge `chat-media` publicada pela Sessão E; migration `20260915130100` no ledger remoto. |

## Ações não terminais por família (inventário: 21 ações; FE/BE/E2E)


Projeção regenerada em 17/09/2026 a partir de `inventario-etapa-2.json` (coordenadora R15): ações `mvp`/`gate-formal-mvp` cujo estado integrado
não é `verified-e2e` nem `flutter-only`. As 33 `deferred-post-mvp` (30 + MFA ×3, E9) ficam fora;
`errors.409` (flutter-only, FE local-green) ainda deve provar FE na rota real.

| Família | Qtd | action_ids |
|---|---:|---|
| account | 1 | `account.profile` (verified/remote-green/pending-verification) |
| agora | 3 | `agora.publish` (verified/done/pending-verification), `agora.expire` (pending-verification/done/pending-verification), `agora.remove` (local-green/pending-verification/pending-verification) |
| auth | 2 | `auth.recover` (verified/done/pending-verification), `auth.reset` (verified/pending-verification/pending-verification) |
| child_safety | 2 | `child-safety.edit` (local-green/done/pending-verification), `child-safety.suspend` (local-green/done/blocked-backend) |
| forms_authoring | 2 | `forms.create` (local-green/done/pending-verification), `forms.edit` (local-green/done/pending-verification) |
| forms_files | 2 | `forms.expire-file` (pending-verification/local-green/pending-verification), `forms.delete-file` (pending-verification/local-green/pending-verification) |
| forms_responses | 1 | `forms.location-answer` (local-green/pending-verification/pending-verification) |
| institutions | 2 | `institutions.error` (pending-verification/local-green/pending-verification), `institutions.access-denied` (pending-verification/local-green/pending-verification) |
| momentos | 4 | `momentos.view` (verified/done/pending-verification), `momentos.create` (local-green/local-green/blocked-environment), `momentos.publish` (pending-verification/local-green/pending-verification), `momentos.remove` (pending-verification/local-green/pending-verification) |
| principal_profile | 2 | `principal.for-you` (verified/blocked-decision/pending-verification), `principal.profile-edit` (local-green/blocked-decision/pending-verification) |

## Resíduos operacionais sem action_id (varredura R01–R14, 16/09)

| Item | Origem | Estado | Gate |
|---|---|---|---|
| Migrations da R14 em produção | R14 Sessões 8/9/10 | **Aplicadas em 16/09 (lote 74, ledger 302–309)** | Provar na rota real (Bloco B). |
| Incidente PostgREST 40001 (OQ-047) | R14 Sessão 8 | Incidente encerrado em 16/09 pela primeira migration do lote 74; restam ~169 `raise serialization_failure` em produção | E1 = A: migration única 40001 → PT409 com pgTAP por família. Regra durável: RPC nova nunca sinaliza versão defasada com 40001. |
| Goldens pré-existentes (391 falhas em 34 suítes) | R12–R14 | Mesma assinatura do cabeçalho (C1); 30 regravadas na R14 | E4 = A: regravar suíte a suíte após conferir o isolatedDiff, com registro. |
| Testes pré-existentes vermelhos | anterior à R14 | `model_save_completion_routes_test` (3), `principal_real_route_test` (1), `principal_profile_for_you_production_routes_test` (1), `activity_routes_test` (1) | Corrigir na R15 antes do censo de suítes. |
| Censo completo de suítes (G8, R09) | R09 | Nunca executado integralmente | Rodar `flutter test` por pacote e registrar o censo no fechamento. |
| Deploy público do frontend (R09 C0) | R09 | Sem deploy público desde a R09; builds QA locais | Reconciliar build/host de produção antes de qualquer publicação. |
| CORS das Edge Functions por porta | R14 Sessões 5/7 | **Concluído 16/09**: `COELO`, `CHAT`, `CIRCULAR`, `HAPPENS`, `MOMENTS` e `NOW_MEDIA_ALLOWED_ORIGINS` regravadas em `evvbomzejfijozbtgvpt` com as três origens `coelo.me` + `localhost`/`127.0.0.1` em 3000/3009/3014–3024; OPTIONS 200/204 em 3016/3018/3022/3024 nas cinco funções, 3030 → 403 | — (sessões paralelas podem usar 3014–3024). |
| `agora.remove` — projeção e fixture D5 | R14 Sessão 7 | Candidato `now_feed_removal_projection` provado no espelho; fixture existe (só `postgres`) | Aplicar pelo rito e provar negativa 422 sem mutação; revogar identidade. |
| `owner.r12-46` layout A+ "Meu acesso" | R13 | Aprovação visual 14/09 sem implementação | coelo-ui: card na mesma linha de "Dados pessoais" com rolagem interna. |
| Stream genérico | R14 Sessão E | Sem contrato, Edge, segredo, fixture ou critério | Só com decisão do Owner; hoje `stream_status=not_applicable`. |
| Espelho CLI `supabase/migrations` com cópias não rastreadas | R14 coordenação | 206 arquivos no espelho ignorado pelo Git | `Sync-SupabaseCliMigrations.ps1 -Mode Clean` antes de qualquer `db push`; corrigir o script (tracked ≠ canonical). |
| Worktrees/branches `r14/*` | R14 | Seis worktrees integradas por cherry-pick, protegidas | Remover com manifesto no fechamento da R15 ou reaproveitar para as sessões da R15. |

## Decisões de escopo do Owner (14/09, 15/09 e 16/09; ver `docs/agent/backlog.md`)


Fora do MVP: operações de Planos comerciais (listar/criar/editar/arquivar/restaurar/
atribuir/vincular/entitlements), `plans.assign`, Financeiro, `institutions.status`,
`institutions.locations-map`, MFA ×3.
V1/Etapa 3: Catálogo de UI. Formulários autosave (H11): V1 se for caro, salvo se >60% pronto.
Etapa 3: `auth.recover`/`auth.reset`; 3 instituições fictícias com hierarquia para o Owner verificar "Para você" (nome a rever).
Antes do fim do MVP: perfis oficiais do Coelo (OQ-032). R15: OQ-033 (decidido em 15/09: opção B + regra de pessoas) e OQ-034 Locais com mapa por imagem (confirmado em 15/09; substitui `institutions.locations-map`).

**15/09/2026 — abertura da execução (artefato 89AVWHKEnq5hrvYN6SFv6M):** temas explicados e sete decisões registradas em `R14-execucao-paralela.md` (papéis, worktrees, portas, handoffs, Bloco B autorizado com E2E ativo 199 → 192, ordem do Bloco C e ordem original do Bloco D). A formalização posterior de `agora.remove` levou a base ativa a 193. Duas sessões executaram em paralelo; a coordenadora (Codex) atualiza este arquivo. A decisão posterior da ADR 0039 transfere recuperação/reset de Auth e a allowlist desse fluxo para a Etapa 3.

**16/09/2026 — Mesa do Owner (artefato Jrsk1XBe97MCLpeUBGAeYz, ADR 0041):** 27 decisões registradas; `institutions.files` fora do MVP; páginas de erro `flutter-only`; H11 → V1; perfil transversal e Perfis de cuidado redesenhados → specs R15; contratos B1–B9 fixados; autorizações D1–D5 concedidas, D6 negada.

## Como atualizar

- Estado por `action_id`: só via `apply-tracker-delta.cjs` com evidência certificada (inventário → três rastreadores).
- Owner items: editar a linha aqui e rodar `node docs/reviews/etapa-2-operacao/next-round/sync-r12-owner-records.cjs`.
- H, itens da ADR e resíduos operacionais: editar a linha aqui. Nunca editar R12/R13/R14 (históricos).
- Validar sempre com `node docs/reviews/validate-trackers.cjs`.
- Execução paralela (sessões, worktrees, handoffs): `R15-execucao-paralela.md` (aberta em 17/09; sessões A/B/C1/C2); prompts em `R15-prompts.md` (coordenadora + Blocos A/B/C, E5); handoffs são comunicação, não fila.
- Recuperação/redefinição de senha (E8): `auth.recover` BE done (entrega real 16/09, `r15-coordenacao/auth-recover-mfa-decisoes-20260916.md`); prova pela tela no Bloco A; allowlist `127.0.0.1:*` preparada (push depende do Owner); SMTP próprio na Etapa 3.
