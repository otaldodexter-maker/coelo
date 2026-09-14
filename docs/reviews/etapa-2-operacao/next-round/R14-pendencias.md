---
title: "R14 — fila única consolidada da Etapa 2"
source: "Owner em 2026-09-14 (consolidar R12/R13 numa única fila); R12-pendencias.md (tabela Owner, 53 IDs); R13-pendencias.md (H02–H28, itens da ADR 0038); inventario-etapa-2.json (SHA 7c5b3998c); R14-catalogo.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
audience: "team"
---

# R14 — fila única consolidada

> **Este é o único arquivo vivo de pendências da Etapa 2.** `R12-pendencias.md` e
> `R13-pendencias.md` estão congelados como histórico. A tabela de Owner items abaixo
> é a fonte lida por `sync-r12-owner-records.cjs` (53 linhas, IDs preservados);
> `docs/reviews/inventario-etapa-2.json` continua a fonte dos estados por `action_id`.
> Regra: item `done` fica registrado aqui apenas para contagem e não volta à execução;
> item `open`/`partial`/bloqueado é a fila. Não criar cópias em outros arquivos.

Contadores certificados (inventário, 14/09/2026 18:00): FE 164/231 (71,00%),
BE 164/224 (73,21%), E2E 137/199 (68,84%), Owner 9/53 (16,98%).

## Ordem de execução (decisão do Owner de 14/09)

1. Cardápios na rota real (`meal-plans.create/edit/model-create/model-edit/publish`) + `owner.r12-36/37` (SQL) + `owner.r12-19` a `27`.
2. OQ-031 catálogos globais de tipo (SQL idempotente por `code`, com Outros).
3. `H08` Duplicar Aviso (RPC + cliente) e Avisos na rota real (`H23`/`H13`).
4. `owner.r12-47` localhost na allowlist de redirect do Auth.
5. `owner.r12-29/30` (múltiplos registros/orientações independentes de cuidado).
6. Circular `H04` (host conforme referência + regravar goldens), Formulários `H10/H11`, Principal `H27/P54/H02`.
7. Segurança infantil (`owner.r12-09` a `18`), `assessments.close/reopen`, foto R2 da Conta (`owner.r12-46`).
8. SQL "c": `owner.r12-18`, `owner.r12-33`, `asset_id` no chat-media + Edge Function.
9. Gates de medição: `H03`, `H07`, `H09`, `H12`, `H14`, `H16`, `H18`–`H20`, `H22`, `H24`–`H26`, `H28`.

## Aprovação visual do Owner — 14/09/2026 (artefato 5218230f, SHA a952f3ff9)

| Tela | action_ids | Decisão | Observação / gate |
|---|---|---|---|
| Estrutura › Turmas › Diretório | groups.list | **A** | — |
| Atividades › Lançar avaliações | assessments.entry/gradebook/detail | **A** | — |
| Saúde e Cuidado › Planos de medicação | medication.list/create/detail/edit | **A** | — |
| Cabeçalho › Meu perfil | account.profile | **A+** | Owner: "o contêiner do Meu Acesso pode ficar na mesma linha que Dados pessoais e ter a rolagem para ir descendo" → correção de layout obrigatória (coelo-ui), entra em `owner.r12-46`. |
| Atividades › Configuração avaliativa | activities.assessment | pendente | sem decisão registrada no artefato |
| Saúde e Cuidado › Perfis de cuidado | health-care.create/detail/edit | pendente | sem decisão registrada no artefato |

## Owner items — abertos/parciais (44)

| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-01 | daily-routine.list | open / Planejado R12; não implementado. / Contratos a verificar; triagem golden encontrou apenas diferença no cabeçalho global, sem atribuir falha ao card. / Não executado para este apontamento. | docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-golden-diagnostic-r12.md; docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Estabilizar/reconciliar o cabeçalho global; depois comparar Modelos em referência autorizada e corrigir alturas/rodapés/ações sem regenerar baseline por inferência. |
| owner.r12-02 | activities.list, daily-routine.list | open / FE parcial: Duplicar existe em Atividades; Arquivar não tem callback/contrato no diretório. / Sem RPC/RLS novo; arquivamento não executado. / Pendente por contrato de archive, confirmação, versão, auditoria e reload. | docs/reviews/evidence/etapa-2/r12-coordenacao/activity-model-actions-diagnostic-r12.md | Definir/aplicar comando aprovado de Arquivar nos dois diretórios, com expected_version, escopo, auditoria e reload; não criar ação fake. |
| owner.r12-03 | activities.list | open / FE local-green: aba `Modelos de atividade` corrigida; `Atividades`, filtros, modos, paginação e ações preservados. / Contrato preservado, sem mutação nova. / Pending-verification: superfície mudou; rota normal/reload/escopo pendentes. | docs/reviews/evidence/etapa-2/r12-coordenacao/activities-list-tabs-r12.md | Conferir rota normal, os dois estados, filtros/paginação, reload e negativa cross-tenant. |
| owner.r12-04 | daily-routine.list, attendance.dashboard | open / Rota atual mantém Modelos/Rotinas/Lançamentos para o fluxo D7; Histórico separado não existe. / Dashboard e contratos preservados; nenhum SQL/RPC novo. / Pendente por definição de tela/rota canônica e mapeamento. | docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-history-diagnostic-r12.md | Definir rota/tela de Histórico com Owner, leitura autorizada, tabela/filtros/reload/escopo; só então separar Lançamentos sem quebrar D7. |
| owner.r12-05 | attendance.create | open / FE local-green: cascata Instituição/Unidade/Turma, Contexto Turma/Atividade, elegibilidade, data, foco e responsividade verificados. / Contrato preservado; servidor continua revalidando escopo/capacidade. / Pending-verification: rota normal, persistência/reload e escopo real pendentes. | docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-context-r12.md | Reproduzir com contexto real autorizado, atividade elegível, persistência/reload e negativa cross-tenant. |
| owner.r12-06 | attendance.create, daily-routine.apply | open / FE local-green: wizard reduzido a Contexto → Chamada; rotina vinculada resolvida pelo contexto autorizado e somente leitura. / Contrato server-side preservado; sem RPC/RLS novo. / Pending-verification: rota normal, rotina/versão, persistência/reload e negativa cross-tenant pendentes. | docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-routine-inline-r12.md | Reproduzir com contexto real autorizado, confirmar rotina efetiva/versionamento e snapshot no servidor, persistência/reload e negativa cross-tenant. |
| owner.r12-08 | attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | open / FE local-green: suíte local cobre save, edição, sentimento posterior, erro/retry, rotina pendente e conclusão. / Contratos preservados; nenhum SQL/RPC novo. / Pending-verification: rota normal, massa suficiente, persistência/reload e negativa cross-tenant pendentes. | docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-behavior-diagnostic-r12.md | Reproduzir pela rota normal com múltiplos alunos/turmas e rotina vinculada; registrar payload/versão, persistência/reload e negativa cross-tenant. |
| owner.r12-09 | child-safety.list | open / Diagnóstico: card já mostra identificação/contexto, situação textual, autorizações e pendências; alerta/restrição separado não existe no modelo. / Contrato preservado; nenhum SQL/RPC novo. / Owner decision pending antes de alterar composição ou dados. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-directory-diagnostic-r12.md | Aprovar campos operacionais autoritativos e então implementar com minimização, estados e escopo real. |
| owner.r12-10 | child-safety.list | open / Golden local falha em 1440px com 0,34%/4.857 px; nenhum código ou baseline alterado. / Contrato preservado; nenhum SQL/RPC novo. / Bloqueado por reconciliação visual e decisão sobre referência. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-table-golden-diagnostic-r12.md | Comparar aprovado/failure lado a lado, localizar diferença e corrigir ou obter decisão do Owner sem regenerar baseline por inferência. |
| owner.r12-11 | gate/mapeamento pendente | open / Cards já têm situação + Escopo máximo/Vínculos/Tipo em composição compacta; pages 15/15 PASS. / Contrato preservado; nenhum SQL/RPC novo. / Visual golden pendente de reconciliação; sem action_id novo. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-cards-diagnostic-r12.md | Comparar goldens aprovado/failure e confirmar com Owner se a composição 2×2 atende antes de alterar. |
| owner.r12-12 | child-safety.child | open / FE local-green: tabela distingue decisão e ciclo de vida em texto (`Aprovado · Ativa`) e preserva validade. / Contrato preservado; nenhum SQL/RPC novo. / Pending-verification: golden, rota normal, reload e escopo autorizado. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-authorization-status-r12.md | Revisar golden aprovado/failure e provar rota normal, reload e escopo autorizado da criança. |
| owner.r12-13 | child-safety.create, child-safety.edit | open / Wizard já usa FormFrame, painel único por etapa, grupos e rodapé canônicos; testes funcionais do wizard passam. / Contrato preservado; nenhum SQL/RPC novo. / Visual/E2E pendente para referência, rota normal, escopo e reload. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-composition-r12.md | Comparar referência e provar create/edit pela rota normal com ator/criança autorizados. |
| owner.r12-14 | child-safety.child | open / FE local-green: códigos mother/father/grandparent/other localizados somente na apresentação, com fallback. / Contrato preservado; nenhum SQL/RPC novo. / Pending-verification: locale, rota normal, reload e escopo autorizado. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-relationship-r12.md | Confirmar idioma suportado e provar rótulos na rota normal com dados autorizados. |
| owner.r12-15 | child-safety.child, child-safety.edit, child-safety.suspend | open / FE local-green: diálogo mostra identidade, contexto, relação, capacidades, motivo, decisão, ciclo de vida e validade; ações seguem condicionadas ao estado. / Contrato preservado; nenhum SQL/RPC novo. / Pending-verification: rota normal, auditoria/retry, reload e negativa cross-tenant. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-manage-context-r12.md | Provar estados pendente/aprovado ativo/suspenso pela rota normal e escopo do ator. |
| owner.r12-16 | child-safety.create | open / FE local-green: stepper bloqueia salto para etapa futura e permite retorno às concluídas; testes do wizard cobrem o fluxo. / Contrato preservado; nenhum SQL/RPC novo. / Pending-verification de rota normal e escopo. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | Provar teclado/rota normal sem salto e sem perda de dados. |
| owner.r12-17 | child-safety.create, child-safety.edit | open / Diagnóstico: campo atual ainda aceita identificador/UUID técnico; não existe contrato de busca autorizada por nome, CPF, e-mail ou celular. / Sem alteração backend; não criar busca fake. / Contract decision pending. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | Aprovar reader/contrato de busca e vínculo real antes de implementar. |
| owner.r12-18 | child-safety.create | open / Diagnóstico: pessoa global sem conta e campos mínimos/deduplicação não têm contrato definido. / Nenhuma tabela/RPC criada. / Contract decision pending. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | Definir obrigatoriedade, identificação, deduplicação, auditoria e escopo. |
| owner.r12-19 | gate/mapeamento pendente | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-19 e fontes antes de executar na R12 autorizada. |
| owner.r12-20 | access-profiles.list | partial / FE local-green: cards distribuem Status, Escopo máximo, Vínculos e Tipo em grade 2×2 responsiva, sem inventar métrica. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-cards-grid-r12-20.md | Provar rota normal, quantidade arbitrária de registros, golden aprovado, reload e negativa cross-tenant. |
| owner.r12-21 | access-profiles.detail | partial / FE local-green: detalhe traduz módulos, telas e ações para rótulos de produto, preservando código técnico fora do texto principal e ações próprias/todas. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-detail-labels-r12-21.md | Provar rota normal, catálogo real, golden aprovado, reload e negativa cross-tenant. |
| owner.r12-22 | access-profiles.create, access-profiles.edit | partial / FE local-green: campo Código removido do fluxo; identificador interno preservado/gerado. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-form-r12-22-26.md | Provar criação/edição pela rota normal, persistência/reload e negativa cross-tenant. |
| owner.r12-23 | access-profiles.create | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-23 e fontes antes de executar na R12 autorizada. |
| owner.r12-24 | access-profiles.create, access-profiles.edit | partial / FE local-green: marcador repetido Crítico/MFA removido; consequência de sensibilidade, MFA e trilha de auditoria explicada por tooltip acessível. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-permission-sensitivity-r12-24-25.md | Provar catálogo real, rota normal, foco/toque, persistência/reload e negativa cross-tenant. |
| owner.r12-25 | access-profiles.create, access-profiles.edit | partial / FE local-green: matriz compartilhada preserva colunas alinhadas e ações próprias/todas, com adaptação empilhada em telas estreitas. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-permission-sensitivity-r12-24-25.md | Provar catálogo real, rota normal, responsividade, persistência/reload e negativa cross-tenant. |
| owner.r12-26 | access-profiles.edit | partial / FE local-green: Continuar habilitado é FilledButton preenchido também na edição. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-form-r12-22-26.md | Provar rota normal e persistência da edição; aprovação visual do Owner permanece separada. |
| owner.r12-27 | access-profiles.create, access-profiles.edit | partial / FE local-green: revisão mostra módulo → tela → ação do catálogo, motivo de indisponibilidade e distinção entre configuração e acesso efetivo. / BE inalterado; conflito Principal em R12-23 separado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-review-r12-27.md | Conferir catálogo real/traduções, alcance, ações adiadas e salvar/reload sem perder próprias/todas. |
| owner.r12-29 | health-care.create, health-care.edit, health-care.detail | partial / FE verified em create/edit/detail com um registro de alergia; múltiplos registros independentes não exercitados na rota real. / BE done. / verified-e2e das ações; o apontamento de CRUD individual por registro segue aberto. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Exercitar dois registros de alergia independentes na rota real (adicionar/remover) e reload. |
| owner.r12-30 | health-care.create, health-care.edit, health-care.detail | partial / FE verified em create/edit/detail com uma orientação; múltiplas orientações independentes não exercitadas na rota real. / BE done. / verified-e2e das ações; o apontamento de CRUD individual por orientação segue aberto. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Exercitar duas orientações independentes na rota real e reload. |
| owner.r12-33 | medication.create, medication.edit, medication.detail | open / Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-33, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-34 | meal-plans.model-create, meal-plans.model-edit | partial / FE local-green: nome da refeição separado do prato, hidratado e serializado. / BE compatível sem mudança SQL. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/meal-name-r12-34.md | Provar adicionar/renomear/duplicar/reordenar e reload pela rota real. |
| owner.r12-35 | meal-plans.model-create, meal-plans.model-edit | partial / FE local-green: seletor canônico de datas específicas com chips ordenados e remoção individual; payload `specificDates` legado preservado. / BE compatível sem mudança SQL. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/meal-specific-dates-r12-35.md | Provar adicionar/editar/remover e reload pela rota real; RLS e aprovação visual permanecem pendentes. |
| owner.r12-36 | meal-plans.create, meal-plans.edit, meal-plans.publish | partial / FE local-green: Prioridade removida; CoeloDateTimeField preserva data/hora, hidrata em hora local e envia UTC. / BE contrato existente, sem SQL novo. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/meal-specific-dates-r12-35.md | Provar instante no Supabase real e visibilidade antes/depois da publicação agendada. |
| owner.r12-37 | meal-plans.create, meal-plans.edit | partial / FE local-green: Datas excluídas removidas do fluxo; dados históricos preservados no domínio/payload. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/meal-plan-form-r12-36-37.md | Provar edição sem apagar exceções históricas e reload real. |
| owner.r12-38 | meal-plans.create, meal-plans.edit, meal-plans.publish, meal-plans.model-edit | open / FE mantém envio desabilitado. / Adapter composto ainda usa Supabase Storage em upload/leitura, incompatível com R2 privado. / E2E não executado. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | C0 migrar SupabaseMealPlanImageRepository e contratos de vínculo para Media Gateway R2; depois habilitar composição e provar upload/reload/escopo. Não é apenas flag. |
| owner.r12-39 | forms.edit, forms.create | partial / FE local-green: arraste/movimentação e alternativas por botões preservadas. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/forms-editor-r12-39-40.md | Provar save/reload e posição final pela rota normal. |
| owner.r12-40 | forms.edit, forms.create | partial / FE local-green: seção pode ser renomeada por diálogo e o draft é atualizado. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/forms-editor-r12-39-40.md | Provar persistência/reload e nome na prévia pela rota normal. |
| owner.r12-42 | agenda.request | partial / FE local-green: tabela canônica com linha de 64 px, alinhamento compartilhado e histórico completo em diálogo. / BE preservado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/agenda-approvals-r12-42.md | Provar rota normal, decisão/reload e revisar goldens da tabela; investigar golden de calendário loading dark 375. |
| owner.r12-44 | invites.list | partial / FE local-green: tabela-only, cards/toggle removidos e busca/filtros/paginação/Novo convite preservados. / Contrato preservado; nenhum envio/reenvio executado. / Pending-verification: composição mudou e rota normal/reload/escopo precisam de nova prova. | docs/reviews/evidence/etapa-2/r12-coordenacao/invites-list-table-only-r12.md | Abrir rota normal QA, conferir tabela responsiva, busca/filtros/paginação/ações por linha, reload e negativa cross-tenant; não certificar por fixture. |
| owner.r12-45 | invites.resend | partial / FE local-green: `Reenviar convite` já encontrável na linha/detalhe expirado, com guards e recibo local. / RPC v2 e contrato preservados; nenhum envio real. / Pending-verification: falta convite expirado real, recibo, reload e escopo. | docs/reviews/evidence/etapa-2/r12-coordenacao/invites-resend-discovery-r12.md | Pela rota autorizada, preparar/localizar convite expirado permitido, reenviar uma vez, provar recibo/link de uso único, reload e negativa cross-tenant; não simular SMTP/Admin API. |
| owner.r12-46 | account.profile | partial / FE verified (rota real 14/09): sigla QE→QR salva e relida após reload, celular e cor exibidos. / BE remote-green (lote 63): sigla/cor/celular em produção; foto R2 ausente. / E2E aberto até a foto privada (R2) existir no BE. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Resolver gate SQL; aplicar contrato, implementar foto privada e provar foto/nome/sigla/cor, remover foto, grupos reais, reload e troca de sessão. Aprovação visual 14/09: A+ — colocar o card "Meu acesso" na mesma linha de "Dados pessoais" com rolagem interna (coelo-ui), depois foto R2. |
| owner.r12-47 | auth.recover, auth.reset | open / Verified histórico; pedido normal e endereço inexistente observados na R11. / Sem mensagem real na caixa acessível; SMTP próprio ausente e redirect local3000 fora da allowlist. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Obter acesso/configuração de caixa/SMTP/redirect; usar link real na UI e provar nova senha/sessão, expiração/uso único; preservar credencial QA privada. Não usar link Admin API como entrega SMTP. |
| owner.r12-49 | assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | partial / FE verified em entry/gradebook/detail (rota real 14/09): participante listada, nota 8.5 salva e relida. / BE done em entry/gradebook/detail (lote 63 + save pela tela); close/reopen local-green. / verified-e2e em entry/gradebook/detail; close/reopen pendentes na rota real. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; usar o mesmo diário d2c945d8, lançar/reler nota, fechar/reabrir com versão e provar escopo real. Não duplicar participante, vínculo, configuração ou diário. |
| owner.r12-52 | chat.attach | partial / FE local-green: mosaico por mensagem para múltiplas mídias visuais, contador de adicionais, tile único e anexos não visuais preservados. / Sem mudança backend; R2 privado, ownership e autorização existentes preservados. / Pending-verification: faltam rota normal, mídia R2/MP4 real, reload e negativa cross-tenant. | docs/reviews/evidence/etapa-2/r12-coordenacao/chat-attach-mosaic-r12.md | Abrir rota normal QA, provar mídia privada real, reload e negativa cross-tenant; não promover por fixture. |
| owner.r12-53 | gate/mapeamento pendente | open / Não iniciada; condição de abertura não atendida. / Não iniciado. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Somente considerar institutions.status OU institutions.locations-map após concluir Conta/Auth e os três blocos de Estrutura, com margem e escopo R12 autorizado. Não promover esta opção a tarefa obrigatória nem abrir outro macrotema. |

