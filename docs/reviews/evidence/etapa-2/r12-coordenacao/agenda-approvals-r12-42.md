---
source: R12-formularios-agenda-owner.md; agenda_approvals_page.dart
status: local-green-fe; runtime-pending
generated_at: 2026-09-13
---

# R12-42 — Agenda, aprovações de publicação

Mapeamento: apps/superadmin > Operação > Agenda > Aprovações > agenda.request.
O inventário já associa agenda.request à rota /agenda/approvals e à decisão
de publicação; não foi criado outro action_id.

A tabela já usava CoeloAdminResizableTable, mas impunha rowHeight 136 e
padding/alinhamento local duplicado. Agora usa linha de 64 px, alinhamento
do componente, colunas separadas de estado e histórico e textos truncados
nas células. Ver histórico abre CoeloAdminDialogShell com ator, instante e
justificativa completa, sem perder dados na linha compacta. O mobile mantém
cards e a decisão continua usando o contrato autorizado existente.

Verificações: 6/6 testes funcionais de aprovações PASS; analyze sem issues.
Estados remotos: 22 PASS, 1 FAIL no golden de calendário loading dark 375,
194 pixels/0,04%; origem da divergência ainda não isolada. Referência não
regravada. Goldens de tabela com a altura antiga precisam de revisão visual.

FE local-green; BE preservado; E2E pending-verification após a mudança visual.
Primeiro gate: rota normal, decisão autorizada/recarga e revisão visual da
tabela em claro/escuro; investigar o golden de calendário separadamente.
Responsável C0 R12. Aprovação visual pertence ao Owner.
