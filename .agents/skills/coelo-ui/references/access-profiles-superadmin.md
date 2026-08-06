---
title: "Composição privada de Perfis e Permissões"
source: "specs/018-profiles-permissions-superadmin.md; tela aprovada de Instituições"
status: "approved"
generated_at: "2026-08-05"
---

# Perfis e Permissões no Superadmin

Esta é uma composição privada do app, não um componente público do Design
System.

Use integralmente a baseline de Instituições para shell, toolbar, busca,
filtros e seus flyouts, grid, cards, hover/foco, faixa de criação, tabela,
paginação sticky, estados e espaçamentos. Popup de Bug, flyout do perfil e
flyout do tour são as referências para superfície, elevação, fechamento e
restauração de foco.

Superadmin e Admin usam perfis reutilizáveis. Principal é somente catálogo de
capacidades contextuais e impacto. Tabs de domínio/origem alternam Superadmin,
Admin e Principal; dentro de cada domínio não há tabs nem filtro de status.
Principal também não exibe criação nem ações administrativas.

Criar e editar reutilizam `SuperadminFormStepNavigation` e
`SuperadminFormActionFooter`. Criar segue `Perfil e escopo → Permissões →
Revisão`; editar insere `Pessoas vinculadas` antes da revisão. A revisão é a
última etapa, exige motivo de auditoria e não usa dialog intermediário.

O editor usa `Checkbox` tematizado e os metadados `module_code`, `screen_code`
e `action_code` recebidos do servidor. Em desktop, as ações reais formam as
colunas; em largura insuficiente, cada tela vira bloco empilhado com suas ações.
Nunca comprimir a matriz, criar scroll horizontal ou usar `Switch` para
selecionar permissões. Estados herdados ou indisponíveis explicam o motivo e
mantêm MFA/risco crítico textuais.

Reutilize `CoeloAdminListingToolbar`, `CoeloSearchField`,
`CoeloAdminMultiSelectFilter`, `CoeloAdminResizableTable`,
`CoeloAdminPagination`, `CoeloAdminCreateAction`, `CoeloStatusChip`,
`CoeloStatePanel`, `CoeloFormTextField`, `CoeloAdminSingleSelectField` e
`CoeloAdminExpandableStatusIndicator`. Use `CoeloAdminDialogShell` somente em
conflitos e confirmações que sejam dialogs reais. O rodapé de paginação e a
matriz de permissões permanecem composições privadas do Superadmin.
