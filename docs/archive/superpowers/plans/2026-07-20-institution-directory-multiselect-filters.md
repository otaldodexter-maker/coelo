---
title: "Institution Directory Multiselect Filters Implementation Plan"
source: "docs/superpowers/specs/2026-07-20-institution-directory-multiselect-filters-design.md"
status: "completed"
generated_at: "2026-07-20"
---

# Institution Directory Multiselect Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar filtros multisseleção aplicados em lote no Diretório de Instituições, com cascata geográfica, consulta real paginada e estado visual persistente.

**Architecture:** Representar filtros como conjuntos imutáveis em `InstitutionDirectoryQuery`, mantendo OR dentro de cada conjunto e AND entre conjuntos. O menu mantém uma seleção provisória local até `Aplicar`; o view model faz uma única carga e os repositórios fictício e Supabase interpretam as mesmas coleções.

**Tech Stack:** Dart, Flutter Material 3, Supabase/PostgREST e Flutter Test.

## Global Constraints

- Tipo, Status, UF, Município e Bairro são multisseleção; a busca por nome permanece textual.
- Marcar opções não fecha o menu nem consulta o repositório antes de `Aplicar`.
- `Limpar filtros` global permanece visível para filtros aplicados e limpa busca e conjuntos.
- Município depende de UFs aplicadas; Bairro depende de Municípios aplicados.
- Nenhuma tabela, view, migration, RLS ou dado do Supabase será alterado.
- Nenhum HEX será criado na feature; usar apenas `ColorScheme` e tokens Coelo.

---

### Task 1: Consulta imutável e semântica dos repositórios

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/domain/institution_directory_query.dart`
- Modify: `apps/superadmin/lib/features/institutions/domain/institution_directory_repository.dart`
- Modify: `apps/superadmin/lib/features/institutions/data/fake_institution_directory_repository.dart`
- Modify: `apps/superadmin/lib/features/institutions/data/supabase_institution_directory_repository.dart`
- Modify: `apps/superadmin/test/features/institutions/domain/institution_directory_query_test.dart`
- Modify: `apps/superadmin/test/features/institutions/data/fake_institution_directory_repository_test.dart`

**Interfaces:**
- Produces: `InstitutionDirectoryQuery(statuses, typeIds, states, cities, districts)` como `Set` imutável; `fetchFilterOptions({Set<String> states, Set<String> cities})`.
- Consumes: `InstitutionStatus.databaseValue` e campos atuais da view `institution_directory`.

- [ ] **Step 1: Escrever testes RED do modelo**

Testar coleções com mais de um valor, igualdade independente da instância, `hasActiveFilters`, offset e impossibilidade de mutar os conjuntos retornados.

- [ ] **Step 2: Escrever testes RED do repositório fictício**

Usar duas UFs/status/tipos para provar OR interno e combinar com Município/Bairro para provar AND entre filtros; testar união das opções dependentes.

- [ ] **Step 3: Executar os testes focados**

Run: `flutter test test/features/institutions/domain/institution_directory_query_test.dart test/features/institutions/data/fake_institution_directory_repository_test.dart`

Expected: FAIL porque a query e a interface ainda são escalares.

- [ ] **Step 4: Implementar o modelo e o repositório fictício**

Construir conjuntos com `Set.unmodifiable`, comparar conteúdo com um helper Dart privado, usar `Object.hashAllUnordered` no `hashCode`, aplicar `contains` no fake e receber conjuntos em `fetchFilterOptions`.

- [ ] **Step 5: Atualizar o repositório Supabase**

Aplicar `.inFilter()` somente para conjuntos não vazios, convertendo status para valores de banco; filtrar opções geográficas com `IN` para UFs e Municípios.

- [ ] **Step 6: Executar os testes focados e confirmar GREEN**

Run: `flutter test test/features/institutions/domain/institution_directory_query_test.dart test/features/institutions/data/fake_institution_directory_repository_test.dart`

Expected: PASS.

### Task 2: View model multisseleção e cascata

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/view_models/institution_directory_view_model.dart`
- Modify: `apps/superadmin/test/features/institutions/presentation/view_models/institution_directory_view_model_test.dart`

**Interfaces:**
- Consumes: conjuntos imutáveis da Task 1.
- Produces: `setStatuses(Set<InstitutionStatus>)`, `setTypes(Set<String>)`, `setStates(Set<String>)`, `setCities(Set<String>)` e `setDistricts(Set<String>)`.

