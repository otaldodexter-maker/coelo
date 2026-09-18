---
title: "Fundacao Coelo UI, Componentizacao e Catalogo Flutter"
source: "AGENTS.md; docs/design/design-system.md; decisions/0009-design-system-and-tokens.md; decisions/0012-contextual-experiences-and-conversation-history.md; specs/007-design-system-base.md; specs/013-ui-packages-componentization.md; auditoria aprovada em 2026-07-22"
status: "completed-local-foundation-with-operational-gates"
generated_at: "2026-07-27"
approved_at: "2026-07-22"
completed_at: "2026-07-27"
---

# Coelo UI Foundation, Componentization, and Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `subagent-driven-development` (recommended) or `executing-plans` to implement
> this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar a fundacao Flutter profissional do Design System Coelo,
componentizar a tela de instituicoes sem diferenca visual, publicar um catalogo
privado com componentes reais e orientar agentes por um indice compacto e pela
skill project-local `coelo-ui`.

**Architecture:** `coelo_tokens` permanece a base semantica; `coelo_ui_core`
recebe widgets Flutter sem dominio e `coelo_ui_admin` recebe padroes densos de
Admin + Superadmin. Instituicoes conserva entidades, view model, repository,
rotas e composicoes de dominio no app. `apps/catalog` e um build Flutter Web
independente e o Superadmin apenas incorpora sua URL privada, sem importar o
registro do catalogo nem `coelo_ui_principal`.

**Tech Stack:** Dart >= 3.8, Flutter >= 3.38 para apps, Flutter >= 3.32 para
pacotes, Material 3, `flutter_test`, goldens, `go_router`, `coelo_auth`, Supabase
e validadores Dart baseados somente em `dart:convert`/`dart:io`.

## Global Constraints

- A tela de instituicoes e a referencia visual principal e nao pode mudar na
  primeira componentizacao.
- Preservar dimensoes, espacamentos, cores, bordas, sombras, hover, focus,
  selected, pressed, disabled, loading, responsividade, semantica e comportamento.
- Registrar goldens antes de alterar a estrutura da tela.
- Qualquer pixel diferente e regressao ate existir proposta visual aprovada.
- Nao adicionar HEX, `TextStyle`, espacamento ou breakpoint local quando houver
  token semantico adequado.
- Nem todo numero tecnico vira token; geometria exclusiva permanece constante
  privada do componente.
- Nao criar componente, variante, dependencia, commit, push ou deploy sem a
  autorizacao correspondente. Este plano nao autoriza commits automaticos.
- Componentes publicos nao recebem repository, view model, rota, permissao ou
  entidade de produto.
- `coelo_ui_principal` nao importa UI administrativa.
- O Superadmin nao importa o catalogo nem componentes exclusivos do Principal.
- O catalogo renderiza implementacoes reais e nao e editor, CMS ou ferramenta
  de aprovacao.
- O showroom atual so pode ser removido depois de equivalencia demonstrada.
- Astro e apenas registrado nesta entrega; nenhum codigo Astro sera criado.
- Toda tarefa usa TDD quando muda contrato ou comportamento e termina com
  verificacao focada e inspecao de `git diff`.
- Formatar somente arquivos afetados e preservar mudancas nao relacionadas.

---

## File and Dependency Map

```text
coelo_tokens
  -> coelo_ui_core
       -> coelo_ui_admin
            -> apps/superadmin
            -> apps/catalog

coelo_auth -> apps/superadmin
coelo_auth -> apps/catalog

coelo_ui_principal (reservado; nao materializar)
coelo_ui_superadmin (reservado; nao materializar)
```

Arquivos publicos planejados:

```text
packages/coelo_ui_core/
  pubspec.yaml
  analysis_options.yaml
  lib/coelo_ui_core.dart
  lib/src/input/coelo_search_field.dart
  lib/src/status/coelo_status_chip.dart
  lib/src/feedback/coelo_state_panel.dart
  test/input/coelo_search_field_test.dart
  test/status/coelo_status_chip_test.dart
  test/feedback/coelo_state_panel_test.dart

packages/coelo_ui_admin/
  pubspec.yaml
  analysis_options.yaml
  lib/coelo_ui_admin.dart
  lib/src/listing/coelo_admin_listing_toolbar.dart
  lib/src/filter/coelo_admin_multi_select_filter.dart
  lib/src/listing/coelo_admin_pagination.dart
  lib/src/listing/coelo_admin_create_action.dart
  lib/src/table/coelo_admin_table_column.dart
  lib/src/table/coelo_admin_resizable_table.dart
  test/...

apps/catalog/
  pubspec.yaml
  analysis_options.yaml
  lib/main.dart
  lib/app/catalog_app.dart
  lib/auth/catalog_access_gateway.dart
  lib/auth/supabase_catalog_access_gateway.dart
  lib/catalog/catalog_entry.dart
  lib/catalog/catalog_registry.dart
  lib/catalog/catalog_filters.dart
  lib/catalog/catalog_sync_status.dart
  lib/presentation/catalog_home_page.dart
  lib/presentation/component_detail_page.dart
  lib/presentation/widgets/catalog_stale_banner.dart
  assets/coelo-ui.index.jsonl
  tool/validate_catalog_sync.dart
  test/...
```

Arquivos locais de instituicoes apos a divisao:

