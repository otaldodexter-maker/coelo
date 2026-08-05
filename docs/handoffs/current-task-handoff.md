# Handoff - Correção UI/UX da tela Suporte (Superadmin)

## Encerramento em seguro
- data-hora: 2026-08-05 09:50:03 -03:00
- objetivo original: corrigir e ajustar a UI/UX da tela Suporte (Superadmin), mantendo o padrão Coelo, acessibilidade e sem mudanças de regra de negócio.
- escopo efetivamente trabalhado: tela `Suporte` (superadmin), com foco em estrutura de listagem (kanban/tabela), ações da barra, comportamento de interação e fundo responsivo mobile/tablet.

## Decisões de produto e UI/UX que devem ser preservadas
- manter a base do tema em mobile/tablet com superfície limpa e clara (`colorScheme.surface`) no Coelo, conforme instrução da correção de coelo-ui.
- reutilizar componentes padronizados existentes (ex.: `CoeloAdminWorkspaceLayout`, `CoeloAdminFlyout`, `CoeloAdminResizableTable`, `CoeloAdminWorkItemCard`).
- manter a correção de abertura do diálogo de criar suporte para título `Novo chamado` (sem tratar como relato de bug).
- manter o comportamento de drag de card no kanban funcional em desktop e touch conforme implementação atual.
- preservar a acessibilidade de foco/semântica já adicionada (status, filtros, menus).

## Arquivo de referências e documentos consultados
- `C:\Users\adrie\Documents\Coelo\.agents\skills\coelo-ui\SKILL.md`
- `C:\Users\adrie\Documents\Coelo\.agents\skills\coelo-ui\scripts\query-index.ps1`
- `C:\Users\adrie\Documents\Coelo\.agents\skills\coelo-ui\scripts\query-index.ps1 -Query "suporte"`
- `C:\Users\adrie\Documents\Coelo\apps\superadmin\lib\features\support\presentation\screens\support_page.dart`
- `C:\Users\adrie\Documents\Coelo\apps\superadmin\lib\features\support\presentation\widgets\support_filter_toolbar.dart`
- `C:\Users\adrie\Documents\Coelo\apps\superadmin\lib\features\support\presentation\widgets\support_ticket_table.dart`
- `C:\Users\adrie\Documents\Coelo\apps/superadmin/lib/features/support/presentation/widgets/support_kanban.dart`
- `C:\Users\adrie\Documents\Coelo\packages/coelo_ui_admin/lib/src/kanban/coelo_admin_work_item_card.dart`
- `C:\Users\adrie\Documents\Coelo\packages/coelo_ui_admin/lib/src/table/coelo_admin_resizable_table.dart`
- `C:\Users\adrie\Documents\Coelo\docs/handoffs/current-task-handoff.md` (status anterior, substituído por este por mudança de escopo).

## Arquivos criados
- Nenhum arquivo novo nesta etapa.

## Arquivos alterados
- `apps/superadmin/lib/features/support/presentation/screens/support_page.dart`
- `apps/superadmin/lib/features/support/presentation/widgets/support_filter_toolbar.dart`
- `apps/superadmin/lib/features/support/presentation/widgets/support_ticket_table.dart`
- `apps/superadmin/lib/app/shell/superadmin_bug_report_dialog.dart`
- `packages/coelo_ui_admin/lib/src/kanban/coelo_admin_work_item_card.dart`

## Componentes, rotas ou superfícies afetadas
- Tela de suporte do Superadmin (`/support`): `SupportPage`, `SupportFilterToolbar`, `SupportTicketTable`, fluxo de criação e card de status.
- Kanban de suporte via `CoeloAdminWorkItemCard` (drag, estado hover/foco e acessibilidade).
- Popup de criação/edição via `showSuperadminBugReportDialog`.

