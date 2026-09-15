---
title: "R14 — fila única consolidada da Etapa 2"
source: "Owner em 2026-09-14 (consolidar R12/R13 numa única fila); Owner em 2026-09-15 (ADR 0039 e ADR 0040); R12-pendencias.md (tabela Owner, 53 IDs); R13-pendencias.md (H02–H28, itens da ADR 0038); inventario-etapa-2.json (estados certificados por action_id); R14-catalogo.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-15"
audience: "team"
---

# R14 — fila única consolidada

> **Este é o único arquivo vivo de pendências da Etapa 2.** `R12-pendencias.md` e
> `R13-pendencias.md` estão congelados como histórico. A tabela de Owner items abaixo
> é a fonte lida por `sync-r12-owner-records.cjs` (53 linhas, IDs preservados);
> `docs/reviews/inventario-etapa-2.json` continua a fonte dos estados por `action_id`.
> Regra: item `done` fica registrado aqui apenas para contagem e não volta à execução;
> item `open`/`partial`/bloqueado é a fila. Não criar cópias em outros arquivos.

Contadores certificados pelo inventário e `validate-trackers.cjs` em
15/09/2026, após o delta oficial de Avaliações: FE 186/232
(80,17%), BE 168/225 (74,67%), E2E 159/193 (82,38%), Owner 15/53
(28,30%). O denominador integrado ativo é 193 após o Bloco B e a formalização
de `agora.remove`. Cardápios tem
prova FE/BE/E2E publicada, mas seus quatro Owner items permanecem `partial`
até o aceite central desta coordenação; não entram artificialmente no 15/53.

## Ordem de execução (decisão do Owner de 14/09, ajustada: fechar primeiro o mais fácil e rápido)

**Bloco A — concluído (10/10 na rota real; FE/BE/E2E certificados conforme aplicável):**
1. Circulares › Anexos (`circulars.attach`) → Circulares 11/11.
2. Agenda › Solicitar (`agenda.request`) → Agenda 7/7.
3. Assiduidade › Nova chamada (`attendance.create`) → Assiduidade 5/5.
4. Rotina › Aplicar (`daily-routine.apply`) → Rotina 5/5.
5. Acontece › Criar (`acontece.create`) → Acontece 4/4.
6. Shell › Troca de contexto (`shell.switch-context`, flutter-only) → Shell 5/5.
7. Atividades › Diretório + Publicar (`activities.list/publish`) → Atividades 7/7.
8. Convites › Lista + Reenviar (`invites.list/resend`) → Convites 5/5.
9. Chat › Criar grupo (`chat.create-group`).
10. Unidades › Erro + Acesso negado (`units.error/access-denied`) → Unidades 10/10.

**Bloco B — reclassificação autorizada pelo Owner em 15/09 (alvo: E2E ativo 199 → 192; FE 231 e BE 224 ficam):**
O delta controlado já foi aplicado ao inventário certificado; o denominador
ativo agora é 192. As sete ações foram marcadas `deferred-post-mvp` no escopo
autorizado e não bloqueiam a execução do MVP.
11. `plans.assign`, `institutions.status`, `institutions.locations-map`, `auth/account/internal-users.mfa`
    → `deferred-post-mvp`/`gate-formal-mvp`; Catálogo de UI (`catalog.*`) → V1/Etapa 3.
    Fecha Planos 4/4 e Usuários internos 4/4.

**Bloco C — uma tela com SQL pequeno + rota real:**
12. Cardápios (`meal-plans.create/edit/model-create/model-edit/publish`) → FE/BE/E2E provados pela Sessão 2; `owner.r12-34/35/36/37` aguardam aceite central, sem repetir a prova.
13. Avaliações › Fechar/Reabrir (`assessments.close/reopen`) — a Sessão C
    publicou a entrega, mas o item voltou a `pending-verification` por
    divergência de alvo CDP; não promover sem rota real, sessão autenticada e
    evidência central reconciliada.
14. Perfis de acesso (`access-profiles.create/edit/assign`) + `owner.r12-19` a `27`.
15. Segurança infantil (`child-safety.child/edit/suspend`, BE done) — sem r12-18.
16. Arquivos de Formulários › Upload + Resolver (só E2E); depois Expirar/Excluir (BE + FE).