```text
apps/superadmin/lib/features/institutions/presentation/
  screens/institution_directory_page.dart
  widgets/institution_directory_toolbar.dart
  widgets/institution_directory_states.dart
  widgets/institution_directory_cards.dart
  widgets/institution_directory_table.dart
  widgets/institution_directory_pagination.dart
  widgets/institution_status_presentation.dart
  widgets/institution_file_actions.dart
```

Contratos adiados deliberadamente:

- O atual botao de copiar continua local porque sua area de 32 px conflita com
  o alvo minimo de 48 px. A promocao exige uma anatomia visualmente neutra
  aprovada.
- O status expansivel atual de instituicoes continua local porque o indicador
  de 24 px e a ativacao por ponteiro nao satisfazem o contrato acessivel. A
  implementacao acessivel da central de atividades serve de referencia futura.
- `coelo_ui_superadmin` e `coelo_ui_principal` permanecem sem `pubspec.yaml` e
  sem `lib/` nesta entrega.

## Public Contracts

Os nomes e assinaturas abaixo sao o contrato da primeira versao. Acrescentar
parametros, construtores nomeados ou enums de variante exige atualizar a spec,
o indice, o catalogo e obter aprovacao.

```dart
final class CoeloSearchField extends StatelessWidget {
  const CoeloSearchField({
    required this.controller,
    required this.onChanged,
    required this.semanticLabel,
    this.hintText,
    this.focusNode,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String semanticLabel;
  final String? hintText;
  final FocusNode? focusNode;
  final bool enabled;
}

final class CoeloStatusChip extends StatelessWidget {
  const CoeloStatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
}

final class CoeloStatePanel extends StatelessWidget {
  const CoeloStatePanel({
    required this.title,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.loading = false,
    super.key,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;
}

final class CoeloAdminListingToolbar extends StatelessWidget {
  const CoeloAdminListingToolbar({
    required this.search,
    required this.filters,
    required this.actions,
    super.key,
  });

  final Widget search;
  final List<Widget> filters;
  final List<Widget> actions;
}

final class CoeloAdminMultiSelectFilter<T> extends StatefulWidget {
  const CoeloAdminMultiSelectFilter({
    required this.label,
    required this.options,
    required this.selectedValues,
    required this.optionLabel,
    required this.onChanged,
    this.searchHintText,
    super.key,
  });

  final String label;
  final List<T> options;
  final Set<T> selectedValues;
  final String Function(T value) optionLabel;
  final ValueChanged<Set<T>> onChanged;
  final String? searchHintText;
}

final class CoeloAdminPagination extends StatelessWidget {
  const CoeloAdminPagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
}

final class CoeloAdminCreateAction extends StatelessWidget {
  const CoeloAdminCreateAction({
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
}

typedef CoeloAdminCellBuilder<T> = Widget Function(BuildContext context, T item);

final class CoeloAdminTableColumn<T> {
  const CoeloAdminTableColumn({
    required this.id,
    required this.label,
    required this.initialWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.cellBuilder,
  });

  final String id;
  final String label;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final CoeloAdminCellBuilder<T> cellBuilder;
}

final class CoeloAdminResizableTable<T> extends StatefulWidget {
  const CoeloAdminResizableTable({
    required this.items,
    required this.rowKey,
    required this.pinnedColumn,
    required this.columns,
    required this.headerHeight,
    required this.rowHeight,
    this.onRowPressed,
    this.isSelected,
    super.key,
  });

  final List<T> items;
  final Object Function(T item) rowKey;
  final CoeloAdminTableColumn<T> pinnedColumn;
  final List<CoeloAdminTableColumn<T>> columns;
  final double headerHeight;
  final double rowHeight;
  final ValueChanged<T>? onRowPressed;
  final bool Function(T item)? isSelected;
}
```

O componente de tabela controla apenas scroll, largura, hover, selecao,
redimensionamento e coluna fixa. `InstitutionDirectoryItem`, enum de colunas,
mensagens de copia, status e construcao das celulas permanecem no Superadmin.

## Index Contract

Cada linha de `apps/catalog/assets/coelo-ui.index.jsonl` e um objeto JSON com
estas chaves obrigatorias e sem campos narrativos extensos:

```json
{"id":"core.search-field","name":"CoeloSearchField","category":"component","status":"implemented","ownerPackage":"coelo_ui_core","consumers":["superadmin"],"purpose":"Busca textual administrativa.","useWhen":"Busca simples por texto.","doNotUseWhen":"Selecao de opcoes.","variants":[],"states":["enabled","focused","disabled"],"tokens":["spacing.2","radius.full","color.outline"],"accessibility":"Rotulo semantico; foco por teclado.","publicFile":"packages/coelo_ui_core/lib/coelo_ui_core.dart","tests":["packages/coelo_ui_core/test/input/coelo_search_field_test.dart"],"example":"CoeloSearchField(controller: c, onChanged: search, semanticLabel: 'Buscar')","replacement":null}
```

Valores aceitos de `status`: `proposed`, `approved`, `implemented`,
`deprecated`, `catalog-stale`. Valores aceitos de consumidor: `shared`,
`admin`, `superadmin`, `principal`, `auth`, `astro-planned`.

---

### Task 1: Freeze the Institution Visual Baseline

**Files:**
- Create: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart`
- Create: `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_*.png`
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- Read only: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`

**Interfaces:**
- Consumes: tela atual sem qualquer alteracao de produto.
- Produces: baseline deterministica para comparar todas as tarefas seguintes.

