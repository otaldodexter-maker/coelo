---
source: Owner 2026-09-13 — consolidar R12/R13 como R12, Luna médio, commits e pendências
status: execução em andamento; C0 fechou dois aceites FE locais e mantém E2E aberto
generated_at: 2026-09-13
---

# R12 — Catálogo consolidado por camada

## R12-19 a R12-53 checkpoint de triagem (C0)

O catálogo completo foi percorrido até R12-53 e consolidado em
`docs/reviews/evidence/etapa-2/r12-coordenacao/r12-19-53-triage.md`. Os itens
continuam abertos quando o primeiro gate exige decisão do Owner, mapeamento,
contrato de produção ou prova integrada; nenhum SQL/deploy foi aplicado por
esta triagem.

53 IDs preservados:5 ajustes visuais entregues e48 abertos. C0 R12 é o responsável pela execução; decisões externas continuam com Owner. Nenhuma promoção funcional por consolidação.

| Item | action_ids | Estado / FE / BE / E2E | Prova preservada | Primeiro gate |
|---|---|---|---|---|
| owner.r12-01 | daily-routine.list | open / Planejado R12; não implementado. / Contratos a verificar; triagem golden encontrou apenas diferença no cabeçalho global, sem atribuir falha ao card. / Não executado para este apontamento. | docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-golden-diagnostic-r12.md; docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Estabilizar/reconciliar o cabeçalho global; depois comparar Modelos em referência autorizada e corrigir alturas/rodapés/ações sem regenerar baseline por inferência. |
| owner.r12-02 | activities.list, daily-routine.list | open / FE parcial: Duplicar existe em Atividades; Arquivar não tem callback/contrato no diretório. / Sem RPC/RLS novo; arquivamento não executado. / Pendente por contrato de archive, confirmação, versão, auditoria e reload. | docs/reviews/evidence/etapa-2/r12-coordenacao/activity-model-actions-diagnostic-r12.md | Definir/aplicar comando aprovado de Arquivar nos dois diretórios, com expected_version, escopo, auditoria e reload; não criar ação fake. |
| owner.r12-03 | activities.list | open / FE local-green: aba `Modelos de atividade` corrigida; `Atividades`, filtros, modos, paginação e ações preservados. / Contrato preservado, sem mutação nova. / Pending-verification: superfície mudou; rota normal/reload/escopo pendentes. | docs/reviews/evidence/etapa-2/r12-coordenacao/activities-list-tabs-r12.md | Conferir rota normal, os dois estados, filtros/paginação, reload e negativa cross-tenant. |
| owner.r12-04 | daily-routine.list, attendance.dashboard | open / Rota atual mantém Modelos/Rotinas/Lançamentos para o fluxo D7; Histórico separado não existe. / Dashboard e contratos preservados; nenhum SQL/RPC novo. / Pendente por definição de tela/rota canônica e mapeamento. | docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-history-diagnostic-r12.md | Definir rota/tela de Histórico com Owner, leitura autorizada, tabela/filtros/reload/escopo; só então separar Lançamentos sem quebrar D7. |
| owner.r12-05 | attendance.create | open / FE local-green: cascata Instituição/Unidade/Turma, Contexto Turma/Atividade, elegibilidade, data, foco e responsividade verificados. / Contrato preservado; servidor continua revalidando escopo/capacidade. / Pending-verification: rota normal, persistência/reload e escopo real pendentes. | docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-context-r12.md | Reproduzir com contexto real autorizado, atividade elegível, persistência/reload e negativa cross-tenant. |
| owner.r12-06 | attendance.create, daily-routine.apply | open / FE local-green: wizard reduzido a Contexto → Chamada; rotina vinculada resolvida pelo contexto autorizado e somente leitura. / Contrato server-side preservado; sem RPC/RLS novo. / Pending-verification: rota normal, rotina/versão, persistência/reload e negativa cross-tenant pendentes. | docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-routine-inline-r12.md | Reproduzir com contexto real autorizado, confirmar rotina efetiva/versionamento e snapshot no servidor, persistência/reload e negativa cross-tenant. |
| owner.r12-07 | attendance.mark, attendance.correct, attendance.finish | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
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
| owner.r12-20 | gate/mapeamento pendente | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-20 e fontes antes de executar na R12 autorizada. |
| owner.r12-21 | access-profiles.detail | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-21 e fontes antes de executar na R12 autorizada. |
| owner.r12-22 | access-profiles.create, access-profiles.edit | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-22 e fontes antes de executar na R12 autorizada. |
| owner.r12-23 | access-profiles.create | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-23 e fontes antes de executar na R12 autorizada. |
| owner.r12-24 | access-profiles.create, access-profiles.edit | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-24 e fontes antes de executar na R12 autorizada. |
| owner.r12-25 | access-profiles.create, access-profiles.edit | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-25 e fontes antes de executar na R12 autorizada. |
| owner.r12-26 | access-profiles.edit | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-26 e fontes antes de executar na R12 autorizada. |
| owner.r12-27 | access-profiles.create, access-profiles.edit | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-27 e fontes antes de executar na R12 autorizada. |
| owner.r12-28 | health-care.edit | open / Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-28, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-29 | health-care.create, health-care.edit, health-care.detail | open / Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-29, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-30 | health-care.create, health-care.edit, health-care.detail | open / Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-30, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-31 | medication.create, medication.edit | open / Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-31, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-32 | medication.list, medication.detail, medication.create, medication.edit | open / Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-32, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-33 | medication.create, medication.edit, medication.detail | open / Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-33, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-34 | meal-plans.model-create, meal-plans.model-edit | open / Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Reconciliar R12-34 e reproduzir após abertura explícita da R12. |
| owner.r12-35 | meal-plans.model-create, meal-plans.model-edit | open / Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Reconciliar R12-35 e reproduzir após abertura explícita da R12. |
| owner.r12-36 | meal-plans.create, meal-plans.edit, meal-plans.publish | open / Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Reconciliar R12-36 e reproduzir após abertura explícita da R12. |
| owner.r12-37 | meal-plans.create, meal-plans.edit | open / Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Reconciliar R12-37 e reproduzir após abertura explícita da R12. |
| owner.r12-38 | meal-plans.create, meal-plans.edit, meal-plans.publish, meal-plans.model-edit | open / Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Reconciliar R12-38 e reproduzir após abertura explícita da R12. |
| owner.r12-39 | forms.edit, forms.create | open / Planejado R12; sem implementação. / Sem diagnóstico novo. / Sem prova nova. | docs/reviews/etapa-2-operacao/next-round/R12-formularios-agenda-owner.md | Reconciliar R12-39, mapear e reproduzir na R12 autorizada. |
| owner.r12-40 | forms.edit, forms.create | open / Planejado R12; sem implementação. / Sem diagnóstico novo. / Sem prova nova. | docs/reviews/etapa-2-operacao/next-round/R12-formularios-agenda-owner.md | Reconciliar R12-40, mapear e reproduzir na R12 autorizada. |
| owner.r12-41 | forms.list | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-42 | gate/mapeamento pendente | open / Planejado R12; sem implementação. / Sem diagnóstico novo. / Sem prova nova. | docs/reviews/etapa-2-operacao/next-round/R12-formularios-agenda-owner.md | Reconciliar R12-42, mapear e reproduzir na R12 autorizada. |
| owner.r12-43 | chat.open | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-44 | invites.list | open / FE local-green: tabela-only, cards/toggle removidos e busca/filtros/paginação/Novo convite preservados. / Contrato preservado; nenhum envio/reenvio executado. / Pending-verification: composição mudou e rota normal/reload/escopo precisam de nova prova. | docs/reviews/evidence/etapa-2/r12-coordenacao/invites-list-table-only-r12.md | Abrir rota normal QA, conferir tabela responsiva, busca/filtros/paginação/ações por linha, reload e negativa cross-tenant; não certificar por fixture. |
| owner.r12-45 | invites.resend | open / FE local-green: `Reenviar convite` já encontrável na linha/detalhe expirado, com guards e recibo local. / RPC v2 e contrato preservados; nenhum envio real. / Pending-verification: falta convite expirado real, recibo, reload e escopo. | docs/reviews/evidence/etapa-2/r12-coordenacao/invites-resend-discovery-r12.md | Pela rota autorizada, preparar/localizar convite expirado permitido, reenviar uma vez, provar recibo/link de uso único, reload e negativa cross-tenant; não simular SMTP/Admin API. |
| owner.r12-46 | account.profile | open / Parcial: rodapé/busca, nome, crop e confirmação autoritativa testados. / Sigla/cor/metadados em candidato local; foto R2 ausente. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Resolver gate SQL; aplicar contrato, implementar foto privada e provar foto/nome/sigla/cor, remover foto, grupos reais, reload e troca de sessão. |
| owner.r12-47 | auth.recover, auth.reset | open / Verified histórico; pedido normal e endereço inexistente observados na R11. / Sem mensagem real na caixa acessível; SMTP próprio ausente e redirect local3000 fora da allowlist. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Obter acesso/configuração de caixa/SMTP/redirect; usar link real na UI e provar nova senha/sessão, expiração/uso único; preservar credencial QA privada. Não usar link Admin API como entrega SMTP. |
| owner.r12-48 | activities.assessment, activities.publish | open / UPDATE do rascunho retido falha; publicação sem novo aceite. / Correção causal local8/8 pgTAP; publicação BE done histórico. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; salvar/reler o mesmo b04c879e e fechar a cadeia de configuração/publicação. Atividade95b98978 já active: não recriar ou alternar status para inflar avanço. |
| owner.r12-49 | assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | open / Aluno ausente reproduzido; prova remota pendente. / Candidato all/selected13/13 pgTAP; local-green preservado. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; usar o mesmo diário d2c945d8, lançar/reler nota, fechar/reabrir com versão e provar escopo real. Não duplicar participante, vínculo, configuração ou diário. |
| owner.r12-50 | groups.list | open / Zeros incorretos reproduzidos; UI/reload pendentes. / Candidato10/10 pgTAP para contagens, herança, status e isolamento. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar projeção após gate SQL e conferir contadores na turma4214106c com vínculos ativos e reload. Aceite antigo da listagem não cobre contadores. |
| owner.r12-51 | gate/mapeamento pendente | open / Não aplicável. / Quatro candidatos locais; nenhum aplicado remotamente. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Owner resolve exigência PITR da R11 versus ADR0034D8; C0 confirma regra vigente, configuração real, backup atualizado e ordem serial antes de aplicar. Transferir rodada não concede exceção ou autorização nova. |
| owner.r12-52 | chat.attach | open / FE local-green: mosaico por mensagem para múltiplas mídias visuais, contador de adicionais, tile único e anexos não visuais preservados. / Sem mudança backend; R2 privado, ownership e autorização existentes preservados. / Pending-verification: faltam rota normal, mídia R2/MP4 real, reload e negativa cross-tenant. | docs/reviews/evidence/etapa-2/r12-coordenacao/chat-attach-mosaic-r12.md | Abrir rota normal QA, provar mídia privada real, reload e negativa cross-tenant; não promover por fixture. |
| owner.r12-53 | gate/mapeamento pendente | open / Não iniciada; condição de abertura não atendida. / Não iniciado. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Somente considerar institutions.status OU institutions.locations-map após concluir Conta/Auth e os três blocos de Estrutura, com margem e escopo R12 autorizado. Não promover esta opção a tarefa obrigatória nem abrir outro macrotema. |

