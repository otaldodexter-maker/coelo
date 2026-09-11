import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_form_sections.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// medication.evidence: o registro de dose vive na revisão do plano em edição e
// vai ao servidor com desfecho, motivo e observação.
void main() {
  testWidgets('registrar dose exige motivo quando não administrada e lista o registro', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final recorded = <({MedicationEvidenceOutcome outcome, String? reason, String? note})>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          medicationId: 'plan-1',
          childId: 'child-1',
          childOptions: const [HealthCareFormChoice(id: 'child-1', label: 'Criança Um')],
          initialDraft: HealthMedicationPlanFormDraft(
            planId: 'plan-1',
            childId: 'child-1',
            medicationName: 'Dipirona',
            doseAmount: 2.5,
            doseUnit: 'ml',
            administrationRoute: 'oral',
            weekdays: const {1},
            responsibleIds: const {},
            validFrom: DateTime(2026, 9, 1),
          ),
          evidence: [
            MedicationEvidence(
              id: 'evidence-0',
              occurredAt: DateTime(2026, 9, 10, 8, 30),
              outcome: MedicationEvidenceOutcome.administered,
            ),
          ],
          onRecordEvidence: ({required outcome, reason, note}) async {
            recorded.add((outcome: outcome, reason: reason, note: note));
            return MedicationEvidence(
              id: 'evidence-1',
              occurredAt: DateTime(2026, 9, 11, 9),
              outcome: outcome,
              reason: reason,
              note: note,
            );
          },
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    expect(find.text('Registros de dose'), findsOneWidget);
    expect(find.textContaining('10/09/2026 08:30 · Administrada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('health-medication-record-evidence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recusada'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('health-medication-evidence-confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'motivo obrigatório');

    await tester.enterText(
      find.byKey(const Key('health-medication-evidence-reason')),
      'Criança recusou',
    );
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(recorded.single.outcome, MedicationEvidenceOutcome.refused);
    expect(recorded.single.reason, 'Criança recusou');
    expect(find.textContaining('11/09/2026 09:00 · Recusada · Criança recusou'), findsOneWidget);
    expect(find.text('Dose registrada.'), findsOneWidget);
  });

  testWidgets('sem plano salvo a revisão não oferece registro de dose', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onRecordEvidence: ({required outcome, reason, note}) async => throw StateError('x'),
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    expect(find.text('Registros de dose'), findsNothing);
  });
}