- [x] **Step 1: Fixar o harness visual**

Criar helper privado no teste com `FakeInstitutionDirectoryRepository`, fonte
Nunito Sans carregada, `devicePixelRatio: 1`, animacoes desabilitadas e
`pumpAndSettle()` depois do carregamento. Nao alterar a tela para facilitar o
teste.

- [x] **Step 2: Registrar os estados estaveis**

Gerar cards e tabela em light/dark para 375, 768, 1024 e 1440. Gerar goldens
focados para hover, focus, selected, loading, erro, vazio e sem permissao.

- [x] **Step 3: Registrar comportamento nao visual atual**

Adicionar testes de tab order, Escape em menus, texto com `TextScaler.linear(2)`
e semantics. Problemas existentes devem ser descritos em nomes de testes de
caracterizacao, sem alterar expectativas visuais nem transformar falha conhecida
em contrato oficial de pacote.

- [x] **Step 4: Executar a baseline**

Run, workdir `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test --update-goldens test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart test/features/institutions/presentation/screens/institution_directory_page_test.dart
```

Expected: ambos os comandos terminam com `All tests passed!`; os PNGs novos
ficam no diff e nenhuma fonte de produto muda.

- [x] **Step 5: Checkpoint**

Inspecionar os PNGs em light/dark e `git diff --check`. Relatar arquivos,
estados cobertos e problemas atuais; nao fazer commit.

### Task 2: Establish the Compact Index Before Packages

**Files:**
- Create: `apps/catalog/pubspec.yaml`
- Create: `apps/catalog/analysis_options.yaml`
- Create: `apps/catalog/assets/coelo-ui.index.jsonl`
- Create: `apps/catalog/tool/validate_catalog_index.dart`
- Create: `apps/catalog/test/tool/validate_catalog_index_test.dart`
- Create: `apps/catalog/README.md`

**Interfaces:**
- Consumes: contrato JSONL deste plano.
- Produces: `CatalogIndexValidationResult validateCatalogIndex(...)` e primeiras
  entradas `approved` para componentes deste plano.

- [x] **Step 1: Escrever testes do parser/validador**

Cobrir linha invalida, id duplicado, chave obrigatoria ausente, status invalido,
arquivo inexistente e `deprecated` sem `replacement` quando houver substituto.
O teste usa diretorio temporario criado por `Directory.systemTemp.createTemp()`
e remove somente esse caminho no `tearDown`.

- [x] **Step 2: Confirmar falha inicial**

Run, workdir `apps/catalog` depois de criar o `pubspec.yaml` minimo junto do
teste, contendo apenas SDK Dart para o validador e Flutter para o app futuro:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/tool/validate_catalog_index_test.dart
```

Expected: falha de compilacao porque `validateCatalogIndex` ainda nao existe.

- [x] **Step 3: Implementar com biblioteca padrao**

Usar `LineSplitter`, `jsonDecode`, `File.existsSync` e objetos de diagnostico
imutaveis. Nao adicionar pacote de schema JSON ou geracao de codigo.

- [x] **Step 4: Adicionar as entradas aprovadas**

Registrar `core.search-field`, `core.status-chip`, `core.state-panel`,
`admin.listing-toolbar`, `admin.multi-select-filter`, `admin.pagination`,
`admin.create-action` e `admin.resizable-table` com `status: "approved"`.

- [x] **Step 5: Verificar**

Run, workdir `apps/catalog`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/tool/validate_catalog_index_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe tool/validate_catalog_index.dart assets/coelo-ui.index.jsonl ..\..
```

Expected: testes passam; o comando reporta zero erro estrutural, permitindo que
arquivos ainda nao implementados permaneçam `approved`.

### Task 3: Add Only Visual-Neutral Semantic Token Aliases

**Files:**
- Modify: `packages/coelo_tokens/lib/src/coelo_theme.dart`
- Modify: `packages/coelo_tokens/lib/src/coelo_scales.dart`
- Modify: `packages/coelo_tokens/test/coelo_tokens_test.dart`

**Interfaces:**
- Produces: `CoeloActionColors.actionLink`, `primaryPressed`, `focusRing` e
  `CoeloOverlayColors.scrim`; nao muda valores resolvidos pelo Superadmin.

- [x] **Step 1: Escrever testes de equivalencia**

Os testes devem obter extensoes de `CoeloTheme.light` e `CoeloTheme.dark`,
confirmar os aliases e comparar as propriedades existentes de `ColorScheme`,
`InputDecorationTheme`, botoes, chips, cards e tabela antes/depois.

- [x] **Step 2: Confirmar falha pelos getters ausentes**

Run, workdir `packages/coelo_tokens`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/coelo_tokens_test.dart
```

Expected: falha de compilacao nos novos nomes semanticos.

- [x] **Step 3: Implementar aliases e extensao de overlay**

Reusar exclusivamente cores ja resolvidas pela paleta/tema. Nao substituir os
420 ms, 260 ms, thresholds 768/1000 ou focus border atual nesta tarefa.

`coelo_scales.dart` permaneceu inalterado: nenhum novo valor de escala foi
necessario para os aliases aprovados, e criar uma opacidade separada apenas para
o scrim duplicaria a decisao ja encapsulada por `CoeloOverlayColors.scrim`.

- [x] **Step 4: Verificar pacote e baseline**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib test
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test
```

