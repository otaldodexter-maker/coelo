import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('form field example documents the authentication contract', (tester) async {
    final example = buildCatalogRegistry()['core.form-text-field']!;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: _ExampleHost(example: example)),
      ),
    );

    final field = tester.widget<CoeloFormTextField>(find.byType(CoeloFormTextField));
    expect(field.textInputAction, TextInputAction.next);
    expect(field.autofillHints, contains(AutofillHints.email));
  });

  testWidgets('pagination example exposes the approved page-size selector', (tester) async {
    final example = buildCatalogRegistry()['admin.pagination']!;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: _ExampleHost(example: example)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
    expect(find.text('Itens por página'), findsOneWidget);
  });

  testWidgets('builds every implemented index component from the real package registry', (
    tester,
  ) async {
    final entries = File('assets/coelo-ui.index.jsonl')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>))
        .where((entry) => entry.status == CatalogStatus.implemented)
        .toList(growable: false);
    final registry = buildCatalogRegistry();

    expect(registry.keys, unorderedEquals(entries.map((entry) => entry.id)));
    for (final entry in entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: CoeloBreakpoints.large.minWidth,
                child: _ExampleHost(example: registry[entry.id]!),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.id);
    }
  });
}

final class _ExampleHost extends StatelessWidget {
  const _ExampleHost({required this.example});

  final CatalogExample example;

  @override
  Widget build(BuildContext context) => example.builder(context);
}
