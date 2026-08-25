import '../../support/import_repository_stub.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('renders the seven presets with one negative cancel action', (tester) async {
    await _pumpDirectory(tester);

    await tester.tap(find.byType(CoeloAdminCreateAction));
    await tester.pumpAndSettle();

    for (final preset in ImportCreationPreset.values) {
      expect(find.text(preset.label), findsOneWidget);
    }

    final cancelFinder = find.widgetWithText(FilledButton, 'Cancelar');
    final cancel = tester.widget<FilledButton>(cancelFinder);
    final colors = Theme.of(tester.element(cancelFinder)).colorScheme;
    expect(cancel.style?.backgroundColor?.resolve({}), colors.errorContainer);
    expect(cancel.style?.foregroundColor?.resolve({}), colors.error);
    expect(find.text('Fechar'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('coelo-admin-dialog-footer')),
        matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('X and Escape close the dialog and restore focus to its opener', (tester) async {
    await _pumpDirectory(tester);
    final opener = find.byType(CoeloAdminCreateAction);

    await tester.tap(opener);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import-new-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-new-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import-new-dialog')), findsNothing);
    _expectFocusInside(opener);

    await tester.tap(opener);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import-new-dialog')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import-new-dialog')), findsNothing);
    _expectFocusInside(opener);
  });
}

Future<void> _pumpDirectory(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: ImportDirectoryPage(repository: InMemoryImportRepository(), onNewImport: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectFocusInside(Finder ancestor) {
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  expect(focusedContext, isNotNull);
  final focusedElement = find.byElementPredicate((element) => identical(element, focusedContext));
  expect(find.descendant(of: ancestor, matching: focusedElement), findsOneWidget);
}