Depois executar novamente o golden de instituicoes sem `--update-goldens`.
Expected: tudo passa e nenhum PNG muda.

### Task 4: Materialize `coelo_ui_core`

**Files:**
- Create: `packages/coelo_ui_core/pubspec.yaml`
- Create: `packages/coelo_ui_core/analysis_options.yaml`
- Create: `packages/coelo_ui_core/lib/coelo_ui_core.dart`
- Create: os tres arquivos `lib/src/...` e seus tres testes descritos no mapa.
- Modify: `packages/coelo_ui_core/README.md`

**Interfaces:**
- Consumes: `coelo_tokens` e Flutter Material.
- Produces: exatamente `CoeloSearchField`, `CoeloStatusChip` e
  `CoeloStatePanel` definidos neste plano.

- [x] **Step 1: Criar testes de contrato antes dos widgets**

Cobrir light/dark, label semantica e foco da busca, disabled, callback de texto,
chip com texto+cor, loading/erro/vazio, acao opcional, texto 200% e largura 375.

- [x] **Step 2: Confirmar falha inicial**

Run, workdir `packages/coelo_ui_core`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test
```

Expected: falha porque o barrel ainda nao exporta os tres widgets.

- [x] **Step 3: Implementar a menor API aprovada**

Reproduzir a decoracao da busca, status chip e painel de estado existentes em
instituicoes usando ThemeData/tokens. Nao criar `CoeloButton`, classe base de
componente, factory, tema duplicado ou parametros futuros.

- [x] **Step 4: Verificar fronteira**

Executar `rg -n "apps/|Institution|ViewModel|Repository|go_router|supabase" lib`
e esperar zero resultado. Executar format, analyze e test no pacote.

### Task 5: Materialize the Small Administrative Patterns

**Files:**
- Create: `packages/coelo_ui_admin/pubspec.yaml`
- Create: `packages/coelo_ui_admin/analysis_options.yaml`
- Create: `packages/coelo_ui_admin/lib/coelo_ui_admin.dart`
- Create: toolbar, filtro, paginacao e acao de criacao descritos no mapa.
- Create: testes correspondentes em `packages/coelo_ui_admin/test/`.
- Modify: `packages/coelo_ui_admin/README.md`

**Interfaces:**
- Consumes: Flutter, `coelo_tokens`, `coelo_ui_core`.
- Produces: os quatro contratos administrativos definidos neste plano.

- [x] **Step 1: Escrever testes da toolbar e filtro**

Cobrir ordem visual, wrap nos quatro viewports, busca interna, selecao multipla,
limpar selecao, hover, foco, Escape, retorno do foco e ausencia de alteracao do
`Set<T>` recebido.

- [x] **Step 2: Escrever testes de paginacao e criacao**

Cobrir primeira/ultima pagina, callbacks nulos, labels semanticos, Enter/Espaco,
hover e reduced motion.

- [x] **Step 3: Confirmar falha e implementar**

Executar a suite para observar exports ausentes; implementar copiando somente a
anatomia visual aprovada de instituicoes e substituindo dependencias de dominio
pelos callbacks do contrato.

- [x] **Step 4: Verificar pacote**

Run, workdir `packages/coelo_ui_admin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib test
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test
```

Expected: zero issue e todos os testes passam.

### Task 6: Extract the Resizable Administrative Table Mechanics

**Files:**
- Create: `packages/coelo_ui_admin/lib/src/table/coelo_admin_table_column.dart`
- Create: `packages/coelo_ui_admin/lib/src/table/coelo_admin_resizable_table.dart`
- Create: `packages/coelo_ui_admin/test/table/coelo_admin_resizable_table_test.dart`
- Modify: `packages/coelo_ui_admin/lib/coelo_ui_admin.dart`

**Interfaces:**
- Produces: `CoeloAdminTableColumn<T>` e `CoeloAdminResizableTable<T>` definidos
  neste plano.

- [x] **Step 1: Caracterizar a mecanica em testes genericos**

Usar um modelo privado `TestRow(id, name, status)`. Cobrir coluna fixa, scroll
horizontal, resize dentro de min/max, alinhamento header/celula, hover, selected,
tap de linha e chaves estaveis.

- [x] **Step 2: Escrever contrato acessivel do redimensionador**

O handle deve ter label semantica `Redimensionar coluna <label>` e aceitar
setas esquerda/direita em passos de 8 px, alem do drag atual. A area visual
continua igual; a area de interacao pode ser ampliada por sobreposicao sem
alterar largura ou alinhamento.

- [x] **Step 3: Confirmar falha e implementar o estado minimo**

Manter apenas um `Map<String, double>` de larguras no State. Nao criar
controller publico, datasource, sort model, selection model ou virtualizacao
sem consumidor aprovado.

- [x] **Step 4: Verificar**

Executar analyze/test do pacote e os goldens de instituicoes. Expected: pacote
passa; instituicoes ainda nao mudou nesta tarefa.

### Task 7: Migrate Institutions Without Visual Change

**Approved boundary decisions (2026-07-23):**
- Keep the vertical create card and compact create banner as local
  institution compositions; do not add a public variant or remove descriptions.
- Preserve page-level and row keys. Encapsulated scroll/header/resizer/pinned
  mechanics may adopt the generic `coelo-admin-*` keys without adding public key
  configuration.

**Files:**
- Modify: `apps/superadmin/pubspec.yaml`
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Create: os sete arquivos locais de instituicoes listados no mapa.
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- Read/retain: `apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart`

**Interfaces:**
- Consumes: `coelo_ui_core`, `coelo_ui_admin`.
- Preserva: construtor publico de `InstitutionDirectoryPage`, view model,
  repository, rotas, keys e callbacks existentes.

- [x] **Step 1: Adicionar dependencias locais**

Adicionar somente paths para `coelo_ui_core` e `coelo_ui_admin`; nao adicionar
pacote externo.

- [x] **Step 2: Migrar busca, estados e status chip** — busca e status
  migrados; estados permaneceram locais pela incompatibilidade aprovada e foram
  separados em composicao local propria.

Substituir widgets privados pelos contratos core mantendo valores e keys. O
mapping `InstitutionStatus -> label/cores` permanece em
`institution_status_presentation.dart`.

- [x] **Step 3: Migrar toolbar, filtro, criacao e paginacao** — toolbar e
  paginacao migradas; filtros e criacao permaneceram locais pelas decisoes de
  compatibilidade aprovadas e foram separados em composicoes locais.

O arquivo local recebe `InstitutionDirectoryViewModel` e adapta seus valores e
metodos para APIs por callback. Nenhum pacote recebe o view model.

- [x] **Step 4: Migrar a mecanica da tabela**

Construir `CoeloAdminTableColumn<InstitutionDirectoryItem>` localmente. Manter
larguras, headers, alturas, pinned column, mensagens, copy e navegacao atuais.

- [x] **Step 5: Dividir cards e composicoes locais** — status, paginacao,
  tabela, toolbar, states e cards separados por responsabilidade, sem promover
  composicoes de dominio.

Mover codigo sem alterar sua estrutura visual. Card de instituicao, detalhes,
copy, status expansivel e fluxos de arquivo permanecem privados.

- [x] **Step 6: Reduzir fronteira de rebuild**

Usar builders/listenables somente ao redor das partes dependentes do estado,
sem mudar a sequencia loading/resultados. Nao alterar debounce nem chamadas do
repository nesta entrega visual.

- [x] **Step 7: Comparar baseline com tolerancia zero**

Run, workdir `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/features/institutions test/features/institutions
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\bin\cache\flutter_tools.snapshot test --no-pub -j 1 test/features/institutions
```

Executar goldens sem `--update-goldens`. Expected: todos passam e os PNGs nao
mudam. Se um pixel mudar, parar esta tarefa e diagnosticar antes de continuar.

#### Follow-up aprovado: opcoes geograficas derivadas dos dados

Somente depois de concluir a migracao com tolerancia visual zero, alterar em uma
entrega funcional separada a fonte das opcoes geograficas. O filtro de UF deve
receber apenas UFs distintas presentes nos registros acessiveis; municipio deve
receber apenas valores existentes para as UFs selecionadas; bairro deve receber
apenas valores existentes para o recorte anterior. A regra e a consulta ficam no
repository/view model de instituicoes, enquanto o multiselect administrativo
continua generico e recebe opcoes por parametro.

Escrever primeiro testes de repository e view model para a cascata, selecoes que
deixam de ser validas e estado sem opcoes. Nao transformar a lista fixa das 27 UFs
em contrato do componente nem modificar o baseline durante a extracao inicial.

#### Correcao visual priorizada antes de encerrar a Task 7

Antes de seguir para a Task 8, revalidar em build local nova:

- submenu da navegacao recolhida com o mesmo hover/espacamento/elevacao do menu
  de tour;
- botao circular de recolher/abrir parcialmente dentro e fora da lateral;
- marca do shell e das telas login, esqueci minha senha e redefinicao:
  - light: circulo laranja com `logo Coelo branco.svg`;
  - dark: circulo branco com `logo Coelo Laranja.svg`.

Usar como fonte canonica os SVGs em `assets/brand/logos/svg/` e confirmar a
fidelidade das copias do app. Criar caracterizacao/goldens antes da mudanca e
comparar depois. Antecipar somente a padronizacao visual da marca; a revisao e
componentizacao de auth continuam na Task 13.

### Task 8: Register Implemented Components and Enforce Package Boundaries

**Files:**
- Modify: `apps/catalog/assets/coelo-ui.index.jsonl`
- Create: `apps/catalog/tool/validate_package_boundaries.dart`
- Create: `apps/catalog/test/tool/validate_package_boundaries_test.dart`

**Interfaces:**
- Produces: validacao de exports publicos e direcao de dependencias.

- [x] **Step 1: Atualizar entradas para `implemented`**

Preencher consumidores, tokens, acessibilidade, arquivo publico, teste e exemplo
minimo de cada componente realmente migrado.

- [x] **Step 2: Implementar scanner sem dependencia**

Ler barrels Dart e reconhecer classes publicas que estendem
`StatelessWidget`/`StatefulWidget`. Falhar quando widget publico nao possui id no
indice, quando core importa admin/app, quando admin importa app/superadmin ou
quando Principal importa pacote administrativo.

- [x] **Step 3: Verificar**

Run, workdir `apps/catalog`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\bin\cache\flutter_tools.snapshot test --no-pub test\tool\validate_package_boundaries_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe tool\validate_package_boundaries.dart assets\coelo-ui.index.jsonl ..\..
```