## Owner items — concluídos (9; não voltam à execução)

| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-07 | attendance.mark, attendance.correct, attendance.finish | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-28 | health-care.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): edição com o nome real da criança (correção 165d3df8c), sinal salvo (version 1→2) e relido após reload. |
| owner.r12-31 | medication.create, medication.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): criação Paracetamol R13 (10 ml, oral, vigência, 08:00, Seg/Qua) e edição da dose 5→7 ml da Dipirona R06, persistidas e relidas. Responsável depende de owner.r12-33 (R14). |
| owner.r12-32 | medication.list, medication.detail, medication.create, medication.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): diretório lista os planos reais por criança com contexto explícito; detalhe/criação/edição provados e relidos. |
| owner.r12-41 | forms.list | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-43 | chat.open | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-48 | activities.assessment, activities.publish | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Concluído 14/09 (rota real): rascunho b04c879e carregado e salvo pela tela (version 2→3), reload relê, negativa por id inexistente; activities.publish já era done. Capturas em r13-coordenacao/capturas. |
| owner.r12-50 | groups.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Concluído 14/09 (rota real): /groups com Alunos 1 e Atividades 3 na turma 4214106c, busca "R05" (hotfix lote 64), reload mantém, negativa por instituição alheia. Capturas em r13-coordenacao/capturas. |
| owner.r12-51 | gate/mapeamento pendente | done / Não aplicável. / Done (lote 63, 14/09): quatro candidatos aplicados em produção com dump SHA-256, espelho e pgTAP verdes, ledger 283→287. / Não aplicável. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Owner resolve exigência PITR da R11 versus ADR0034D8; C0 confirma regra vigente, configuração real, backup atualizado e ordem serial antes de aplicar. Transferir rodada não concede exceção ou autorização nova. |

