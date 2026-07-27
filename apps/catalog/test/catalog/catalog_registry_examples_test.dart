import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