Expected: zero violacao.

### Task 9: Build the Independent Catalog App and Fail-Closed Access Gate

**Files:**
- Complete: `apps/catalog/pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`
- Create: `apps/catalog/lib/app/catalog_app.dart`
- Create: `apps/catalog/lib/auth/catalog_access_gateway.dart`
- Create: `apps/catalog/lib/auth/supabase_catalog_access_gateway.dart`
- Create: `apps/catalog/test/auth/catalog_access_gateway_test.dart`
- Copy canonical font asset to: `apps/catalog/assets/brand/NunitoSans-VariableFont.ttf`

**Interfaces:**
- Consumes: `coelo_auth`, `coelo_tokens`, Supabase publishable client.
- Produces: `Future<CatalogAccessResult> checkAccess()`.

```dart
abstract interface class CatalogAccessGateway {
  Future<CatalogAccessResult> checkAccess();
}

enum CatalogAccessResult { allowed, unauthenticated, denied, unavailable }
```

- [x] **Step 1: Escrever testes de acesso**

Cobrir sem sessao, sessao sem linhas visiveis, usuario com membership visivel e
erro de rede. Apenas membership protegido por RLS e `platform.read` permite
`allowed`; toda excecao resulta em `unavailable`, nunca em acesso liberado.

- [x] **Step 2: Implementar autenticacao separada**