## Resíduos H (herdados de R01–R07) — abertos (24)

| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H02 | noturna/R01 | Atualização oficial a partir do Sobre | Decidido (ADR 0038): conectar no MVP. Próximo gate: consumidor produtivo de ProfileAboutOfficialUpdateRequest e prova na rota normal. |
| H03 | noturna/R01 | Composição das quatro abas de Perfil | Comparar referência vigente e decidir consumidor produtivo. |
| H04 | R02/R07 | Compositor produtivo de Circular e blocos intercalados | Unificar host e provar na rota normal. |
| H07 | noturna/R01 | Hash de edição/revogação sem `conversation_id` | Executar replay/contexto na revisão de segurança. |
| H08 | R02 | Duplicar Aviso | Decidido (ADR 0038): Duplicar no MVP. Próximo gate: RPC de cópia para rascunho + botão no diretório/detalhe + prova. |
| H09 | R04/R06 | Disparo agendado de expiração Agora | Medir trigger real; leitura não basta. |
| H10 | noturna/R01 | Múltiplas regras de audiência em Formulários | Decidido (ADR 0038): preservar todas as regras de audiência. Próximo gate: editor lista/edita regras sem perder as demais + teste. |
| H11 | noturna/R01 | Autosave de autoria de Formulários | Decidido (ADR 0038): autosave do autor ligado. Próximo gate: host produtivo passa `authoringApi` + teste. |
| H12 | noturna/R01 | Controles de mínimo/máximo de seleção | Localizar contrato e registrar aceite. |
| H13 | noturna/R01 | Destino do CTA de Comunicação | Decidido (ADR 0038): CTA abre o detalhe do item relacionado. Próximo gate: destino por tipo no adaptador + prova. |
| H14 | R06 | Sino sem `action_id`/subaceite | Mapear ao action_id-pai sem novo denominador. |
| H15 | R06 | Atribuição de Plano | Decidido (ADR 0038): `plans.assign` fora do MVP. Fechado: botão honestamente indisponível. |
| H16 | R06 | Leitura people-based de cuidado | Provar escopo entre unidades. |
| H18 | R06 | Unicidade global concorrente de `@` | Revisar concorrência entre tabelas. |
| H19 | R06 | Responsável vazio em Medicação | Reproduzir com contexto e destinatário válidos. |
| H20 | R06 | Imagem da dose sem gateway | Localizar consumidor e obter prova específica. |
| H21 | R07 | Limite de texto/rodapé de Circular | Parcial em 14/09: **backend concluído (lote 68)** — `save_draft_v2` e constraint de `circular_revisions` em 4.000 somando blocos de texto; pgTAP 10/10; produção recusa 4.001 (`CIRCULAR_INVALID_INPUT`). Cliente `CircularLimits.bodyCharacters = 4000` (contador já somava blocos). Falta H04: host/rodapé em card/Opções conforme referência e regravação dos goldens web (18 goldens de circular já falhavam antes desta mudança). |
| H22 | noturna/R01 | Descritor privado de Circular | Alinhar à ADR 0032 e provar ausência de bucket público. |
| H23 | noturna/R01 | Continuidade visual de Avisos após refresh | Decidido (ADR 0038): manter lista + barra fina de progresso, padrão para todas as listas. Próximo gate: implementar em Avisos e registrar o padrão em coelo-ui. |
| H24 | noturna/R01 | Rótulos do Sobre | Comparar com referência vigente. |
| H25 | noturna/R01 | Alvo de redimensionamento de tabela | Medir teclado, semântica e toque. |
| H26 | noturna/R01 | Opcional, escala legada e opções vazias | Reconciliar contrato atual por caso. |
| H27 | noturna/R01 | Sinal de atualização de Momentos | Decidido (ADR 0038): saudação por hora do dia; ponto laranja na aba Momentos quando há momento não visto. Próximo gate: implementar no Principal + prova. |
| H28 | R01 | Filtros, avatar e buffers de Pessoas | Rever somente diferenças funcionais persistentes. |

