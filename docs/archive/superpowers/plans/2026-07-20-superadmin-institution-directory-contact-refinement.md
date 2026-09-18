---
source:
  - docs/superpowers/specs/2026-07-20-superadmin-institution-directory-contact-refinement-design.md
status: executing
generated_at: 2026-07-20
---

# Superadmin Institution Directory Contact Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add institutional/unit contact storage and complete the approved comfort, table, filter, and header refinement for the institution directory.

**Architecture:** Add one-to-one contact tables beside the existing one-to-one address tables, expose only institutional contacts through protected `security_invoker` views, and extend the existing domain/repository/view-model pipeline. Keep the Flutter feature layered and refactor presentation through small themed Material widgets.

**Tech Stack:** PostgreSQL 17, Supabase RLS/Data API, Flutter, Dart, Material 3, `supabase_flutter`, `coelo_tokens`, `flutter_test`.

## Global Constraints

- Use only semantic Coelo theme/tokens; no local HEX colors or new dependencies.
- Do not seed institutions, units, contacts, addresses, or institution types.
- Keep `/institutions` protected and `/dev/institutions` fake-only.
- Keep server pagination at 20 and search debounce at 300 ms.
- Do not expose CNPJ or personal `person_contacts` through the directory.
- New public tables/views require explicit grants, RLS where applicable, and `platform.read` authorization.
- Preserve unrelated auth, password recovery, router, database, and user worktree changes.
- The shared dirty `dev` worktree must not be staged, committed, reset, or cleaned.

## File Map

- Create `packages/coelo_database/migrations/20260720103023_institution_contact_directory_refinement.sql`.
- Create `packages/coelo_database/tests/2026-07-20-institution-contact-directory-validation.sql`.
- Modify `apps/superadmin/lib/features/institutions/domain/institution_directory_item.dart`.
- Modify `apps/superadmin/lib/features/institutions/domain/institution_directory_query.dart`.
- Modify `apps/superadmin/lib/features/institutions/domain/institution_directory_repository.dart`.
- Modify `apps/superadmin/lib/features/institutions/data/fake_institution_directory_repository.dart`.
- Modify `apps/superadmin/lib/features/institutions/data/supabase_institution_directory_repository.dart`.
- Modify `apps/superadmin/lib/features/institutions/presentation/view_models/institution_directory_view_model.dart`.
- Modify `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`.
- Modify `apps/superadmin/lib/app/shell/superadmin_shell.dart`.
- Modify matching SQL, domain, repository, view-model, page, and shell tests.

---

### Task 1: Contact Schema and Protected Directory Views

**Interfaces:**
- Produce `public.institution_contacts(institution_id, email, phone, mobile_phone, status, created_at, updated_at)`.
- Produce `public.unit_contacts(unit_id, email, phone, mobile_phone, status, created_at, updated_at)`.
- Extend `public.institution_directory` with `contact_email`, `contact_phone`, and `contact_mobile_phone`.
- Produce `public.institution_directory_locations(state, city, district)`.

- [ ] **Step 1: Write the failing SQL validation**

Add assertions that both contact tables and contact columns are absent before the migration, then require primary keys, cascade foreign keys, RLS, explicit grants, `platform.read` policies, non-blank constraints, at-least-one-value constraints, catalog entries, and `security_invoker` views.

- [ ] **Step 2: Run the SQL validation against the current schema**

Run the validation through Supabase `execute_sql` in a rollback-only transaction.
Expected: failure stating `institution_contacts` is missing.

- [ ] **Step 3: Create the migration**

Create both contact tables with one row per owner, enable RLS, revoke from `public` and `anon`, grant `select` to `authenticated`, and add policies using `(select app_private.has_platform_permission('platform.read'))`. Replace the directory view without changing its previous columns and create the distinct location view. Update `schema_tables` and `schema_columns`.

- [ ] **Step 4: Apply and verify the migration**

Apply the versioned migration to project `evvbomzejfijozbtgvpt`, rerun SQL validation, verify the migration list, and run security/performance advisors.
Expected: all assertions pass; catalog/contact tables remain empty.

### Task 2: Domain, Repository, and Cascading Filters

