import 'package:coelo_superadmin/features/activities/data/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_controller.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'draft requires name institution and one unit while completion also requires a group',
    () async {
      final options = await FakeActivityDirectoryRepository().fetchFormOptions();
      final controller = ActivityFormController.create(options);
      addTearDown(controller.dispose);

      expect(controller.validateDraft(), isFalse);
      controller.name.text = 'Robótica';
      controller.selectInstitution('institution-1');
      controller.toggleUnit('institution-1-unit-1');

      expect(controller.validateDraft(), isTrue);
      expect(controller.validateCompletion(), isFalse);

      controller.toggleGroup('institution-1-group-1');
      expect(controller.validateCompletion(), isTrue);
    },
  );

  test('category suggestions are chained and Other keeps a custom value', () async {
    final options = await FakeActivityDirectoryRepository().fetchFormOptions();
    final controller = ActivityFormController.create(options);
    addTearDown(controller.dispose);

    controller.selectCategory(ActivityCategory.languages);
    expect(controller.activitySuggestions, ['Português', 'Inglês', 'Outro']);
    controller.selectActivitySuggestion('Outro');
    controller.otherActivity.text = 'Espanhol';

    expect(controller.activityLabel, 'Espanhol');
  });

  test('unit changes prune groups locations and professional assignments', () async {
    final options = await FakeActivityDirectoryRepository().fetchFormOptions();
    final controller = ActivityFormController.create(options);
    addTearDown(controller.dispose);
    controller.selectInstitution('institution-1');
    controller.toggleUnit('institution-1-unit-1');
    controller.toggleGroup('institution-1-group-1');
    controller.selectLocation('institution-1-unit-1-location-1');
    controller.toggleProfessional('institution-1-group-1', 'professional-1');

    expect(controller.assignments.single.permissions.happens, isTrue);
    expect(controller.assignments.single.permissions.now, isTrue);
    expect(controller.assignments.single.permissions.moments, isTrue);
    expect(controller.assignments.single.permissions.chat, isTrue);

    controller.toggleUnit('institution-1-unit-1');
    expect(controller.selectedGroupIds, isEmpty);
    expect(controller.selectedLocationId, isNull);
    expect(controller.assignments, isEmpty);
  });

  test('edit keeps institution fixed and preserves fixed governance', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFormOptions();
    final detail = await repository.fetchById('activity-3');
    final controller = ActivityFormController.edit(options, detail!);
    addTearDown(controller.dispose);

    expect(controller.institutionLocked, isTrue);
    expect(controller.governance, ActivityGovernance.fixed);
    final institution = controller.selectedInstitutionId;
    controller.selectInstitution('institution-2');
    expect(controller.selectedInstitutionId, institution);
  });

  test('edit hydrates the complete presentation draft without replacing relationships', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFormOptions();
    final detail = await repository.fetchById('activity-3');
    final initialDraft = ActivityFormDraft(
      name: detail!.item.name,
      description: detail.item.description ?? '',
      category: ActivityCategory.exactSciences,
      activityLabel: 'Rob\u00f3tica',
      governance: detail.item.governance,
      institutionId: detail.item.institutionId,
      unitIds: {'institution-3-unit-2'},
      groupIds: {'institution-3-group-2'},
      assignments: const [
        ActivityProfessionalAssignment(
          groupId: 'institution-3-group-2',
          professionalId: 'professional-2',
          permissions: ActivityProfessionalPermissions(chat: false),
        ),
      ],
      imageName: 'robotica.png',
    );

    final controller = ActivityFormController.edit(options, detail, initialDraft: initialDraft);
    addTearDown(controller.dispose);

    expect(controller.category, ActivityCategory.exactSciences);
    expect(controller.activityLabel, 'Rob\u00f3tica');
    expect(controller.selectedUnitIds, initialDraft.unitIds);
    expect(controller.selectedGroupIds, initialDraft.groupIds);
    expect(controller.assignments.single.permissions.chat, isFalse);
    expect(controller.imageName, 'robotica.png');
    expect(controller.isDirty, isFalse);
  });
}
