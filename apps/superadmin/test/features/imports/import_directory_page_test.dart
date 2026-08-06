import 'package:coelo_superadmin/features/imports/data/fake_import_repository.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> buildImportsPage(
    WidgetTester tester, {
    required Size size,
    required ValueChanged<ImportCreationPreset> onNewImport,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportDirectoryPage(repository: FakeImportRepository(), onNewImport: onNewImport),
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
}
