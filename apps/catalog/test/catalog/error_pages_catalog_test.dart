import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_catalog/presentation/catalog_foundation_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entries = _entriesById();
  final foundations = buildCatalogFoundationRegistry();

  test('indexes the approved fullscreen error-page pattern', () {
    final entry = entries['pattern.error-pages']!;

    expect(entry.status, CatalogStatus.approved);
    expect(entry.variants, ['403', '404', '500', '503']);
    expect(entry.consumers, contains('superadmin'));
    expect(entry.tokens, containsAll(['color.primary-container', 'color.on-primary-container']));
  });

  testWidgets('renders and switches the four canonical error references', (tester) async {
    final entry = entries['pattern.error-pages']!;
    final foundation = foundations['pattern.error-pages']!;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: CatalogFoundationPage(entry: entry, foundation: foundation, previewWidth: 768),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foundation-error-page-preview')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('foundation-error-page-preview')),
        matching: find.text('403'),
      ),
      findsOneWidget,
    );
    expect(find.text('Você não tem permissão para acessar esta área.'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Erro 403. Você não tem permissão para acessar esta área.'),
      findsOneWidget,
    );

    final option503 = find.byKey(const Key('foundation-error-page-option-503'));
    await tester.ensureVisible(option503);
    await tester.tap(option503);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('foundation-error-page-preview')),
        matching: find.text('503'),
      ),
      findsOneWidget,
    );
    expect(find.text('O Coelo está temporariamente indisponível.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

Map<String, CatalogEntry> _entriesById() {
  final entries = File('assets/coelo-ui.index.jsonl')
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>));
  return {for (final entry in entries) entry.id: entry};
}
