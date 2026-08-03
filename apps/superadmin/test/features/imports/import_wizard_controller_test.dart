import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/imports/data/fake_import_repository.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_wizard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates deterministic previews and conflicts for every entity', () {
    final repository = FakeImportRepository();
    for (final entity in ImportEntity.values) {
      final draft = repository.createDraft(entity: entity, strategy: ImportStrategy.createOnly);
      expect(draft.previewRows, hasLength(8));
      expect(draft.mapping, isNotEmpty);
      expect(draft.conflicts, isNotEmpty);
    }
  });

  test('completion records one audit event and all progress milestones', () async {
    final activity = SuperadminActivityController();
    final store = SuperadminPrototypeStore(activityController: activity);
    final controller = ImportWizardController(
      repository: FakeImportRepository(),
      store: store,
      stepInterval: Duration.zero,
    );
    controller.selectEntity(ImportEntity.internalUsers);
    controller.selectFile(ImportFileFixture.xlsx);
    controller.selectStrategy(ImportStrategy.createAndUpdate);
    controller.confirm();
    for (var index = 0; index < 8; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(controller.job!.progress, 100);
    expect(controller.job!.result.updated, greaterThan(0));
    expect(
      activity.activities.map((item) => item.progress),
      containsAll(<int?>[0, 25, 55, 80, 100]),
    );
    expect(store.auditEvents, hasLength(1));
    controller.dispose();
  });

  test('dispose cancels pending progress timer', () async {
    final controller = ImportWizardController(
      repository: FakeImportRepository(),
      store: SuperadminPrototypeStore(activityController: SuperadminActivityController()),
      stepInterval: const Duration(milliseconds: 20),
    );
    controller.confirm();
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.job!.progress, 0);
  });
}
