# Superadmin Activity Form Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add demonstrative Create/Edit Activity affordances and forms to the Superadmin without persisting changes.

**Architecture:** Extend the existing activity feature with a small form model/controller and one shared create/edit page. Read institutions, active units, and existing details through the authenticated read-only repository; submit only validates, resets dirty state where applicable, and reports that nothing was saved.

**Tech Stack:** Flutter, Dart, go_router, Supabase/PostgREST read-only queries, coelo_tokens, coelo_ui_core, coelo_ui_admin, flutter_test.

## Global Constraints

- Institution forms, cards, table, menu, Bug popup, profile flyout, tour flyout, and pagination are the visual baseline.
- No Supabase writes, migration, RLS, grant, RPC, permission, public component, token, or package API changes.
- Create fields: required name, optional description, required institution, required active initial unit from that institution.
- Edit fields: editable name and description; institution, origin, and origin unit are read-only context.
- Submit copy is `Protótipo visual — nenhuma alteração foi salva.`
- Validate 375, 768, 1024, and 1440 px; light/dark; text at 200%; keyboard, focus, semantics, and reduced motion.

---

### Task 1: Read-only form contracts

**Files:**
- Modify: `apps/superadmin/lib/features/activities/domain/activity_directory.dart`
- Modify: `apps/superadmin/lib/features/activities/data/fake_activity_directory_repository.dart`
- Modify: `apps/superadmin/lib/features/activities/data/supabase_activity_directory_repository.dart`
- Test: `apps/superadmin/test/features/activities/domain/activity_directory_test.dart`
- Test: `apps/superadmin/test/features/activities/data/fake_activity_directory_repository_test.dart`
- Test: `apps/superadmin/test/features/activities/data/supabase_activity_directory_repository_test.dart`

**Interfaces:**
- Produces: `ActivityFormOptions`, `ActivityFormInstitutionOption`, `ActivityFormUnitOption`.
- Produces: `Future<ActivityFormOptions> fetchFormOptions()`.

- [ ] **Step 1: Write failing tests**

```dart
expect(await repository.fetchFormOptions(), hasInstitutionsAndActiveUnits);
expect(options.unitsFor('institution-1'), everyElement(hasInstitution('institution-1')));
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/features/activities/domain test/features/activities/data`
Expected: FAIL because `fetchFormOptions` and form option types do not exist.

- [ ] **Step 3: Implement minimal read-only options**

```dart
final class ActivityFormOptions {
  const ActivityFormOptions({required this.institutions, required this.units});
  List<ActivityFormUnitOption> unitsFor(String institutionId) =>
      units.where((unit) => unit.institutionId == institutionId).toList();
}
```

Supabase queries only `institutions(id,name,status)` and
`units(id,institution_id,name,status)`, filters active units, orders by name,
and maps `42501`/`PGRST301` to the existing unauthorized exception.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/features/activities/domain test/features/activities/data`
Expected: PASS.

### Task 2: Form controller

**Files:**
- Create: `apps/superadmin/lib/features/activities/presentation/activity_form_controller.dart`
- Create: `apps/superadmin/test/features/activities/presentation/activity_form_controller_test.dart`

**Interfaces:**
- Consumes: `ActivityFormOptions`, `ActivityDetail`.
- Produces: `ActivityFormController.create(options)` and
  `ActivityFormController.edit(options, detail)`.
- Produces: `isEditing`, `isDirty`, `isSubmitting`, `validate()`,
  `markSubmitted()`, `units`, and field errors.

- [ ] **Step 1: Write failing controller tests**

```dart
final controller = ActivityFormController.create(options);
expect(controller.validate(), isFalse);
controller.name.text = 'Música';
controller.selectInstitution('institution-1');
controller.selectUnit('unit-1');
expect(controller.validate(), isTrue);
expect(controller.isDirty, isTrue);
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/features/activities/presentation/activity_form_controller_test.dart`
Expected: FAIL because the controller is absent.

- [ ] **Step 3: Implement minimal controller**

Use explicit `TextEditingController`s for name and description, selected
institution/unit IDs, a baseline signature, submit validation, dependent unit
reset, and `dispose`. Do not copy the institution wizard/controller.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/features/activities/presentation/activity_form_controller_test.dart`
Expected: PASS.

### Task 3: Create/Edit form page

**Files:**
- Create: `apps/superadmin/lib/features/activities/presentation/activity_form_page.dart`
- Create: `apps/superadmin/test/features/activities/presentation/activity_form_page_test.dart`

**Interfaces:**
- Consumes: `ActivityDirectoryRepository`, optional `activityId`.
- Produces: `ActivityFormPage`, `onCancel`, `onPrototypeSubmitted`.

