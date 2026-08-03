import 'package:coelo_superadmin/features/imports/data/fake_import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers a create card and responsive job cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportDirectoryPage(
            repository: FakeImportRepository(),
            onNewImport: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    await tester.tap(find.byType(CoeloAdminCreateAction));
    expect(opened, isTrue);
  });
}