**Bloco D — entregue tecnicamente; aceite central pendente:**
17. OQ-031 catálogos de tipo, reader self da Conta e `owner.r12-29/30` foram
    provados pela Sessão D em produção, no branch `r14/bloco-cd`, SHA
    `b135c8f20`: pgTAP remoto 11/11, 6/6 e 6/6, respectivamente. As coleções
    aceitam registros independentes e rejeitam o 101º por entidade/coleção.
    Falta integrar seletivamente os artefatos ao `dev` e obter o aceite central;
    os contadores não mudam neste corte. H08/H13/H23 foram transferidos para
    R15 por decisão do Owner, sem inventar contrato ausente. Reader de Planos
    comerciais e recuperação/reset de Auth não entram na R14.

**Bloco E — mais caros (contrato novo ou reconstrução):**
18. Conta: A+ do layout "Meu acesso" + foto R2 (`account.profile`). Recuperação/
    redefinição (`auth.recover/reset`) ficam reservadas para a Etapa 3.
19. Circular `H04` (host + goldens); Formulários `H10` (+ `H11` só se >60% pronto); Principal `H27/P54/H02`.
20. Chat › Anexar (`chat.attach`: asset_id + Edge Function); Agora e Momentos (mídia R2/Stream real); Agora › Remover (`agora.remove`: remoção imediata);
    `owner.r12-33` medicação; `owner.r12-18` pessoa sem conta; páginas de erro (BE/E2E).
21. Gates de medição: `H03`, `H07`, `H09`, `H12`, `H14`, `H16`, `H18`–`H20`, `H22`, `H24`–`H26`, `H28`.

`agora.remove` foi formalizado pela ADR 0040 como ação MVP separada: remoção
explícita imediata, revogação no catálogo/gateway e purge idempotente do objeto
R2 e da cópia Stream, preservando catálogo/recibo/auditoria. O action_id está
no inventário como `pending-verification`; não há implementação nem aceite
produtivo neste corte.

## Aprovação visual do Owner — 14/09/2026 (artefato 5218230f, SHA a952f3ff9) — 6/6 decididas: 5 A, 1 A+

| Tela | action_ids | Decisão | Observação / gate |
|---|---|---|---|
| Estrutura › Turmas › Diretório | groups.list | **A** | — |
| Atividades › Lançar avaliações | assessments.entry/gradebook/detail | **A** | — |
| Saúde e Cuidado › Planos de medicação | medication.list/create/detail/edit | **A** | — |
| Cabeçalho › Meu perfil | account.profile | **A+** | Owner: "o contêiner do Meu Acesso pode ficar na mesma linha que Dados pessoais e ter a rolagem para ir descendo" → correção de layout obrigatória (coelo-ui), entra em `owner.r12-46`. |
| Atividades › Configuração avaliativa | activities.assessment | **A** | — |
| Saúde e Cuidado › Perfis de cuidado | health-care.create/detail/edit | **A** | — |

## Owner items — abertos/parciais e atualizações da execução (38)

| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-01 | daily-routine.list | open / Planejado R12; não implementado. / Contratos a verificar; triagem golden encontrou apenas diferença no cabeçalho global, sem atribuir falha ao card. / Não executado para este apontamento. | docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-golden-diagnostic-r12.md; docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Estabilizar/reconciliar o cabeçalho global; depois comparar Modelos em referência autorizada e corrigir alturas/rodapés/ações sem regenerar baseline por inferência. |
| owner.r12-02 | activities.list, daily-routine.list | open / FE parcial: Duplicar existe em Atividades; Arquivar não tem callback/contrato no diretório. / Sem RPC/RLS novo; arquivamento não executado. / Pendente por contrato de archive, confirmação, versão, auditoria e reload. | docs/reviews/evidence/etapa-2/r12-coordenacao/activity-model-actions-diagnostic-r12.md | Definir/aplicar comando aprovado de Arquivar nos dois diretórios, com expected_version, escopo, auditoria e reload; não criar ação fake. |
| owner.r12-04 | daily-routine.list, attendance.dashboard | open / Rota atual mantém Modelos/Rotinas/Lançamentos para o fluxo D7; Histórico separado não existe. / Dashboard e contratos preservados; nenhum SQL/RPC novo. / Pendente por definição de tela/rota canônica e mapeamento. | docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-history-diagnostic-r12.md | Definir rota/tela de Histórico com Owner, leitura autorizada, tabela/filtros/reload/escopo; só então separar Lançamentos sem quebrar D7. |
| owner.r12-05 | attendance.create | partial / FE verified (rota real 15/09): cascata Instituição/Unidade/Turma/Contexto com contexto real, data, chamada criada e relida. / BE done; superadmin_attendance_context_options devolve a única atividade elegível (95b98978) com escopo 190dd028/f5284f2f/4214106c ausente das listas institutions/units/groups — inconsistência de escopo na RPC ou de massa. / verified-e2e de attendance.create com contexto Turma; contexto Atividade não exercitável até corrigir a RPC/massa. | docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-context-r12.md | Sessão 2/R15: alinhar o escopo de activities ao de groups em superadmin_attendance_context_options (ou massa elegível na QA R04) e provar contexto Atividade pela tela. |
| owner.r12-06 | attendance.create, daily-routine.apply | partial / FE verified (rota real 15/09): wizard Contexto → Chamada sem etapa de rotina; texto "rotina resolvida pelo contexto autorizado". / BE done; superadmin_attendance_call_detail não expõe rotina/aplicação/versão e a rota de produção não injeta rotina na chamada — o vínculo efetivo não é observável por contrato. / verified-e2e de attendance.create; rotina efetiva/versionamento/snapshot exigem contrato novo. | docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-routine-inline-r12.md | R15: definir contrato de leitura da rotina efetiva na chamada (SQL) antes de provar rotina/versão/snapshot. |
| owner.r12-08 | attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | partial / FE verified em mark/finish na rota real 15/09 (chamada cd60f2d8: presente salvo, reload, concluída). / Contratos preservados; set_participant v2 e complete_call v3 em produção. / Pendente só a massa: as turmas do escopo têm no máximo 1 aluno; múltiplos alunos/turmas e rotina vinculada não exercitados. | docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-behavior-diagnostic-r12.md | Criar vínculos criança↔turma adicionais (tela de Segurança infantil ou massa da Sessão 2) e repetir com ≥2 alunos; rotina vinculada depende de r12-06. |
| owner.r12-09 | child-safety.list | open / Diagnóstico: card já mostra identificação/contexto, situação textual, autorizações e pendências; alerta/restrição separado não existe no modelo. / Contrato preservado; nenhum SQL/RPC novo. / Owner decision pending antes de alterar composição ou dados. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-directory-diagnostic-r12.md | Aprovar campos operacionais autoritativos e então implementar com minimização, estados e escopo real. |
| owner.r12-10 | child-safety.list | open / Golden local falha em 1440px com 0,34%/4.857 px; nenhum código ou baseline alterado. / Contrato preservado; nenhum SQL/RPC novo. / Bloqueado por reconciliação visual e decisão sobre referência. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-table-golden-diagnostic-r12.md | Comparar aprovado/failure lado a lado, localizar diferença e corrigir ou obter decisão do Owner sem regenerar baseline por inferência. |
| owner.r12-11 | gate/mapeamento pendente | open / Cards já têm situação + Escopo máximo/Vínculos/Tipo em composição compacta; pages 15/15 PASS. / Contrato preservado; nenhum SQL/RPC novo. / Visual golden pendente de reconciliação; sem action_id novo. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-cards-diagnostic-r12.md | Comparar goldens aprovado/failure e confirmar com Owner se a composição 2×2 atende antes de alterar. |
| owner.r12-13 | child-safety.create, child-safety.edit | open / Wizard já usa FormFrame, painel único por etapa, grupos e rodapé canônicos; testes funcionais do wizard passam. / Contrato preservado; nenhum SQL/RPC novo. / Visual/E2E pendente para referência, rota normal, escopo e reload. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-composition-r12.md | Comparar referência e provar create/edit pela rota normal com ator/criança autorizados. |
| owner.r12-15 | child-safety.child, child-safety.edit, child-safety.suspend | partial / FE verified no estado suspenso (rota real 15/09): diálogo com identidade, contexto, relação, capacidades, motivo, decisão, situação, validade e só Concluir. / BE: child_safety_change_lifecycle responde 504 (timeout) em produção — bloqueio para Sessão 2 (SQL/espelho). / child verified-e2e; suspend blocked-backend; estados pendente e aprovado-ativo não exercitados. | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-manage-context-r12.md | Sessão 2: diagnosticar o 504 de change_lifecycle no espelho; depois criar autorização pendente pelo wizard, aprovar e suspender pela tela para fechar r12-15/13/16. |
| owner.r12-16 | child-safety.create | open / FE local-green: stepper bloqueia salto para etapa futura e permite retorno às concluídas; testes do wizard cobrem o fluxo. / Contrato preservado; nenhum SQL/RPC novo. / Pending-verification de rota normal e escopo. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | Provar teclado/rota normal sem salto e sem perda de dados. |
| owner.r12-17 | child-safety.create, child-safety.edit | open / Diagnóstico: campo atual ainda aceita identificador/UUID técnico; não existe contrato de busca autorizada por nome, CPF, e-mail ou celular. / Sem alteração backend; não criar busca fake. / Contract decision pending. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | Aprovar reader/contrato de busca e vínculo real antes de implementar. |
| owner.r12-18 | child-safety.create | open / Diagnóstico: pessoa global sem conta e campos mínimos/deduplicação não têm contrato definido. / Nenhuma tabela/RPC criada. / Contract decision pending. | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | Definir obrigatoriedade, identificação, deduplicação, auditoria e escopo. |
| owner.r12-19 | gate/mapeamento pendente | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-19 e fontes antes de executar na cota R14 autorizada. |
| owner.r12-20 | access-profiles.list | partial / FE local-green: cards distribuem Status, Escopo máximo, Vínculos e Tipo em grade 2×2 responsiva, sem inventar métrica. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-cards-grid-r12-20.md | Provar rota normal, quantidade arbitrária de registros, golden aprovado, reload e negativa cross-tenant. |
| owner.r12-21 | access-profiles.detail | partial / FE local-green: detalhe traduz módulos, telas e ações para rótulos de produto, preservando código técnico fora do texto principal e ações próprias/todas. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-detail-labels-r12-21.md | Provar rota normal, catálogo real, golden aprovado, reload e negativa cross-tenant. |
| owner.r12-22 | access-profiles.create, access-profiles.edit | partial / FE local-green: campo Código removido do fluxo; identificador interno preservado/gerado. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-form-r12-22-26.md | Provar criação/edição pela rota normal, persistência/reload e negativa cross-tenant. |
| owner.r12-23 | access-profiles.create | open / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-23 e fontes antes de executar na cota R14 autorizada. |
| owner.r12-24 | access-profiles.create, access-profiles.edit | partial / FE local-green: marcador repetido Crítico/MFA removido; consequência de sensibilidade, MFA e trilha de auditoria explicada por tooltip acessível. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-permission-sensitivity-r12-24-25.md | Provar catálogo real, rota normal, foco/toque, persistência/reload e negativa cross-tenant. |
| owner.r12-25 | access-profiles.create, access-profiles.edit | partial / FE local-green: matriz compartilhada preserva colunas alinhadas e ações próprias/todas, com adaptação empilhada em telas estreitas. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-permission-sensitivity-r12-24-25.md | Provar catálogo real, rota normal, responsividade, persistência/reload e negativa cross-tenant. |
| owner.r12-26 | access-profiles.edit | partial / FE local-green: Continuar habilitado é FilledButton preenchido também na edição. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-form-r12-22-26.md | Provar rota normal e persistência da edição; aprovação visual do Owner permanece separada. |
| owner.r12-27 | access-profiles.create, access-profiles.edit | partial / FE local-green: revisão mostra módulo → tela → ação do catálogo, motivo de indisponibilidade e distinção entre configuração e acesso efetivo. / BE inalterado; conflito Principal em R12-23 separado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-review-r12-27.md | Conferir catálogo real/traduções, alcance, ações adiadas e salvar/reload sem perder próprias/todas. |
| owner.r12-29 | health-care.create, health-care.edit, health-care.detail | partial / Sessão D provou em produção a coleção independente de alergias, com IDs, adicionar/remover/reload e compatibilidade legada; pgTAP remoto 6/6 e limite backend de 100, com rejeição do 101º. / BE done. / verified-e2e das ações; aceite central ainda pendente. | `origin/r14/bloco-cd` em `b135c8f20`, handoff e evidência `r14-sessao-2/block-d-20260915.md` | Integrar seletivamente a evidência ao `dev` e registrar aceite central; não reduzir o contrato a dois registros. |
| owner.r12-30 | health-care.create, health-care.edit, health-care.detail | partial / Sessão D provou em produção a coleção independente de orientações, com IDs, adicionar/remover/reload e compatibilidade legada; pgTAP remoto 6/6 e limite backend de 100, com rejeição do 101º. / BE done. / verified-e2e das ações; aceite central ainda pendente. | `origin/r14/bloco-cd` em `b135c8f20`, handoff e evidência `r14-sessao-2/block-d-20260915.md` | Integrar seletivamente a evidência ao `dev` e registrar aceite central; não reduzir o contrato a dois registros. |
| owner.r12-34 | meal-plans.model-create, meal-plans.model-edit | partial / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md | Sessão 2 publicou a prova de camada na rota real; aceite central do Owner ainda não foi incorporado ao contador desta coordenação. Não repetir a prova; imagem R2 segue em owner.r12-38. |
| owner.r12-35 | meal-plans.model-create, meal-plans.model-edit | partial / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md | Sessão 2 publicou a prova de camada na rota real; aceite central do Owner ainda não foi incorporado ao contador desta coordenação. Não repetir a prova. |
| owner.r12-36 | meal-plans.create, meal-plans.edit, meal-plans.publish | partial / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md | Sessão 2 publicou a prova de camada na rota real; aceite central do Owner ainda não foi incorporado ao contador desta coordenação. Não repetir a prova. |
| owner.r12-37 | meal-plans.create, meal-plans.edit | partial / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md | Sessão 2 publicou a prova de camada na rota real; aceite central do Owner ainda não foi incorporado ao contador desta coordenação. Não repetir a prova. |
| owner.r12-33 | medication.create, medication.edit, medication.detail | open / Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-33, reproduzir e desenhar contrato focal na cota R14 autorizada. |
| owner.r12-38 | meal-plans.create, meal-plans.edit, meal-plans.publish, meal-plans.model-edit | open / FE mantém envio desabilitado. / Adapter composto ainda usa Supabase Storage em upload/leitura, incompatível com R2 privado. / E2E não executado. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | C0 migrar SupabaseMealPlanImageRepository e contratos de vínculo para Media Gateway R2; depois habilitar composição e provar upload/reload/escopo. Não é apenas flag. |
| owner.r12-39 | forms.edit, forms.create | partial / FE local-green: arraste/movimentação e alternativas por botões preservadas. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/forms-editor-r12-39-40.md | Provar save/reload e posição final pela rota normal. |
| owner.r12-40 | forms.edit, forms.create | partial / FE local-green: seção pode ser renomeada por diálogo e o draft é atualizado. / BE inalterado. / E2E pending-verification. | docs/reviews/evidence/etapa-2/r12-coordenacao/forms-editor-r12-39-40.md | Provar persistência/reload e nome na prévia pela rota normal. |
| owner.r12-46 | account.profile | partial / FE verified (rota real 14/09): sigla QE→QR salva e relida após reload, celular e cor exibidos. / BE remote-green (lote 63): sigla/cor/celular em produção; foto R2 ausente. / E2E aberto até a foto privada (R2) existir no BE. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Resolver gate SQL; aplicar contrato, implementar foto privada e provar foto/nome/sigla/cor, remover foto, grupos reais, reload e troca de sessão. A confirmação deve atualizar também o avatar global do cabeçalho; rascunho local não pode aparentar sucesso quando o servidor não confirmou. O Celular permanece obrigatório e precisa de máscara/formato de entrada, normalização e prova de valor inválido/válido. Aprovação visual 14/09: A+ — colocar o card "Meu acesso" na mesma linha de "Dados pessoais" com rolagem interna (coelo-ui), depois foto R2. |
| owner.r12-47 | auth.recover, auth.reset | open / Verified histórico; pedido normal e endereço inexistente observados na R11. / Sem mensagem real na caixa acessível; SMTP próprio ausente e redirect local3000 fora da allowlist. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Transferido para Etapa 3 pela ADR 0039; não executar na R14. Quando aberto, obter acesso/configuração de caixa/SMTP/redirect e provar link real, nova senha/sessão, expiração e uso único; preservar credencial QA privada. |
| owner.r12-49 | assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | partial / FE verified em entry/gradebook/detail (rota real 14/09): participante listada, nota 8.5 salva e relida. / BE done em entry/gradebook/detail (lote 63 + save pela tela); close/reopen local-green. / verified-e2e em entry/gradebook/detail; close/reopen pendentes na rota real. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; usar o mesmo diário d2c945d8, lançar/reler nota, fechar/reabrir com versão e provar escopo real. Não duplicar participante, vínculo, configuração ou diário. |
| owner.r12-52 | chat.attach | partial / FE local-green: mosaico por mensagem para múltiplas mídias visuais, contador de adicionais, tile único e anexos não visuais preservados. / Sem mudança backend; R2 privado, ownership e autorização existentes preservados. / Pending-verification: faltam rota normal, mídia R2/MP4 real, reload e negativa cross-tenant. | docs/reviews/evidence/etapa-2/r12-coordenacao/chat-attach-mosaic-r12.md | Abrir rota normal QA, provar mídia privada real, reload e negativa cross-tenant; não promover por fixture. |
| owner.r12-53 | gate/mapeamento pendente | open / Não iniciada; condição de abertura não atendida. / Não iniciado. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Não promover `institutions.status` ou `institutions.locations-map` na R14: estão fora do MVP/escopo ativo. OQ-034 (Locais com mapa por imagem) fica preparado para a R15, sem abrir outro macrotema. |

