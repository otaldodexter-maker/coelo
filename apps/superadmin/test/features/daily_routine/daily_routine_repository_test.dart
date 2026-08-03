import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';

void main() {
  test('feeling catalog exposes five primary and four additional options', () {
    expect(DailyRoutineFeeling.primary, hasLength(5));
    expect(DailyRoutineFeeling.additional, hasLength(4));
    expect(DailyRoutineFeeling.values.map((feeling) => feeling.label), const [
      'Animado',
      'Calmo',
      'Sensível',
      'Irritado',
      'Sonolento',
      'Triste',
      'Desanimado',
      'Distraído',
      'Agitado',
    ]);
  });

  test('mood field is optional and has no initial value', () {
    final field = InMemoryDailyRoutineRepository.seeded().models.first.sections
        .expand((section) => section.fields)
        .singleWhere((field) => field.id == 'mood');

    expect(field.required, isFalse);
    expect(field.initialValue, isNull);
  });

  test('participant feeling can be selected and cleared', () {
    final repository = InMemoryDailyRoutineRepository.seeded();

    repository.setParticipantFeeling('participant-2', DailyRoutineFeeling.sad);
    expect(repository.participantFeeling('participant-2'), DailyRoutineFeeling.sad);

    repository.clearParticipantFeeling('participant-2');
    expect(repository.participantFeeling('participant-2'), isNull);
    expect(repository.participantValues['participant-2'], isNot(contains('mood')));
  });

  test('suggestion stays pending and never changes the approved catalog', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    final catalogLength = DailyRoutineFeeling.values.length;

    repository.suggestFeeling('  Curioso  ', now: DateTime.utc(2026, 8, 3));

    expect(repository.feelingSuggestions.single.text, 'Curioso');
    expect(
      repository.feelingSuggestions.single.status,
      DailyRoutineFeelingSuggestionStatus.pending,
    );
    expect(repository.feelingSuggestions.single.createdAt, DateTime.utc(2026, 8, 3));
    expect(DailyRoutineFeeling.values, hasLength(catalogLength));
  });

  test('owner manages models while read-only actor cannot', () {
    expect(DailyRoutinePermissions.owner.canManage, isTrue);
    expect(DailyRoutinePermissions.readOnly.canManage, isFalse);
  });

  test('activity scope remains contextual to selected groups', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    final model = repository.models.first;
    expect(repository.appliesTo(model.id, groupId: 'group-a', activityId: 'activity-meal'), isTrue);
    expect(
      repository.appliesTo(model.id, groupId: 'group-b', activityId: 'activity-meal'),
      isFalse,
    );
  });

  test('optional update never overwrites the unit version', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    final before = repository.models.firstWhere((model) => model.id == 'unit-model');
    repository.publishInstitutionUpdate(mandatory: false);
    final after = repository.models.firstWhere((model) => model.id == 'unit-model');
    expect(after.version, before.version);
    expect(after.updateAvailable, isTrue);
  });

  test('mandatory change archives conflicts and notifies locally', () {
    final activities = SuperadminActivityController();
    final repository = InMemoryDailyRoutineRepository.seeded(activities: activities);
    repository.publishInstitutionUpdate(mandatory: true);
    expect(repository.archivedConflicts, isNotEmpty);
    expect(activities.activities.single.kind, SuperadminActivityKind.routineUpdate);
  });

  test('new versions do not mutate historical snapshots', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    final snapshot = repository.snapshots.single;
    repository.publishInstitutionUpdate(mandatory: true);
    expect(repository.snapshots.single.version, snapshot.version);
    expect(repository.snapshots.single.values, snapshot.values);
  });

  test('bulk application preserves participant exceptions', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    repository.setParticipantValue('participant-1', 'mood', 'Tranquilo');
    repository.applyToParticipants(
      const {'participant-1', 'participant-2'},
      fieldId: 'mood',
      value: 'Animado',
      overwrite: false,
    );
    expect(repository.participantValues['participant-1']!['mood'], 'Tranquilo');
    expect(repository.participantValues['participant-2']!['mood'], 'Animado');
  });
}
