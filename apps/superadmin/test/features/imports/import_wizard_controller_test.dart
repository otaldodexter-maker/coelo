import '../../support/import_repository_stub.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_wizard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to the only available import domain', () {
    final controller = ImportWizardController(repository: InMemoryImportRepository());

    expect(controller.entity, ImportEntity.units);
    expect(controller.canConfirm, isFalse);
    controller.dispose();
  });

  test('does not confirm without an authenticated source file', () {
    final controller = ImportWizardController(repository: InMemoryImportRepository());

    controller.confirm();

    expect(controller.job, isNull);
    controller.dispose();
  });

  test('dispose cancels pending polling', () async {
    final controller = ImportWizardController(
      repository: InMemoryImportRepository(),
      stepInterval: const Duration(milliseconds: 20),
    );

    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.job, isNull);
  });
}
