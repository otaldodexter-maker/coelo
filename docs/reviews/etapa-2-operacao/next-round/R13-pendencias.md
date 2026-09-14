---
source: Owner 2026-09-13; R13-owner-items-atual.json; R12-fechamento.md; R01–R07 resíduos incorporados; inventario-etapa-2.json
status: active; fila vigente R13; execução documental parcial
generated_at: 2026-09-13
updated_at: 2026-09-14
decisions: decisions/0038-owner-decisions-etapa2-backlog-20260914.md
---

> R13 é a fila vigente da Etapa 2. Ela reúne os 50 compromissos ainda
> abertos/parciais da R12 e os resíduos H02–H28 herdados de R01–R07, sem novo
> aceite terminal. R01–R12 permanecem apenas como origem e histórico; R14 não
> foi iniciada. O estado agregado está em
> [ETAPA-2-estado-atual.md](../ETAPA-2-estado-atual.md).


# R13 — Pendências vigentes após fechamento R12

## Fila R13 incorporada de R01–R07

Os resíduos abaixo foram transferidos para a R13 como pendências herdadas. Os
IDs H não são novos `action_id` nem Owner items; servem para preservar a
proveniência e concentrar o próximo gate em uma única rodada.

| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H02 | noturna/R01 | Atualização oficial a partir do Sobre | Decidido (ADR 0038): conectar no MVP. Próximo gate: consumidor produtivo de ProfileAboutOfficialUpdateRequest e prova na rota normal. |
| H03 | noturna/R01 | Composição das quatro abas de Perfil | Comparar referência vigente e decidir consumidor produtivo. |
| H04 | R02/R07 | Compositor produtivo de Circular e blocos intercalados | Unificar host e provar na rota normal. |
| H05 | noturna/R01 | Denominador histórico de recibos do Chat | Decidido (ADR 0038): recibos contam participantes ativos atuais. Fechado sem mudança; aceite MVP mantido. |
| H06 | noturna/R01 | Revogar em Chat somente leitura | Decidido (ADR 0038): revogar proibido em conversa somente leitura. Próximo gate: `revoke_message_v2` recusa `CHAT_READ_ONLY` + pgTAP. |
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
| H17 | R06 | Papel fixo versus capacidade em cuidado | Decidido (ADR 0038): só capacidade. Próximo gate: capacidade `care_policies.manage` + remover papel fixo em `superadmin_unit_care_policy_set_v1` + pgTAP. |
| H18 | R06 | Unicidade global concorrente de `@` | Revisar concorrência entre tabelas. |
| H19 | R06 | Responsável vazio em Medicação | Reproduzir com contexto e destinatário válidos. |
| H20 | R06 | Imagem da dose sem gateway | Localizar consumidor e obter prova específica. |
| H21 | R07 | Limite de texto/rodapé de Circular | Decidido (ADR 0038): 4.000 no total da circular; compositor segue a referência inteira (shell, rodapé em card, Opções). Próximo gate: corrigir host, spec 037 e regravar os 6 goldens web. |
| H22 | noturna/R01 | Descritor privado de Circular | Alinhar à ADR 0032 e provar ausência de bucket público. |
| H23 | noturna/R01 | Continuidade visual de Avisos após refresh | Decidido (ADR 0038): manter lista + barra fina de progresso, padrão para todas as listas. Próximo gate: implementar em Avisos e registrar o padrão em coelo-ui. |
| H24 | noturna/R01 | Rótulos do Sobre | Comparar com referência vigente. |
| H25 | noturna/R01 | Alvo de redimensionamento de tabela | Medir teclado, semântica e toque. |
| H26 | noturna/R01 | Opcional, escala legada e opções vazias | Reconciliar contrato atual por caso. |
| H27 | noturna/R01 | Sinal de atualização de Momentos | Decidido (ADR 0038): saudação por hora do dia; ponto laranja na aba Momentos quando há momento não visto. Próximo gate: implementar no Principal + prova. |
| H28 | R01 | Filtros, avatar e buffers de Pessoas | Rever somente diferenças funcionais persistentes. |

H01 (credencial QA) está resolvido e permanece fora da fila. O detalhe de
responsável, evidência e primeiro gate também está nos três rastreadores, agora
sob a seção **Pendências R13 incorporadas de R01–R07**.

As linhas herdadas do catálogo abaixo preservam textos históricos que podem
mencionar abertura ou autorização da R12. O destino operacional vigente desses
itens é a R13; nenhuma retomada deve ser executada na R12.

## Pendências por `action_id` do inventário