## Resíduos H — concluídos (3)

| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H05 | noturna/R01 | Denominador histórico de recibos do Chat | Decidido (ADR 0038): recibos contam participantes ativos atuais. Fechado sem mudança; aceite MVP mantido. |
| H06 | noturna/R01 | Revogar em Chat somente leitura | **Concluído em 14/09 (lote 65)**: `superadmin_chat_revoke_message_v2` recusa `CHAT_READ_ONLY` no servidor; pgTAP 14/14 + suíte base 36/36 no espelho; guard presente em produção; negativa `CHAT_NOT_FOUND` por RPC. `chat.revoke` já era verified-e2e; sem delta de estado. |
| H17 | R06 | Papel fixo versus capacidade em cuidado | **Concluído em 14/09 (lote 66)**: capacidade `care_policies.manage` nos catálogos Superadmin (Owner) e Admin (Administrador da instituição); `superadmin_unit_care_policy_set_v1` exige só a capacidade; pgTAP 15/15 + base 20/20; get/set/reload em produção na unidade f5284f2f e negativa por unidade alheia. Sem action_id próprio no inventário (sem tela no cliente); sem delta de estado. |

## Itens da ADR 0038 sem ID H nem Owner item — abertos (5)

| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Identidade da mídia do Chat (`asset_id` no envelope) | Aberto | Pacote SQL aditivo em `authorize_read` + deploy da Edge Function `chat-media`; re-provar E2E do chat. |
| Catálogos globais de tipo (OQ-031) | Aberto | Migration idempotente por `code` com as quatro listas da ADR e "Outros"; entidade pode mudar de tipo. |
| Readers de Planos no principal 039 e reader self da Conta | Aberto | Readers somente leitura no principal interno; `units_with_override` só com cálculo comprovado. |
| Local interno em Formulários (IDs fixados na publicação; revisão conserva valor) | Aberto | Verificar contrato atual de `form_publish`/resposta; pacote só se faltar. |
| Auth: localhost na allowlist de redirect (R12-47) | Aberto | Configurar pelo CLI/painel; sem custo. |

