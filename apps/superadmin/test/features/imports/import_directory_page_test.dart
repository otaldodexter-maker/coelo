import 'package:coelo_superadmin/features/imports/data/fake_import_repository.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('open creation dialog and keep selected scope', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ImportCreationPreset? openedByPreset;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportDirectoryPage(
            repository: FakeImportRepository(),
            onNewImport: (preset) => openedByPreset = preset,
          ),
        ),
      ),
    );
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    await tester.tap(find.byType(CoeloAdminCreateAction));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-preset-units')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(openedByPreset, equals(ImportCreationPreset.units));
  });
}
