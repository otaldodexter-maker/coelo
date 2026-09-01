---
title: "Plano de implementação — Finalização de Acessos e Saúde e Cuidado"
source: "docs/superpowers/specs/2026-09-01-superadmin-access-health-care-finalization-design.md"
status: "approved-spec-implementation-plan"
generated_at: "2026-09-01"
---

# Acessos e Saúde e Cuidado Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finalizar sete superfícies do Superadmin com paridade visual de Instituições, dataset `/dev` coerente, CRUD Supabase protegido por RLS e evidências atualizadas.

**Architecture:** As telas reutilizam os componentes administrativos públicos e repositories injetados pelo router. `/dev` recebe um catálogo determinístico compartilhado por IDs estruturais; produção recebe somente repositories Supabase. Perfis e Modelos formam uma única central, enquanto o backend mantém autorização efetiva em catálogos, papéis e atribuições auditadas.

**Tech Stack:** Flutter/Dart, `go_router`, `coelo_ui_admin`, Supabase Flutter, PostgreSQL 17, SQL/RLS/pgTAP, `flutter_map` 8.3.2 e OpenStreetMap.

## Global Constraints

- Orçamento total: quatro horas; usar testes focados e não regenerar goldens sem mudança visual intencional.
- `/dev` usa somente fixtures; rotas normais usam somente Supabase e falham fechadas.
- Pessoa é global; papel, aplicativo e alcance são contextuais.
- RLS é deny-by-default; ator, tenant e alcance são derivados ou revalidados server-side.
- Importar/Exportar sem contrato fica visível, desabilitado e explica o motivo.
- Instituições é a baseline de diretórios e wizards.
- A tarefa Estruturas é a fonte dos IDs de instituição, unidade e turma.
- Não usar `service_role`, segredo ou metadata mutável no Flutter.

---

### Task 1: Fundação visual, mapa e dataset compartilhado

**Files:**
- Create: `apps/superadmin/lib/shared/presentation/widgets/coelo_compact_address_map.dart`
- Create: `apps/superadmin/lib/app/dev_menu/development_access_health_fixture_catalog.dart`
- Modify: `apps/superadmin/pubspec.yaml`
- Modify: `apps/superadmin/pubspec.lock`
- Modify: `apps/superadmin/test/app/dev_menu/development_dataset_contract_test.dart`
- Create: `apps/superadmin/test/shared/presentation/widgets/coelo_compact_address_map_test.dart`

**Interfaces:**
- Consumes: `demoInstitutionRecords` and the unit/group identifiers exposed by the structural fixture repositories.
- Produces: `CoeloCompactAddressMap`, `DevelopmentAccessHealthFixtureCatalog.standard()`, stable people/child/context IDs and typed slices consumed by Tasks 2–5.

- [ ] **Step 1: Write failing dataset and map tests**

```dart
test('access and health fixture preserves approved scale and links', () {
  final data = DevelopmentAccessHealthFixtureCatalog.standard();
  expect(data.children, hasLength(180));
  expect(data.guardians, hasLength(270));
  expect(data.teamMembers, hasLength(42));
  expect(data.safetyRecords, hasLength(164));
  expect(data.safetyRecords.where((item) => item.status == 'authorized'), hasLength(126));
  expect(data.children.every((child) => data.institutionIds.contains(child.institutionId)), isTrue);
  expect(data.children.where((child) => child.guardianIds.length >= 3), hasLength(9));
});

testWidgets('compact map exposes marker and OSM attribution', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: CoeloCompactAddressMap(latitude: -23.5505, longitude: -46.6333),
  ));
  expect(find.byKey(const Key('coelo-address-map-marker')), findsOneWidget);
  expect(find.textContaining('OpenStreetMap'), findsOneWidget);
});
```

- [ ] **Step 2: Verify the tests fail before implementation**

Run: `rtk flutter test test/app/dev_menu/development_dataset_contract_test.dart test/shared/presentation/widgets/coelo_compact_address_map_test.dart`

Expected: compilation fails because the catalog and map do not exist.

- [ ] **Step 3: Add the map dependency and minimal public widget**

Add `flutter_map: 8.3.2` to `apps/superadmin/pubspec.yaml`, run `flutter pub get`, and implement:

