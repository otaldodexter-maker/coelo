import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/app/dev_menu/development_activity_fixture_repository.dart';
import 'package:coelo_superadmin/features/activities/data/dev/dev_activity_command_repository.dart';
import 'package:coelo_superadmin/features/activities/data/dev/dev_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/data/dev/dev_activity_session_store.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development catalog exposes thirty activities and twelve templates', () async {
    final repository = DevelopmentActivityFixtureRepository();
    final page = await repository.fetchPage(ActivityDirectoryQuery(pageSize: 100));
    final options = await repository.fetchFormOptions(institutionId: 'demo-institution-aurora');

    expect(page.totalCount, 30);
    expect(options.templates, hasLength(12));
  });

  test('development catalog search returns matching fake activities', () async {
    final repository = DevelopmentActivityFixtureRepository();

    final result = await repository.fetchPage(ActivityDirectoryQuery(search: 'robótica'));
    final missing = await repository.fetchPage(ActivityDirectoryQuery(search: 'não existe'));

    expect(result.items, isNotEmpty);
    expect(
      result.items.every(
        (item) =>
            item.name.toLowerCase().contains('robótica') ||
            (item.description ?? '').toLowerCase().contains('robótica'),
      ),
      isTrue,
    );
    expect(missing.items, isEmpty);
  });

  test('one DEV session exposes create edit and reload through the directory', () async {
    final store = DevActivitySessionStore.empty();
    final commands = DevActivityCommandRepository(store: store);
    final directory = DevActivityDirectoryRepository(store: store);
    final created = await commands.save(_command('create'));

    expect((await directory.fetchById(created.activityId))?.item.name, 'Robótica');
    final edited = await commands.save(
      _command(
        'edit',
        activityId: created.activityId,
        expectedVersion: created.managementVersion,
        name: 'Robótica avançada',
      ),
    );
    final reloaded = await directory.fetchById(edited.activityId);
    expect(reloaded?.item.name, 'Robótica avançada');
    expect(reloaded?.item.managementVersion, 2);
    expect(
      (await directory.fetchPage(ActivityDirectoryQuery(search: 'avançada'))).items.single.id,
      edited.activityId,
    );
  });

  test('Profile About DEV repository persists only canonical domain models', () async {
    final repository = DevelopmentActivityProfileAboutRepository();
    final empty = await repository.load(institutionId: 'institution-1', activityId: 'activity-1');
    final page = empty.replaceField(
      const ProfileAboutField(
        key: ProfileAboutFieldKey.objective,
        value: 'Desenvolver criatividade',
      ),
    );
    final saved = await repository.save(
      page: page,
      institutionId: 'institution-1',
      activityId: 'activity-1',
      requestId: 'about-request-1',
    );
    final reloaded = await repository.load(
      institutionId: 'institution-1',
      activityId: 'activity-1',
    );

    expect(saved.version, 1);
    expect(reloaded.fields.single.value, 'Desenvolver criatividade');
    expect(reloaded.subject.type, ProfileAboutSubjectType.activity);
  });

  test('a new session does not leak prior in-memory writes', () async {
    final first = DevActivitySessionStore.empty();
    final created = await DevActivityCommandRepository(store: first).save(_command('create'));
    expect(
      await DevActivityDirectoryRepository(store: first).fetchById(created.activityId),
      isNotNull,
    );
    expect(
      await DevActivityDirectoryRepository(
        store: DevActivitySessionStore.empty(),
      ).fetchById(created.activityId),
      isNull,
    );
  });
}

ActivitySaveCommand _command(
  String requestId, {
  String? activityId,
  int expectedVersion = 0,
  String name = 'Robótica',
}) => ActivitySaveCommand(
  requestId: requestId,
  intent: ActivityCommandIntent.publish,
  activityId: activityId,
  expectedVersion: expectedVersion,
  name: name,
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
