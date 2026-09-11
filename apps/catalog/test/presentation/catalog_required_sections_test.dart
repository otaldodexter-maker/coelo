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
    expect(tester.takeException(), isNull);

    // O composto de diretorio (admin.directory) tambem rola dentro da lista e
    // captura o gesto de arrastar no centro da viewport: rolar pela posicao.
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first,
        )
        .position;
    Future<void> scrollTo(String label) async {
      for (var step = 0; step < 200 && find.text(label).evaluate().isEmpty; step++) {
        position.jumpTo((position.pixels + 300).clamp(0, position.maxScrollExtent));
        await tester.pump();
      }
      await Scrollable.ensureVisible(tester.element(find.text(label)));
      await tester.pumpAndSettle();
    }

    await scrollTo('Produtos');
    expect(find.text('Produtos'), findsOneWidget);
    await scrollTo('Governança');
    expect(find.text('Governança'), findsOneWidget);
    expect(entries.any((entry) => entry.category == 'product'), isTrue);
    expect(entries.any((entry) => entry.category == 'governance'), isTrue);
  });
}
