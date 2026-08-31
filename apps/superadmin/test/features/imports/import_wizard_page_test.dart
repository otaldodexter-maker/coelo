import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_wizard_controller.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_wizard_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/import_repository_stub.dart';

void main() {
  testWidgets('shows the eight approved import entities in a responsive catalog', (tester) async {
    final controller = ImportWizardController(repository: InMemoryImportRepository());

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ImportWizardPage(controller: controller, onFinished: () {}),
      ),
    );
    await tester.pump();

    for (final label in const [
      'Instituições',
      'Unidades',
      'Pessoas',
      'Grupos e turmas',
      'Atividades',
      'Planos de medicação',
      'Cardápios',
      'Formulários',
    ]) {
      await tester.ensureVisible(find.text(label));
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('reports unavailable entities honestly without invoking persistence', (tester) async {
    final repository = _TrackingImportRepository();
    final controller = ImportWizardController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ImportWizardPage(controller: controller, onFinished: () {}),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Formulários'));
    await tester.tap(find.text('Formulários'));
    await tester.pump();

    expect(controller.entity, ImportEntity.forms);
    expect(find.textContaining('Execução indisponível nesta etapa'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('import-wizard-primary'))).onPressed,
      isNull,
    );
    expect(repository.createDraftCalls, 0);
  });

  testWidgets('rendering and invalid advance never create a remote draft', (tester) async {
    final repository = _TrackingImportRepository();
    final controller = ImportWizardController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ImportWizardPage(controller: controller, onFinished: () {}),
      ),
    );
    await tester.pump();

    expect(repository.createDraftCalls, 0);

    await tester.tap(find.byKey(const Key('import-wizard-primary')));
    await tester.pump();
    expect(controller.currentStep, 1);
    expect(repository.createDraftCalls, 0);

    await tester.tap(find.byKey(const Key('import-wizard-primary')));
    await tester.pump();
    expect(controller.currentStep, 1);
    expect(repository.createDraftCalls, 0);
    expect(find.text('Selecione um arquivo CSV ou XLSX antes de continuar.'), findsOneWidget);
  });
}

final class _TrackingImportRepository implements ImportRepository {
  final _delegate = InMemoryImportRepository();
  var createDraftCalls = 0;

  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) {
    createDraftCalls++;
    return _delegate.createDraft(entity: entity, strategy: strategy, context: context, file: file);
  }

  @override
  Future<List<ImportJob>> fetchJobs() => _delegate.fetchJobs();

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) => _delegate.fetchPage(query);

  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) =>
      _delegate.save(job, sourceFile: sourceFile);

  @override
  Future<ImportJob> update(ImportJob job) => _delegate.update(job);
}