## Owner items — concluídos (15; não voltam à execução)

| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
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

## Sobra preparada para a R15 (R15 ainda não aberta)

Esta seção é uma transferência preparada, não uma nova fila executável. Os itens
continuam visíveis para não serem confundidos com referências vigentes nem
reexecutados sem nova abertura do Owner:

- `owner.r12-05`: corrigir a inconsistência de escopo em
  `superadmin_attendance_context_options` e provar o contexto Atividade;
- `owner.r12-06`: definir o contrato de leitura da rotina efetiva, versão e
  snapshot em `superadmin_attendance_call_detail`;
- `owner.r12-08`: ampliar a massa para pelo menos dois alunos e repetir o fluxo;
- `owner.r12-15`, `r12-13` e `r12-16`: diagnosticar o 504 de
  `child_safety_change_lifecycle`, depois provar create/edit/suspend;
- `owner.r12-19` a `r12-27`: executar Perfis de acesso após a reivindicação da
  Sessão C, preservando as rotas reais `/profiles` e
  `/internal-users/:id/edit`;
- Formulários: criar uma ocorrência aberta identificada para provar upload em
  resposta; manter Expirar/Excluir separados;
- Principal: corrigir a indicação de contexto ativo após “Ver como”;
- `owner.r12-38` e `owner.r12-46`: migrar/provar imagem privada R2 de Cardápios
  e Conta, incluindo o layout A+ do “Meu acesso”;