## R12-52 checkpoint de execução (C0)

FE local-green nesta fatia: o consumidor agrupa múltiplas mídias visuais da
mesma mensagem em mosaico de até três itens, com contador de adicionais;
single-media e anexos não visuais permanecem no tile existente. Provas:
32+21+4 testes PASS e `flutter analyze --no-fatal-infos` sem issues.
Backend permanece inalterado e E2E não certificado; faltam rota normal, upload
MP4 real, reload e negativa cross-tenant. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/chat-attach-mosaic-r12.md`.

## R12-44 checkpoint de execução (C0)

FE local-green nesta fatia: Convites renderiza somente a tabela canônica;
cards e toggle foram removidos, preservando busca, filtros, paginação, Novo
convite e ações por linha. `flutter test
test/features/invites/invite_directory_page_test.dart` passou 24/24 e o golden
do diretório compartilhado passou 14/14. `flutter analyze --no-fatal-infos`
foi reexecutado após remover um import de teste não usado.

Nenhum contrato Supabase, RPC, RLS, envio ou reenvio foi alterado. Como a
composição substitui a superfície anteriormente certificada, o integrado foi
reaberto para `pending-verification`; faltam rota normal QA, reload e negativa
cross-tenant. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/invites-list-table-only-r12.md`.

## R12-45 checkpoint de execução (C0)

