import '../../support/import_repository_stub.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> buildImportsPage(
    WidgetTester tester, {
    required Size size,
    required ValueChanged<ImportCreationPreset> onNewImport,
    ImportRepository? repository,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ImportDirectoryPage(
            repository: repository ?? InMemoryImportRepository(),
            onNewImport: onNewImport,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('delegates the page heading to the operational shell', (tester) async {
    await buildImportsPage(tester, size: const Size(1280, 900), onNewImport: (_) {});

    expect(find.text('Importações'), findsNothing);
    expect(find.text('Histórico de importações para auditoria operacional.'), findsNothing);
  });

  testWidgets('open creation dialog and keep selected scope', (tester) async {
    ImportCreationPreset? openedByPreset;
    await buildImportsPage(
      tester,
      size: const Size(375, 800),
      onNewImport: (preset) => openedByPreset = preset,
    );

    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    await tester.tap(find.byType(CoeloAdminCreateAction));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-new-dialog')), findsOneWidget);
    expect(find.text('Escolha o caminho de origem para iniciar a importação.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-preset-units')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(openedByPreset, equals(ImportCreationPreset.units));
  });

  testWidgets('renders empty state and creates import preset flow on desktop', (tester) async {
    ImportCreationPreset? openedByPreset;

    await buildImportsPage(
      tester,
      size: const Size(1280, 900),
      onNewImport: (preset) => openedByPreset = preset,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sem resultados'), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);

    await tester.tap(find.byType(CoeloAdminCreateAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import-preset-institutions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(openedByPreset, equals(ImportCreationPreset.institutions));
  });

  testWidgets('adapts mobile/tablet scaffold and keeps list context', (tester) async {
    await buildImportsPage(tester, size: const Size(390, 844), onNewImport: (_) {});

    expect(tester.takeException(), isNull);
    expect(find.text('Sem resultados'), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
  });

  testWidgets('uses operational metrics instead of institution status tabs', (tester) async {
    final repository = InMemoryImportRepository();
    final activeDraft = await repository.createDraft(
      entity: ImportEntity.people,
      strategy: ImportStrategy.createOnly,
    );
    await repository.save(
      activeDraft.copyWith(
        status: ImportJobStatus.inProgress,
        progress: 40,
        result: const ImportResult(rejected: 2),
      ),
    );
    await buildImportsPage(
      tester,
      size: const Size(1280, 900),
      repository: repository,
      onNewImport: (_) {},
    );
    expect(find.text('Ativos'), findsNothing);
    expect(find.text('Em Implantação'), findsNothing);
    expect(find.text('Inativos'), findsNothing);
    expect(find.byKey(const Key('import-metric-total')), findsOneWidget);
    expect(find.byKey(const Key('import-metric-in-progress')), findsOneWidget);
    expect(find.byKey(const Key('import-metric-rejected')), findsOneWidget);
    expect(find.byKey(const Key('import-directory-surface')), findsOneWidget);
    final metricSurface = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('import-metric-total')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = metricSurface.decoration as BoxDecoration;
    final colors = Theme.of(tester.element(find.byType(ImportDirectoryPage))).colorScheme;
    expect(decoration.color, colors.surface);
  });

  testWidgets('paginates long import histories', (tester) async {
    final repository = InMemoryImportRepository();
    for (var index = 0; index < 9; index++) {
      final draft = await repository.createDraft(
        entity: ImportEntity.people,
        strategy: ImportStrategy.createOnly,
        context: 'Contexto $index',
      );
      await repository.save(draft);
    }
    await buildImportsPage(
      tester,
      size: const Size(1280, 900),
      repository: repository,
      onNewImport: (_) {},
    );
    expect(find.byType(CoeloAdminPagination), findsOneWidget);
  });
  testWidgets('renders an honest unavailable state when the import service is unavailable', (
    tester,
  ) async {
    await buildImportsPage(
      tester,
      size: const Size(1280, 900),
      repository: const UnavailableImportRepository(),
      onNewImport: (_) {},
    );

    expect(find.text('Importações indisponíveis'), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
  });
}
