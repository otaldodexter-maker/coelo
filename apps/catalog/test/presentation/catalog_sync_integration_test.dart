import 'dart:async';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_catalog/catalog/catalog_sync_status.dart';
import 'package:coelo_catalog/presentation/catalog_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the catalog available and warns when the sync report cannot load', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage.fromIndexAsset(
          registry: buildCatalogRegistry(),
          entriesLoader: () async => [_entry],
          syncReportLoader: () async => throw const FormatException('invalid report'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollToEntry(tester);
    expect(find.text('CoeloSearchField'), findsOneWidget);
    expect(find.text('Componente implementado; índice e catálogo desatualizados.'), findsOneWidget);
  });

  testWidgets('starts stale without blocking content until synchronization is confirmed', (
    tester,
  ) async {
    final report = Completer<CatalogSyncReport>();
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage.fromIndexAsset(
          registry: buildCatalogRegistry(),
          entriesLoader: () async => [_entry],
          syncReportLoader: () => report.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _scrollToEntry(tester);
    expect(find.text('CoeloSearchField'), findsOneWidget);
    expect(find.text('Componente implementado; índice e catálogo desatualizados.'), findsOneWidget);

    report.complete(const CatalogSyncReport.synchronized());
    await tester.pump();
    await tester.pump();

    expect(find.text('Componente implementado; índice e catálogo desatualizados.'), findsNothing);
  });
}

Future<void> _scrollToEntry(WidgetTester tester) {
  return tester.scrollUntilVisible(
    find.text('CoeloSearchField'),
    80,
    scrollable: find.byType(Scrollable).first,
  );
}

const _entry = CatalogEntry(
  id: 'core.search-field',
  name: 'CoeloSearchField',
  category: 'component',
  status: CatalogStatus.implemented,
  ownerPackage: 'coelo_ui_core',
  consumers: ['superadmin'],
  purpose: 'Busca textual',
  useWhen: 'Buscar',
  doNotUseWhen: 'Selecionar',
  variants: [],
  states: ['enabled'],
  tokens: ['color.primary'],
  accessibility: 'Rótulo',
  publicFile: 'packages/coelo_ui_core/lib/coelo_ui_core.dart',
  tests: [],
  example: "CoeloSearchField(semanticLabel: 'Buscar')",
);
