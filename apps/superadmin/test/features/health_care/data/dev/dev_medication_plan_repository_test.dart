import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replays identical request globally and rejects request id payload collisions', () async {
    final repository = DevMedicationPlanRepository();

    final created = await repository.save(_command(requestId: 'request-global'));
    final replayed = await repository.save(_command(requestId: 'request-global'));

    expect(replayed, same(created));
    expect((await repository.fetchPage(const MedicationPlanQuery())).total, 1);
    await expectLater(
      repository.save(_command(requestId: 'request-global', medicationName: 'Payload diferente')),
      throwsA(isA<MedicationPlanConflictException>()),
    );
    expect((await repository.fetchPage(const MedicationPlanQuery())).total, 1);

    await repository.save(_command(requestId: 'request-new-intent'));
    expect((await repository.fetchPage(const MedicationPlanQuery())).total, 2);
  });

  test('keeps expected version and not found checks for new request ids', () async {
    final repository = DevMedicationPlanRepository();
    final created = await repository.save(_command(requestId: 'request-create'));

    await expectLater(
      repository.save(
        _command(requestId: 'request-stale-update', planId: created.id, expectedVersion: 0),
      ),
      throwsA(isA<MedicationPlanConflictException>()),
    );
    await expectLater(
      repository.save(
        _command(requestId: 'request-missing', planId: 'missing', expectedVersion: 1),
      ),
      throwsA(isA<MedicationPlanNotFoundException>()),
    );
  });

  test('serializes concurrent updates against the same expected version', () async {
    final repository = DevMedicationPlanRepository();
    final created = await repository.save(_command(requestId: 'request-create'));

    Future<Object> capture(Future<MedicationPlanDetail> operation) async {
      try {
        return await operation;
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([
      capture(
        repository.save(
          _command(
            requestId: 'request-update-a',
            planId: created.id,
            expectedVersion: 1,
            medicationName: 'Plano A',
          ),
        ),
      ),
      capture(
        repository.save(
          _command(
            requestId: 'request-update-b',
            planId: created.id,
            expectedVersion: 1,
            medicationName: 'Plano B',
          ),
        ),
      ),
    ]);

    expect(results.whereType<MedicationPlanDetail>(), hasLength(1));
    expect(results.whereType<MedicationPlanConflictException>(), hasLength(1));
    expect((await repository.fetchDetail(created.id)).currentVersion, 2);
  });

  test('rejects concurrent payloads that reuse one request id', () async {
    final repository = DevMedicationPlanRepository();

    Future<Object> capture(Future<MedicationPlanDetail> operation) async {
      try {
        return await operation;
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([
      capture(repository.save(_command(requestId: 'shared-request', medicationName: 'Plano A'))),
      capture(repository.save(_command(requestId: 'shared-request', medicationName: 'Plano B'))),
    ]);

    expect(results.whereType<MedicationPlanDetail>(), hasLength(1));
    expect(results.whereType<MedicationPlanConflictException>(), hasLength(1));
    expect((await repository.fetchPage(const MedicationPlanQuery())).total, 1);
  });

  test('supports create, detail, update and reset for dev plans', () async {
    final repository = DevMedicationPlanRepository();
    final command = MedicationPlanSaveCommand(
      requestId: 'request-1',
      childPersonId: 'child-1',
      expectedVersion: 0,
      medicationName: 'Inalador',
      doseAmount: 2,
      doseUnit: 'jatos',
      administrationRoute: 'Inalatória',
      validFrom: DateTime(2026, 1, 1),
      reason: 'Rotina',
      scopeKind: 'institution',
      timezone: 'America/Sao_Paulo',
      schedules: [
        MedicationScheduleDraft(
          timeOfDay: '08:00',
          weekdays: {1, 2, 3, 4, 5},
          timezone: 'America/Sao_Paulo',
        ),
      ],
    );
    final created = await repository.save(command);
    expect((await repository.fetchDetail(created.id)).medicationName, 'Inalador');
    final updated = await repository.save(
      MedicationPlanSaveCommand(
        requestId: 'request-2',
        planId: created.id,
        childPersonId: 'child-1',
        expectedVersion: 1,
        medicationName: 'Inalador novo',
        doseAmount: 1,
        doseUnit: 'jato',
        administrationRoute: 'Inalatória',
        validFrom: DateTime(2026, 1, 1),
        reason: 'Ajuste',
        scopeKind: 'institution',
        timezone: 'America/Sao_Paulo',
        schedules: command.schedules,
      ),
    );
    expect(updated.currentVersion, 2);
    repository.resetSession();
    expect((await repository.fetchPage(const MedicationPlanQuery())).items, isEmpty);
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
  validFrom: DateTime(2026, 1, 1),
  reason: 'Rotina',
  scopeKind: 'institution',
  timezone: 'America/Sao_Paulo',
  schedules: [
    MedicationScheduleDraft(
      timeOfDay: '08:00',
      weekdays: {1, 2, 3, 4, 5},
      timezone: 'America/Sao_Paulo',
    ),
  ],
);