```dart
final class CoeloCompactAddressMap extends StatelessWidget {
  const CoeloCompactAddressMap({required this.latitude, required this.longitude, super.key});
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return SizedBox(
      height: 184,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        child: FlutterMap(
          options: MapOptions(initialCenter: point, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'me.coelo.superadmin',
            ),
            MarkerLayer(markers: [Marker(
              point: point,
              width: CoeloSize.touchMin,
              height: CoeloSize.touchMin,
              child: const Icon(Icons.location_pin, key: Key('coelo-address-map-marker')),
            )]),
            const RichAttributionWidget(attributions: [
              TextSourceAttribution('OpenStreetMap contributors'),
            ]),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the deterministic fixture catalog**

Create immutable fixture records and `DevelopmentAccessHealthFixtureCatalog.standard()` with exactly 180 children, 270 guardians, 42 team members, 164 safety records and the approved status distribution. Derive stable UUID-shaped IDs from indexes, choose names from fixed Brazilian first/surname lists, and assign only institution/unit/group IDs present in the structural catalog. Use this public shape:

```dart
final class DevelopmentAccessHealthFixtureCatalog {
  const DevelopmentAccessHealthFixtureCatalog({
    required this.institutionIds,
    required this.children,
    required this.guardians,
    required this.teamMembers,
    required this.safetyRecords,
    required this.careProfiles,
    required this.medicationPlans,
  });
  factory DevelopmentAccessHealthFixtureCatalog.standard();
  final Set<String> institutionIds;
  final List<DevelopmentChildFixture> children;
  final List<DevelopmentAdultFixture> guardians;
  final List<DevelopmentAdultFixture> teamMembers;
  final List<DevelopmentSafetyFixture> safetyRecords;
  final List<DevelopmentCareProfileFixture> careProfiles;
  final List<DevelopmentMedicationPlanFixture> medicationPlans;
}
```

- [ ] **Step 5: Run focused tests and commit**

Run: `rtk flutter test test/app/dev_menu/development_dataset_contract_test.dart test/shared/presentation/widgets/coelo_compact_address_map_test.dart`

Expected: all tests pass.

Commit: `feat(dev): add linked access and health fixture catalog`

### Task 2: Pessoas e Usuários internos

**Files:**
- Modify: `apps/superadmin/lib/features/people/presentation/person_directory_page.dart`
- Modify: `apps/superadmin/lib/features/people/presentation/person_form_page.dart`
- Modify: `apps/superadmin/lib/features/people/data/fake_person_directory_repository.dart`
- Modify: `apps/superadmin/lib/features/platform_users/presentation/platform_user_directory_page.dart`
- Modify: `apps/superadmin/lib/features/platform_users/presentation/platform_user_form_page.dart`
- Modify: `apps/superadmin/lib/features/platform_users/data/fake_platform_user_repository.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: `apps/superadmin/test/features/people/presentation/person_directory_page_test.dart`
- Modify: `apps/superadmin/test/features/people/presentation/person_form_page_test.dart`
- Modify: `apps/superadmin/test/features/platform_users/presentation/platform_user_directory_page_test.dart`
- Modify: `apps/superadmin/test/features/platform_users/presentation/platform_user_pages_test.dart`

**Interfaces:**
- Consumes: `DevelopmentAccessHealthFixtureCatalog.standard()` and `CoeloCompactAddressMap`.
- Produces: Institution-parity directories; direct edit callbacks; searchable, paged repositories; address map in both wizards.

- [ ] **Step 1: Add failing interaction tests**

```dart
testWidgets('person table supports select all, files and direct edit', (tester) async {
  String? editedId;
  await pumpPersonDirectory(tester, onEdit: (id) => editedId = id);
  expect(find.text('Arquivos'), findsOneWidget);
  await tester.tap(find.byKey(const Key('person-select-page')));
  expect(find.textContaining('selecionados'), findsOneWidget);
  await tester.tap(find.byKey(const Key('person-row-person-0001')));
  expect(editedId, 'person-0001');
  expect(find.byType(CoeloAdminPagination), findsOneWidget);
});
```

Add the equivalent internal-user test for `platform-user-select-page`, Files,
pagination, direct edit, searchable institution selector and select all.

- [ ] **Step 2: Verify the focused tests fail**

Run: `rtk flutter test test/features/people/presentation/person_directory_page_test.dart test/features/platform_users/presentation/platform_user_directory_page_test.dart`