- [ ] **Step 1: Write failing widget tests**

```dart
expect(find.text('Criar atividade'), findsOneWidget);
expect(find.byType(CoeloFormTextField), findsNWidgets(2));
expect(find.byType(CoeloAdminSingleSelectField<String>), findsNWidgets(2));
expect(find.text('Protótipo visual — nenhuma alteração foi salva.'), findsNothing);
```

Also cover edit hydration, read-only context, validation, loading/not-found/
failure/unauthorized, dependent units, dirty exit, Escape, 375/768/1024/1440,
text at 200%, and no overflow.

- [ ] **Step 2: Run RED**

Run: `flutter test test/features/activities/presentation/activity_form_page_test.dart`
Expected: FAIL because `ActivityFormPage` is absent.

- [ ] **Step 3: Implement the minimal page**

Compose `SuperadminShell`, `LayoutBuilder`, centered `ConstrainedBox(maxWidth:
880)`, neutral section, two-column `Wrap` above compact width, public text and
single-select controls, and neutral responsive footer. Use
`CoeloAdminDialogShell` for dirty exit. Submit never calls a write method.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/features/activities/presentation/activity_form_page_test.dart`
Expected: PASS.

### Task 4: Create affordances, edit action, and routes

**Files:**
- Modify: `apps/superadmin/lib/features/activities/presentation/activity_directory_page.dart`
- Modify: `apps/superadmin/lib/features/activities/presentation/activity_detail_page.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_routes.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Test: `apps/superadmin/test/features/activities/presentation/activity_directory_page_test.dart`
- Test: `apps/superadmin/test/features/activities/presentation/activity_detail_page_test.dart`
- Test: `apps/superadmin/test/app/router/activity_routes_test.dart`

**Interfaces:**
- `ActivityDirectoryPage` adds required `VoidCallback onCreate`.
- `ActivityDetailPage` adds required `VoidCallback onEdit`.
- Routes add `/activities/new`, `/activities/:activityId/edit`, and `/dev`
  equivalents.

- [ ] **Step 1: Write failing navigation tests**

Assert tile in cards, banner above table, Edit in detail, and protected/dev
create/edit routes.

- [ ] **Step 2: Run RED**

Run: `flutter test test/features/activities/presentation/activity_directory_page_test.dart test/features/activities/presentation/activity_detail_page_test.dart test/app/router/activity_routes_test.dart`
Expected: FAIL because actions/routes are absent.

- [ ] **Step 3: Implement actions and routes**

Reuse `CoeloAdminCreateAction.tile` in cards and
`SuperadminDirectoryCreateBanner` above the table. Add a primary Edit action
to the detail header. Wire both normal and dev routers to the shared form page.

- [ ] **Step 4: Run GREEN**

Run the RED command again. Expected: PASS.

### Task 5: Goldens and canonical synchronization

**Files:**
- Modify: `apps/superadmin/test/features/activities/presentation/activity_golden_test.dart`
- Create: `apps/superadmin/test/goldens/activities/activity_form_create_light_375.png`
- Create: `apps/superadmin/test/goldens/activities/activity_form_edit_dark_1440.png`
- Modify: `docs/product/prd-superadmin.md`
- Modify: `docs/knowledge/team/superadmin-activity-directory.md`
- Modify: `docs/knowledge/index.md`

- [ ] **Step 1: Add golden expectations and run without update**

Run: `flutter test test/features/activities/presentation/activity_golden_test.dart`
Expected: FAIL only because the two approved masters do not exist.

- [ ] **Step 2: Generate and inspect**

Run: `flutter test test/features/activities/presentation/activity_golden_test.dart --update-goldens`
Inspect both images against the Institution create/edit masters.

- [ ] **Step 3: Re-run without update**

Expected: PASS.

- [ ] **Step 4: Synchronize durable documentation**

Record that create/edit are explicit non-persistent prototypes and that
production authorization remains unchanged.

### Task 6: Final verification and commit

- [ ] **Step 1: Format affected Dart**

Run: `dart format <affected Dart files>`.

- [ ] **Step 2: Analyze and test**

Run focused activity tests, public reused component tests, and
`dart analyze` from `apps/superadmin`.

- [ ] **Step 3: Validate UI/knowledge**

Run index, boundary, catalog, both knowledge gates, and `git diff --check`.
Report unrelated existing diagnostics separately.

- [ ] **Step 4: Commit only scoped files**

Stage the exact activity, route, documentation, test, and golden files.
Review `git diff --cached --stat` and commit without staging concurrent work.
