import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create remains unavailable without externally loaded children', (tester) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async => saves += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma opção disponível'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(continueButton.onPressed, isNull);
    expect(saves, 0);
  });

  testWidgets('edit never renders an unknown child id as its label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          medicationId: 'plan-from-route',
          childId: 'child-secret-uuid',
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criança indisponível'), findsOneWidget);
    expect(find.text('child-secret-uuid'), findsNothing);
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(continueButton.onPressed, isNull);
  });
}