Expected: missing selection/direct-edit contracts fail.

- [ ] **Step 3: Implement directory parity and fixture adapters**

Use `CoeloAdminFileActions`, `CoeloAdminResizableTable`, the existing view toggle and `CoeloAdminPagination`. Put create first in cards and in a left-aligned banner above table. Repository queries must normalize search and reset page when filters change. Adapt fixture records without copying structural IDs.

- [ ] **Step 4: Add compact maps to address steps**

Render `CoeloCompactAddressMap` only when a valid coordinate pair exists. For an unresolved real address render an inline neutral state with the text `Localização ainda não encontrada`; keep address fields editable.

- [ ] **Step 5: Wire direct edit routes and verify**

Use the existing router edit route; card and row callbacks call it directly and never open the detail route first.

Run: `rtk flutter test test/features/people/presentation/person_directory_page_test.dart test/features/people/presentation/person_form_page_test.dart test/features/platform_users/presentation/platform_user_directory_page_test.dart test/features/platform_users/presentation/platform_user_pages_test.dart`

Expected: all tests pass.

Commit: `fix(superadmin): align people and internal access screens`

### Task 3: Segurança da criança

**Files:**
- Modify: `apps/superadmin/lib/features/safety/presentation/safety_pages.dart`
- Modify: `apps/superadmin/lib/features/safety/data/dev/dev_child_safety_repository.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: `apps/superadmin/test/features/safety/presentation/safety_pages_test.dart`
- Modify: `apps/superadmin/test/features/safety/data/dev/dev_child_safety_repository_test.dart`

**Interfaces:**
- Consumes: shared child/safety fixtures.
- Produces: aligned create tile, canonical table, search/status pagination, select page and direct edit.

- [ ] **Step 1: Write failing UI and fixture tests**

```dart
testWidgets('safety table uses top create action and direct edit', (tester) async {
  String? edited;
  await pumpSafety(tester, onEdit: (id) => edited = id);
  expect(find.byKey(const Key('safety-create-banner')), findsOneWidget);
  expect(find.text('Cadastrar pessoa'), findsNothing);
  expect(find.byKey(const Key('safety-select-page')), findsOneWidget);
  await tester.tap(find.byKey(const Key('safety-row-safety-0001')));
  expect(edited, 'safety-0001');
  expect(find.byType(CoeloAdminPagination), findsOneWidget);
});
```

- [ ] **Step 2: Run failing tests**

Run: `rtk flutter test test/features/safety/presentation/safety_pages_test.dart test/features/safety/data/dev/dev_child_safety_repository_test.dart`

Expected: table/banner/direct-edit assertions fail.

- [ ] **Step 3: Replace the private table composition**

Use `CoeloAdminResizableTable`; render the create banner above table and the create tile as the first equal-height grid child in cards. Add page selection, Files and `CoeloAdminPagination`. Search child name, private identifier, institution and unit.

- [ ] **Step 4: Align the wizard and direct routes**

Use `SuperadminFormStepNavigation` and `SuperadminFormActionFooter` for Criança, Pessoa autorizada, Validade/capacidades and Revisão. Cards and rows call edit directly; approval/rejection/suspension remain separate commands.

- [ ] **Step 5: Verify and commit**

Run the two focused test files from Step 2.

Expected: all tests pass.

Commit: `fix(superadmin): complete child safety directory flow`

### Task 4: Central de Perfis e Modelos e catálogo transversal

**Files:**
- Modify: `apps/superadmin/lib/app/navigation/superadmin_navigation.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_routes.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: `apps/superadmin/lib/features/access_profiles/domain/access_profile.dart`
- Modify: `apps/superadmin/lib/features/access_profiles/presentation/access_profile_directory_page.dart`
- Modify: `apps/superadmin/lib/features/access_profiles/presentation/access_profile_form_page.dart`
- Modify: `apps/superadmin/lib/features/access_profiles/data/fake_access_profile_repository.dart`
- Modify: `apps/superadmin/lib/features/access_profiles/data/supabase_access_profile_repository.dart`
- Create: `packages/coelo_database/migrations/20260901170000_access_profile_cross_app_catalog.sql`
- Create: `packages/coelo_database/supabase/tests/access_profile_cross_app_catalog_test.sql`
- Modify: `apps/superadmin/test/features/access_profiles/presentation/access_profile_pages_test.dart`
- Modify: `apps/superadmin/test/features/access_profiles/data/supabase_access_profile_repository_test.dart`

