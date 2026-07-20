---
title: "Responsive Navigation Interactions Implementation Plan"
source: "docs/superpowers/specs/2026-07-20-responsive-navigation-interactions-design.md"
status: "in-progress"
generated_at: "2026-07-20"
---

# Responsive Navigation Interactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refinar hover, flyout e marca responsiva do menu Superadmin sem alterar sua hierarquia ou identidade aprovada.

**Architecture:** Manter o componente único `SuperadminShell` e ajustar somente estilos resolvidos, alinhamento do `MenuAnchor` e composição do drawer. Reutilizar `_BrandHeader` e `_InsetDivider`; nenhuma nova abstração ou dependência será criada.

**Tech Stack:** Dart, Flutter Material 3, Flutter SVG e Flutter Test.

## Global Constraints

- Usar somente `ColorScheme`, `CoeloActionColors` e tokens Coelo existentes.
- Nenhum overlay Material cinza pode se sobrepor ao hover laranja.
- O flyout recolhido abre à direita e alinhado ao acionador.
- Mobile e tablet reutilizam a marca oficial e o divisor do desktop.
- Rotas, dados, filtros, Supabase, assets e menu do usuário não mudam.

---

### Task 1: Estados sem película cinza

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `ColorScheme`, `CoeloActionColors`, `WidgetState` e flags `active`/`_highlighted`.
- Produces: estilos determinísticos para seção recolhida, seção aberta, destino aberto e item de flyout.

- [ ] **Step 1: Escrever testes RED dos estados resolvidos**

Adicionar asserções para: seção recolhida ativa usa `primary` em repouso e `CoeloActionColors.primaryHover` no hover; overlay é transparente; destino ativo do flyout tem fundo laranja suave e hover reforçado; item inativo do flyout usa `primaryContainer` no hover sem overlay.

- [ ] **Step 2: Executar o teste do shell e confirmar RED**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: falha nos estados de hover/overlay ainda não implementados.

- [ ] **Step 3: Implementar resolvedores mínimos**

No `IconButton` recolhido, resolver `backgroundColor` por estado e usar overlay transparente. Em `_navigationMenuItemStyle`, aceitar `active`, manter foreground primário e usar fundo primário com baixa opacidade no ativo. Em `_NavigationSectionHeader` e `_NavigationItem`, usar a cor de hover com alpha zero como repouso inativo para impedir interpolação via preto transparente.

- [ ] **Step 4: Executar o teste do shell e confirmar GREEN**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: todos os testes do shell passam.

---

### Task 2: Flyout lateral alinhado

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `MenuAnchor.style.alignment`, `alignmentOffset` e keys do acionador/flyout.
- Produces: flyout à direita com topo alinhado ao botão recolhido.

- [ ] **Step 1: Escrever teste RED de geometria**

Após recolher o menu e abrir Estrutura, comparar `getTopLeft` do flyout e do acionador: `flyout.dx` deve ser maior que o `right` do acionador e a diferença vertical deve ser menor ou igual a `CoeloSpacing.space2`.

- [ ] **Step 2: Executar o teste e confirmar RED**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: falha porque o menu atual usa o alinhamento padrão abaixo do acionador.

- [ ] **Step 3: Definir alinhamento lateral**

Configurar `MenuStyle.alignment` como `AlignmentDirectional.topEnd` e manter um afastamento horizontal de `CoeloSpacing.space2`, sem deslocamento vertical.

- [ ] **Step 4: Executar o teste e confirmar GREEN**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: todos os testes passam.

---

### Task 3: Marca no drawer de mobile e tablet

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `_BrandHeader(collapsed: false)`, `_InsetDivider` e `_NavigationContent`.
- Produces: drawer responsivo com cabeçalho, divisor e navegação.

- [ ] **Step 1: Escrever testes RED em 375 px e 768 px**

Abrir o menu hambúrguer e exigir `superadmin-brand-mark`, logo temática, texto `Superadmin`, `superadmin-brand-divider`, navegação e ausência de `Owner Coelo` dentro do drawer.

- [ ] **Step 2: Executar o teste e confirmar RED**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: falha porque o drawer atual contém apenas `_NavigationContent`.

- [ ] **Step 3: Compor o drawer com componentes existentes**

Substituir o conteúdo do `SafeArea` por `Column(children: [_BrandHeader(collapsed: false), _InsetDivider(...), Expanded(child: _NavigationContent(collapsed: false))])`.

- [ ] **Step 4: Executar o teste e confirmar GREEN**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: todos os testes do shell passam nos dois viewports.

---

### Task 4: Validação e entrega

**Files:**
- Modify: `docs/superpowers/plans/2026-07-20-responsive-navigation-interactions.md`

**Interfaces:**
- Consumes: Tasks 1–3 concluídas.
- Produces: código formatado, análise limpa, suíte aprovada, build e preview atualizados.

- [ ] **Step 1: Formatar e analisar**

Run: `dart format lib/app/shell/superadmin_shell.dart test/app/shell/superadmin_shell_test.dart` e `flutter analyze`

Expected: nenhuma alteração pendente de formatação e nenhum problema de análise.

- [ ] **Step 2: Executar a suíte completa**

Run: `flutter test`

Expected: todos os testes passam.

- [ ] **Step 3: Gerar build web**

Run: `flutter build web --dart-define=COELO_DEV_MFA=true`

Expected: build concluído em `build/web`.

- [ ] **Step 4: Atualizar preview e criar commit isolado**

Reiniciar o servidor local, confirmar HTTP 200 e versionar somente esta entrega, preservando alterações preexistentes de logos.
