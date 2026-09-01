import 'dart:typed_data';

import 'package:coelo_superadmin/features/imports/data/development_import_repository.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job_page.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_wizard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offers coherent paginated and filterable development history', () async {
    final repository = DevelopmentImportRepository();

    final first = await repository.fetchPage(const ImportJobQuery(pageSize: 25));
    final second = await repository.fetchPage(
      ImportJobQuery(pageSize: 25, cursor: first.nextCursor),
    );
    final forms = await repository.fetchPage(
      const ImportJobQuery(entities: <ImportEntity>{ImportEntity.forms}),
    );
    final searched = await repository.fetchPage(const ImportJobQuery(search: 'Carolina Mendes'));

    expect(first.items, hasLength(25));
    expect(first.nextCursor, isNotNull);
    expect(second.items, hasLength(9));
    expect(second.nextCursor, isNull);
    expect(forms.items, isNotEmpty);
    expect(
      forms.items,
      everyElement(predicate<ImportJob>((job) => job.entity == ImportEntity.forms)),
    );
    expect(searched.items, isNotEmpty);
    expect(
      searched.items,
      everyElement(predicate<ImportJob>((job) => job.actor == 'Carolina Mendes')),
    );
    expect(first.items.first.displayFileName, isNot('modelo-importacao.csv'));
  });

  test('simulates every development wizard entity through completion', () async {
    final repository = DevelopmentImportRepository(now: () => DateTime.utc(2026, 9, 1));
    expect(repository.supportedImportEntities, containsAll(ImportWizardDevelopmentEntities.values));

    final draft = await repository.createDraft(
      entity: ImportEntity.forms,
      strategy: ImportStrategy.createAndUpdate,
      context: 'Comunidade escolar',
    );
    final source = ImportSourceFile(
      name: 'formularios-comunidade.csv',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      mimeType: 'text/csv',
    );
    final saved = await repository.save(draft, sourceFile: source);
    final processing = await repository.update(saved);
    final completed = await repository.update(processing);

    expect(draft.mapping, containsPair('titulo', 'Título'));
    expect(draft.previewRows.first.values['nome'], 'Pesquisa anual das famílias');
    expect(saved.displayFileName, 'formularios-comunidade.csv');
    expect(saved.status, ImportJobStatus.inProgress);
    expect(processing.progress, 65);
    expect(completed.status, ImportJobStatus.completed);
    expect(completed.progress, 100);
    expect((await repository.fetchJobs()).first.id, completed.id);
  });

  test('development capability unlocks non-unit wizard execution', () {
    final controller = ImportWizardController(
      repository: DevelopmentImportRepository(),
      initialEntity: ImportEntity.forms,
    );
    addTearDown(controller.dispose);

    expect(controller.executionAvailable, isTrue);
    controller.selectEntity(ImportEntity.mealPlans);
    expect(controller.executionAvailable, isTrue);
  });
}
