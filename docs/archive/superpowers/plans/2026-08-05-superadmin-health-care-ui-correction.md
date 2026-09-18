# Superadmin Health Care UI Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir integralmente a UI de Saúde e Cuidado no Superadmin, preservando Perfis de cuidado e Planos de medicação como diretórios irmãos e alinhando diretórios, formulários e detalhes às baselines Coelo.

**Architecture:** Manter o domínio e os controllers atuais. Compor a feature somente com componentes compartilhados já aprovados (`CoeloAdminFileActions`, `SuperadminDirectoryViewToggle`, `CoeloAdminResizableTable`, `SuperadminFormStepNavigation` e `SuperadminFormActionFooter`) e limitar widgets locais a conteúdo de domínio. Formulários e detalhes passam a selecionar uma seção por vez, sem criar nova camada de estado ou persistência.

**Tech Stack:** Flutter, Dart, `coelo_tokens`, `coelo_ui_core`, `coelo_ui_admin`, `flutter_test` e golden tests.

## Global Constraints

- Módulo visível: `Saúde e Cuidado`; submenus: `Perfis de cuidado` e `Planos de medicação`.
- Marca Coelo: `#D63C00`, grafite `#3F4549`, Nunito Sans e tokens semânticos.
- Nenhuma migration, Supabase remoto, RLS, nova permissão ou regra de domínio.
- Responsividade por constraints em 375, 768, 1024 e 1440 px.
- Alvo mínimo de 48 px, foco, teclado, toque, texto a 200% e reduced motion.
- Nenhum hover cinza, widget Material cru novo ou golden de `failures/` como baseline.
- Preservar o tamanho atual de `CoeloAdminCreateAction`.

---

## File Structure

- Create `apps/superadmin/lib/features/health_care/presentation/health_care_file_actions.dart`: ações demonstrativas compartilhadas de importar/CSV/XLSX para os dois diretórios.
- Modify `apps/superadmin/lib/features/health_care/presentation/health_care_directory_page.dart`: toolbar, remoção do banner e arquivos.
- Modify `apps/superadmin/lib/features/health_care/presentation/health_medication_plan_directory_page.dart`: arquivos e composição da toolbar.
- Modify `apps/superadmin/lib/features/health_care/presentation/health_care_form_pages.dart`: etapas responsivas e revisão.
- Modify `apps/superadmin/lib/features/health_care/presentation/health_care_detail_page.dart`: detalhe somente leitura por seções.
- Modify `apps/superadmin/lib/features/health_care/presentation/health_medication_plan_detail_page.dart`: resumo operacional e seções.
- Modify `apps/superadmin/test/features/health_care/presentation/health_care_pages_test.dart`: diretórios e ações de arquivos.
- Modify `apps/superadmin/test/features/health_care/presentation/health_care_form_pages_test.dart`: navegação, rodapé e responsividade.
- Modify `apps/superadmin/test/features/health_care/presentation/health_medication_plan_detail_page_test.dart`: detalhe de plano.
- Modify `apps/superadmin/test/features/health_care/presentation/health_care_golden_test.dart`: estados visuais aprovados.
- Modify `docs/knowledge/team/health-care.md` and `docs/knowledge/admin/health-care.md` only if the final behavior adds reusable approved knowledge.

### Task 1: Shared file actions for both directories

**Interfaces:**
- Consumes: `CoeloAdminFileActions`, `CoeloAdminDialogShell`, `SuperadminActivityController`.
- Produces: `HealthCareFileActions({required activityController, required subject, required fileBaseName, compact})`.

- [ ] **Step 1: Write the failing widget tests**