- demais H, OQ-031, `chat.attach`, `owner.r12-33` e os gates de medição seguem
  na ordem da R14. Não abrir Planos comerciais, reader de Planos ou Auth
  recovery/reset; estes continuam fora da R14 conforme ADR 0039.

## R16 preparado — não aberto

Registro de bloqueios e itens sem certificação após a Sessão E. R16 não está
aberta, não cria `action_id` e não autoriza novas provas.

- `agora.remove`: a negativa cross-tenant foi tentada e bloqueada porque o
  helper remoto de fixture não existe no schema vinculado e a preparação SQL
  falhou antes da publicação; identidades temporárias foram removidas. Evidência
  em `agora-remove-cross-tenant-blocked-20260915.md`, commit `8ac946b3a`.
  Stream genérico permanece sem contrato, Edge, segredo, fixture e critério de
  aceite; o pacote atual comprova R2 privado e `stream_status=not_applicable`.
- `owner.r12-46`: pacote técnico e prova local existem, mas falta captura
  produtiva explícita do cabeçalho/avatar em nova sessão, com reload e save
  confirmado.
- H10/H11: regras de audiência preservadas, porém sem aceite remoto; autosave
  não tem prova remota acima de 60% e permanece V1 se esse limiar não for
  demonstrado.
- Circular, Principal, páginas de erro e H03, H04, H07, H09, H12, H14, H16,
  H18–H20, H22, H24–H26 e H28 continuam sem combinação executável de
  `action_id`, contrato e evidência. H08, H13 e H23 continuam transferidos sem
  contrato produtivo do item relacionado e sem `action_id` próprio.