**Interfaces:**
- Consumes: current platform, institution and principal catalogs and guarded profile RPCs.
- Produces: one Profiles/Models route, `AccessProfileApplication`, application-aware permission items, select-all hierarchy and additive cross-app catalog metadata.

- [ ] **Step 1: Write failing Dart and SQL tests**

```dart
testWidgets('central switches between profiles and models', (tester) async {
  await pumpAccessProfiles(tester);
  expect(find.text('Perfis'), findsOneWidget);
  expect(find.text('Modelos'), findsOneWidget);
  await tester.tap(find.text('Modelos'));
  expect(find.byKey(const Key('access-profile-model-table')), findsOneWidget);
});

testWidgets('permission matrix selects a whole screen', (tester) async {
  await pumpAccessProfileForm(tester);
  await tester.tap(find.byKey(const Key('permission-screen-people-select-all')));
  expect(selectedCodes(), containsAll(['people.read', 'people.create', 'people.update']));
});
```

The pgTAP test must assert anonymous denial, authenticated denial without
`platform.roles.manage`, AAL2 enforcement, application metadata for all three
apps, and inability to assign institution/principal scope without a matching
membership or guardian context.

- [ ] **Step 2: Run the focused tests and record the failures**

Run Dart: `rtk flutter test test/features/access_profiles/presentation/access_profile_pages_test.dart test/features/access_profiles/data/supabase_access_profile_repository_test.dart`

Run SQL: the repository's existing pgTAP command for `access_profile_cross_app_catalog_test.sql`.

- [ ] **Step 3: Implement additive catalog metadata and guarded RPC payloads**

The migration adds `application_code` (`superadmin`, `admin`, `principal`) to
the read catalog projection, preserves module/screen/action codes, adds indexes
for `(application_code,module_code,screen_code,action_code)`, and updates the
guarded detail/save RPC payload. Direct table grants remain revoked. Save
validates that every requested code is active, grantable and within the actor's
authority; assignment scopes continue through the existing platform,
institution and guardian-context tables.

- [ ] **Step 4: Consolidate navigation and directory**

Remove the separate Modelos navigation node. Keep old `/profile-models` and
`/dev/profile-models` as redirects to the Models tab for bookmarked URLs. Use
the shared underline tabs `Perfis` and `Modelos`, app filters, Files,
cards/table, direct edit and numbered pagination.

- [ ] **Step 5: Implement the hierarchical matrix**

Add application → module → screen grouping with checkboxes at each level. A
parent state is checked, unchecked or indeterminate from its grantable
children. Non-grantable/inherited actions stay disabled and retain server
reasons. The review step lists additions/removals and requires audit reason.

- [ ] **Step 6: Verify Dart, SQL and commit**

Run the commands from Step 2 plus `rtk flutter test test/app/navigation/superadmin_navigation_test.dart test/app/router/access_profile_routes_test.dart test/app/router/access_profile_preview_routes_test.dart`.

Expected: all focused tests pass and pgTAP reports no failures.

Commit: `feat(superadmin): unify access profiles and models`

### Task 5: Perfis de cuidado e Planos de medicação

**Files:**
- Modify: `apps/superadmin/lib/features/health_care/presentation/health_care_directory_page.dart`
- Modify: `apps/superadmin/lib/features/health_care/presentation/health_care_form_pages.dart`
- Modify: `apps/superadmin/lib/features/health_care/presentation/health_medication_plan_directory_page.dart`
- Modify: `apps/superadmin/lib/features/health_care/presentation/health_medication_plan_form_page.dart`
- Modify: `apps/superadmin/lib/features/health_care/presentation/health_medication_form_sections.dart`
- Modify: `apps/superadmin/lib/features/health_care/data/dev/dev_health_care_repository.dart`
- Modify: `apps/superadmin/lib/features/health_care/data/dev/dev_medication_plan_repository.dart`
- Modify: `apps/superadmin/test/features/health_care/presentation/health_care_profile_directory_page_test.dart`
- Modify: `apps/superadmin/test/features/health_care/presentation/health_medication_plan_directory_page_test.dart`
- Modify: `apps/superadmin/test/features/health_care/presentation/health_care_form_pages_test.dart`
- Modify: `apps/superadmin/test/features/health_care/presentation/medication_plan_ui_contract_test.dart`

