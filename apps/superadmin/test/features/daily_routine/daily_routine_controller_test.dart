import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wizard has four steps and excludes participants and preview', () {
    expect(DailyRoutineFormStep.values, const [
      DailyRoutineFormStep.identity,
      DailyRoutineFormStep.scope,
      DailyRoutineFormStep.sectionsAndFields,
      DailyRoutineFormStep.reviewAndActivation,
    ]);
  });

  test('new draft preserves the selected entry type', () {
    final repository = InMemoryDailyRoutineRepository.empty();
    final controller = DailyRoutineFormController(
      repository: repository,
      permissions: DailyRoutinePermissions.owner,
      entryType: DailyRoutineEntryType.routine,
    );

    controller.updateName('Rotina da manhã');
    final saved = controller.save(activate: false);

    expect(saved, isNotNull);
    expect(saved!.type, DailyRoutineEntryType.routine);
    expect(repository.models.single.type, DailyRoutineEntryType.routine);
  });

  test('editing preserves the source entry type', () {
    final repository = InMemoryDailyRoutineRepository.empty();
    repository.save(
      const DailyRoutineModel(
        id: 'routine',
        name: 'Rotina',
        description: '',
        origin: DailyRoutineOrigin.institution,
        version: 1,
        status: DailyRoutineStatus.draft,
        sections: [],
        type: DailyRoutineEntryType.routine,
      ),
    );
    final controller = DailyRoutineFormController(
      repository: repository,
      permissions: DailyRoutinePermissions.owner,
      modelId: 'routine',
    );

    expect(controller.entryType, DailyRoutineEntryType.routine);
  });

  test('choice initial value must be one of the current options', () {
    final controller = DailyRoutineFormController(
      repository: InMemoryDailyRoutineRepository.empty(),
      permissions: DailyRoutinePermissions.owner,
    );
    final sectionId = controller.upsertSection(name: 'Chegada');

    expect(
      () => controller.upsertField(
        sectionId: sectionId,
        label: 'Humor',
        type: DailyRoutineFieldType.singleChoice,
        required: false,
        options: const ['Calmo', 'Animado'],
        initialValue: 'Removido',
      ),
      throwsArgumentError,
    );
  });

  test('multiple choice rejects removed initial options', () {
    final controller = DailyRoutineFormController(
      repository: InMemoryDailyRoutineRepository.empty(),
      permissions: DailyRoutinePermissions.owner,
    );
    final sectionId = controller.upsertSection(name: 'Alimentação');

    expect(
      () => controller.upsertField(
        sectionId: sectionId,
        label: 'Refeições',
        type: DailyRoutineFieldType.multipleChoice,
        required: false,
        options: const ['Café', 'Almoço'],
        initialValue: const ['Café', 'Lanche'],
      ),
      throwsArgumentError,
    );
  });

  test('Coelo-provided model is exposed as read-only by the form controller', () {
    final repository = InMemoryDailyRoutineRepository.seeded();
    final controller = DailyRoutineFormController(
      repository: repository,
      permissions: DailyRoutinePermissions.owner,
      modelId: 'institution-model',
    );

    expect(controller.isCoeloProvided, isTrue);
  });
}