- Resíduos da Sessão C ainda não certificados: `access-profiles.create/edit/assign`,
  `child-safety.create/edit/suspend`, `forms.expire-file/delete-file` e
  `owner.r12-13/15/16/19–27`. O 504 de `child_safety_change_lifecycle`, sessão
  QA/CORS/CDP indisponíveis e ausência de massa autorizada permanecem bloqueios.
- `auth.recover`, `auth.reset`, SMTP, provedor e allowlist de recuperação seguem
  fora da R14/R15/R16 até a abertura da Etapa 3.

## Resíduos H (herdados de R01–R07) — abertos (20)

| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H02 | noturna/R01 | Atualização oficial a partir do Sobre | Decidido (ADR 0038): conectar no MVP. Próximo gate: consumidor produtivo de ProfileAboutOfficialUpdateRequest e prova na rota normal. |
| H03 | noturna/R01 | Composição das quatro abas de Perfil | Comparar referência vigente e decidir consumidor produtivo. |
| H04 | R02/R07 | Compositor produtivo de Circular e blocos intercalados | Unificar host e provar na rota normal. |
| H07 | noturna/R01 | Hash de edição/revogação sem `conversation_id` | Executar replay/contexto na revisão de segurança. |
| H09 | R04/R06 | Disparo agendado de expiração Agora | Medir trigger real; leitura não basta. |
| H10 | noturna/R01 | Múltiplas regras de audiência em Formulários | Decidido (ADR 0038): preservar todas as regras de audiência. Próximo gate: editor lista/edita regras sem perder as demais + teste. |
| H11 | noturna/R01 | Autosave de autoria de Formulários | Decidido (ADR 0038): autosave do autor ligado. Próximo gate: host produtivo passa `authoringApi` + teste. |
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