FE local-green de descoberta: `Reenviar convite` aparece no menu da linha e
no detalhe expirado quando `canResend` permite; pending vigente permanece sem
reenvio. O comando conserva `requestId`, `managementVersion`, RPC
`superadmin_invite_resend_v2` e link somente em diálogo temporário. Provas:
detalhe 32 PASS, repositório 13 PASS e diretório R12-44 24 PASS.

Não houve envio real nem alteração backend. O integrado segue
`pending-verification`: falta convite expirado real na rota normal, recibo,
reload e negativa cross-tenant. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/invites-resend-discovery-r12.md`.

## Triagem do próximo gate R12-01

Os goldens de Rotina diária foram executados, mas as diferenças isoladas
ficaram somente no cabeçalho global do Superadmin (avatar/ícones/texto), fora
da área de Modelos. Nenhum baseline foi regenerado e nenhum código foi
alterado. O diagnóstico está em
`docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-golden-diagnostic-r12.md`;
R12-01 permanece aberto até estabilizar essa referência e então comparar o
card/rodapé/ações do recorte autorizado.

## R12-03 checkpoint de execução (C0)

FE local-green: a aba de modelos do diretório de Atividades agora se chama
`Modelos de atividade`, preservando `Atividades`, filtros, modos, paginação e
ações. TDD falhou com o label antigo e a suíte do diretório passou 23/23.
Backend inalterado; integrado reaberto para pending-verification até rota
normal, reload e negativa cross-tenant. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/activities-list-tabs-r12.md`.

