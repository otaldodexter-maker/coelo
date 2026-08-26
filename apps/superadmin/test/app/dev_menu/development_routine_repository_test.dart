import 'package:coelo_superadmin/app/dev_menu/development_routine_repository.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content supports list, create and edit with instance reset', () async {
    final repository = DevelopmentRoutineRepository.content();
    final createdId = await repository.saveModel(
      _model('new-model', 'Rotina criada'),
      requestId: '1',
    );
    expect((await repository.fetchModel(createdId)).name, 'Rotina criada');

    await repository.saveModel(_model(createdId, 'Rotina editada'), requestId: '2');
    expect((await repository.fetchModel(createdId)).name, 'Rotina editada');
    expect(
      (await repository.fetchPage(
        const RoutineDirectoryQuery(kind: RoutineEntryKind.model),
      )).items.first.name,
      'Rotina editada',
    );

    final reset = DevelopmentRoutineRepository.content();
    await expectLater(
      reset.fetchModel(createdId),
      throwsA(
        isA<RoutineRepositoryException>().having(
          (error) => error.kind,
          'kind',
          RoutineRepositoryFailureKind.notFound,
        ),
      ),
    );
  });

  test('launch publish persists in the same repository', () async {
    final repository = DevelopmentRoutineRepository.content();
    final launch = RoutineLaunch(
      id: 'new-launch',
      applicationId: 'application-1',
      applicationRevisionId: 'revision-1',
      institutionId: 'institution-1',
      unitId: 'unit-1',
      groupId: 'group-1',
      authorMembershipId: 'membership-1',
      serviceDate: DateTime(2026, 8, 24),
      status: RoutineLaunchStatus.draft,
      expectedVersion: 1,
    );
    final id = await repository.saveLaunchDraft(launch, requestId: 'launch-1');
    await repository.publishLaunch(launchId: id, expectedVersion: 1, requestId: 'launch-2');
    expect((await repository.fetchLaunch(id)).status, RoutineLaunchStatus.published);
  });

  test('empty, failure and unauthorized scenarios are deterministic', () async {
    expect(
      (await DevelopmentRoutineRepository.empty().fetchPage(
        const RoutineDirectoryQuery(kind: RoutineEntryKind.model),
      )).items,
      isEmpty,
    );
    await expectLater(
      DevelopmentRoutineRepository.failure().fetchPage(
        const RoutineDirectoryQuery(kind: RoutineEntryKind.model),
      ),
      throwsA(
        isA<RoutineRepositoryException>().having(
          (error) => error.kind,
          'kind',
          RoutineRepositoryFailureKind.unavailable,
        ),
      ),
    );
    await expectLater(
      DevelopmentRoutineRepository.unauthorized().fetchPage(
        const RoutineDirectoryQuery(kind: RoutineEntryKind.model),
      ),
      throwsA(
        isA<RoutineRepositoryException>().having(
          (error) => error.kind,
          'kind',
          RoutineRepositoryFailureKind.unauthorized,
        ),
      ),
    );
  });
}

RoutineModel _model(String id, String name) => RoutineModel(
  id: id,
  name: name,
  description: 'Fixture local',
  version: 1,
  status: RoutineModelStatus.active,
  sections: const [],
  expectedVersion: 1,
  institutionId: 'institution-1',
  canManage: true,
);
