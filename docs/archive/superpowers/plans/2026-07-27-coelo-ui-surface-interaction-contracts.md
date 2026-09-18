---
source: "docs/superpowers/specs/2026-07-27-popup-surface-standard-design.md"
status: "approved-for-execution"
generated_at: "2026-07-27"
---

# Coelo UI Surface Interaction Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tornar superfícies de popup, hover, fechamento e filtros padrões
oficiais, recuperáveis e verificáveis do Coelo UI.

**Architecture:** O Design System contém o contrato normativo; o índice torna
cada padrão encontrável; o catálogo demonstra composições reais sem promover
novos componentes; o skill encaminha tarefas visuais para uma referência curta
e obrigatória. Testes de consulta, catálogo e cenários de agente protegem contra
regressão.

**Tech Stack:** Markdown, PowerShell, JSONL, Flutter/Dart e widget tests.

## Global Constraints

- Popup usa `colorScheme.surface`: branco no light e neutro escuro no dark.
- Hover discreto usa `primaryContainer`, `primary`, `CoeloRadius.md` e 4 px
  entre itens; filtros e tabelas permanecem linhas contínuas.
- Fechamento usa `close_rounded`, `error`, `errorContainer`, forma circular,
  alvo mínimo de 48 px e tooltip contextual.
- Filtros seguem Instituições no multi-select e Bug no single-select.
- Tabelas densas seguem `CoeloAdminResizableTable` de Instituições, preservando
  cabeçalho sutil, linhas contínuas, coluna fixa, resize e scroll horizontal.
- Não criar HEX, token, variante ou componente público novo.
- Preservar todas as mudanças preexistentes no working tree.

---

### Task 1: Provar as falhas do skill atual

**Files:**
- Modify: `.agents/skills/coelo-ui/tests/scenarios.md`

**Interfaces:**
- Consumes: skill atual e o documento de design aprovado.
- Produces: baseline reproduzível para popup, hover, fechamento e filtros.

- [ ] **Step 1: Executar cenários sem o skill**

Usar agentes novos, somente leitura, sob pressão de tempo. Solicitar um popup
com fundo de marca, hover padrão Material, “X” genérico e filtro improvisado.
Registrar as escolhas e justificativas observadas.

- [ ] **Step 2: Registrar o RED**

Acrescentar quatro cenários e seus resultados reais a `scenarios.md`, incluindo
os termos exatos que o agente usou para aceitar superfície laranja, hover cinza,
fechamento sem contrato e filtro fora do padrão.

- [ ] **Step 3: Confirmar que o baseline falha pelo motivo esperado**

Verificar que ao menos um cenário viola cada família de contrato. Se um cenário
passar naturalmente, apertar somente a pressão correspondente e repetir antes
de editar o skill.

### Task 2: Oficializar contratos normativos e orientação do skill

**Files:**
- Modify: `docs/design/design-system.md`
- Create: `.agents/skills/coelo-ui/references/surface-interaction-contracts.md`
- Modify: `.agents/skills/coelo-ui/SKILL.md`
- Create: `.agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1`

**Interfaces:**
- Consumes: `colorScheme`, `CoeloSpacing`, `CoeloRadius` e componentes atuais.
- Produces: referência obrigatória sem criar API pública.

- [ ] **Step 1: Escrever o teste documental e verificar RED**

O teste PowerShell deve exigir no arquivo de referência:

```powershell
Assert-Contains 'colorScheme.surface'
Assert-Contains 'colorScheme.primaryContainer'
Assert-Contains 'CoeloRadius.md'
Assert-Contains 'CoeloSpacing.spaceHalf'
Assert-Contains 'colorScheme.errorContainer'
Assert-Contains 'CoeloRadius.full'
Assert-Contains 'CoeloAdminMultiSelectFilter'
```

Executar:

```powershell
& '.agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1'
```

Esperado: FAIL porque a referência ainda não existe.