- [ ] **Step 1: Escrever testes RED dos setters em lote**

Testar duas seleções por filtro, uma consulta por setter, página zero e preservação dos outros conjuntos.

- [ ] **Step 2: Escrever teste RED da cascata**

Aplicar duas UFs, duas cidades e bairros; trocar UFs e confirmar cidades/bairros vazios; trocar cidades e confirmar bairros vazios; validar parâmetros de `fetchFilterOptions`.

- [ ] **Step 3: Executar o teste focado**

Run: `flutter test test/features/institutions/presentation/view_models/institution_directory_view_model_test.dart`

Expected: FAIL porque os setters escalares ainda existem.

- [ ] **Step 4: Implementar uma função privada de cópia da query**

Centralizar a reconstrução em `_queryWith(...)`, evitando perder filtros ao alterar busca, página ou conjuntos; setters pais zeram explicitamente filhos.

- [ ] **Step 5: Executar o teste focado e confirmar GREEN**

Run: `flutter test test/features/institutions/presentation/view_models/institution_directory_view_model_test.dart`

Expected: PASS e uma carga por aplicação.

### Task 3: Menu multisseleção aplicado em lote

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Consumes: setters de conjunto da Task 2.
- Produces: `_DirectoryFilterMenu<T>` com `Set<T> values`, `ValueChanged<Set<T>> onApply`, rótulo contado, draft local, `Limpar` e `Aplicar`.

- [ ] **Step 1: Escrever teste RED de interação em lote**

Abrir Status, marcar `Ativa` e `Em implantação`, confirmar que o menu permanece aberto e a tabela não recarrega, tocar `Aplicar` e esperar `2 selecionados`.

- [ ] **Step 2: Escrever testes RED de descarte e limpeza**

Fechar sem aplicar e reabrir para confirmar descarte; usar `Limpar` local; aplicar e confirmar que `Limpar filtros` global aparece e remove todos os conjuntos.

- [ ] **Step 3: Escrever teste RED de estado visual**

Resolver o `ButtonStyle` de uma opção e confirmar: hover usa `primaryContainer`, selecionado usa fundo derivado de `primary`, texto/ícone selecionado usam `primary` e overlay é transparente em light/dark.

- [ ] **Step 4: Executar o teste focado**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: FAIL porque o menu atual aplica um único valor imediatamente.

- [ ] **Step 5: Implementar draft, ações e semântica**

Sincronizar `_draftValues` no `onOpen`, alternar checkboxes sem fechar, descartar no `onClose` quando não aplicado, limpar pesquisa e draft separadamente, e fechar pelo `MenuController` após aplicar.

- [ ] **Step 6: Atualizar a toolbar e a dependência geográfica**

Passar conjuntos e setters; exibir Município quando `states.isNotEmpty`, Bairro quando `cities.isNotEmpty`; preservar pesquisa interna e `Limpar filtros` global.

- [ ] **Step 7: Executar o teste focado e confirmar GREEN**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: PASS nos viewports existentes.

### Task 4: Migração de consumidores e verificação

**Files:**
- Modify: `docs/superpowers/plans/2026-07-20-institution-directory-multiselect-filters.md`

**Interfaces:**
- Consumes: API final das Tasks 1–3.
- Produces: código formatado, análise limpa, suíte completa e build web.

- [ ] **Step 1: Formatar os arquivos Dart alterados**

Run: `dart format lib test`

Expected: formatação concluída sem erro.

- [ ] **Step 2: Executar análise estática**

Run: `flutter analyze`

Expected: `No issues found!`.

- [ ] **Step 3: Executar a suíte completa**

Run: `flutter test`

Expected: todos os testes passam.

- [ ] **Step 4: Gerar build web**

Run: `flutter build web --dart-define=COELO_DEV_MFA=true`

Expected: build concluído em `build/web`.

- [ ] **Step 5: Atualizar preview e criar commit isolado**

Substituir o servidor local pelo build novo, confirmar HTTP 200 e versionar somente os arquivos da entrega com `feat(superadmin): add multiselect directory filters`.

## Resultado da execução

- Implementação concluída em 2026-07-20.
- `flutter analyze`: sem problemas.
- `flutter test`: 144 testes aprovados.
- `flutter build web --dart-define=COELO_DEV_MFA=true`: concluído.