Usar chave de persistencia `coelo.catalog.auth.session`. Nao ler storage do
Superadmin nem aceitar query string, fragmento ou `postMessage` como credencial.

- [x] **Step 3: Implementar autorizacao existente**

Consultar `platform_memberships` com `select('id').limit(1)`. A policy existente
baseada em `app_private.has_platform_permission('platform.read')` determina a
visibilidade server-side. Resultado vazio e acesso negado.

- [x] **Step 4: Verificar**

Executar analyze/test do app. Expected: usuario autenticado sem
`platform.read` continua bloqueado e nenhuma `service_role` aparece no codigo.

### Task 10: Render the Real Components and Catalog Metadata

**Files:**
- Create: arquivos `lib/catalog/...` e `lib/presentation/...` listados no mapa.
- Create: `apps/catalog/test/catalog/catalog_filters_test.dart`
- Create: `apps/catalog/test/presentation/catalog_home_page_test.dart`
- Create: `apps/catalog/test/presentation/component_detail_page_test.dart`

**Interfaces:**
- Produces: `CatalogEntry`, `CatalogExample`, `CatalogFilter` e
  `Map<String, CatalogExample> buildCatalogRegistry()`.

- [x] **Step 1: Testar parsing e filtros**

Cobrir todos, compartilhados, Admin + Superadmin, somente Superadmin, somente
Admin, somente Principal, auth e Astro planejado; cobrir status e busca por
nome/id.

- [x] **Step 2: Criar registro de builders reais**

Cada `id` implementado usa imports dos barrels publicos dos pacotes. Exemplos
de dominio permanecem no catalogo e alimentam callbacks fake locais; nenhum
widget visual e copiado.

- [x] **Step 3: Construir fundamentos e detalhe**

Mostrar tema, viewport 375/768/1024/1440, interacao, estados registrados,
tokens, acessibilidade, pacote, consumidores, arquivos, testes, quando usar,
quando nao usar e snippet minimo copiavel. Controles aparecem somente para
variantes listadas no indice.

- [x] **Step 4: Testar interacoes**

Digitar na busca, abrir filtro, navegar por teclado, mudar light/dark, mudar
viewport e copiar snippet. Verificar texto 200% e reduced motion.

- [x] **Step 5: Verificar app**

Executar format, analyze, testes focados e suite completa de `apps/catalog`.

### Task 11: Add Non-Blocking Synchronization Validation

**Files:**
- Create: `apps/catalog/lib/catalog/catalog_sync_status.dart`
- Create: `apps/catalog/lib/presentation/widgets/catalog_stale_banner.dart`
- Create: `apps/catalog/tool/validate_catalog_sync.dart`
- Create: `apps/catalog/test/tool/validate_catalog_sync_test.dart`
- Create: `apps/catalog/test/presentation/catalog_stale_banner_test.dart`

**Interfaces:**
- Produces: `CatalogSyncReport` com diagnostics e status
  `synchronized|catalogStale`; processo retorna exit code 0 na primeira versao.

- [x] **Step 1: Testar as cinco divergencias exigidas**

Cobrir widget publico ausente, arquivo inexistente, fingerprint de fonte ou
exemplo diferente, variantes registry/index divergentes e deprecated sem
substituto aplicavel.

- [x] **Step 2: Implementar fingerprints**

Usar hash deterministico simples implementado no script sobre bytes dos arquivos
publicos e snippets. Nao adicionar pacote crypto para um sinal de stale que nao
e controle de seguranca.

- [x] **Step 3: Implementar alerta persistente**

Renderizar exatamente `Componente implementado; índice e catálogo
desatualizados.` enquanto existir diagnostico e mostrar status
`catálogo desatualizado`. O banner nao pode ser dispensado.

- [x] **Step 4: Confirmar que a validacao nao bloqueia publicacao**

O comando imprime diagnostics, grava um JSON de relatorio consumido pelo app e
retorna 0. Testes confirmam texto/status e retorno nao bloqueante.

### Task 12: Create and Validate the Project-Local `coelo-ui` Skill

**Skills required:** `skill-creator`, `writing-skills`.

