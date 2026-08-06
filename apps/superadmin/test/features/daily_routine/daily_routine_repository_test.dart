import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';

void main() {
  test('seed exposes the five immutable Coelo models and a separate routine', () {
    final repository = InMemoryDailyRoutineRepository.seeded();

    expect(
      repository.models
          .where((item) => item.type == DailyRoutineEntryType.model)
          .map((item) => item.name),
      containsAll(const [
        'Modelo Berçário',
        'Modelo Fundamental',
        'Modelo Médio',
        'Modelo Pré',
        'Modelo Maternal',
      ]),
    );
    expect(
      repository.models.where((item) => item.type == DailyRoutineEntryType.model),
      everyElement(isA<DailyRoutineModel>().having((item) => item.isCoeloProvided, 'locked', true)),
    );
    expect(
      repository.models.where((item) => item.type == DailyRoutineEntryType.routine),
      isNotEmpty,
    );
  });

  test('Coelo model cannot be overwritten or removed in the repository', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    final model = repository.models.firstWhere((item) => item.isCoeloProvided);

    expect(() => repository.save(model.copyWith(name: 'Alterado')), throwsStateError);
    expect(() => repository.remove(model.id), throwsStateError);
  });

  test('duplicate keeps type, unlocks copy and increments normalized suffix', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    final source = repository.models.firstWhere((item) => item.name == 'Modelo Berçário');

    final second = repository.duplicate(source.id);
    final third = repository.duplicate(second.id);

    expect(second.name, 'Modelo Berçário (2)');
    expect(third.name, 'Modelo Berçário (3)');
    expect(second.type, DailyRoutineEntryType.model);
    expect(third.type, DailyRoutineEntryType.model);
    expect(second.isCoeloProvided, isFalse);
  });

  test('duplicate routine preserves the routine type', () {
    final repository = InMemoryDailyRoutineRepository.seeded();

    final copy = repository.duplicate('unit-model');

    expect(copy.type, DailyRoutineEntryType.routine);
    expect(copy.name, 'Rotina Unidade Centro (2)');
    expect(copy.isCoeloProvided, isFalse);
  });
  test('remove followed by duplicate or create keeps generated ids unique', () {
    InMemoryDailyRoutineRepository repositoryWithGap() {
      final repository = InMemoryDailyRoutineRepository.empty();
      for (final entry in const [
        DailyRoutineModel(
          id: 'source',
          name: 'Modelo fonte',
          description: '',
          origin: DailyRoutineOrigin.institution,
          version: 1,
          status: DailyRoutineStatus.draft,
          sections: [],
        ),
        DailyRoutineModel(
          id: 'daily-routine-2',
          name: 'Removível',
          description: '',
          origin: DailyRoutineOrigin.institution,
          version: 1,
          status: DailyRoutineStatus.draft,
          sections: [],
        ),
        DailyRoutineModel(
          id: 'daily-routine-3',
          name: 'Existente',
          description: '',
          origin: DailyRoutineOrigin.institution,
          version: 1,
          status: DailyRoutineStatus.draft,
          sections: [],
        ),
      ]) {
        repository.save(entry);
      }
      repository.remove('daily-routine-2');
      return repository;
    }

    final duplicateRepository = repositoryWithGap();
    final duplicate = duplicateRepository.duplicate('source');
    expect(duplicate.id, isNot('daily-routine-3'));
    expect(
      duplicateRepository.models.map((item) => item.id).toSet(),
      hasLength(duplicateRepository.models.length),
    );

    final routineRepository = repositoryWithGap();
    final routine = routineRepository.createRoutineFromModel('source');
    expect(routine.id, isNot('daily-routine-3'));
    expect(
      routineRepository.models.map((item) => item.id).toSet(),
      hasLength(routineRepository.models.length),
    );
  });
  test('routine created from model is prefilled and keeps source link', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    final source = repository.models.firstWhere((item) => item.name == 'Modelo Maternal');

    final routine = repository.createRoutineFromModel(source.id);

    expect(routine.type, DailyRoutineEntryType.routine);
    expect(routine.baseModelId, source.id);
    expect(routine.sections, source.sections);
    expect(routine.name, 'Modelo Maternal');
    expect(routine.isCoeloProvided, isFalse);
  });

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

  test('each selected group keeps its own contextual activities', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    const model = DailyRoutineModel(
      id: 'multi-group-model',
      name: 'Rotina compartilhada',
      description: '',
      origin: DailyRoutineOrigin.institution,
      version: 1,
      status: DailyRoutineStatus.draft,
      sections: [],
      scopes: [
        DailyRoutineScope(groupId: 'group-a', activityIds: {'activity-meal'}),
        DailyRoutineScope(groupId: 'group-b', activityIds: {'activity-nap'}),
      ],
    );
    repository.save(model);

    expect(repository.appliesTo(model.id, groupId: 'group-a', activityId: 'activity-meal'), isTrue);
    expect(repository.appliesTo(model.id, groupId: 'group-b', activityId: 'activity-nap'), isTrue);
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

  test('choice initial value must remain among registered options', () {
    final repository = InMemoryDailyRoutineRepository.empty();
    const invalid = DailyRoutineModel(
      id: 'invalid-choice',
      name: 'Modelo inválido',
      description: '',
      origin: DailyRoutineOrigin.institution,
      version: 1,
      status: DailyRoutineStatus.draft,
      sections: [
        DailyRoutineSection(
          id: 'section',
          name: 'Seção',
          fields: [
            DailyRoutineField(
              id: 'choice',
              label: 'Escolha',
              type: DailyRoutineFieldType.singleChoice,
              options: ['A', 'B'],
              initialValue: 'C',
            ),
          ],
        ),
      ],
    );

    expect(() => repository.save(invalid), throwsArgumentError);
  });
}
