---
title: Diretório de instituições do Superadmin
knowledge_id: superadmin-institution-directory
source: docs/design/design-system.md
status: validated
generated_at: 2026-07-29
audience: team
surfaces: [superadmin, institutions]
visibility: internal
review_owner: Coelo Product
---

# Diretório de instituições do Superadmin

A paginação do diretório de Instituições usa `CoeloAdminPagination` nos modos de
cards e tabela. O conjunto completo fica centralizado e mantém cada quebra
responsiva centralizada.

O seletor de itens por página é compacto, usa gatilho pill e menu neutro com a
mesma largura do gatilho. A opção selecionada, hover e foco usam
`primaryContainer` e `primary`, sem check ou checkbox. Cards oferecem
`11, 20, 50, 100`; tabela oferece `8, 20, 50, 100`.

Na tela de Instituições, a paginação fica em rodapé sticky local, com inset
medido para impedir que o último card ou linha seja coberto. A faixa usa
superfície semântica translúcida, blur e borda superior. Essa composição é
específica da superfície e não cria variante pública. Quando o launcher de
mensagens está disponível, ele recebe o mesmo inset medido e permanece acima
do rodapé, sem cobrir a paginação.

O contrato reutilizável está em `admin.pagination` e
`pattern.selection-controls` no índice Coelo UI. Não existe variante pública
específica de Instituições.

A composição completa do diretório usa toolbar, busca, filtros, toggle
cards/tabela e arquivos; há `space4` entre toolbar e conteúdo. Cards usam
`space6` nos dois eixos, mínimo de referência de 340 px por coluna, altura
mínima de 216 px e padding horizontal `space6`/vertical `space4`. No modo
tabela, a faixa de criação precede `space4` e a tabela redimensionável.

Hover do card preserva `surface` e enfatiza borda/sombra com `primary`; hover de
linha usa `primaryContainer` sem raio ou gap. O toggle segmentado usa
`surface`/`outlineVariant`, com seleção, hover e foco em
`primaryContainer`/`primary`. Arquivos reutiliza `CoeloAdminFileActions`.
