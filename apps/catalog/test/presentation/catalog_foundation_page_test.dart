import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_foundation.dart';
import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_catalog/presentation/catalog_foundation_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entries = _entriesById();
  final foundations = buildCatalogFoundationRegistry();

  for (final themeCase in [
    (name: 'light', theme: CoeloTheme.light),
    (name: 'dark', theme: CoeloTheme.dark),
  ]) {
    testWidgets('renders all migrated guidance in ${themeCase.name}', (tester) async {
      for (final foundation in foundations.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: themeCase.theme,
            home: CatalogFoundationPage(entry: entries[foundation.id]!, foundation: foundation),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(Key('catalog-foundation-content-${foundation.id}')),
          findsOneWidget,
          reason: foundation.id,
        );
        expect(tester.takeException(), isNull, reason: foundation.id);
      }
    });
  }

  testWidgets('renders package components instead of fake catalog copies', (tester) async {
    await _pumpFoundation(tester, entries, foundations, 'pattern.approved-superadmin-surfaces');
    expect(find.byType(CoeloAdminInteractiveCard), findsOneWidget);
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsOneWidget);

    await _pumpFoundation(tester, entries, foundations, 'pattern.action-hierarchy');
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byKey(const Key('action-hierarchy-primary')), findsOneWidget);
    expect(find.byKey(const Key('action-hierarchy-secondary')), findsOneWidget);
    expect(find.byKey(const Key('action-hierarchy-tertiary')), findsOneWidget);

    await _pumpFoundation(tester, entries, foundations, 'pattern.form-controls');
    expect(find.byType(CoeloFormTextField), findsNWidgets(2));

    await _pumpFoundation(tester, entries, foundations, 'pattern.selection-controls');
    expect(find.byType(CoeloAdminMultiSelectFilter<String>), findsOneWidget);
    expect(find.byType(CoeloAdminSingleSelectField<String>), findsOneWidget);

    await _pumpFoundation(tester, entries, foundations, 'pattern.status-feedback');
    expect(find.byType(CoeloStatusChip), findsOneWidget);
    expect(find.byType(CoeloStatePanel), findsOneWidget);
  });

  testWidgets('documents the canonical registration and editing form contract', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpFoundation(tester, entries, foundations, 'pattern.form-controls');

    expect(find.byKey(const Key('foundation-form-neutral-surface')), findsOneWidget);
    expect(find.byKey(const Key('foundation-form-responsive-grid')), findsOneWidget);
    expect(find.byKey(const Key('foundation-form-action-footer')), findsOneWidget);
    expect(find.textContaining('Instituições é a referência canônica'), findsOneWidget);
    expect(find.textContaining('375, 768, 1024 e 1440'), findsOneWidget);
    expect(find.textContaining('texto a 200%'), findsAtLeastNWidgets(1));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: Builder(builder: foundations['pattern.form-controls']!.builder),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final footer = tester.getRect(find.byKey(const Key('foundation-form-action-footer-row')));
    final exit = tester.getRect(find.widgetWithText(OutlinedButton, 'Sair sem salvar'));
    final continueEditing = tester.getRect(find.widgetWithText(FilledButton, 'Continuar editando'));
    expect(exit.left, footer.left);
    expect(continueEditing.right, footer.right);
    expect(exit.right, lessThan(continueEditing.left));
  });

  testWidgets('stacks screen footer primary before the negative action on compact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: Builder(builder: foundations['pattern.form-controls']!.builder)),
      ),
    );
    await tester.pumpAndSettle();

    final primary = tester.getRect(find.widgetWithText(FilledButton, 'Continuar editando'));
    final exit = tester.getRect(find.widgetWithText(OutlinedButton, 'Sair sem salvar'));
    expect(primary.width, exit.width);
    expect(primary.bottom, lessThan(exit.top));
  });

  testWidgets('keeps migrated action, form, selection and theme guidance interactive', (
    tester,
  ) async {
    await _pumpFoundation(tester, entries, foundations, 'pattern.action-hierarchy');
    final action = find.text('Criar instituição');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Ativações no exemplo: 1'), findsOneWidget);

    await _pumpFoundation(tester, entries, foundations, 'pattern.form-controls');
    final field = find.descendant(
      of: find.byKey(const Key('foundation-real-core-form-text-field')),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Coelo');
    await tester.pump();
    expect(find.text('Coelo'), findsOneWidget);

    await _pumpFoundation(tester, entries, foundations, 'pattern.selection-controls');
    final selection = find.text('Ativa');
    await tester.ensureVisible(selection);
    await tester.tap(selection);
    await tester.pumpAndSettle();
    expect(find.text('Em análise'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _pumpFoundation(tester, entries, foundations, 'foundation.themes');
    final dark = find.text('Dark');
    await tester.ensureVisible(dark);
    await tester.tap(dark);
    await tester.pumpAndSettle();
    final previewContext = tester.element(find.byKey(const Key('foundation-theme-preview')));
    expect(Theme.of(previewContext).brightness, Brightness.dark);
  });
}

Future<void> _pumpFoundation(
  WidgetTester tester,
  Map<String, CatalogEntry> entries,
  Map<String, CatalogFoundation> foundations,
  String id,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: CatalogFoundationPage(entry: entries[id]!, foundation: foundations[id]!),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, CatalogEntry> _entriesById() {
  final entries = File('assets/coelo-ui.index.jsonl')
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>));
  return {for (final entry in entries) entry.id: entry};
}
