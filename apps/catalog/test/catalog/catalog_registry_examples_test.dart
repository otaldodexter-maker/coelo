import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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

  testWidgets('multi-select field example uses the public component', (tester) async {
    final example = buildCatalogRegistry()['admin.multi-select-field']!;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: _ExampleHost(example: example)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminMultiSelectField<String>), findsOneWidget);
  });

  testWidgets('date range example uses the shared picker and field', (tester) async {
    final example = buildCatalogRegistry()['core.date-range-picker']!;

    await _pumpExample(tester, example);

    expect(find.byType(CoeloDateRangePicker), findsOneWidget);
    expect(find.byType(CoeloDateRangeField), findsOneWidget);
    expect(example.approvedVariants, containsAll(['open', 'compact', 'field']));
  });

  testWidgets('new package examples use the canonical public components', (tester) async {
    final registry = buildCatalogRegistry();

    await _pumpExample(tester, registry['core.brazilian-phone-input-formatter']!);
    final phoneField = tester.widget<CoeloFormTextField>(find.byType(CoeloFormTextField));
    expect(phoneField.inputFormatters, contains(isA<CoeloBrazilianPhoneInputFormatter>()));

    await _pumpExample(tester, registry['admin.toggle-field']!);
    expect(find.byType(CoeloAdminToggleField), findsOneWidget);

    await _pumpExample(tester, registry['admin.interactive-card']!);
    expect(find.byType(CoeloAdminInteractiveCard), findsOneWidget);

    await _pumpExample(tester, registry['admin.expandable-status-indicator']!);
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsOneWidget);

    await _pumpExample(tester, registry['admin.flyout']!);
    expect(find.byType(CoeloAdminFlyout<String>), findsOneWidget);
  });

  test('keeps approved variants synchronized with the index', () {
    final registry = buildCatalogRegistry();

    expect(registry['core.form-text-field']!.approvedVariants, [
      'single-line',
      'multiline-top-aligned',
      'formatted-input',
    ]);
    expect(registry['core.brazilian-phone-input-formatter']!.approvedVariants, [
      'landline',
      'mobile',
    ]);
    expect(registry['admin.multi-select-field']!.approvedVariants, [
      'searchable',
      'non-searchable',
    ]);
    expect(registry['admin.interactive-card']!.approvedVariants, ['default-card']);
    expect(registry['admin.flyout']!.approvedVariants, ['standard', 'negative-group']);
  });

  test('registers the administrative dialog shell as an implemented component', () {
    final registry = buildCatalogRegistry();

    expect(registry, contains('admin.dialog-shell'));
  });

  testWidgets('builds every implemented package component from the real package registry', (
    tester,
  ) async {
    final entries = File('assets/coelo-ui.index.jsonl')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>))
        .where(
          (entry) =>
              entry.status == CatalogStatus.implemented && entry.publicFile.startsWith('packages/'),
        )
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

Future<void> _pumpExample(WidgetTester tester, CatalogExample example) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(body: _ExampleHost(example: example)),
    ),
  );
  await tester.pumpAndSettle();
}

final class _ExampleHost extends StatelessWidget {
  const _ExampleHost({required this.example});

  final CatalogExample example;

  @override
  Widget build(BuildContext context) => example.builder(context);
}