**Interfaces:**
- Consumes: shared children/care/medication fixtures and existing health repositories.
- Produces: canonical directories and wizards without changing undecided clinical policy.

- [ ] **Step 1: Write failing parity and form tests**

Assert Files, create-left, table/cards, select page, direct edit and
`CoeloAdminPagination` in both directories. Assert the care wizard steps are
Criança, Alergias e restrições, Orientações de cuidado and Revisão. Assert the
medication wizard steps are Criança e medicamento, Vigência, Horários e
responsáveis, Documento and Revisão, with no overlapping labels at 375 and
1440 logical pixels.

- [ ] **Step 2: Run focused tests and verify failures**

Run: `rtk flutter test test/features/health_care/presentation/health_care_profile_directory_page_test.dart test/features/health_care/presentation/health_medication_plan_directory_page_test.dart test/features/health_care/presentation/health_care_form_pages_test.dart test/features/health_care/presentation/medication_plan_ui_contract_test.dart`

- [ ] **Step 3: Implement directory and wizard parity**

Use shared admin table, Files, create banner/tile, selection and pagination.
Replace private wizard navigation/footer with the shared components. Keep child
identity locked only during edit. Keep administration, approval, suspension
and evidence as separate disabled or authorized actions according to the
existing backend contract.

- [ ] **Step 4: Connect shared fixtures and verify**

Map fixture IDs to existing domain records; do not generate medication plans
for every child and do not create administration events.

Run the command from Step 2.

Expected: all tests pass.

Commit: `fix(superadmin): align care and medication workflows`

### Task 6: Integração Supabase, rastreadores e gate final

**Files:**
- Modify only if evidence requires: relevant Supabase repositories and the new migration from Task 4.
- Modify: `docs/reviews/coelo-flutter-pendencias.md`
- Modify: `docs/reviews/coelo-supabase-pendencias.md`
- Modify: `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`
- Modify when durable knowledge changed: `docs/knowledge/team/superadmin-development-dataset.md`
- Modify when durable knowledge changed: `docs/knowledge/team/superadmin-access-profiles.md`

**Interfaces:**
- Consumes: Tasks 1–5 and the structural fixture IDs.
- Produces: scoped verification evidence, accurate tracker states and a clean branch handoff.

- [ ] **Step 1: Run static and visual contract checks**

Run analyzer from `apps/superadmin` and the visual validator from `apps/catalog`:

```text
rtk dart analyze lib/app lib/features/people lib/features/platform_users lib/features/safety lib/features/access_profiles lib/features/health_care
cd ../catalog
rtk dart run tool/validate_admin_visual_contracts.dart
```

Expected: no analyzer errors in changed files and visual contract validator exits 0.

- [ ] **Step 2: Run focused Flutter suites**

Run only the changed test files from Tasks 1–5 plus router/navigation tests.
Expected: all pass. Do not run every golden unless a changed contract requires
regeneration.

- [ ] **Step 3: Run database security evidence**

Run the existing pgTAP harness for people, child safety and access profiles,
including the new cross-app catalog test. Verify RLS, grants, AAL2,
anti-escalation and cross-tenant denial. If remote migration state differs from
local, record drift and do not claim remote completion.

- [ ] **Step 4: Smoke `/dev` and production composition**

Open the seven `/dev` routes and verify search, filters, view switch, Files,
selection, direct edit, wizard navigation and pagination. In a real authorized
session verify list/read and one reversible create/edit cycle where the
approved backend contract exists. Never use fixtures in this smoke.

- [ ] **Step 5: Update trackers and knowledge**

For every scoped action, record exact status and evidence. Promote to done only
when Flutter, Supabase and integrated evidence are all present. Otherwise use
`local-green`, `blocked-supabase`, `blocked-decision` or `not-reviewed` with a
concrete reason. Update knowledge only for durable approved behavior.

- [ ] **Step 6: Final diff/security review and commit**

Run:

```text
rtk git diff --check
rtk git status --short
rtk git diff --cached -- . ':!**/*.png'
```

Confirm no secret, service role key, generated cache or unrelated user change
is staged.

Commit: `docs(review): record access and health completion evidence`
