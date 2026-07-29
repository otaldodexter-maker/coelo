---
title: Diretório de instituições do Superadmin
knowledge_id: superadmin-institution-directory
source: docs/superpowers/specs/2026-07-28-superadmin-institution-sticky-pagination-design.md
status: validated
generated_at: 2026-07-28
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

Nos modos cards e tabela, a paginação permanece fixa no limite inferior da área
útil sobre uma faixa local translúcida com blur. O conteúdo rolável reserva a
altura real do rodapé mais o espaçamento de segurança, mantendo o último item
totalmente visível. Essa composição é específica do diretório e não cria
variante pública no Coelo UI.

O contrato reutilizável está em `admin.pagination` e
`pattern.selection-controls` no índice Coelo UI. Não existe variante pública
específica de Instituições.
