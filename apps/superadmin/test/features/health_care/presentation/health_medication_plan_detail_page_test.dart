import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/data/demo_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows plan data and keeps dose records in the plan detail', (tester) async {
    final controller = HealthCareController(DemoHealthCareRepository());
    addTearDown(controller.dispose);
    final child = await controller.repository.findChild('child-demo-a', actor: controller.actor);
    final medicationId = child!.medications.first.id;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanDetailPage(
          controller: controller,
          medicationId: medicationId,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vigência'), findsOneWidget);
    expect(find.text('Horários e responsáveis'), findsOneWidget);
    expect(find.text('Registros de doses'), findsOneWidget);
    expect(find.text(child.displayName), findsWidgets);
  });
}
