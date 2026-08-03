import 'dart:async';

import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_safety/data/demo_health_safety_repository.dart';
import 'package:coelo_superadmin/features/health_safety/domain/health_safety.dart'
    hide HealthSafetyDirectoryPage;
import 'package:coelo_superadmin/features/health_safety/presentation/health_safety_controller.dart';
import 'package:coelo_superadmin/features/health_safety/presentation/health_safety_detail_page.dart';
import 'package:coelo_superadmin/features/health_safety/presentation/health_safety_directory_page.dart';
import 'package:coelo_superadmin/features/health_safety/presentation/health_safety_forms.dart';

void main() {
  test('controller keeps identity filters independent from hierarchy filters', () async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await controller.load();
    await controller.setPersonIds({'person-demo-a'});
    await controller.setInstitutionIds({'institution-demo-b'});

    expect(controller.query.personIds, {'person-demo-a'});
    expect(controller.query.institutionIds, {'institution-demo-b'});
    expect(controller.items.single.id, 'child-demo-a');

    await controller.setInstitutionIds({});
    expect(controller.query.personIds, {'person-demo-a'});
  });

  test(
    'controller scopes directory to actor and prunes hierarchy without identity coupling',
    () async {
      final controller = HealthSafetyController(
        DemoHealthSafetyRepository(),
        actor: HealthSafetyActor(
          id: 'reader-b',
          profile: DemoHealthSafetyProfile.sensitiveReader,
          institutionId: 'institution-demo-b',
          authorizedChildIds: {'child-demo-b'},
        ),
      );

      await controller.load();
      expect(controller.items.map((item) => item.id), ['child-demo-b']);

      await controller.setPersonIds({'person-demo-b'});
      await controller.setInstitutionIds({'institution-demo-b'});
      await controller.setUnitIds({'unit-demo-b'});
      await controller.setGroupIds({'group-demo-b'});
      await controller.setInstitutionIds({'institution-demo-a'});

      expect(controller.query.personIds, {'person-demo-b'});
      expect(controller.query.unitIds, isEmpty);
      expect(controller.query.groupOrActivityIds, isEmpty);
    },
  );

  test('minimized actor cannot elevate itself to Owner', () async {
    final controller = HealthSafetyController(
      DemoHealthSafetyRepository(),
      actor: HealthSafetyActor(
        id: 'minimized-demo',
        profile: DemoHealthSafetyProfile.minimized,
        authorizedChildIds: {'child-demo-a'},
      ),
    );

    await expectLater(controller.setProfile(DemoHealthSafetyProfile.owner), throwsStateError);
    expect(controller.profile, DemoHealthSafetyProfile.minimized);
    expect(controller.canEdit, isFalse);
  });

  test('clearing institution clears hierarchy while preserving global identity filters', () async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await controller.setPersonIds({'person-demo-a'});
    await controller.setChildIds({'child-demo-a'});
    await controller.setInstitutionIds({'institution-demo-a'});
    expect(controller.availableUnitIds, {'unit-demo-a'});
    await controller.setUnitIds({'unit-demo-a'});
    expect(controller.availableGroupIds, {'group-demo-a'});
    await controller.setGroupIds({'group-demo-a'});

    await controller.setInstitutionIds({});

    expect(controller.query.personIds, {'person-demo-a'});
    expect(controller.query.childIds, {'child-demo-a'});
    expect(controller.query.unitIds, isEmpty);
    expect(controller.query.groupOrActivityIds, isEmpty);
    expect(controller.availableUnitIds, isEmpty);
    expect(controller.availableGroupIds, isEmpty);
  });

  test('programmatic child filters cannot exist without their hierarchy parent', () async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await controller.setUnitIds({'unit-demo-a'});
    await controller.setGroupIds({'group-demo-a'});
    expect(controller.query.unitIds, isEmpty);
    expect(controller.query.groupOrActivityIds, isEmpty);
  });

  test('owner command requires justification, audits before/after and reloads detail', () async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await controller.loadDetail('child-demo-a');

    expect(
      () => HealthMedicationCorrectionCommand(
        childId: 'child-demo-a',
        medicationId: 'medication-demo-a',
        name: 'Nome corrigido',
        justification: ' ',
      ),
      throwsArgumentError,
    );

    await controller.correctMedication(
      HealthMedicationCorrectionCommand(
        childId: 'child-demo-a',
        medicationId: 'medication-demo-a',
        name: 'Nome corrigido',
        justification: 'Correção validada pelo Owner',
      ),
    );

    expect(controller.detail!.medications.single.currentVersion.name, 'Nome corrigido');
    final audit = controller.detail!.auditEvents.last;
    expect(audit.justification, 'Correção validada pelo Owner');
    expect(audit.before, isNotEmpty);
    expect(audit.after, isNotEmpty);
  });

  test('owner allergy and care commands require justification and reload audited detail', () async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await controller.loadDetail('child-demo-a');

    await controller.inactivateAllergy(
      HealthAllergyInactivationCommand(
        childId: 'child-demo-a',
        allergyId: 'allergy-demo-active',
        justification: 'Item revisto pelo Owner',
      ),
    );
    expect(controller.detail!.allergies.first.active, isFalse);
    expect(controller.detail!.auditEvents.last.justification, 'Item revisto pelo Owner');

    await controller.updateCareProfile(
      HealthCareProfileUpdateCommand(
        childId: 'child-demo-a',
        items: [HealthSafetyCareProfileItem(catalogItemId: 'asthma')],
        justification: 'Apoio atualizado pelo Owner',
      ),
    );
    expect(controller.detail!.careProfile.map((item) => item.catalogItemId), contains('asthma'));
    expect(controller.detail!.auditEvents.last.justification, 'Apoio atualizado pelo Owner');
  });

  test('owner creation commands persist, audit and reload detail', () async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await controller.loadDetail('child-demo-a');
    final medicationCount = controller.detail!.medications.length;
    final allergyCount = controller.detail!.allergies.length;

    await controller.createMedication(
      HealthMedicationCreateCommand(
        childId: 'child-demo-a',
        name: 'Medicamento criado',
        dose: '5',
        doseUnit: 'mL',
        route: 'oral',
        startsAt: DateTime.utc(2026, 8, 4),
        endsAt: DateTime.utc(2026, 8, 8),
        schedules: [
          HealthMedicationSchedule(
            id: 'created-home',
            time: HealthSafetyTimeOfDay(9, 0),
            atHome: true,
          ),
        ],
      ),
    );
    await controller.createAllergy(
      HealthAllergyCreateCommand(
        childId: 'child-demo-a',
        label: 'Látex',
        type: HealthSafetyAllergyType.other,
      ),
    );

    expect(controller.detail!.medications, hasLength(medicationCount + 1));
    expect(controller.detail!.allergies, hasLength(allergyCount + 1));
    expect(controller.detail!.auditEvents.last.actorId, 'owner-demo');
  });

  test('typed medication draft rejects inverted dates and accepts multiple exact schedules', () {
    final schedules = [
      HealthMedicationSchedule(id: 'home', time: HealthSafetyTimeOfDay(7, 30), atHome: true),
      HealthMedicationSchedule(
        id: 'school',
        time: HealthSafetyTimeOfDay(12, 0),
        institutionId: 'institution-demo-a',
      ),
    ];
    expect(
      () => HealthMedicationDraft(
        name: 'Demo',
        dose: '5',
        doseUnit: 'mL',
        route: 'Oral',
        startsAt: DateTime(2026, 8, 10),
        endsAt: DateTime(2026, 8, 3),
        schedules: schedules,
      ),
      throwsArgumentError,
    );
    final draft = HealthMedicationDraft(
      name: 'Demo',
      dose: '5 mL',
      doseUnit: 'mL',
      route: 'Oral',
      startsAt: DateTime(2026, 8, 3),
      endsAt: DateTime(2026, 8, 10),
      schedules: schedules,
    );
    expect(draft.schedules, hasLength(2));
    expect(draft.schedules.first.atHome, isTrue);
    expect(draft.schedules.last.institutionId, 'institution-demo-a');
    expect(() => draft.schedules.clear(), throwsUnsupportedError);
  });

  testWidgets('directory uses shared listing controls and exposes cards and table', (tester) async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await tester.pumpWidget(
      _app(HealthSafetyDirectoryPage(controller: controller, logout: _logout)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminListingToolbar), findsOneWidget);
    expect(find.byType(CoeloSearchField), findsOneWidget);
    expect(find.text('Pessoa'), findsOneWidget);
    expect(find.text('Criança'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Criança Demo A'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('health-safety-directory-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Criança Demo A'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('health-safety-view-table')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('health-safety-view-table')));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminResizableTable<HealthSafetyChildSummary>), findsOneWidget);
  });

  testWidgets('detail enforces profiles and renders the three stacked sections', (tester) async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await tester.pumpWidget(
      _app(
        HealthSafetyDetailPage(controller: controller, childId: 'child-demo-a', logout: _logout),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Medicamentos'), findsOneWidget);
    expect(find.textContaining('claim'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Alergias e restrições'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('health-safety-detail-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Alergias e restrições'), findsOneWidget);
    expect(find.text('Alergia Medicamentosa Demo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Perfil de Cuidado'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('health-safety-detail-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Perfil de Cuidado'), findsOneWidget);
    expect(find.textContaining('Ciência'), findsWidgets);

    final minimizedController = HealthSafetyController(
      DemoHealthSafetyRepository(),
      actor: HealthSafetyActor(
        id: 'minimized-demo',
        profile: DemoHealthSafetyProfile.minimized,
        authorizedChildIds: {'child-demo-a'},
      ),
    );
    await tester.pumpWidget(
      _app(
        HealthSafetyDetailPage(
          controller: minimizedController,
          childId: 'child-demo-a',
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resumo minimizado'), findsOneWidget);
    expect(find.text('Medicamentos'), findsNothing);
  });

  testWidgets('detail Owner correction submits typed command and reloads the visible record', (
    tester,
  ) async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await tester.pumpWidget(
      _app(
        HealthSafetyDetailPage(controller: controller, childId: 'child-demo-a', logout: _logout),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Corrigir'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Corrigir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('health-owner-after')), 'Nome via UI');
    await tester.enterText(
      find.byKey(const Key('health-owner-justification')),
      'Correção necessária e revisada',
    );
    await tester.tap(find.text('Salvar correção'));
    await tester.pumpAndSettle();

    expect(controller.detail!.medications.single.currentVersion.name, 'Nome via UI');
    expect(find.textContaining('Nome via UI'), findsOneWidget);
  });

  testWidgets('detail binds create and mutation actions to their concrete records', (tester) async {
    final controller = HealthSafetyController(DemoHealthSafetyRepository());
    await tester.pumpWidget(
      _app(
        HealthSafetyDetailPage(controller: controller, childId: 'child-demo-a', logout: _logout),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('health-medication-create')), findsOneWidget);
    expect(find.byKey(const Key('health-medication-correct-medication-demo-a')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Alergias e restrições'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('health-safety-detail-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('health-allergy-create')), findsOneWidget);
    expect(find.byKey(const Key('health-allergy-inactivate-allergy-demo-active')), findsOneWidget);
    expect(find.byKey(const Key('health-allergy-inactivate-allergy-demo-inactive')), findsNothing);
  });

  testWidgets('Owner correction blocks duplicate saves and exposes recoverable async error', (
    tester,
  ) async {
    var attempts = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showHealthOwnerCorrectionDialog(
              context,
              before: 'Antes',
              onSave: (_) async {
                attempts += 1;
                if (attempts == 1) return pending.future;
              },
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('health-owner-after')), 'Depois');
    await tester.enterText(find.byKey(const Key('health-owner-justification')), 'Justificativa');
    await tester.tap(find.text('Salvar correção'));
    await tester.pump();
    await tester.tap(find.text('Salvando…'));
    expect(attempts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.completeError(StateError('Falha demonstrativa'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar. Tente novamente.'), findsOneWidget);
    expect(find.text('Salvar correção'), findsOneWidget);
  });

  testWidgets('Owner correction reports after and justification errors independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () =>
                showHealthOwnerCorrectionDialog(context, before: 'Antes', onSave: (_) {}),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar correção'));
    await tester.pump();

    expect(find.text('Informe o valor depois.'), findsOneWidget);
    expect(find.text('Informe a justificativa.'), findsOneWidget);
  });

  testWidgets('minimized directory card does not announce a blocked open action', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = HealthSafetyController(
      DemoHealthSafetyRepository(),
      actor: HealthSafetyActor(
        id: 'minimized-demo',
        profile: DemoHealthSafetyProfile.minimized,
        authorizedChildIds: {'child-demo-a'},
      ),
    );
    await tester.pumpWidget(
      _app(HealthSafetyDirectoryPage(controller: controller, logout: _logout)),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Abrir Saúde e Segurança')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Resumo minimizado')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('detail swaps controller listeners and reloads when inputs change', (tester) async {
    final first = HealthSafetyController(DemoHealthSafetyRepository());
    final second = HealthSafetyController(DemoHealthSafetyRepository());
    await tester.pumpWidget(
      _app(
        HealthSafetyDetailPage(
          key: const ValueKey('detail'),
          controller: first,
          childId: 'child-demo-a',
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        HealthSafetyDetailPage(
          key: const ValueKey('detail'),
          controller: second,
          childId: 'child-demo-b',
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(second.detail?.id, 'child-demo-b');
  });

  testWidgets('directory swaps controller listeners and loads replacement controller', (
    tester,
  ) async {
    final first = HealthSafetyController(DemoHealthSafetyRepository());
    final second = HealthSafetyController(
      DemoHealthSafetyRepository(),
      actor: HealthSafetyActor(
        id: 'reader-b',
        profile: DemoHealthSafetyProfile.sensitiveReader,
        institutionId: 'institution-demo-b',
        authorizedChildIds: {'child-demo-b'},
      ),
    );
    await tester.pumpWidget(
      _app(
        HealthSafetyDirectoryPage(
          key: const ValueKey('directory'),
          controller: first,
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        HealthSafetyDirectoryPage(
          key: const ValueKey('directory'),
          controller: second,
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(second.items.map((item) => item.id), ['child-demo-b']);
  });

  testWidgets('medication dialog validates required fields then saves exact schedules', (
    tester,
  ) async {
    HealthMedicationDraft? saved;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showHealthMedicationDialog(context, onSave: (value) => saved = value),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    expect(find.byType(CoeloFormTextField), findsWidgets);
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    expect(find.text('Informe o nome.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('health-medication-name')), 'Medicamento local');
    await tester.enterText(find.byKey(const Key('health-medication-dose')), '5 mL');
    await tester.enterText(find.byKey(const Key('health-medication-dose-unit')), 'mL');
    await tester.enterText(find.byKey(const Key('health-medication-route')), 'Oral');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(saved?.schedules.single.atHome, isTrue);
  });

  testWidgets('medication dialog adds multiple typed schedules with exclusive responsibility', (
    tester,
  ) async {
    HealthMedicationDraft? saved;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showHealthMedicationDialog(context, onSave: (value) => saved = value),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adicionar horário'));
    await tester.pump();
    await tester.tap(find.text('Adicionar horário'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('health-medication-name')), 'Medicamento local');
    await tester.enterText(find.byKey(const Key('health-medication-dose')), '5 mL');
    await tester.enterText(find.byKey(const Key('health-medication-dose-unit')), 'mL');
    await tester.enterText(find.byKey(const Key('health-medication-route')), 'Oral');
    await tester.ensureVisible(find.text('Salvar'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(saved!.startsAt, isA<DateTime>());
    expect(saved!.schedules, hasLength(2));
    expect(saved!.schedules.every((item) => item.atHome != (item.institutionId != null)), isTrue);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('directory has no overflow at $width with 200% text', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          HealthSafetyDirectoryPage(
            controller: HealthSafetyController(DemoHealthSafetyRepository()),
            logout: _logout,
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('detail and medication form have no overflow at $width with 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = HealthSafetyController(DemoHealthSafetyRepository());
      await tester.pumpWidget(
        _app(
          HealthSafetyDetailPage(controller: controller, childId: 'child-demo-a', logout: _logout),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('health-medication-create')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('health-medication-create')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

Widget _app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler, disableAnimations: true),
      child: child,
    ),
  ),
);
