import '../../support/import_repository_stub.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the honest empty state for an authorized empty history', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ImportDirectoryPage(repository: InMemoryImportRepository(), onNewImport: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma importação ainda'), findsOneWidget);
    expect(find.text('Nova importação'), findsOneWidget);
  });

  testWidgets('renders unavailable separately from an authorized empty history', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ImportDirectoryPage(
            repository: const UnavailableImportRepository(),
            onNewImport: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Importações indisponíveis'), findsOneWidget);
  });
}
