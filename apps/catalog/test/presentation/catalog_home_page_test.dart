import 'dart:async';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_catalog/presentation/catalog_home_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filters, navigates by keyboard, and changes theme and viewport', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        darkTheme: CoeloTheme.dark,
        home: CatalogHomePage(entries: _entries, registry: buildCatalogRegistry()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(EditableText), 'search');
    await tester.pump();
    expect(find.text('CoeloSearchField'), findsOneWidget);
    expect(find.text('CoeloAdminPagination'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Compartilhados'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filtrar contexto'));
    await tester.pumpAndSettle();
    expect(find.text('Compartilhados'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-theme-toggle')));
    await tester.pump();
    expect(find.byTooltip('Usar tema claro'), findsOneWidget);
    for (final width in [375, 768, 1024, 1440]) {
      await tester.tap(find.byKey(Key('catalog-viewport-$width')));
      await tester.pump();
      await tester.tap(find.text('CoeloSearchField'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('catalog-preview-frame'))).width, width);
      expect(
        Theme.of(tester.element(find.byKey(const Key('catalog-preview-frame')))).brightness,
        Brightness.dark,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('keeps catalog controls usable at 200 percent text and reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2), disableAnimations: true),
          child: CatalogHomePage(entries: _entries, registry: buildCatalogRegistry()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('catalog-search')), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Movimento reduzido'),
      find.byType(Scrollable).first,
      const Offset(0, -100),
    );
    expect(find.byKey(const Key('catalog-motion-status')), findsOneWidget);
    expect(find.text('Movimento reduzido'), findsOneWidget);
  });

  testWidgets('groups and opens indexed foundation guidance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage(
          entries: [_foundationEntry, ..._entries],
          registry: buildCatalogRegistry(),
          foundations: buildCatalogFoundationRegistry(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Fundamentos'), findsOneWidget);
    await tester.tap(find.text('Cores semânticas'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('catalog-foundation-content-foundation.semantic-colors')),
      findsOneWidget,
    );
  });

  testWidgets('reloads when supplied entries change', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage(entries: [_entries.first], registry: buildCatalogRegistry()),
      ),
    );
    await tester.pump();
    expect(find.text('CoeloSearchField'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage(entries: [_entries.last], registry: buildCatalogRegistry()),
      ),
    );
    await tester.pump();

    expect(find.text('CoeloAdminPagination'), findsOneWidget);
    expect(find.text('CoeloSearchField'), findsNothing);
  });

  testWidgets('shows loading, retryable errors, and ignores an older loader result', (
    tester,
  ) async {
    final older = Completer<List<CatalogEntry>>();
    final newer = Completer<List<CatalogEntry>>();
    var calls = 0;
    Future<List<CatalogEntry>> load() => ++calls == 1 ? older.future : newer.future;

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage.fromIndexAsset(registry: buildCatalogRegistry(), entriesLoader: load),
      ),
    );
    await tester.pump();
    expect(find.text('Carregando catálogo'), findsOneWidget);

    older.completeError(StateError('asset failed'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Não foi possível carregar o catálogo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-retry-load')));
    await tester.pump();
    newer.complete([_entries.last]);
    await tester.pump();
    await tester.pump();
    expect(find.text('CoeloAdminPagination'), findsOneWidget);
  });

  testWidgets('ignores a stale loader completion after its loader changes', (tester) async {
    final older = Completer<List<CatalogEntry>>();
    final newer = Completer<List<CatalogEntry>>();

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage.fromIndexAsset(
          registry: buildCatalogRegistry(),
          entriesLoader: () => older.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage.fromIndexAsset(
          registry: buildCatalogRegistry(),
          entriesLoader: () => newer.future,
        ),
      ),
    );
    await tester.pump();

    newer.complete([_entries.last]);
    await tester.pump();
    await tester.pump();
    older.complete([_entries.first]);
    await tester.pump();
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('CoeloAdminPagination'),
      CoeloSpacing.space20,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CoeloAdminPagination'), findsOneWidget);
    expect(find.text('CoeloSearchField'), findsNothing);
  });
}

final _entries = [
  CatalogEntry(
    id: 'core.search-field',
    name: 'CoeloSearchField',
    category: 'component',
    status: CatalogStatus.implemented,
    ownerPackage: 'coelo_ui_core',
    consumers: const ['superadmin'],
    purpose: 'Busca textual',
    useWhen: 'Buscar',
    doNotUseWhen: 'Selecionar',
    variants: const [],
    states: const ['enabled'],
    tokens: const ['color.primary'],
    accessibility: 'Rotulo',
    publicFile: 'packages/coelo_ui_core/lib/coelo_ui_core.dart',
    tests: const [],
    example: "CoeloSearchField(semanticLabel: 'Buscar')",
  ),
  CatalogEntry(
    id: 'admin.pagination',
    name: 'CoeloAdminPagination',
    category: 'component',
    status: CatalogStatus.implemented,
    ownerPackage: 'coelo_ui_admin',
    consumers: const ['superadmin'],
    purpose: 'Paginacao',
    useWhen: 'Paginar',
    doNotUseWhen: 'Carregamento continuo',
    variants: const [],
    states: const ['enabled'],
    tokens: const ['size.touch-min'],
    accessibility: 'Teclado',
    publicFile: 'packages/coelo_ui_admin/lib/coelo_ui_admin.dart',
    tests: const [],
    example: 'CoeloAdminPagination()',
  ),
];

final _foundationEntry = CatalogEntry(
  id: 'foundation.semantic-colors',
  name: 'Cores semânticas',
  category: 'foundation',
  status: CatalogStatus.approved,
  ownerPackage: 'coelo_tokens',
  consumers: const ['shared'],
  purpose: 'Papéis de cor',
  useWhen: 'Usar tokens',
  doNotUseWhen: 'HEX local',
  variants: const [],
  states: const ['light', 'dark'],
  tokens: const ['color.primary'],
  accessibility: 'Contraste',
  publicFile: 'packages/coelo_tokens/lib/coelo_tokens.dart',
  tests: const [],
  example: 'Theme.of(context).colorScheme',
);
