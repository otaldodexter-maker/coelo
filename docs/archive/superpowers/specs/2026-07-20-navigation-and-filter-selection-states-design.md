---
title: "Navigation and Filter Selection States"
source: "User-approved visual refinement for Superadmin navigation and institution filters"
status: "approved"
generated_at: "2026-07-20"
---

# Estados selecionados da navegação e dos filtros

## Objetivo

Diferenciar com clareza o item ativo do submenu lateral e simplificar a seleção das opções nos filtros do Diretório de Instituições, preservando o design system Coelo em light e dark mode.

## Escopo

- O submenu lateral ativo mantém texto e ícone em `colorScheme.primary` e recebe um fundo laranja suave permanente derivado de `colorScheme.primary`.
- O hover de um submenu inativo continua usando `colorScheme.primaryContainer`.
- O hover sobre o submenu ativo aumenta levemente a presença do fundo ativo, sem película cinza.
- Uma opção marcada dentro de um filtro não possui fundo permanente.
- A opção marcada é identificada pelo checkbox e pelo texto/ícone em `colorScheme.primary`.
- O hover das opções do filtro mantém um fundo laranja suave somente durante a interação.
- Nenhuma cor hexadecimal ou componente paralelo será criado.

## Fora de escopo

- Alterar hierarquia, rotas, conteúdo ou comportamento de abertura do menu lateral.
- Alterar a lógica multisseleção, os botões `Limpar` e `Aplicar` ou as consultas ao Supabase.
- Alterar logos ou outros elementos visuais do shell.

## Componentes afetados

- `_NavigationItem` em `superadmin_shell.dart`.
- `_filterMenuItemStyle` em `institution_directory_page.dart`.
- Testes de widget do shell e do diretório de instituições.

## Critérios de aceite

- O submenu ativo possui fundo laranja suave mesmo sem hover.
- O fundo ativo é visualmente diferente do hover de item inativo.
- Opções marcadas nos filtros permanecem sem fundo quando não estão sob hover.
- Checkbox e texto continuam indicando a seleção no filtro.
- Estados hover, foco e seleção não introduzem sobreposição cinza.
- Testes cobrem os estados normais e hover em light mode; a suíte responsiva existente continua validando light e dark mode.
