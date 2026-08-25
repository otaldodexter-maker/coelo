import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import '../support/health_care_fixture_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_directory_page.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_file_actions.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_directory_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller keeps identity filters independent from hierarchy filters', () async {
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setPersonIds({'person-demo-a'});
    await controller.setInstitutionIds({'institution-demo-b'});

    expect(controller.query.personIds, {'person-demo-a'});
    expect(controller.query.institutionIds, {'institution-demo-b'});
    expect(controller.items.single.id, 'child-demo-a');

    await controller.setInstitutionIds({});
    expect(controller.query.personIds, {'person-demo-a'});
  });

  test('controller scopes results to the actor', () async {
    final controller = HealthCareController(
      FixtureHealthCareRepository(),
      actor: HealthCareActor(
        id: 'reader-b',
        profile: HealthCareAccessProfile.sensitiveReader,
        institutionId: 'institution-demo-b',
        authorizedChildIds: {'child-demo-b'},
      ),
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.items.map((item) => item.id), ['child-demo-b']);
  });

  test('minimized actor remains read-only', () async {
    final controller = HealthCareController(
      FixtureHealthCareRepository(),
      actor: HealthCareActor(
        id: 'minimized-demo',
        profile: HealthCareAccessProfile.minimized,
        authorizedChildIds: {'child-demo-a'},
      ),
    );
    addTearDown(controller.dispose);
    expect(controller.canEdit, isFalse);
  });

  test('clearing institution prunes hierarchy and preserves identity', () async {
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);
    await controller.setPersonIds({'person-demo-a'});
    await controller.setInstitutionIds({'institution-demo-a'});
    await controller.setUnitIds({'unit-demo-a'});
    await controller.setGroupIds({'group-demo-a'});

    await controller.setInstitutionIds({});

    expect(controller.query.personIds, {'person-demo-a'});
    expect(controller.query.unitIds, isEmpty);
    expect(controller.query.groupOrActivityIds, isEmpty);
  });

  test('owner mutations stay audited in the demonstrative repository', () async {
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);
    await controller.loadDetail('child-demo-a');

    await controller.inactivateAllergy(
      HealthAllergyInactivationCommand(
        childId: 'child-demo-a',
        allergyId: 'allergy-demo-active',
        justification: 'Item revisto pelo Owner',
      ),
    );
    await controller.updateCareProfile(
      HealthCareProfileUpdateCommand(
        childId: 'child-demo-a',
        items: [HealthCareProfileItem(catalogItemId: 'asthma')],
        justification: 'Apoio atualizado pelo Owner',
      ),
    );

    expect(controller.detail!.allergies.first.active, isFalse);
    expect(controller.detail!.careProfile.map((item) => item.catalogItemId), contains('asthma'));
    expect(controller.detail!.auditEvents.last.actorId, 'owner-demo');
  });

  testWidgets('profile directory uses canonical cards, table and linear tabs', (tester) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);

    await _pump(
      tester,
      HealthCareProfileDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
      ),
    );

    expect(find.byType(CoeloAdminInteractiveCard), findsWidgets);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
    expect(find.textContaining('Demonstra\u00e7\u00e3o local'), findsNothing);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Em Implanta\u00e7\u00e3o'), findsOneWidget);

    final toolbar = find.byType(CoeloAdminListingToolbar);
    final tabs = find.text('Todos');
    expect(tester.getTopLeft(toolbar).dy, lessThan(tester.getTopLeft(tabs).dy));

    final viewToggle = find.byWidgetPredicate((widget) => widget is SuperadminDirectoryViewToggle);
    expect(tester.getSize(viewToggle), const Size(128, CoeloSize.touchMin));

    await tester.tap(find.byKey(const Key('health-care-profiles-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('health-care-profiles-table')), findsOneWidget);
    expect(find.byType(CoeloAdminResizableTable<HealthCareChildSummary>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile directory exposes import and export file actions', (tester) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);

    await _pump(
      tester,
      HealthCareProfileDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
      ),
    );

    expect(find.text('Arquivos'), findsOneWidget);
    final profileShell = tester.widget<SuperadminShell>(find.byType(SuperadminShell));
    final profileFiles = tester.widget<HealthCareFileActions>(find.byType(HealthCareFileActions));
    expect(identical(profileShell.activityController, profileFiles.activityController), isTrue);
    await tester.tap(find.text('Arquivos'));
    await tester.pumpAndSettle();

    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);
  });

  testWidgets('medication plan directory exposes import and export file actions', (tester) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);

    await _pump(
      tester,
      HealthMedicationPlanDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
        onPlanSelected: (_) {},
      ),
    );

    expect(find.text('Arquivos'), findsOneWidget);
    final medicationShell = tester.widget<SuperadminShell>(find.byType(SuperadminShell));
    final medicationFiles = tester.widget<HealthCareFileActions>(
      find.byType(HealthCareFileActions),
    );
    expect(
      identical(medicationShell.activityController, medicationFiles.activityController),
      isTrue,
    );
    await tester.tap(find.text('Arquivos'));
    await tester.pumpAndSettle();

    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);
  });

  testWidgets('file export completes through the activity controller', (tester) async {
    final activityController = SuperadminActivityController();
    addTearDown(activityController.dispose);
    await _pump(
      tester,
      Scaffold(
        body: HealthCareFileActions(
          activityController: activityController,
          subject: 'Perfis de cuidado',
          fileBaseName: 'perfis-de-cuidado',
        ),
      ),
    );

    await tester.tap(find.text('Arquivos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();

    expect(activityController.activities, hasLength(1));
    expect(activityController.activities.single.kind, SuperadminActivityKind.export);
    expect(activityController.activities.single.fileName, 'perfis-de-cuidado.csv');
  });

  for (final width in [375.0, 768.0]) {
    testWidgets('health care uses a clean light surface at $width px', (tester) async {
      await _setViewport(tester, Size(width, 1000));
      final controller = HealthCareController(FixtureHealthCareRepository());
      addTearDown(controller.dispose);

      for (final page in <Widget>[
        HealthCareProfileDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
          onCreate: () {},
        ),
        HealthMedicationPlanDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onPlanSelected: (_) {},
        ),
        HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
        HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ]) {
        await _pump(tester, page);

        final scaffoldContext = tester.element(find.byType(Scaffold).first);
        final theme = Theme.of(scaffoldContext);
        expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
        expect(theme.appBarTheme.backgroundColor, theme.colorScheme.surface);
      }
    });
  }
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('profile directory has no overflow at $width with 200% text', (tester) async {
      await _setViewport(tester, Size(width, 1000));
      final controller = HealthCareController(FixtureHealthCareRepository());
      addTearDown(controller.dispose);

      await _pump(
        tester,
        HealthCareProfileDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
          onCreate: () {},
        ),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pump(WidgetTester tester, Widget child, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: appChild!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