Add assertions that each directory renders `Arquivos`, opens a flyout containing `Importar`, `Exportar CSV` and `Exportar XLSX`, and that activating an export reports completion through the activity controller.

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/health_care/presentation/health_care_pages_test.dart`

Expected: FAIL because the health-care toolbars do not render file actions.

- [ ] **Step 3: Implement the shared actions**

Create a stateless composition whose action list is exactly:

```dart
CoeloAdminFileActions(
  compact: compact,
  actions: [
    CoeloAdminFileAction(key: const Key('health-care-files-import'), label: 'Importar', icon: Icons.upload_file_outlined, onPressed: openImport),
    CoeloAdminFileAction(key: const Key('health-care-files-export-csv'), label: 'Exportar CSV', icon: Icons.table_rows_outlined, onPressed: exportCsv),
    CoeloAdminFileAction(key: const Key('health-care-files-export-xlsx'), label: 'Exportar XLSX', icon: Icons.grid_on_outlined, onPressed: exportXlsx),
  ],
)
```

Use `CoeloAdminDialogShell` for the demonstrative import confirmation and `showSuperadminNotice` for feedback. Do not add file picker or persistence.

- [ ] **Step 4: Add the component to both toolbar action groups**

Place `HealthCareFileActions` after `SuperadminDirectoryViewToggle`, matching Pessoas and Instituições.

- [ ] **Step 5: Run the focused tests and commit**

Expected: PASS.

Commit: `feat(superadmin): add health care file actions`

### Task 2: Correct both directory compositions

**Interfaces:**
- Consumes: `HealthCareFileActions`, current controllers and shared directory widgets.
- Produces: baseline-compliant profile and medication directories without changing domain queries.

- [ ] **Step 1: Extend failing directory tests**

Assert that Perfis begins with the listing toolbar, renders the four underline tabs, has no demonstration banner, keeps the create tile first in Cards and the create banner only in Table. Assert that both toggles expose 64 × 48 segments and select `Agrupado` directly.

- [ ] **Step 2: Run tests and verify the banner assertion fails**

Run the same focused page test command from Task 1.

- [ ] **Step 3: Apply the minimal directory changes**

Delete `_demoBanner`, remove its spacing, use `space4` between toolbar, tabs and content, and keep existing cards/tables. Do not alter `CoeloAdminCreateAction`, `CoeloAdminResizableTable` or `SuperadminDirectoryViewToggle` unless their own package tests expose a shared regression.

- [ ] **Step 4: Verify shared table and toggle contracts**

Run:

`flutter test test/shared/presentation/widgets/superadmin_directory_view_toggle_test.dart`

From `packages/coelo_ui_admin`, run:

`flutter test test/table/coelo_admin_resizable_table_test.dart test/overlay/coelo_admin_flyout_test.dart test/listing/coelo_admin_file_actions_test.dart`

Expected: all PASS, including natural centering and scrollbar painted above the pinned column.

- [ ] **Step 5: Commit**

Commit: `fix(superadmin): align health care directories`

### Task 3: Convert create/edit forms to approved steps

**Interfaces:**
- Consumes: `SuperadminFormStepNavigation`, `SuperadminFormActionFooter`, existing field controllers.
- Produces: `_HealthCareFormFrame(currentStep, steps, onStepSelected, onPrevious, onContinue, onSave, child)`.

- [ ] **Step 1: Write failing form navigation tests**

For profile, assert four steps: `Criança`, `Alergias e restrições`, `Orientações de cuidado`, `Revisão`. For medication, assert five steps: `Criança e medicamento`, `Vigência`, `Horários e responsáveis`, `Documento`, `Revisão`. Verify `Continuar`, `Anterior`, direct enabled step selection, `Cancelar` and final save labels.

- [ ] **Step 2: Run form tests and verify failure**

Run: `flutter test test/features/health_care/presentation/health_care_form_pages_test.dart`

Expected: FAIL because the current forms render every section in one scroll.

- [ ] **Step 3: Add local step enums and state**

Use one enum per form and store only the selected index. Build `SuperadminFormStep` values from the current index; previous steps are `complete`, current is `current`, future steps are `incomplete`.

- [ ] **Step 4: Refactor the shared frame**

At medium/wide render:

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SuperadminFormStepNavigation(steps: steps, currentIndex: currentStep, onStepSelected: onStepSelected),
    const SizedBox(width: CoeloSpacing.space6),
    Expanded(child: stepContent),
  ],
)
```

At compact render the same navigation before the content so it resolves to the approved compact summary. Keep the measured `SuperadminFormActionFooter` below the scroll area.

- [ ] **Step 5: Map existing sections into steps and add review summaries**

Reuse the existing `_FormSection`, fields and controllers. Review rows are neutral `surface` sections with an `Editar` text action that returns to the corresponding step; do not add chips, gray strips or new domain validation.

- [ ] **Step 6: Run tests and commit**

Expected: all form tests PASS at compact and desktop constraints.

Commit: `refactor(superadmin): step health care forms`

### Task 4: Replace rejected detail layouts

**Interfaces:**
- Consumes: `SuperadminFormStepNavigation` as read-only section navigation and current fixture models.
- Produces: responsive profile and medication details with one prioritized section visible at a time.

- [ ] **Step 1: Write failing detail tests**

Assert that profile detail exposes `Resumo`, `Alergias e restrições`, `Orientações` and `Planos de medicação`; medication detail exposes `Resumo`, `Agenda e responsáveis` and `Registros de dose`. Verify one section body at a time, an `Editar` primary action, back navigation and absence of the rejected long stacked composition.

- [ ] **Step 2: Run detail tests and verify failure**

Run: `flutter test test/features/health_care/presentation/health_care_pages_test.dart test/features/health_care/presentation/health_medication_plan_detail_page_test.dart`

- [ ] **Step 3: Implement sectioned read-only layouts**

Use `LayoutBuilder`: medium/wide receives a 248 px section navigation and expanded content; compact receives the summary above content. Use `colorScheme.surface`, tokenized gaps and semantic status text. Keep clinical wording and all existing fixture values.

- [ ] **Step 4: Run detail tests and commit**

Expected: PASS.

Commit: `fix(superadmin): rebuild health care details`

### Task 5: Golden, naming, visual gate and knowledge gate

**Interfaces:**
- Consumes: completed UI from Tasks 1–4.
- Produces: approved evidence at 375/768/1024/1440 and validated documentation.

- [ ] **Step 1: Add or update exact golden cases**

Cover profile and medication directories, file flyout open, card hover, table, profile/medication create mobile light, edit desktop dark, and both details. Never copy from `failures/`.

- [ ] **Step 2: Run functional tests before updating goldens**

Run: `flutter test test/features/health_care/presentation`

Expected: PASS.

- [ ] **Step 3: Update and rerun health-care goldens**

Run: `flutter test --update-goldens test/features/health_care/presentation/health_care_golden_test.dart`

Then rerun without `--update-goldens`; expected PASS.

- [ ] **Step 4: Run naming and visual contract gates**

Search: `rg -n "Saúde e Segurança|Saude e Seguranca" apps/superadmin specs docs/knowledge`

Expected: no user-visible stale name.

From `apps/catalog`, run:

`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_admin_visual_contracts.dart ../.. assets/admin-visual-contract-allowlist.json`

Expected: PASS without allowlist changes.

- [ ] **Step 5: Run static analysis and knowledge validation**

Run `dart analyze` for `apps/superadmin`, then `scripts/Test-CoeloKnowledge.ps1` and `tests/Test-CoeloKnowledge.ps1`. Update health-care knowledge only if reusable behavior changed beyond the canonical spec link; otherwise record a knowledge no-op.

- [ ] **Step 6: Final verification and commit**

Run all focused package and feature tests once more. Inspect `git diff --check` and `git status --short` without staging unrelated user changes.

Commit: `test(superadmin): verify health care ui correction`

