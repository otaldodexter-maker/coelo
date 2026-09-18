---
title: "Navigation and Filter Selection States Implementation Plan"
source: "docs/superpowers/specs/2026-07-20-navigation-and-filter-selection-states-design.md"
status: "completed"
generated_at: "2026-07-20"
---

# Navigation and Filter Selection States Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Diferenciar o submenu lateral ativo do hover e remover o fundo permanente das opções marcadas nos filtros de instituições.

**Architecture:** Ajustar somente os resolvedores de cor existentes em `_NavigationItem` e `_filterMenuItemStyle`. Os estados continuam derivados de `ColorScheme`, sem criar novos componentes, tokens ou lógica de navegação.

**Tech Stack:** Dart, Flutter Material 3 e Flutter Test.

## Global Constraints

- O submenu lateral ativo mantém texto e ícone em `colorScheme.primary`.
- O submenu ativo usa um fundo laranja suave permanente, diferente do hover inativo.
- Opções marcadas nos filtros não possuem fundo permanente.
- Checkbox e texto em `colorScheme.primary` continuam indicando seleção.
- Hover e foco não introduzem película cinza.
- Nenhum HEX, migration ou alteração de Supabase faz parte desta entrega.

---

### Task 1: Estado ativo do submenu lateral

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `Theme.of(context).colorScheme` e `widget.isActive`.
- Produces: decoração persistente do `AnimatedContainer` identificado por `superadmin-navigation-<id>`.

- [ ] **Step 1: Alterar o teste para exigir fundo ativo sem hover**

Atualizar a asserção de `superadmin-navigation-institutions` para esperar `colorScheme.primary` com a opacidade semântica definida pela implementação, além de confirmar que o hover inativo continua em `primaryContainer`.

- [ ] **Step 2: Executar o teste e confirmar RED**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: falha porque o fundo ativo atual é transparente.

- [ ] **Step 3: Implementar os estados do submenu**

Usar `colors.primary.withValues(alpha: colors.brightness == Brightness.dark ? 0.18 : 0.10)` no estado ativo normal e aumentar levemente a opacidade quando ativo e destacado. Manter `colors.primaryContainer` somente para hover/foco de item inativo.

- [ ] **Step 4: Executar o teste e confirmar GREEN**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: todos os testes do shell passam.

---

### Task 2: Seleção sem fundo permanente nos filtros

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Test: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Consumes: `_filterMenuItemStyle(ColorScheme colors, {required bool selected})`.
- Produces: `ButtonStyle` com foreground selecionado em `primary`, background normal transparente e background de hover em `primaryContainer`.

- [ ] **Step 1: Alterar o teste visual de opções selecionadas**

Exigir `Colors.transparent` para opção selecionada sem hover e `colorScheme.primaryContainer` durante hover. Manter as asserções de texto/ícone em `colorScheme.primary` e checkbox marcado.

- [ ] **Step 2: Executar o teste e confirmar RED**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: falha porque o selecionado atual possui fundo laranja permanente.

- [ ] **Step 3: Simplificar o resolvedor de background**

Remover o ramo de background permanente para `selected`; retornar `primaryContainer` somente para hover/foco e `Colors.transparent` nos demais estados. Preservar foreground e iconColor em `primary` quando selecionado.

- [ ] **Step 4: Executar o teste e confirmar GREEN**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: todos os testes da tela passam.

---

### Task 3: Validação e versionamento

**Files:**
- Modify: `docs/superpowers/plans/2026-07-20-navigation-and-filter-selection-states.md`

**Interfaces:**
- Consumes: Tasks 1 e 2 concluídas.
- Produces: análise limpa, suíte aprovada, build web atualizado e commit isolado.

- [ ] **Step 1: Formatar e analisar**

Run: `dart format lib test && flutter analyze`

Expected: nenhum problema encontrado.

- [ ] **Step 2: Executar a suíte completa**

Run: `flutter test`

Expected: todos os testes passam.

- [ ] **Step 3: Gerar o build web**

Run: `flutter build web --dart-define=COELO_DEV_MFA=true`

Expected: build concluído em `build/web`.

- [ ] **Step 4: Atualizar preview e criar commit**

Reiniciar o servidor local com o novo build, confirmar HTTP 200 e criar um commit isolado sem incluir alterações preexistentes de logos.

## Resultado da execução

- Implementação concluída em 2026-07-20 com ciclos RED/GREEN para os dois estados visuais.
- `flutter analyze`: sem problemas.
- `flutter test`: 144 testes aprovados.
- `flutter build web --dart-define=COELO_DEV_MFA=true`: concluído.