Além dos H e dos 50 Owner items, a R13 é o destino operacional dos action IDs
que permanecem não terminais no inventário: 78 ações ativas na união das
camadas (64 FE, 43 BE e 77 integradas). Esses números não são somados entre si;
as 22 ações `deferred-post-mvp` ficam rastreadas separadamente e não entram no
trabalho corrente do MVP. O detalhe por tela/subtela está nos três rastreadores
e em `docs/reviews/inventario-etapa-2.json`.

## Corte executado da R13 — 2026-09-14

Os 50 IDs abaixo foram reavaliados no checkout `dev` em `536b5afa1`, sem
renumeração e sem repetir `owner.r12-07`, `owner.r12-41` ou `owner.r12-43`.
Nenhum recebeu `done`: a prova exigida é rota normal + persistência/reload real
+ ownership + negativa cross-tenant, e não foi seguro executá-la enquanto havia
runtime externo ativo e o primeiro gate de produção permanecia aberto.

- `owner.r12-51`: **done em 14/09/2026 (lote 63)** — regra da ADR 0038
  cumprida: dump lógico com SHA-256, espelho baseline+167 na ordem real,
  pgTAP verde, ledger 283→287; evidência em
  `docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md`.
- `owner.r12-48`, `owner.r12-49`, `owner.r12-50`: BE provado em produção por
  RPC (UPDATE de b04c879e, diário d2c945d8 com participante, contadores da
  turma 4214106c + hotfix de busca no lote 64); FE e E2E na rota real ainda
  `pending-verification`.
- `owner.r12-38`, `owner.r12-46`, `owner.r12-52`: `blocked-environment` ou
  `pending-verification`; R2 privado/Gateway e prova de mídia real permanecem
  sem certificado para essas rotas. Cardápios ainda usam Storage no adapter.
- `owner.r12-45`, `owner.r12-47`: `blocked-environment`; SMTP próprio, caixa QA
  e redirect allowlist reais não estão disponíveis.
- `owner.r12-53`: `deferred`; sua condição formal ainda não foi atendida.
- Os 40 IDs restantes permanecem no estado anterior (`open`/`partial`) com
  primeiro gate preservado; a evidência de execução por ID é o JSON da rodada:
  [r13-execution-audit-20260914.json](../../../evidence/etapa-2/r13-coordenacao/r13-execution-audit-20260914.json).

Checks proporcionais: `r2_s3_test` 20/20 PASS e cleanup de Cardápios 3/3 PASS.
O analyze Flutter foi interrompido após 70 s por runtimes externos ativos; uma
suite Deno completa também ficou bloqueada por dependência ausente. Estes
checks locais não alteram os estados FE/BE/E2E nem certificam produção.

50 compromissos preservados. IDs de origem mantidos, sem novo action_id ou ganho funcional. Fontes e estados atualizados abaixo; execução R13 registrada como parcial.

