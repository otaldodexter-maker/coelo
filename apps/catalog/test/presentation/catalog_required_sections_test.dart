import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_catalog/presentation/catalog_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the required product and governance sections from the real index', (
    tester,
  ) async {
    final entries = File('assets/coelo-ui.index.jsonl')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>))
        .toList(growable: false);

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogHomePage(
          entries: entries,
          registry: buildCatalogRegistry(),
          foundations: buildCatalogFoundationRegistry(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final catalogScrollable = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;

    await tester.scrollUntilVisible(find.text('Produtos'), 300, scrollable: catalogScrollable);
    expect(find.text('Produtos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Governança'), 300, scrollable: catalogScrollable);
    expect(find.text('Governança'), findsOneWidget);
    expect(entries.any((entry) => entry.category == 'product'), isTrue);
    expect(entries.any((entry) => entry.category == 'governance'), isTrue);
  });
}
