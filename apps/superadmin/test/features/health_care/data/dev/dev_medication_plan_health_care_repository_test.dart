import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty medication repository produces an empty health care directory', () async {
    final repository = DevMedicationPlanHealthCareRepository(
      medicationPlans: DevMedicationPlanRepository(),
      childLabels: const {'child-1': 'Ana'},
    );

    final page = await repository.fetchDirectory(
      const HealthCareDirectoryQuery(),
      actor: repository.defaultActor,
    );

    expect(page.items, isEmpty);
    expect(page.totalCount, 0);
  });

  test('saved medication is exposed with child, version and schedule fields', () async {
    final medicationPlans = DevMedicationPlanRepository();
    final repository = DevMedicationPlanHealthCareRepository(
      medicationPlans: medicationPlans,
      childLabels: const {'child-1': 'Ana'},
    );
    await medicationPlans.save(_command(requestId: 'create-1'));

    final page = await repository.fetchDirectory(
      const HealthCareDirectoryQuery(),
      actor: repository.defaultActor,
    );
    final child = await repository.findChild('child-1', actor: repository.defaultActor);
    final version = child!.medications.single.currentVersion;

    expect(page.items.single.displayName, 'Ana');
    expect(page.items.single.medicationCount, 1);
    expect(child.personId, 'child-1');
    expect(version.version, 1);
    expect(version.name, 'Inalador');
    expect(version.dose, '2');
    expect(version.doseUnit, 'jatos');
    expect(version.route, 'Inalatória');
    expect(version.startsAt, DateTime(2026, 8, 27));
    expect(version.endsAt, DateTime(2026, 9, 27));
    expect(version.status, HealthMedicationReviewStatus.active);
    expect(version.schedules.single.time.hour, 8);
    expect(version.schedules.single.time.minute, 30);
    expect(version.schedules.single.atHome, isFalse);
    expect(version.schedules.single.institutionId, 'institution-dev');
  });

  test('updated medication replaces the current projected version', () async {
    final medicationPlans = DevMedicationPlanRepository();
    final repository = DevMedicationPlanHealthCareRepository(
      medicationPlans: medicationPlans,
      childLabels: const {'child-1': 'Ana'},
    );
    final created = await medicationPlans.save(_command(requestId: 'create-1'));
    await medicationPlans.save(
      _command(
        requestId: 'update-1',
        planId: created.id,
        expectedVersion: created.currentVersion,
        medicationName: 'Inalador atualizado',
      ),
    );

    final child = await repository.findChild('child-1', actor: repository.defaultActor);
    final medication = child!.medications.single;

    expect(medication.versions, hasLength(1));
    expect(medication.currentVersion.version, 2);
    expect(medication.currentVersion.name, 'Inalador atualizado');
  });
}

MedicationPlanSaveCommand _command({
  required String requestId,
  String? planId,
  int expectedVersion = 0,
  String medicationName = 'Inalador',
}) => MedicationPlanSaveCommand(
  requestId: requestId,
  planId: planId,
  childPersonId: 'child-1',
  expectedVersion: expectedVersion,
  medicationName: medicationName,
  doseAmount: 2,
  doseUnit: 'jatos',
  administrationRoute: 'Inalatória',
  validFrom: DateTime(2026, 8, 27),
  validUntil: DateTime(2026, 9, 27),
  reason: 'Rotina de cuidado',
  scopeKind: 'institution',
  institutionId: 'institution-dev',
  timezone: 'America/Sao_Paulo',
  schedules: [
    MedicationScheduleDraft(
      timeOfDay: '08:30',
      weekdays: const {1, 2, 3, 4, 5},
      timezone: 'America/Sao_Paulo',
    ),
  ],
);