**Interfaces:**
- Add nullable `district`, `contactEmail`, `contactPhone`, and `contactMobilePhone` to `InstitutionDirectoryItem`.
- Add nullable `city` and `district` to `InstitutionDirectoryQuery`.
- Change filter loading to `fetchFilterOptions({String? state, String? city})` and return sorted `cities` and `districts`.
- Add `setCity` and `setDistrict`; `setState` clears both descendants and `setCity` clears district.

- [ ] **Step 1: Write failing model/query/repository/view-model tests**

Assert JSON mapping, query equality/active filters, fake filtering by district/city, Supabase location selection, and cascading resets with page reset.

- [ ] **Step 2: Run focused tests and confirm RED**

Run domain, fake repository, Supabase repository, and view-model test files.
Expected: compile failures for missing fields and methods.

- [ ] **Step 3: Implement the minimal data pipeline**

Map the new view fields, add query filters to Supabase requests, load `institution_directory_locations` with parent filters, deduplicate/sort fake options, and reload options after parent changes.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Expected: all institution data/view-model tests pass.

### Task 3: Comfortable Cards, Wide Table, and Rounded Menus

**Interfaces:**
- Cards render location plus `Tipo`, `Plano`, `Unidades`, and `Grupos (Turmas)` only.
- Table renders 13 approved columns and independent copy actions.
- `_DirectoryFilterMenu<T>` uses Material `MenuAnchor` and opens below a pill trigger.

- [ ] **Step 1: Write failing widget tests**

Assert no card domain, `Bairro, Municipio/UF`, restrained title/status placement, increased internal gaps, table columns and copy keys, filter order, conditional municipality/district visibility, and rounded menu shape/offset.

- [ ] **Step 2: Run the page test and confirm RED**

Expected: failures for current card domain, combined municipality/UF table column, plan filter, and `DropdownButtonFormField`.

- [ ] **Step 3: Implement the minimal presentation changes**

Refactor the card detail grid, generalize the clipboard action, replace dropdowns with `MenuAnchor`, conditionally build dependent filters, and wrap the create banner/table in one minimum-width horizontal layout.

- [ ] **Step 4: Run the page test and confirm GREEN**

Expected: all page tests pass at the four target widths in light and dark themes.

### Task 4: Header Actions and Profile Menu

**Interfaces:**
- Header action keys: `superadmin-notifications`, `superadmin-report-bug`, `superadmin-profile-menu`.
- Profile entries: `superadmin-profile-action`, `superadmin-settings-action`, `superadmin-logout-action`.
- Sidebar contains no Settings entry.

- [ ] **Step 1: Write failing shell tests**

Assert bell/bug/profile placement, absence of inline `Sair`, profile menu contents, real logout callback, future-flow feedback for other actions, and removal of Settings from desktop/drawer navigation.

- [ ] **Step 2: Run the shell test and confirm RED**

Expected: failures for missing bell/bug/menu and existing sidebar Settings/inline logout.

- [ ] **Step 3: Implement the header composition**

Build semantic icon actions and a rounded `MenuAnchor` profile trigger. Route only `Sair` to `LogoutAction`; other actions show safe SnackBars. Keep actions reachable on compact layouts.

- [ ] **Step 4: Run the shell test and confirm GREEN**

Expected: all shell tests pass.

### Task 5: Complete Validation and Preview

- [ ] **Step 1: Format modified Dart files**

Run `dart format` only on the intentionally modified Superadmin files and tests.

- [ ] **Step 2: Run static and automated validation**

Run `dart analyze`, the full Flutter suite, SQL validation, `git diff --check`, and `flutter build web --no-pub --dart-define=COELO_DEV_MFA=true`.
Expected: no analysis issues, all tests pass, SQL assertions pass, diff check exits zero, and web build succeeds.

- [ ] **Step 3: Inspect responsive behavior**

Serve `/dev/institutions/` on a single localhost, inspect 375, 768, 1024, and 1440 widths, card/table switching, menus, card/table hover, conditional filters, copy feedback, and profile actions.

- [ ] **Step 4: Preserve the shared branch**

Leave `dev` and all unrelated dirty changes untouched. Do not commit, stage, merge, push, discard, or clean.
