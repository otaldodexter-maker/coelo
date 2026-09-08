import 'dart:async';

import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/health_care_fixture_repository.dart';

void main() {
  for (final kind in [
    'medication-create',
    'medication-correct',
    'allergy-create',
    'allergy-inactivate',
    'profile',
  ]) {
    test('late $kind does not reload the previous child after navigation', () async {
      final repository = _MutationRepository();
      final controller = HealthCareController(repository);
      addTearDown(controller.dispose);
      await controller.loadDetail('child-demo-a');
      final mutation = _mutate(kind, controller, controller.detail!);
      await controller.loadDetail('child-demo-b');
      repository.gates.single.complete();
      await mutation;
      expect(controller.detail?.id, 'child-demo-b');
      expect(repository.reads, ['child-demo-a', 'child-demo-b']);
      expect(controller.state, HealthCareLoadState.ready);
    });

    test('$kind still reloads when its original view remains active', () async {
      final repository = _MutationRepository();
      final controller = HealthCareController(repository);
      addTearDown(controller.dispose);
      await controller.loadDetail('child-demo-a');
      final mutation = _mutate(kind, controller, controller.detail!);
      repository.gates.single.complete();
      await mutation;
      expect(controller.detail?.id, 'child-demo-a');
      expect(repository.reads, ['child-demo-a', 'child-demo-a']);
    });
  }

  test(
    'two mutations in one view both refresh even when the first refresh finishes earlier',
    () async {
      final repository = _MutationRepository();
      final controller = HealthCareController(repository);
      addTearDown(controller.dispose);
      await controller.loadDetail('child-demo-a');
      final a = _mutate('profile', controller, controller.detail!);
      final b = _mutate('allergy-create', controller, controller.detail!);
      repository.gates[0].complete();
      await a;
      repository.gates[1].complete();
      await b;
      expect(repository.reads, ['child-demo-a', 'child-demo-a', 'child-demo-a']);
      expect(
        controller.detail!.allergies.any((allergy) => allergy.label == 'New fixture allergy'),
        isTrue,
      );
    },
  );

  test('mutation completion after disposal starts no refresh', () async {
    final repository = _MutationRepository();
    final controller = HealthCareController(repository);
    await controller.loadDetail('child-demo-a');
    final mutation = _mutate('profile', controller, controller.detail!);
    controller.dispose();
    repository.gates.single.complete();
    await mutation;
    expect(repository.reads, ['child-demo-a']);
  });
}

Future<void> _mutate(String kind, HealthCareController controller, HealthCareChild child) {
  final version = child.medications.first.currentVersion;
  return switch (kind) {
    'medication-create' => controller.createMedication(
      HealthMedicationCreateCommand(
        childId: child.id,
        name: 'New fixture medicine',
        dose: version.dose,
        doseUnit: version.doseUnit,
        route: version.route,
        startsAt: version.startsAt,
        endsAt: version.endsAt,
        schedules: version.schedules,
      ),
    ),
    'medication-correct' => controller.correctMedication(
      HealthMedicationCorrectionCommand(
        childId: child.id,
        medicationId: child.medications.first.id,
        name: 'Corrected fixture medicine',
        justification: 'Fixture correction',
      ),
    ),
    'allergy-create' => controller.createAllergy(
      HealthAllergyCreateCommand(
        childId: child.id,
        label: 'New fixture allergy',
        type: HealthCareAllergyType.medication,
      ),
    ),
    'allergy-inactivate' => controller.inactivateAllergy(
      HealthAllergyInactivationCommand(
        childId: child.id,
        allergyId: 'allergy-demo-active',
        justification: 'Fixture review',
      ),
    ),
    _ => controller.updateCareProfile(
      HealthCareProfileUpdateCommand(
        childId: child.id,
        items: [HealthCareProfileItem(catalogItemId: 'asthma')],
        justification: 'Fixture update',
      ),
    ),
  };
}

final class _MutationRepository implements HealthCareRepository {
  final fixture = FixtureHealthCareRepository();
  final gates = <Completer<void>>[];
  final reads = <String>[];

  Future<T> _wait<T>(Future<T> Function() action) async {
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return action();
  }

  @override
  HealthCareActor get defaultActor => fixture.defaultActor;

  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) {
    reads.add(childId);
    return fixture.findChild(childId, actor: actor);
  }

  @override
  Future<HealthMedication> createMedication({
    required String childId,
    required String name,
    required String dose,
    required String doseUnit,
    required String route,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<HealthMedicationSchedule> schedules,
    String? documentName,
    String? documentType,
    required HealthCareActor actor,
  }) => _wait(
    () => fixture.createMedication(
      childId: childId,
      name: name,
      dose: dose,
      doseUnit: doseUnit,
      route: route,
      startsAt: startsAt,
      endsAt: endsAt,
      schedules: schedules,
      documentName: documentName,
      documentType: documentType,
      actor: actor,
    ),
  );

  @override
  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthCareActor actor,
  }) => _wait(
    () => fixture.changeMedicationRelevant(
      childId: childId,
      medicationId: medicationId,
      name: name,
      justification: justification,
      actor: actor,
    ),
  );

  @override
  Future<HealthCareAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthCareAllergyType type,
    required HealthCareActor actor,
  }) =>
      _wait(() => fixture.createAllergy(childId: childId, label: label, type: type, actor: actor));

  @override
  Future<HealthCareAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthCareActor actor,
  }) => _wait(
    () => fixture.deactivateAllergy(
      childId: childId,
      allergyId: allergyId,
      justification: justification,
      actor: actor,
    ),
  );

  @override
  Future<HealthCareAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthCareProfileItem> items,
    required String justification,
    required HealthCareActor actor,
  }) => _wait(
    () => fixture.updateCareProfile(
      childId: childId,
      items: items,
      justification: justification,
      actor: actor,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