## O que foi concluído
1. Corrigido ajuste de texto de subtítulo da tela de suporte (substituído texto de bug por contexto operacional).
2. Implementado visual e padrão de status com `CoeloAdminFlyout` no table de suporte, mantendo semântica e contraste.
3. Ajustada tabela para exibir scrollbar horizontal no mobile e desktop conforme padrão.
4. Forçada centralização inicial da tabela quando sem agrupamento (com `Align`/`SizedBox` já aplicado anteriormente).
5. Corrigido drag dos cards do kanban com suporte para fallback touch/desktop (`LongPressDraggable` e `Draggable`) e overlay mínimo no pacote de card padrão.
6. Corrigida abertura do "Criar suporte" para usar diálogo com título específico (`Novo chamado`) em vez de linguagem de bug.
7. Adicionado ajuste de fundo específico para mobile/tablet no tema claro da tela de suporte, aplicando `theme.colorScheme.surface` como base limpa (`ColoredBox`) para evitar cinza como primeiro plano.

## O que ficou parcialmente concluído
- Ainda não houve validação visual via runtime (`localhost` não aberto nesta etapa, conforme solicitado).
- Ainda não foi feito benchmark visual com screenshots de referência no ciclo atual.

## O que ainda não foi iniciado
- Revisão dos ajustes finais de contraste/caixa de sombra em estados de hover/focus após aplicação do novo fundo, caso necessário.

## Verificações executadas e resultados
- `C:\Users\adrie\Documents\Coelo\\.agents\\skills\\coelo-ui\\scripts\\query-index.ps1 -Query "suporte"`: retornou índice com entrada do componente `admin.work-item-card` para suportar decisão do padrão de card.
- `git -C "C:\Users\adrie\Documents\Coelo" diff --check -- apps/superadmin/lib/features/support/presentation/screens/support_page.dart apps/superadmin/lib/features/support/presentation/widgets/support_filter_toolbar.dart ...` (sem erro de whitespace).
- `git -C "C:\Users\adrie\Documents\Coelo" status --short` (apontou workspace com várias alterações; nesta unidade, foco em `support_page.dart` e arquivos de suporte acima).

## Erros ou avisos ainda existentes
- Sem erros de compilação levantados nesta etapa porque não foi executada suíte local.
- Avisos de normalização LF/CRLF continuam sendo reportados em arquivos já tocados anteriormente no workspace.

## Bloqueios encontrados
- Nenhum bloqueio técnico novo.

## Débitos técnicos conscientes
- Validação visual em dispositivos mobile/tablet ainda depende de execução visual local.
- Não foi executado o validador indicado no skill (`apps/catalog/tool/validate_admin_visual_contracts.dart`) nesta retomada curta.

## Estado atual do git status
- Repositório com muitas alterações não relacionadas já em curso.
- Nesta unidade, a alteração funcional adicional realizada agora foi em `apps/superadmin/lib/features/support/presentation/screens/support_page.dart`.

## Resumo do git diff
- `apps/superadmin/lib/features/support/presentation/screens/support_page.dart`: novo wrapper de superfície para mobile/tablet claro (`ColoredBox` com `theme.colorScheme.surface`) e continuidade dos ajustes já existentes da tela.
- demais arquivos de suporte e card/table no escopo da etapa já constam de alterações anteriores e permanecem como progresso da sequência atual.

## Próximo passo exato
- manter a etapa em “Revisão de validação visual” da tela Suporte (mobile/tablet e desktop), com foco em contraste e contraste de superfícies.

## Primeiro arquivo para abrir na retomada
- `C:\Users\adrie\Documents\Coelo\apps\superadmin\lib\features\support\presentation\screens\support_page.dart`

## Comandos necessários para validar/retomada
- `git -C "C:\Users\adrie\Documents\Coelo" status --short`
- `git -C "C:\Users\adrie\Documents\Coelo" diff -- "apps/superadmin/lib/features/support/presentation/screens/support_page.dart"`
- `git -C "C:\Users\adrie\Documents\Coelo" diff --check`
- `Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"`

## Critérios para considerar a próxima etapa concluída
- fundo da tela de suporte em mobile/tablet permanece limpo e branco/`surface` no modo claro.
- não há regressão funcional conhecida na abertura de criação, drag dos cards e alternância cards/tabela.
- contraste e estados em hover/foco permanecem acessíveis em revisão visual manual da tela.