- [ ] **Step 2: Adicionar a seção normativa ao Design System**

Registrar anatomia, estados, exceções, acessibilidade e referências canônicas
em uma seção operacional derivada da spec aprovada.

- [ ] **Step 3: Criar a referência e o roteamento obrigatório**

O `SKILL.md` deve exigir a leitura de
`references/surface-interaction-contracts.md` quando a tarefa mencionar popup,
modal, dialog, overlay, hover, menu, filtro, close, dismiss ou “X”.

- [ ] **Step 4: Verificar GREEN**

Executar o teste PowerShell e esperar `surface-interaction-contracts.tests.ps1: PASS`.

### Task 3: Tornar os padrões recuperáveis no índice

**Files:**
- Modify: `apps/catalog/assets/coelo-ui.index.jsonl`
- Modify: `.agents/skills/coelo-ui/tests/query-index.tests.ps1`

**Interfaces:**
- Consumes: contratos normativos e entradas atuais de busca/seleção.
- Produces: `pattern.overlay-surfaces`, `pattern.interaction-states` e entradas
  enriquecidas de toolbar/multi-select/selection.

- [ ] **Step 1: Adicionar consultas que falham**

Exigir:

```powershell
Assert-QueryContains -Query 'popup modal dialog overlay' -ExpectedId 'pattern.overlay-surfaces'
Assert-QueryContains -Query 'hover laranja arredondado' -ExpectedId 'pattern.interaction-states'
Assert-QueryContains -Query 'close dismiss vermelho' -ExpectedId 'pattern.overlay-surfaces'
Assert-QueryContains -Query 'single-select' -ExpectedId 'pattern.selection-controls'
```

Executar `query-index.tests.ps1` e confirmar FAIL para IDs ausentes.

- [ ] **Step 2: Atualizar JSONL**

Adicionar as duas entradas de padrão e enriquecer `admin.listing-toolbar`,
`admin.multi-select-filter` e `pattern.selection-controls` com estados, tokens,
acessibilidade e palavras-chave aprovadas.

- [ ] **Step 3: Verificar consultas e schema**

Executar:

```powershell
& '.agents/skills/coelo-ui/tests/query-index.tests.ps1'
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe --disable-dart-dev tool/validate_catalog_index.dart assets/coelo-ui.index.jsonl ../..
```

Esperado: ambas as verificações passam sem diagnóstico.

### Task 4: Demonstrar os contratos no catálogo

**Files:**
- Create: `apps/catalog/lib/catalog/surface_interaction_catalog_foundations.dart`
- Modify: `apps/catalog/lib/catalog/catalog_foundations.dart`
- Create: `apps/catalog/test/catalog/surface_interaction_catalog_test.dart`

**Interfaces:**
- Consumes: `CatalogFoundation`, `CoeloAdminMultiSelectFilter`,
  `CoeloAdminResizableTable` e tokens de tema.
- Produces: `buildSurfaceInteractionFoundationRegistry()`.

- [ ] **Step 1: Escrever widget tests e verificar RED**

Os testes devem procurar os padrões indexados, abrir o popup de demonstração e
inspecionar:

```dart
expect(dialog.backgroundColor, theme.colorScheme.surface);
expect(close.style?.foregroundColor?.resolve({}), theme.colorScheme.error);
expect(
  close.style?.backgroundColor?.resolve({WidgetState.hovered}),
  theme.colorScheme.errorContainer,
);
expect(discreteStyle.shape?.resolve({}), isA<RoundedRectangleBorder>());
expect(filterStyle.backgroundColor?.resolve({WidgetState.hovered}), theme.colorScheme.primaryContainer);
expect(find.byType(CoeloAdminMultiSelectFilter<String>), findsOneWidget);
expect(find.byType(CoeloAdminResizableTable<_ExampleInstitution>), findsOneWidget);
```

Executar o teste focado e confirmar falha por registry ausente.

- [ ] **Step 2: Implementar as foundations**

