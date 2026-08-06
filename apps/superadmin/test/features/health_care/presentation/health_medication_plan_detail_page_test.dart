import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/data/demo_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_detail_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows one navigable medication section at a time', (tester) async {
    await _setViewport(tester, const Size(1440, 1000));
    final controller = HealthCareController(DemoHealthCareRepository());
    addTearDown(controller.dispose);
    final child = await controller.repository.findChild('child-demo-a', actor: controller.actor);
    final medicationId = child!.medications.first.id;
    var edited = false;

    await _pump(
      tester,
      HealthMedicationPlanDetailPage(
        controller: controller,
        medicationId: medicationId,
        logout: unavailableSuperadminLogout,
        onEdit: () => edited = true,
      ),
    );

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(tester.getSize(find.byType(SuperadminFormStepNavigation)).width, 248);
    for (final label in const ['Resumo', 'Agenda e responsáveis', 'Registros de dose']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text(child.displayName), findsWidgets);
    expect(find.text('Dose: 5 mL'), findsOneWidget);
    expect(find.textContaining('07:30'), findsNothing);
    expect(find.textContaining('03/08/2026'), findsNothing);

    await tester.tap(find.text('Agenda e responsáveis'));
    await tester.pumpAndSettle();
    expect(find.textContaining('07:30'), findsOneWidget);
    expect(find.text('Dose: 5 mL'), findsNothing);
    expect(find.textContaining('03/08/2026'), findsNothing);

    await tester.tap(find.text('Registros de dose'));
    await tester.pumpAndSettle();
    expect(find.textContaining('03/08/2026'), findsWidgets);
    expect(find.textContaining('07:30'), findsNothing);

    await tester.tap(find.text('Editar plano'));
    await tester.pump();
    expect(edited, isTrue);
  });

  for (final size in [const Size(375, 1000), const Size(1440, 1000)]) {
    testWidgets('keeps the plan header near the content top at ${size.width}', (tester) async {
      await _setViewport(tester, size);
      final controller = HealthCareController(DemoHealthCareRepository());
      addTearDown(controller.dispose);
      final child = await controller.repository.findChild('child-demo-a', actor: controller.actor);

      await _pump(
        tester,
        HealthMedicationPlanDetailPage(
          controller: controller,
          medicationId: child!.medications.first.id,
          logout: unavailableSuperadminLogout,
        ),
      );

      final headerCard = find
          .ancestor(of: find.text(child.displayName).first, matching: find.byType(Card))
          .first;
      expect(
        tester.getTopLeft(headerCard).dy,
        lessThan(180),
        reason: 'The detail content must start below the page header, not be vertically centered.',
      );
    });
  }
  testWidgets('uses semantic error status for a refused medication plan', (tester) async {
    await _setViewport(tester, const Size(1440, 1000));
    final repository = DemoHealthCareRepository();
    final actor = HealthCareActor(
      id: 'owner-demo',
      profile: DemoHealthCareProfile.owner,
      institutionId: 'institution-demo-a',
      authorizedChildIds: const {'child-demo-a'},
      contextualCapabilities: const {HealthCareCapability.clinicalReview},
    );
    final medication = await repository.createMedication(
      childId: 'child-demo-a',
      name: 'Medicamento recusado',
      dose: '2',
      doseUnit: 'mL',
      route: 'oral',
      startsAt: DateTime.utc(2026, 8, 1),
      endsAt: DateTime.utc(2026, 8, 10),
      schedules: [
        HealthMedicationSchedule(
          id: 'schedule-refused',
          time: HealthCareTimeOfDay(9, 0),
          institutionId: 'institution-demo-a',
        ),
      ],
      actor: actor,
    );
    await repository.reviewMedication(
      childId: 'child-demo-a',
      medicationId: medication.id,
      status: HealthMedicationReviewStatus.underReview,
      actor: actor,
    );
    await repository.reviewMedication(
      childId: 'child-demo-a',
      medicationId: medication.id,
      status: HealthMedicationReviewStatus.refused,
      reason: 'Recusa demonstrativa',
      actor: actor,
    );
    final controller = HealthCareController(repository, actor: actor);
    addTearDown(controller.dispose);

    await _pump(
      tester,
      HealthMedicationPlanDetailPage(
        controller: controller,
        medicationId: medication.id,
        logout: unavailableSuperadminLogout,
      ),
    );

    final status = tester.widget<CoeloStatusChip>(find.byType(CoeloStatusChip));
    expect(status.label, 'Recusado');
    expect(status.icon, Icons.block_rounded);
    expect(status.backgroundColor, CoeloStatusColors.light.errorContainer);
    expect(status.foregroundColor, CoeloStatusColors.light.onErrorContainer);
  });
  for (final width in [375.0, 768.0, 1440.0]) {
    testWidgets('is responsive at $width with 200% text', (tester) async {
      await _setViewport(tester, Size(width, 1200));
      final controller = HealthCareController(DemoHealthCareRepository());
      addTearDown(controller.dispose);
      final child = await controller.repository.findChild('child-demo-a', actor: controller.actor);

      await _pump(
        tester,
        HealthMedicationPlanDetailPage(
          controller: controller,
          medicationId: child!.medications.first.id,
          logout: unavailableSuperadminLogout,
          onEdit: () {},
        ),
        textScale: 2,
      );

      expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
      if (width == 375) {
        expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
        expect(find.byKey(const Key('health-medication-detail-previous-section')), findsOneWidget);
        expect(find.byKey(const Key('health-medication-detail-next-section')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('health-medication-detail-next-section')),
          240,
          scrollable: find.descendant(
            of: find.byKey(const Key('health-medication-detail-scroll')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.byKey(const Key('health-medication-detail-next-section')));
        await tester.pumpAndSettle();
        expect(find.textContaining('07:30'), findsOneWidget);
      }
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
