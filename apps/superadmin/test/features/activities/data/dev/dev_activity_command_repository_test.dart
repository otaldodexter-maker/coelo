import 'package:coelo_superadmin/features/activities/data/dev/dev_activity_command_repository.dart';
import 'package:coelo_superadmin/features/activities/data/dev/dev_activity_session_store.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save is stateful and preserves pedagogical versions and justification', () async {
    final store = DevActivitySessionStore.empty();
    final repository = DevActivityCommandRepository(store: store);

    final result = await repository.save(_command('request-1'));
    final detail = store.detail(result.activityId)!;

    expect(result.status, ActivityStatus.active);
    expect(detail.item.managementVersion, 1);
    expect(detail.pedagogicalConfiguration?['enabled'], isTrue);
    expect(detail.pedagogicalConfiguration?['expected_version'], 4);
    expect(detail.pedagogicalConfiguration?['change_justification'], 'Nova matriz pedagógica');
  });

  test('equivalent replay returns the result and divergent pedagogy conflicts', () async {
    final repository = DevActivityCommandRepository(store: DevActivitySessionStore.empty());
    final first = await repository.save(_command('request-1'));
    final replay = await repository.save(_command('request-1'));

    expect(replay.activityId, first.activityId);
    expect(replay.managementVersion, first.managementVersion);
    await expectLater(
      repository.save(
        _command(
          'request-1',
          pedagogicalConfiguration: const {'enabled': true, 'model': 'grade_only'},
        ),
      ),
      throwsA(isA<ActivityCommandConflictException>()),
    );
  });

  test('edit enforces optimistic management version', () async {
    final store = DevActivitySessionStore.empty();
    final repository = DevActivityCommandRepository(store: store);
    final created = await repository.save(_command('create'));

    await expectLater(
      repository.save(_command('stale', activityId: created.activityId, expectedVersion: 0)),
      throwsA(isA<ActivityCommandConflictException>()),
    );
  });

  test('failure and unauthorized modes stay fail-closed', () async {
    await expectLater(
      DevActivityCommandRepository(
        store: DevActivitySessionStore.failure(),
      ).save(_command('failure')),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    await expectLater(
      DevActivityCommandRepository(
        store: DevActivitySessionStore.unauthorized(),
      ).save(_command('unauthorized')),
      throwsA(isA<ActivityCommandUnauthorizedException>()),
    );
  });
}

ActivitySaveCommand _command(
  String requestId, {
  String? activityId,
  int expectedVersion = 0,
  Map<String, Object?> pedagogicalConfiguration = const {'enabled': true, 'model': 'gradeOnly'},
}) => ActivitySaveCommand(
  requestId: requestId,
  intent: ActivityCommandIntent.publish,
  activityId: activityId,
  expectedVersion: expectedVersion,
  pedagogicalConfiguration: pedagogicalConfiguration,
  expectedAssessmentVersion: 3,
  assessmentChangeJustification: 'Nova matriz pedagógica',
  name: 'Robótica',
  description: 'Atividade local',
  taxonomyId: 'taxonomy-sciences',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: const {'institution-1-unit-1'},
  groupIds: const {'institution-1-group-1'},
  assignments: const [],
  identity: const ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'RO',
    color: '#D63C00',
    icon: 'activity',
  ),
);