Compor popup, ação de fechar, item discreto, linhas contínuas, seletores e a
tabela canônica com `CoeloAdminResizableTable`, sem criar componente público
ou importar código do Superadmin.

- [ ] **Step 3: Integrar ao registry sem remover Chat**

Importar o novo arquivo e espalhar
`...buildSurfaceInteractionFoundationRegistry()` junto do registry já
existente.

- [ ] **Step 4: Verificar catálogo**

Executar os testes focados, `catalog_foundation_page_test.dart` e
`showroom_content_equivalence_test.dart`.

### Task 5: Reexecutar cenários e validar o conjunto

**Files:**
- Modify: `.agents/skills/coelo-ui/tests/scenarios.md`
- Modify: `apps/catalog/test/presentation/showroom_content_equivalence_test.dart`
- Update: `apps/catalog/assets/catalog-sync-report.json` somente pelo validador.

**Interfaces:**
- Consumes: skill, referência, Design System, índice e catálogo atualizados.
- Produces: evidência GREEN e relatório de sincronização.

- [ ] **Step 1: Reexecutar os mesmos cenários com o skill**

Cada resposta deve consultar o índice, abrir a referência e rejeitar
explicitamente fundo laranja do popup, hover cinza, “X” neutro e filtro
improvisado.

- [ ] **Step 2: Registrar GREEN e fechar brechas**

Documentar as respostas e acrescentar somente regras necessárias para qualquer
desvio observado; repetir até os quatro cenários passarem.

Atualizar a expectativa de estados do multi-select para incluir os estados
aprovados de busca, vazio, rascunho e aplicação sem introduzir `disabled`.

- [ ] **Step 3: Executar verificação final**

```powershell
& '.agents/skills/coelo-ui/tests/query-index.tests.ps1'
& '.agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1'
dart test test/catalog/surface_interaction_catalog_test.dart
dart test test/presentation/catalog_foundation_page_test.dart
dart test test/presentation/showroom_content_equivalence_test.dart
dart test test/tool/validate_catalog_index_test.dart
dart test test/tool/validate_catalog_sync_test.dart
dart analyze
```

Esperado: zero falhas e zero erros.

- [ ] **Step 4: Revisar o diff**

Confirmar que apenas o escopo aprovado foi alterado e que nenhuma mudança local
preexistente foi removida ou reformatada.

### Task 6: Oficializar a tabela administrativa canônica

**Files:**
- Modify: `docs/design/design-system.md`
- Modify: `.agents/skills/coelo-ui/references/surface-interaction-contracts.md`
- Modify: `.agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1`
- Modify: `.agents/skills/coelo-ui/tests/scenarios.md`

**Interfaces:**
- Consumes: `CoeloAdminResizableTable` e a composição da tela de Instituições.
- Produces: contrato normativo, cenário de skill e catálogo da tabela canônica.

- [ ] **Step 1: Executar e registrar RED sem o skill**

Solicitar sob pressão uma tabela administrativa rápida sem indicar o componente.
Registrar se o agente escolhe `DataTable`, omite scroll/resize/coluna fixa ou
usa zebra/hover neutro.

- [ ] **Step 2: Escrever testes que falham**

Exigir na referência os tokens, a anatomia e o comportamento abaixo por teste
PowerShell antes de acrescentá-los.

- [ ] **Step 3: Registrar o contrato mínimo**

Documentar `surface`, borda/raio/clip, cabeçalho `surfaceContainer`, linhas
contínuas com divisor `outlineVariant`, hover/seleção `primaryContainer`,
altura 64 px mais divisor, coluna fixa visual, scrollbar horizontal visível,
resize por mouse/teclado, truncamento sem wrap, status semântico e ações
compactas.

- [ ] **Step 4: Verificar GREEN**

Executar o teste documental e reexecutar o cenário com o skill. O agente deve
consultar `admin.resizable-table` e reutilizá-lo. A Task 4 demonstra o
componente real no catálogo.
