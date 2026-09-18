---
title: "Institution Directory Polish Implementation Plan"
source: "docs/superpowers/specs/2026-07-20-institution-directory-polish-design.md"
status: "completed"
generated_at: "2026-07-20"
---

# Institution Directory Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refinar a marca e os estados do menu do usuário e adicionar pesquisa local aos filtros geográficos do diretório de instituições.

**Architecture:** Manter a shell e a tela existentes, adicionando somente assets oficiais empacotados, estilos Material explícitos e estado local no menu de filtro. A busca geográfica opera sobre as opções já carregadas pelo view model e não altera repositórios nem Supabase.

**Tech Stack:** Flutter, Dart, Material 3, `flutter_svg`, Flutter widget tests.

## Global Constraints

- Usar apenas tokens e cores semânticas do Coelo; nenhum HEX local.
- Não alterar os SVGs oficiais mantidos na raiz do monorepo.
- Não alterar schema, migration, RLS ou integração Supabase nesta entrega.
- Preservar a ordem e a dependência atuais: UF, Município depois de UF, Bairro depois de Município.
- Não criar a legenda de status antes da definição da taxonomia registrada em `OQ-020`.

---

### Task 1: Contratos visuais da shell

**Files:**
- Modify: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`

**Interfaces:**
- Consumes: `CoeloTheme.light`, `CoeloTheme.dark` e os itens existentes de `_ProfileSummary`.
- Produces: keys `superadmin-brand-logo-light` e `superadmin-brand-logo-dark`; estilos de menu com `backgroundColor`, `foregroundColor`, `iconColor` e `overlayColor` explícitos.

- [ ] **Step 1: Escrever testes falhos para marca e menu do usuário**

Adicionar asserts que exigem círculo semântico e asset específico por tema, ícone/texto de Sair em `colorScheme.error`, fundo `errorContainer` no hover e overlay transparente em todos os itens.

- [ ] **Step 2: Executar o teste focado e confirmar RED**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: FAIL porque os assets/keys e os estilos explícitos ainda não existem.

- [ ] **Step 3: Implementar a marca e os estados sem película**

Substituir o desenho customizado do cabeçalho por `SvgPicture.asset` dentro de `BoxShape.circle`; resolver o tema por `colorScheme.brightness`. Nos itens, usar `WidgetStateProperty` para fundo/foreground/iconColor e `Colors.transparent` para overlay.

- [ ] **Step 4: Executar o teste focado e confirmar GREEN**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: PASS sem exceções ou warnings.

### Task 2: Assets SVG oficiais no app

**Files:**
- Create: `apps/superadmin/assets/brand/logo-coelo-white.svg`
- Create: `apps/superadmin/assets/brand/logo-coelo-orange.svg`
- Modify: `apps/superadmin/pubspec.yaml`
- Modify: `apps/superadmin/pubspec.lock`

**Interfaces:**
- Consumes: `assets/brand/logos/svg/logo Coelo branco.svg` e `assets/brand/logos/svg/logo Coelo Laranja.svg` somente como fontes de leitura.
- Produces: assets empacotados e dependência `flutter_svg` para `_BrandHeader`.

- [ ] **Step 1: Adicionar as cópias literais dos SVGs e declarar os assets**

Criar os dois arquivos do app sem modificar as fontes da raiz e listar ambos em `flutter.assets`.

- [ ] **Step 2: Declarar `flutter_svg` e resolver dependências**

Adicionar uma versão compatível em `dependencies` e executar `flutter pub get`.

- [ ] **Step 3: Verificar carregamento pelos testes da shell**

Run: `flutter test test/app/shell/superadmin_shell_test.dart`

Expected: PASS, incluindo os temas claro e escuro.

### Task 3: Pesquisa nos filtros geográficos

**Files:**
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`

**Interfaces:**
- Consumes: `_FilterMenuOption<T>`, opções do view model e seleção dependente atual.
- Produces: `_DirectoryFilterMenu<T>(searchable, searchFieldKey, searchHintText)` com normalização local de caixa e diacríticos.

- [ ] **Step 1: Escrever testes falhos para UF, Município e Bairro**

Exigir os campos `institution-state-filter-search`, `institution-city-filter-search` e `institution-district-filter-search`; pesquisar `sao`, `CAMP` e `cambui`; confirmar resultados e limpeza após reabrir.

- [ ] **Step 2: Executar o teste focado e confirmar RED**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: FAIL porque os campos pesquisáveis ainda não existem.

- [ ] **Step 3: Implementar estado local e normalização**

Converter `_DirectoryFilterMenu` em `StatefulWidget`, manter `TextEditingController`, filtrar rótulos com uma função que converte letras portuguesas acentuadas e caixa, exibir mensagem de nenhum resultado e limpar consulta ao abrir, fechar e selecionar.

- [ ] **Step 4: Aplicar somente aos filtros geográficos**

Passar `searchable: true`, key e placeholder para UF, Município e Bairro; Tipo e Status permanecem menus simples.

- [ ] **Step 5: Executar o teste focado e confirmar GREEN**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: PASS, incluindo testes responsivos existentes.

### Task 4: Verificação e entrega

**Files:**
- Modify: somente arquivos já listados, se formatação exigir.

**Interfaces:**
- Consumes: implementação concluída das Tasks 1–3.
- Produces: build web verificável e commit isolado, sem incluir alterações locais dos SVGs da raiz.

- [ ] **Step 1: Formatar os Dart modificados**

Run: `dart format lib/app/shell/superadmin_shell.dart lib/features/institutions/presentation/screens/institution_directory_page.dart test/app/shell/superadmin_shell_test.dart test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: arquivos formatados sem erro.

- [ ] **Step 2: Executar análise estática**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 3: Executar a suíte completa**

Run: `flutter test`

Expected: todos os testes passam.

- [ ] **Step 4: Gerar o build web**

Run: `flutter build web --dart-define=COELO_DEV_MFA=true`

Expected: build concluído em `build/web`.

- [ ] **Step 5: Revisar diff e criar commit**

Adicionar somente os arquivos desta entrega e criar `feat(superadmin): polish directory interactions and brand`.

## Resultado da execução

- RED confirmado para os estilos do menu do usuário e para a marca circular por tema.
- RED confirmado para os campos pesquisáveis de UF, Município e Bairro.
- `flutter analyze`: nenhum issue.
- `flutter test`: 138 testes aprovados.
- `flutter build web --dart-define=COELO_DEV_MFA=true`: build concluído.