| Item | Ações | FE / BE / E2E | Evidência | Primeiro gate |
|---|---|---|---|---|
| owner.r12-01 | daily-routine.list | Planejado R12; não implementado. / Contratos a verificar; sem falha nova confirmada. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Ler R12-01 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| owner.r12-02 | activities.list, daily-routine.list | Planejado R12; não implementado. / Contratos a verificar; sem falha nova confirmada. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Decidido (ADR 0038): modelos Coelo não se arquivam. Próximo gate: Arquivar só nos modelos da instituição, botão indisponível com explicação nos modelos de sistema. |
| owner.r12-03 | activities.list | Planejado R12; não implementado. / Contratos a verificar; sem falha nova confirmada. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Ler R12-03 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| owner.r12-04 | daily-routine.list, attendance.dashboard | Planejado R12; não implementado. / Contratos a verificar; sem falha nova confirmada. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Ler R12-04 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| owner.r12-05 | attendance.create | Planejado R12; não implementado. / Contratos a verificar; sem falha nova confirmada. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Ler R12-05 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| owner.r12-06 | attendance.create, daily-routine.apply | Planejado R12; não implementado. / Contratos a verificar; sem falha nova confirmada. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Ler R12-06 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| owner.r12-08 | attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | Planejado R12; não implementado. / Contratos a verificar; sem falha nova confirmada. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md | Ler R12-08 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| owner.r12-09 | child-safety.list | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Ler R12-09, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| owner.r12-10 | child-safety.list | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Decidido (ADR 0038): diferença é só o cabeçalho global. Fechado para a tela; regravar referência quando o cabeçalho estabilizar. |
| owner.r12-11 | gate/condição | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Ler R12-11, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| owner.r12-12 | child-safety.child | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Ler R12-12, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| owner.r12-13 | child-safety.create, child-safety.edit | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Ler R12-13, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| owner.r12-14 | child-safety.child | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Ler R12-14, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| owner.r12-15 | child-safety.child, child-safety.edit, child-safety.suspend | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Ler R12-15, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| owner.r12-16 | child-safety.create | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Ler R12-16, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| owner.r12-17 | child-safety.create, child-safety.edit | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Ler R12-17, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| owner.r12-18 | child-safety.create | Planejado R12; sem implementação. / Contrato a verificar; sem diagnóstico novo. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-seguranca-perfis-owner.md | Decidido (ADR 0038): nome, sobrenome e CPF obrigatórios; resto opcional; dedupe por HMAC do CPF. Próximo gate: contrato de pessoa sem conta (tabela/RPC/RLS) + wizard. |
| owner.r12-19 | gate/condição | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-19 e fontes antes de executar na R12 autorizada. |
| owner.r12-20 | gate/condição | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-20 e fontes antes de executar na R12 autorizada. |
| owner.r12-21 | access-profiles.detail | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-21 e fontes antes de executar na R12 autorizada. |
| owner.r12-22 | access-profiles.create, access-profiles.edit | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-22 e fontes antes de executar na R12 autorizada. |
| owner.r12-23 | access-profiles.create | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Decidido (ADR 0038): perfis profissionais para uso no Principal aprovados (capacidades finas por ação, atribuídas por vínculo/contexto). Próximo gate: revisar spec 018 e desenhar catálogo de capacidades do Principal antes do SQL. |
| owner.r12-24 | access-profiles.create, access-profiles.edit | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-24 e fontes antes de executar na R12 autorizada. |
| owner.r12-25 | access-profiles.create, access-profiles.edit | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-25 e fontes antes de executar na R12 autorizada. |
| owner.r12-26 | access-profiles.edit | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-26 e fontes antes de executar na R12 autorizada. |
| owner.r12-27 | access-profiles.create, access-profiles.edit | Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | Reconciliar R12-27 e fontes antes de executar na R12 autorizada. |
| owner.r12-28 | health-care.edit | Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-28, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-29 | health-care.create, health-care.edit, health-care.detail | Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-29, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-30 | health-care.create, health-care.edit, health-care.detail | Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-30, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-31 | medication.create, medication.edit | Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-31, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-32 | medication.list, medication.detail, medication.create, medication.edit | Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Reconciliar R12-32, reproduzir e desenhar contrato focal após abertura R12. |
| owner.r12-33 | medication.create, medication.edit, medication.detail | Planejado R12, não implementado. / Contratos e persistência a verificar. / Não executado para este apontamento. | docs/reviews/etapa-2-operacao/next-round/R12-saude-cuidado-owner.md | Decidido (ADR 0038): responsáveis = guardiões e equipe no escopo; notificar novo/alteração/suspensão + lembrete 30 e 15 min antes; só sino. Próximo gate: contrato de eventos/destinatários + pgTAP. |
| owner.r12-34 | meal-plans.model-create, meal-plans.model-edit | Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Reconciliar R12-34 e reproduzir após abertura explícita da R12. |
| owner.r12-35 | meal-plans.model-create, meal-plans.model-edit | Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Reconciliar R12-35 e reproduzir após abertura explícita da R12. |
| owner.r12-36 | meal-plans.create, meal-plans.edit, meal-plans.publish | Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Decidido (ADR 0038): Prioridade explícita sai do contrato. Próximo gate: migration remove o campo e bloqueia sobreposição ao salvar; prova de instante/publicação agendada. |
| owner.r12-37 | meal-plans.create, meal-plans.edit | Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Decidido (ADR 0038): Datas excluídas saem do contrato. Próximo gate: mesma migration de R12-36; prova de edição e reload. |
| owner.r12-38 | meal-plans.create, meal-plans.edit, meal-plans.publish, meal-plans.model-edit | Planejado R12; não implementado. / Contratos a verificar, sem diagnóstico novo. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-cardapios-owner.md | Reconciliar R12-38 e reproduzir após abertura explícita da R12. |
| owner.r12-39 | forms.edit, forms.create | Planejado R12; sem implementação. / Sem diagnóstico novo. / Sem prova nova. | docs/reviews/etapa-2-operacao/next-round/R12-formularios-agenda-owner.md | Reconciliar R12-39, mapear e reproduzir na R12 autorizada. |
| owner.r12-40 | forms.edit, forms.create | Planejado R12; sem implementação. / Sem diagnóstico novo. / Sem prova nova. | docs/reviews/etapa-2-operacao/next-round/R12-formularios-agenda-owner.md | Reconciliar R12-40, mapear e reproduzir na R12 autorizada. |
| owner.r12-42 | gate/condição | Planejado R12; sem implementação. / Sem diagnóstico novo. / Sem prova nova. | docs/reviews/etapa-2-operacao/next-round/R12-formularios-agenda-owner.md | Reconciliar R12-42, mapear e reproduzir na R12 autorizada. |
| owner.r12-44 | invites.list | Planejado R12; não implementado. / Contrato preservado, reenvio a conferir. / Sem prova nova. | docs/reviews/etapa-2-operacao/next-round/R12-convites-owner.md | Reconciliar R12-44 e reproduzir na R12 autorizada. |
| owner.r12-45 | invites.resend | Planejado R12; não implementado. / Contrato preservado, reenvio a conferir. / Sem prova nova. | docs/reviews/etapa-2-operacao/next-round/R12-convites-owner.md | Reconciliar R12-45 e reproduzir na R12 autorizada. |
| owner.r12-46 | account.profile | Parcial: rodapé/busca, nome, crop e confirmação autoritativa testados. / BE remote-green (lote 63, 14/09): save_v2 sigla/cor/celular + get provados em produção; foto R2 ausente. / E2E pendente na rota real. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Resolver gate SQL; aplicar contrato, implementar foto privada e provar foto/nome/sigla/cor, remover foto, grupos reais, reload e troca de sessão. |
| owner.r12-47 | auth.recover, auth.reset | Verified histórico; pedido normal e endereço inexistente observados na R11. / Sem mensagem real na caixa acessível; SMTP próprio ausente e redirect local3000 fora da allowlist. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Decidido (ADR 0038): SMTP próprio fica para o fechamento do MVP; redirect localhost autorizado na allowlist. Próximo gate: configurar redirect e provar com link Auth Admin por canal seguro. |
| owner.r12-48 | activities.assessment, activities.publish | FE pendente na rota real. / BE done (lote 63, 14/09): UPDATE de b04c879e em produção version 1→2 e releitura. / E2E pendente na rota real. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; salvar/reler o mesmo b04c879e e fechar a cadeia de configuração/publicação. Atividade95b98978 já active: não recriar ou alternar status para inflar avanço. |
| owner.r12-49 | assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | FE pendente na rota real. / BE done em gradebook/detail (lote 63, 14/09): diário d2c945d8 lista a participante em produção; entry/close/reopen seguem local-green (não exercitados). / E2E pendente na rota real. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; usar o mesmo diário d2c945d8, lançar/reler nota, fechar/reabrir com versão e provar escopo real. Não duplicar participante, vínculo, configuração ou diário. |
| owner.r12-50 | groups.list | FE/UI reload pendente na rota real. / BE done (lotes 63+64, 14/09): turma 4214106c com student_count=1 e 3 atividades em produção; hotfix do escape da busca (22025). / E2E pendente na rota real. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar projeção após gate SQL e conferir contadores na turma4214106c com vínculos ativos e reload. Aceite antigo da listagem não cobre contadores. |
| owner.r12-51 | gate/condição | Não aplicável. / Done (lote 63, 14/09): quatro candidatos aplicados em produção com dump SHA-256, espelho e pgTAP verdes, ledger 283→287. / Não aplicável. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Decidido (ADR 0038): Decisão 8 mantida (dump lógico antes de cada lote) até o primeiro cliente real ou Etapa 3. Fila SQL liberada; C0 aplica os quatro candidatos na ordem serial. |
| owner.r12-52 | chat.attach | Ajuste local parcial: imagens/vídeos deixam de usar cartão administrativo; mídia inline e vídeo/play existentes preservados. Mosaico e demais acabamento ainda abertos. / Contrato R2/permissões preservado; sem mudança BE. / Pendente; nenhuma prova E2E nova. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md; apps/superadmin/test/features/chat/presentation/superadmin_chat_attachment_tile_test.dart | Reutilizar chat-media-composer-owner-reference-20260913.md: provar foto inline maior, vídeo com play/duração, mosaico e escrita em cápsula pela rota normal, sem declarar local-green como E2E. Coordenar com R12-43 (contorno), sem duplicar aceite nem alterar formulários administrativos globalmente. |
| owner.r12-53 | gate/condição | Não iniciada; condição de abertura não atendida. / Não iniciado. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Decidido (ADR 0038): nenhum opcional; fechado. institutions.status e locations-map ficam fora da Etapa 2. |

## Handoff complementar R12

Recorte07/41/43 entregue, não refazer. Preservar correções e provas em R12-fechamento.md. C0 R13: os4 goldens Circulares e20 achados do validador visual permanecem dívida herdada, com primeiro gate por tela em R12-pendencias.md. Isso não cria novo action_id nem apaga os50 compromissos acima. Liberação de continuidade pelo supervisor conforme R13-luna-continuacao.md.
