import 'package:coelo_superadmin/features/activities/data/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates create fields and resets an incompatible unit', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFormOptions();
    final controller = ActivityFormController.create(options);
    addTearDown(controller.dispose);

    expect(controller.validate(), isFalse);
    expect(controller.nameError, 'Informe o nome da atividade.');

    controller.name.text = 'Música';
    controller.selectInstitution('institution-1');
    controller.selectUnit('institution-1-unit-1');
    expect(controller.validate(), isTrue);
    expect(controller.isDirty, isTrue);

    controller.selectInstitution('institution-2');
    expect(controller.selectedUnitId, isNull);
  });

  test('hydrates edit fields and resets the dirty baseline after submit', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFormOptions();
    final detail = await repository.fetchById('activity-1');
    final controller = ActivityFormController.edit(options, detail!);
    addTearDown(controller.dispose);

    expect(controller.name.text, detail.item.name);
    expect(controller.isDirty, isFalse);
    controller.name.text = 'Música atualizada';
    expect(controller.isDirty, isTrue);
    controller.markSubmitted();
    expect(controller.isDirty, isFalse);
  });
}