**Files:**
- Create: `.agents/skills/coelo-ui/SKILL.md`
- Create: `.agents/skills/coelo-ui/references/package-boundaries.md`
- Create: `.agents/skills/coelo-ui/references/component-proposal.md`
- Create: `.agents/skills/coelo-ui/references/verification.md`
- Create: `.agents/skills/coelo-ui/scripts/query-index.ps1`
- Create: `.agents/skills/coelo-ui/tests/scenarios.md`

**Interfaces:**
- Consumes primeiro: `apps/catalog/assets/coelo-ui.index.jsonl`.
- Produces: skill curta que dispara ao criar, alterar ou revisar UI Coelo.

- [x] **Step 1: Executar cinco cenarios sem a skill**

Registrar respostas reais para: filtro administrativo, novo status, troca de
contexto do Principal, campo de auth e pedido Astro. Marcar falhas de token,
pacote, variante silenciosa, mistura Principal/admin e import Flutter/Astro.

- [x] **Step 2: Escrever o SKILL.md minimo**

Incluir trigger, fluxo obrigatorio, comando de consulta do indice, anuncio da
consulta, gates para componente/variante/padrao e links para referencias. Nao
copiar Design System, spec ou indice para dentro da skill.

- [x] **Step 3: Repetir os cenarios**

Confirmar reutilizacao primeiro, proposta completa quando faltar componente,
respeito ao ADR 0012 e separacao Astro/Flutter. A skill pode propor livremente,
mas nao oficializar sem aprovacao.

- [x] **Step 4: Validar a skill**

Executar o validador indicado por `skill-creator`/`writing-skills`, testar o
script com um id existente e inexistente e confirmar que a leitura inicial e
economica.

### Task 13: Review Authentication Against the Established Foundation

**Files:**
- Modify somente se houver equivalencia: arquivos em `apps/superadmin/lib/features/auth/presentation/`.
- Modify: testes e goldens correspondentes em `apps/superadmin/test/features/auth/`.
- Modify: indice/registro do catalogo para componentes realmente promovidos.

**Interfaces:**
- Preserva: view models/actions e layout de login, esqueci e reset.

- [x] **Step 1: Registrar matriz golden faltante**

Adicionar login dark e forgot dark/success dark antes de refatorar. Executar
light/dark, 375/768/1024/1440 e texto 200%.

- [x] **Step 2: Comparar primitives com core**

Promover somente campo ou feedback cuja anatomia e estados coincidam. Forms que
recebem actions/view models continuam locais. Nao criar variante auth para
forcar reutilizacao.

- [x] **Step 3: Migrar apenas equivalencias**

Executar TDD, atualizar indice/registro e comparar goldens sem atualiza-los.
Qualquer diferenca encerra a tentativa e mantem o widget auth local.

### Task 14: Migrate Useful Showroom Content Before Removal

**Files:**
- Read/migrate: `apps/superadmin/lib/features/design_system/presentation/screens/design_system_showroom.dart`
- Modify: registro, indice e paginas de fundamentos de `apps/catalog`.
- Delete somente apos equivalencia: showroom e diretorios vazios relacionados.

**Interfaces:**
- Produces: checklist de equivalencia para acoes, forms, selecao, status, cores,
  tipografia e temas existentes.

- [x] **Step 1: Testar a equivalencia de conteudo**

Criar teste que lista as secoes uteis do showroom e exige ids correspondentes
no catalogo. Exemplos falsos de Material nao contam como componentes reais, mas
suas orientacoes uteis devem aparecer em fundamentos/padroes.

- [x] **Step 2: Migrar e validar visualmente**

Renderizar os componentes reais, conferir light/dark e interacao.

- [x] **Step 3: Remover somente com o teste verde**

Antes da remocao, confirmar por `rg` que a classe nao possui consumidor e que o
catalogo cobre todas as secoes. Registrar explicitamente os arquivos removidos e
que continuam recuperaveis pelo Git; nao remover se qualquer conteudo estiver
faltando.

### Task 15: Integrate `Governança > Catálogo` Without Bundle Coupling