## Resíduos H — transferidos para R15 (3)

| ID | Origem | Motivo da transferência |
|---|---|---|
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

## Itens da ADR 0038 sem ID H nem Owner item — abertos (4) e transferidos (2)

| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Identidade da mídia do Chat (`asset_id` no envelope) | Aberto | Pacote SQL aditivo em `authorize_read` + deploy da Edge Function `chat-media`; re-provar E2E do chat. |
| Catálogos globais de tipo (OQ-031) | Entregue tecnicamente; aceite central pendente | Sessão D aplicou a migration `20260915131500` em produção e confirmou pgTAP remoto 11/11, quatro catálogos com oito entradas e "Outros"; evidência no branch `origin/r14/bloco-cd` (`b135c8f20`). |
| Reader self da Conta (039) | Entregue tecnicamente; aceite central pendente | Sessão D aplicou a migration `20260915133000` em produção e confirmou pgTAP remoto 6/6, sessão autenticada e ausência de sobrecarga por UUID; evidência no branch `origin/r14/bloco-cd` (`b135c8f20`). |
| Reader de Planos comerciais no Principal (039) | Transferido para V1/V2 | Não executar na R14; preservar contrato e IDs como preparação futura. `units_with_override` só deve ser calculado quando o Owner abrir o escopo. |
| Local interno em Formulários (IDs fixados na publicação; revisão conserva valor) | Aberto | Verificar contrato atual de `form_publish`/resposta; pacote só se faltar. |
| Auth: localhost na allowlist de redirect (R12-47) | Transferido para Etapa 3 | Não executar na R14; pertence ao contrato futuro de recuperação/reset, com ambiente e prova próprios. |