## Itens da ADR 0038 — concluídos (2)

| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Anexos por mensagem no Chat (10 por envio) | **Concluído em 14/09 (lote 67)** | `superadmin_chat_attachment_prepare_v1` recusa o 11º pendente com `CHAT_ATTACHMENT_LIMIT` (422); pgTAP 9/9 + base 28/28; produção: 10 aceitos e 11º recusado na conversa 355a3403 (sintéticos arquivados); cliente mapeia `chat_attachment_limit` (243 testes do chat verdes). |
| Status de Suporte (OQ-028) | **Concluído em 14/09 (lote 69)** | `set_status` grava open/pending/resolved conforme o mapeamento A; trigger mantém `ticket_status` coerente (expired/revoked → Concluído); `closure_reason` em get/list; pgTAP 13/13 + bases 23/23, 28/28, 17/17; produção: chamado 6c5eb791 waiting→pending, completed→resolved. Cliente mostra “Concluído · Expirado/Revogado”. |

## Ações não terminais por família (inventário: 66 ações; FE/BE/E2E)

| Família | Qtd | action_ids |
|---|---:|---|
| access_profiles | 3 | `access-profiles.create` (local-green/done/pending-verification), `access-profiles.edit` (local-green/done/pending-verification), `access-profiles.assign` (pending-verification/done/pending-verification) |
| account | 2 | `account.profile` (verified/remote-green/pending-verification), `account.mfa` (pending-verification/gate-formal-mvp/gate-formal-mvp) |
| acontece | 1 | `acontece.create` (local-green/done/pending-verification) |
| activities | 2 | `activities.list` (local-green/done/pending-verification), `activities.publish` (local-green/done/pending-verification) |
| agenda | 1 | `agenda.request` (local-green/done/pending-verification) |
| agora | 4 | `agora.view` (verified/done/pending-verification), `agora.create` (local-green/local-green/pending-verification), `agora.publish` (pending-verification/local-green/pending-verification), `agora.expire` (pending-verification/local-green/pending-verification) |
| assessments | 2 | `assessments.close` (pending-verification/local-green/pending-verification), `assessments.reopen` (pending-verification/local-green/pending-verification) |
| attendance | 1 | `attendance.create` (local-green/done/pending-verification) |
| auth | 3 | `auth.recover` (verified/pending-verification/pending-verification), `auth.reset` (verified/pending-verification/pending-verification), `auth.mfa` (pending-verification/gate-formal-mvp/gate-formal-mvp) |
| catalog | 4 | `catalog.list` (verified/pending-verification/pending-verification), `catalog.validate` (verified/pending-verification/pending-verification), `catalog.sync` (verified/pending-verification/pending-verification), `catalog.publish` (pending-verification/pending-verification/pending-verification) |
| chat | 2 | `chat.create-group` (verified/done/pending-verification), `chat.attach` (local-green/local-green/pending-verification) |
| child_safety | 3 | `child-safety.child` (local-green/done/pending-verification), `child-safety.edit` (local-green/done/pending-verification), `child-safety.suspend` (local-green/done/pending-verification) |
| circulars | 1 | `circulars.attach` (local-green/done/pending-verification) |
| daily_routine | 1 | `daily-routine.apply` (local-green/done/pending-verification) |
| error_pages | 6 | `errors.403` (verified/pending-verification/pending-verification), `errors.404` (verified/pending-verification/pending-verification), `errors.409` (local-green/pending-verification/pending-verification), `errors.500` (verified/pending-verification/pending-verification), `errors.503` (verified/pending-verification/pending-verification), `errors.retry` (verified/pending-verification/pending-verification) |
| forms_authoring | 2 | `forms.create` (local-green/done/pending-verification), `forms.edit` (local-green/done/pending-verification) |
| forms_files | 4 | `forms.upload` (local-green/done/pending-verification), `forms.resolve-file` (local-green/done/pending-verification), `forms.expire-file` (pending-verification/local-green/pending-verification), `forms.delete-file` (pending-verification/local-green/pending-verification) |
| forms_responses | 1 | `forms.location-answer` (local-green/pending-verification/pending-verification) |
| institutions | 5 | `institutions.status` (pending-verification/pending-verification/pending-verification), `institutions.files` (pending-verification/pending-verification/pending-verification), `institutions.error` (pending-verification/local-green/pending-verification), `institutions.access-denied` (pending-verification/local-green/pending-verification), `institutions.locations-map` (pending-verification/local-green/pending-verification) |
| internal_users | 1 | `internal-users.mfa` (pending-verification/gate-formal-mvp/gate-formal-mvp) |
| invites | 2 | `invites.list` (local-green/done/pending-verification), `invites.resend` (local-green/done/pending-verification) |
| meal_plans | 5 | `meal-plans.create` (local-green/done/pending-verification), `meal-plans.edit` (local-green/done/pending-verification), `meal-plans.model-create` (local-green/done/pending-verification), `meal-plans.model-edit` (local-green/done/pending-verification), `meal-plans.publish` (local-green/done/pending-verification) |
| momentos | 4 | `momentos.view` (verified/done/pending-verification), `momentos.create` (local-green/local-green/blocked-environment), `momentos.publish` (pending-verification/local-green/pending-verification), `momentos.remove` (pending-verification/local-green/pending-verification) |
| plans | 1 | `plans.assign` (pending-verification/pending-verification/pending-verification) |
| principal_profile | 2 | `principal.for-you` (verified/blocked-decision/pending-verification), `principal.profile-edit` (local-green/blocked-decision/pending-verification) |
| shell | 1 | `shell.switch-context` (pending-verification/not-applicable/flutter-only) |
| units | 2 | `units.error` (pending-verification/local-green/pending-verification), `units.access-denied` (pending-verification/local-green/pending-verification) |

## Como atualizar

- Estado por `action_id`: só via `apply-tracker-delta.cjs` com evidência certificada (inventário → três rastreadores).
- Owner items: editar a linha aqui e rodar `node docs/reviews/etapa-2-operacao/next-round/sync-r12-owner-records.cjs`.
- H e itens da ADR: editar a linha aqui. Nunca editar R12/R13 (históricos).
- Validar sempre com `node docs/reviews/validate-trackers.cjs`.