**Files:**
- Create: `apps/superadmin/lib/features/catalog/presentation/catalog_host_page.dart`
- Create: `apps/superadmin/test/features/catalog/presentation/catalog_host_page_test.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_routes.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Modify: testes de router/shell/app.

**Interfaces:**
- Consumes: URL client-safe de catalogo.
- Produces: rota protegida `/governance/catalog` e item
  `Governança > Catálogo`.

- [x] **Step 1: Criar teste de fronteira de bundle**

Falhar se qualquer Dart do Superadmin importar `apps/catalog`,
`coelo_ui_principal` ou um registro de exemplos. Registrar tamanho do build web
atual antes da integracao com o mesmo comando/configuracao usado depois.

- [x] **Step 2: Testar rota e navegacao protegidas**

Usuario sem sessao e redirecionado ao login; `/dev/` nao ganha bypass para o
catalogo. O item aparece sob Governanca, seleciona corretamente e preserva shell.

- [x] **Step 3: Implementar host web minimo**

Incorporar somente origem configurada, usar politica de referrer restritiva,
permitir fallback de abertura direta e nao aceitar credenciais por URL ou
mensagem. Em plataformas sem embedding, mostrar o fallback. Antes de qualquer
publicacao, proteger no host/edge todos os arquivos estaticos do catalogo com
autenticacao Coelo e enviar CSP com `frame-ancestors` restrito ao Superadmin;
o gate Flutter isolado nao torna o bundle nem o indice privados. A origem do
catalogo deve ser propria e distinta da origem do Superadmin, inclusive para
isolar a sincronizacao entre abas feita pelo `BroadcastChannel` do cliente auth.

- [x] **Step 4: Verificar tamanho e fronteiras**

Repetir build equivalente, comparar artefatos e relatar numeros sem alegar
reducao. Rodar scanner de imports, tests de shell/router e goldens relevantes.

### Task 16: Final Verification and Astro Boundary Record

**Files:**
- Modify: `specs/013-ui-packages-componentization.md` somente para status final comprovado.
- Modify: READMEs dos pacotes/apps materializados.
- Modify: indice e catalogo se a verificacao encontrar stale.
- Do not create: arquivos Astro.

- [x] **Step 1: Executar verificacao estatica por unidade afetada**

Executar format somente nos arquivos alterados, `dart analyze` em tokens/core/
admin, `flutter analyze` nos apps e testes focados antes das suites completas.

- [x] **Step 2: Executar matriz visual e acessivel**

Reexecutar light/dark, 375/768/1024/1440, hover, focus, selected, disabled,
loading, erro, texto 200%, teclado, semantics e reduced motion. Goldens de
instituicoes devem permanecer byte/pixel equivalentes ao baseline.

- [x] **Step 3: Executar buscas de governanca**

```powershell
rg -n "#[0-9A-Fa-f]{6,8}|Color\(0x|TextStyle\(|MediaQuery.*(768|1000)" apps/superadmin/lib packages/coelo_ui_core/lib packages/coelo_ui_admin/lib
rg -n "coelo_ui_admin|coelo_ui_superadmin" packages/coelo_ui_principal apps/principal
rg -n "apps/catalog|coelo_ui_principal" apps/superadmin/lib
```

Classificar cada resultado existente; nao substituir numeros que preservam o
visual sem decisao normativa.

- [x] **Step 4: Validar sincronizacao**

Executar validadores de indice, pacotes e catalogo. Expected: zero diagnostic e
ausencia do banner stale antes de declarar conclusao.

- [x] **Step 5: Registrar Astro sem implementar**

Manter consumidor `astro-planned` e a fronteira de tokens neutros futuros no
indice/spec. Confirmar por diff que nenhum widget Flutter foi importado em Astro
e nenhum arquivo Astro foi criado.

- [x] **Step 6: Relatorio final**

Informar resultado, arquivos, componentes promovidos/locais, diferencas visuais,
comandos/resultados, tamanho de build, pendencias e decisoes futuras. Nao marcar
concluido se qualquer teste, golden, validator ou analise estiver falhando.

---

## Delivery Dependencies

```text
Task 1 baseline
  -> Task 3 token aliases
  -> Tasks 4-6 packages
  -> Task 7 institution migration
  -> Task 8 registry/boundaries
  -> Tasks 9-11 catalog
  -> Task 12 coelo-ui skill
  -> Task 13 auth review
  -> Task 14 showroom migration
  -> Task 15 Superadmin integration
  -> Task 16 final verification

Task 2 index starts after Task 1 and precedes public package implementation.
```

Tasks 4 and 5 may be reviewed independently after Task 3, but Task 6 depends on
the admin package. No implementation task starts before approval of this plan.

## Required Checkpoint Format

Ao fim de cada task, informar:

1. resultado obtido;
2. arquivos alterados;
3. componentes criados, promovidos ou mantidos locais;
4. diferenca visual encontrada;
5. testes executados com comando e resultado;
6. pendencias;
7. decisao que precisa de aprovacao.

## Self-Review Against the Specifications

- Baseline antes de extracao: Task 1.
- Indice compacto antes dos pacotes: Task 2.
- Apenas pacotes necessarios: Tasks 4-6; Superadmin/Principal reservados.
- Tokens semanticos sem transformar toda medida: Task 3.
- Primitives e padroes administrativos: Tasks 4-6.
- Instituicoes visualmente identica: Task 7 e Task 16.
- Catalogo independente, privado, real e interativo: Tasks 9-11.
- Filtros, metadados, descontinuacao e stale: Tasks 10-11.
- Skill curta, progressiva e testada contra baseline: Task 12.
- Auth somente depois da fundacao: Task 13.
- Showroom preservado ate equivalencia: Task 14.
- Integracao sem Principal no Superadmin: Task 15.
- Astro apenas futuro: Task 16.
- ADR 0012 preservado: Principal nao foi reduzido a responsaveis e nenhuma
  feature contextual foi implementada fora de spec.
- Nenhuma dependencia externa nova e proposta para validadores ou UI.
- Nenhum commit, push ou deploy e autorizado por este plano.

## Gate 2

Este documento e um plano para aprovacao. Nenhuma Task de implementacao pode
comecar antes de aprovacao explicita do usuario.

A aprovacao deve confirmar tambem duas melhorias nao visuais propostas e
explicitamente testadas: adicionar rotulo semantico ao campo de busca e permitir
redimensionar colunas por teclado com semantica propria. Elas nao alteram pixels,
dados, rotas ou resultado de consultas, mas ampliam o comportamento acessivel.
Se a exigencia for identidade absoluta inclusive de semantics e comandos de
teclado, essas duas melhorias serao adiadas e os respectivos widgets permanecem
locais ate uma aprovacao separada.
