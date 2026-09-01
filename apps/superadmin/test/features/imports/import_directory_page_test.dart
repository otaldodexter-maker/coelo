import '../../support/import_repository_stub.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
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
    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
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
    expect(find.text('Nova importação'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('renders unauthorized alone without toolbar or creation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ImportDirectoryPage(
            repository: const _UnauthorizedImportRepository(),
            onNewImport: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byType(CoeloAdminListingToolbar), findsNothing);
    expect(find.text('Nova importação'), findsNothing);
  });

  testWidgets('search reloads canonically after debounce without a separate action', (
    tester,
  ) async {
    final repository = _QueryImportRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ImportDirectoryPage(repository: repository, onNewImport: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, 'unidades agosto');
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.queries.last.search, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(repository.queries.last.search, 'unidades agosto');
    expect(find.widgetWithText(TextButton, 'Buscar'), findsNothing);
  });

  testWidgets('uses the canonical Institutions pagination footer', (tester) async {
    final repository = InMemoryImportRepository();
    final draft = await repository.createDraft(
      entity: ImportEntity.units,
      strategy: ImportStrategy.createOnly,
    );
    await repository.save(draft);
    await _pumpDirectory(tester, repository: repository);

    expect(find.byType(SuperadminListingPaginationFooter), findsOneWidget);
    expect(find.byKey(const Key('imports-directory-pagination-footer')), findsOneWidget);
    expect(find.byType(CoeloAdminPagination), findsOneWidget);
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

Future<void> _pumpDirectory(WidgetTester tester, {InMemoryImportRepository? repository}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: ImportDirectoryPage(
          repository: repository ?? InMemoryImportRepository(),
          onNewImport: (_) {},
        ),
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

final class _UnauthorizedImportRepository implements ImportRepository {
  const _UnauthorizedImportRepository();

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) =>
      Future.error(const ImportRepositoryUnauthorizedException());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _QueryImportRepository implements ImportRepository {
  final queries = <ImportJobQuery>[];

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) async {
    queries.add(query);
    return const ImportJobPage(items: []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