## R12-02 checkpoint de execução (C0)

Duplicar modelo está disponível em cards/tabela e coberto pela suíte de
Atividades. Arquivar não possui callback nem contrato de comando no diretório
de Atividades; o status archived somente lido não autoriza inventar mutação.
Nenhum código/backend foi alterado nesta triagem. Evidência e próximo gate:
`docs/reviews/evidence/etapa-2/r12-coordenacao/activity-model-actions-diagnostic-r12.md`.

## R12-04 checkpoint de execução (C0)

A aba `Lançamentos` ainda é dependência do fluxo D7 de criar/publicar o
lançamento; não existe tela/rota separada de Histórico de chamadas no
Superadmin. Remover ou inventar uma nova tela agora quebraria o fluxo ou
criaria escopo não aprovado. Nenhum código/backend foi alterado. Diagnóstico:
`docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-history-diagnostic-r12.md`.

## R12-05 checkpoint de execução (C0)

O fluxo de Nova chamada já possui a cascata Instituição → Unidade → Turma,
Contexto Turma/Atividade e dependências de atividade, com guards locais e
revalidação server-side preservadas. A suíte de `attendance_pages_test.dart`
passou 58/58, incluindo estados de erro, retry, foco, troca de repositório,
elegibilidade e responsividade. Nenhum código/backend foi alterado; E2E segue
pending-verification. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-context-r12.md`.

## R12-06 checkpoint de execução (C0)

O wizard de Nova chamada foi reduzido a `Contexto → Chamada`, removendo a
etapa separada `Rotina diária`. A rotina vinculada permanece somente leitura e
é resolvida pelo contexto autorizado; a resolução efetiva, versão e snapshot
continuam no contrato server-side. A suíte de `attendance_pages_test.dart`
passou 57/57 e `flutter analyze --no-fatal-infos` passou sem issues. E2E segue
pending-verification para rota normal, persistência/reload e negativa
cross-tenant. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-routine-inline-r12.md`.

## R12-08 checkpoint de execução (C0)

A suíte local existente cobre os relatos de comportamento com massa sintética:
save explícito por participante, edição/correção, sentimento posterior,
erro/retry, rotina pendente, conclusão e proteção contra respostas obsoletas.
Passou 57/57 e a análise estática passou sem issues. Não houve reprodução
remota pela rota normal nem mudança de SQL/RPC; o item permanece aberto para
múltiplos alunos/turmas, persistência/reload e negativa cross-tenant.
Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-behavior-diagnostic-r12.md`.

## Dívidas transversais preservadas

Circulares:4 goldens falhos também na base; reconciliar referência/fixture na fatia correspondente. Validador visual:20 achados iguais à base, sem ampliar allowlist. Evidências em docs/reviews/evidence/etapa-2/r12-coordenacao/. Compromissos anteriores adicionais permanecem em entrega-atual.json e matrizes; não desaparecem do plano Etapa2.
