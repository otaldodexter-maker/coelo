---
title: "Composição privada de Perfis e Permissões"
source: "specs/018-profiles-permissions-superadmin.md; tela aprovada de Instituições"
status: "approved"
generated_at: "2026-07-29"
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
capacidades contextuais e impacto. O editor usa `Checkbox` tematizado,
agrupamento por domínio e seções empilhadas em compacto; nunca comprime uma
matriz larga e nunca usa `Switch` para selecionar permissões.

Reutilize `CoeloAdminListingToolbar`, `CoeloSearchField`,
`CoeloAdminMultiSelectFilter`, `CoeloAdminResizableTable`,
`CoeloAdminPagination`, `CoeloAdminCreateAction`, `CoeloStatusChip`,
`CoeloStatePanel`, `CoeloFormTextField`, `CoeloAdminSingleSelectField` e
`CoeloAdminDialogShell`. O rodapé de paginação é composição compartilhada
somente dentro do Superadmin.
