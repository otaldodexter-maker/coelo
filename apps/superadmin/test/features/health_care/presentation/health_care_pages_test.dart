import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/data/demo_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_detail_page.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller keeps identity filters independent from hierarchy filters', () async {
    final controller = HealthCareController(DemoHealthCareRepository());
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
      DemoHealthCareRepository(),
      actor: HealthCareActor(
        id: 'reader-b',
        profile: DemoHealthCareProfile.sensitiveReader,
        institutionId: 'institution-demo-b',
        authorizedChildIds: {'child-demo-b'},
      ),
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.items.map((item) => item.id), ['child-demo-b']);
  });

  test('minimized actor cannot elevate itself to Owner', () async {
    final controller = HealthCareController(
      DemoHealthCareRepository(),
      actor: HealthCareActor(
        id: 'minimized-demo',
        profile: DemoHealthCareProfile.minimized,
        authorizedChildIds: {'child-demo-a'},
      ),
    );
    addTearDown(controller.dispose);

    await expectLater(controller.setProfile(DemoHealthCareProfile.owner), throwsStateError);
    expect(controller.canEdit, isFalse);
  });

  test('clearing institution prunes hierarchy and preserves identity', () async {
    final controller = HealthCareController(DemoHealthCareRepository());
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
    final controller = HealthCareController(DemoHealthCareRepository());
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
    final controller = HealthCareController(DemoHealthCareRepository());
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
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Em Implanta\u00e7\u00e3o'), findsOneWidget);

    await tester.tap(find.byKey(const Key('health-care-profiles-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('health-care-profiles-table')), findsOneWidget);
    expect(find.byType(CoeloAdminResizableTable<HealthCareChildSummary>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile detail separates care from medication plans', (tester) async {
    await _setViewport(tester, const Size(1024, 900));
    final controller = HealthCareController(DemoHealthCareRepository());
    addTearDown(controller.dispose);
    var plansOpened = false;

    await _pump(
      tester,
      HealthCareProfileDetailPage(
        controller: controller,
        childId: 'child-demo-a',
        logout: unavailableSuperadminLogout,
        onMedicationPlans: () => plansOpened = true,
        onEditCareProfile: () {},
      ),
    );

    expect(find.text('Alergias e restri\u00e7\u00f5es'), findsOneWidget);
    expect(find.text('Em acompanhamento'), findsOneWidget);
    expect(find.text('Epis\u00f3dio grave'), findsOneWidget);
    expect(find.text('Hist\u00f3rico'), findsOneWidget);
    expect(find.text('Epis\u00f3dio leve'), findsOneWidget);
    expect(find.text('Perfil de cuidado'), findsWidgets);
    expect(find.text('Planos de medica\u00e7\u00e3o'), findsWidgets);
    expect(find.text('Medicamentos'), findsNothing);
    expect(find.byKey(const Key('health-medication-create')), findsNothing);

    await tester.tap(find.text('Ver planos da crian\u00e7a'));
    await tester.pump();
    expect(plansOpened, isTrue);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('profile directory has no overflow at $width with 200% text', (tester) async {
      await _setViewport(tester, Size(width, 1000));
      final controller = HealthCareController(DemoHealthCareRepository());
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

    testWidgets('profile detail has no overflow at $width with 200% text', (tester) async {
      await _setViewport(tester, Size(width, 1000));
      final controller = HealthCareController(DemoHealthCareRepository());
      addTearDown(controller.dispose);

      await _pump(
        tester,
        HealthCareProfileDetailPage(
          controller: controller,
          childId: 'child-demo-a',
          logout: unavailableSuperadminLogout,
          onMedicationPlans: () {},
          onEditCareProfile: () {},
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
