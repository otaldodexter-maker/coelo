---
source: "docs/superpowers/specs/2026-07-27-superadmin-sidebar-home-motion-design.md"
status: "approved"
generated_at: "2026-07-27"
---

# Superadmin Sidebar Home Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Iniciar a Home com a sidebar expandida e Estrutura recolhida, remover o hover do cabeçalho e suavizar a transição sem árvores duplicadas.

**Architecture:** Manter o `AnimationController` existente como fonte única do progresso de largura e posição do botão. Renderizar somente o estado visual coerente com o espaço disponível, evitando o `AnimatedSwitcher` que sobrepõe duas sidebars completas.

**Tech Stack:** Flutter, Dart, `flutter_test`, tokens Coelo.

## Global Constraints

- Preservar mudanças locais não relacionadas no arquivo da shell e nos testes.
- Não criar API pública, componente compartilhado ou token.
- Respeitar `MediaQuery.disableAnimations`.
- Executar produção somente depois de testes falharem pelo motivo esperado.

---

### Task 1: Estado inicial e hover

**Files:**
- Modify: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`

**Interfaces:**
- Consumes: `SuperadminShell.currentDestination`
- Produces: estado inicial contextual de `_NavigationContentState` e overlay transparente de `_BrandHeader`

- [ ] **Step 1: Write the failing tests**

Adicionar testes que montem `currentDestination: 'home'`, verifiquem que Home
está presente e que `Unidades` e `Grupos` não estão visíveis; montar
`currentDestination: 'institutions'` e verificar que os filhos de Estrutura
continuam visíveis. Resolver o `overlayColor` do `InkWell` do cabeçalho para
hover, foco e pressão e esperar `Colors.transparent`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/app/shell/superadmin_shell_test.dart --plain-name "starts Home with Structure collapsed and opens the active section contextually"`

Expected: FAIL porque Estrutura ainda nasce aberta na Home.

Run: `flutter test test/app/shell/superadmin_shell_test.dart --plain-name "keeps the Superadmin brand background transparent in every interaction state"`

Expected: FAIL porque o overlay atual resolve para `primaryContainer`.

- [ ] **Step 3: Write minimal implementation**

Remover `'structure'` incondicional de `_expandedSections`, preservando apenas a
seção que contém `currentDestination`. Trocar o overlay do cabeçalho por
`const WidgetStatePropertyAll(Colors.transparent)`.

- [ ] **Step 4: Run focused tests**

Executar novamente os dois comandos e esperar PASS.

### Task 2: Transição única e suave

**Files:**
- Modify: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`

**Interfaces:**
- Consumes: `_sidebarController`, `_sidebarCollapsed`, `_sidebarMotionDuration`
- Produces: uma única `_Sidebar` durante toda a animação

- [ ] **Step 1: Write the failing test**

Durante o frame intermediário do recolhimento, verificar que existe exatamente
uma `_FloatingSurface` com a chave `superadmin-floating-sidebar`, que a largura
está entre 88 e 260 e que não há duas ocorrências da chave de Home nem exceção
de layout.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app/shell/superadmin_shell_test.dart --plain-name "uses one sidebar tree throughout the collapse and expand motion"`

Expected: FAIL porque o `AnimatedSwitcher` mantém a árvore anterior e a nova.

- [ ] **Step 3: Write minimal implementation**

Substituir `_SidebarTransition` por uma composição sem `AnimatedSwitcher`. Usar
o espaço real disponível para alternar a apresentação expandida ou recolhida em
um único ponto seguro da progressão, mantendo a largura externa e o botão
dirigidos pelo mesmo controller. Preservar troca imediata em reduced motion.

- [ ] **Step 4: Run focused motion tests**

Run: `flutter test test/app/shell/superadmin_shell_test.dart --plain-name "sidebar"`

Expected: todos os testes selecionados passam.

### Task 3: Verificação proporcional e memória

**Files:**
- Verify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Verify: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: implementação concluída
- Produces: evidência de formatação, análise, testes e gate de memória

- [ ] **Step 1: Format affected Dart files**

Run: `dart format apps/superadmin/lib/app/shell/superadmin_shell.dart apps/superadmin/test/app/shell/superadmin_shell_test.dart`

- [ ] **Step 2: Run static analysis**

Run: `dart analyze apps/superadmin/lib/app/shell/superadmin_shell.dart apps/superadmin/test/app/shell/superadmin_shell_test.dart`

Expected: sem erros.

- [ ] **Step 3: Run the complete shell test file**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: todos os testes passam.

- [ ] **Step 4: Review the diff and memory gate**

Run: `git diff --check` e revisar somente os hunks afetados. Executar
`scripts/Test-CoeloKnowledge.ps1` e `tests/Test-CoeloKnowledge.ps1`; registrar
`no-op` porque o comportamento durável já está na fonte canônica aprovada e não
exige uma nova projeção de conhecimento.

