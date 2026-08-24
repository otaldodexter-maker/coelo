import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supports create, detail, update and reset for dev plans', () async {
    final repository = DevMedicationPlanRepository();
    final command = MedicationPlanSaveCommand(
      requestId: 'request-1', childPersonId: 'child-1', expectedVersion: 0,
      medicationName: 'Inalador', doseAmount: 2, doseUnit: 'jatos', administrationRoute: 'Inalatória',
      validFrom: DateTime(2026, 1, 1), reason: 'Rotina', scopeKind: 'institution', timezone: 'America/Sao_Paulo',
      schedules: [MedicationScheduleDraft(timeOfDay: '08:00', weekdays: {1, 2, 3, 4, 5}, timezone: 'America/Sao_Paulo')],
    );
    final created = await repository.save(command);
    expect((await repository.fetchDetail(created.id)).medicationName, 'Inalador');
    final updated = await repository.save(MedicationPlanSaveCommand(
      requestId: 'request-2', planId: created.id, childPersonId: 'child-1', expectedVersion: 1,
      medicationName: 'Inalador novo', doseAmount: 1, doseUnit: 'jato', administrationRoute: 'Inalatória',
      validFrom: DateTime(2026, 1, 1), reason: 'Ajuste', scopeKind: 'institution', timezone: 'America/Sao_Paulo',
      schedules: command.schedules,
    ));
    expect(updated.currentVersion, 2);
    repository.resetSession();
    expect((await repository.fetchPage(const MedicationPlanQuery())).items, isEmpty);
  });
}