## Itens da ADR 0038 — concluídos (2)

| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Anexos por mensagem no Chat (10 por envio) | **Concluído em 14/09 (lote 67)** | `superadmin_chat_attachment_prepare_v1` recusa o 11º pendente com `CHAT_ATTACHMENT_LIMIT` (422); pgTAP 9/9 + base 28/28; produção: 10 aceitos e 11º recusado na conversa 355a3403 (sintéticos arquivados); cliente mapeia `chat_attachment_limit` (243 testes do chat verdes). |
| Status de Suporte (OQ-028) | **Concluído em 14/09 (lote 69)** | `set_status` grava open/pending/resolved conforme o mapeamento A; trigger mantém `ticket_status` coerente (expired/revoked → Concluído); `closure_reason` em get/list; pgTAP 13/13 + bases 23/23, 28/28, 17/17; produção: chamado 6c5eb791 waiting→pending, completed→resolved. Cliente mostra “Concluído · Expirado/Revogado”. |

## Ações não terminais por família (inventário: 67 ações; FE/BE/E2E)

| Família | Qtd | action_ids |
|---|---:|---|
| access_profiles | 3 | `access-profiles.create` (local-green/done/pending-verification), `access-profiles.edit` (local-green/done/pending-verification), `access-profiles.assign` (pending-verification/done/pending-verification) |
| account | 2 | `account.profile` (verified/remote-green/pending-verification), `account.mfa` (pending-verification/gate-formal-mvp/gate-formal-mvp) |
| acontece | 1 | `acontece.create` (local-green/done/pending-verification) |
| activities | 2 | `activities.list` (local-green/done/pending-verification), `activities.publish` (local-green/done/pending-verification) |
| agenda | 1 | `agenda.request` (local-green/done/pending-verification) |
| agora | 5 | `agora.view` (verified/done/pending-verification), `agora.create` (local-green/local-green/pending-verification), `agora.publish` (pending-verification/local-green/pending-verification), `agora.expire` (pending-verification/local-green/pending-verification), `agora.remove` (pending-verification/pending-verification/pending-verification) |
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

## Decisões de escopo do Owner (14/09 e 15/09, ver `docs/agent/backlog.md`)

Fora do MVP: operações de Planos comerciais (listar/criar/editar/arquivar/restaurar/
atribuir/vincular/entitlements), `plans.assign`, Financeiro, `institutions.status`,
`institutions.locations-map`, MFA ×3.
V1/Etapa 3: Catálogo de UI. Formulários autosave (H11): V1 se for caro, salvo se >60% pronto.
Etapa 3: `auth.recover`/`auth.reset`; 3 instituições fictícias com hierarquia para o Owner verificar "Para você" (nome a rever).
Antes do fim do MVP: perfis oficiais do Coelo (OQ-032). R15: OQ-033 (decidido em 15/09: opção B + regra de pessoas) e OQ-034 Locais com mapa por imagem (confirmado em 15/09; substitui `institutions.locations-map`).

**15/09/2026 — abertura da execução (artefato 89AVWHKEnq5hrvYN6SFv6M):** temas explicados e sete decisões registradas em `R14-execucao-paralela.md` (papéis, worktrees, portas, handoffs, Bloco B autorizado com E2E ativo 199 → 192, ordem do Bloco C e ordem original do Bloco D). Duas sessões executam em paralelo; a coordenadora (Codex) atualiza este arquivo. A decisão posterior da ADR 0039 transfere recuperação/reset de Auth e a allowlist desse fluxo para a Etapa 3.

## Como atualizar

- Estado por `action_id`: só via `apply-tracker-delta.cjs` com evidência certificada (inventário → três rastreadores).
- Owner items: editar a linha aqui e rodar `node docs/reviews/etapa-2-operacao/next-round/sync-r12-owner-records.cjs`.
- H e itens da ADR: editar a linha aqui. Nunca editar R12/R13 (históricos).
- Validar sempre com `node docs/reviews/validate-trackers.cjs`.
- Execução paralela (sessões, worktrees, handoffs): `R14-execucao-paralela.md`. Handoffs `R14-handoff-sessao-1.md`/`-2.md` são comunicação, não fila.
