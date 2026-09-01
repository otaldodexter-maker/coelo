import 'package:coelo_superadmin/app/dev_menu/development_access_health_fixture_catalog.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content exposes 32 coherent plans linked to catalog children', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final repository = DevMedicationPlanRepository.content(catalog: catalog);

    final first = await repository.fetchPage(const MedicationPlanQuery(pageSize: 11));
    final third = await repository.fetchPage(const MedicationPlanQuery(page: 2, pageSize: 11));
    final all = await repository.fetchPage(const MedicationPlanQuery(pageSize: 100));

    expect(first.total, 32);
    expect(first.items, hasLength(11));
    expect(third.items, hasLength(10));
    expect(
      all.items.map((item) => item.childPersonId),
      everyElement(isIn(catalog.children.map((item) => item.id))),
    );
    expect(all.items.map((item) => item.medicationName).toSet(), hasLength(5));
  });

  test('content adapter preserves child labels, search and reset', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final repository = DevMedicationPlanRepository.content(catalog: catalog);
    final adapter = DevMedicationPlanHealthCareRepository.content(
      medicationPlans: repository,
      catalog: catalog,
    );
    final target = catalog.medicationPlans[7];
    final child = catalog.children.singleWhere((item) => item.id == target.childId);

    final search = await adapter.fetchDirectory(
      HealthCareDirectoryQuery(search: child.name, pageSize: 100),
      actor: adapter.defaultActor,
    );
    final detail = await adapter.findChild(child.id, actor: adapter.defaultActor);
    await repository.save(_command(requestId: 'fixture-create', childPersonId: child.id));
    expect((await repository.fetchPage(const MedicationPlanQuery(pageSize: 100))).total, 33);
    repository.resetSession();

    expect(search.items.map((item) => item.id), contains(child.id));
    expect(detail?.displayName, child.name);
    expect(detail?.medications, isNotEmpty);
    expect((await repository.fetchPage(const MedicationPlanQuery(pageSize: 100))).total, 32);
  });

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
  String childPersonId = 'child-1',
}) => MedicationPlanSaveCommand(
  requestId: requestId,
  planId: planId,
  childPersonId: childPersonId,
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
