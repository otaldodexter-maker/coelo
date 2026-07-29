import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_foundation.dart';
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
    await _pumpFoundation(tester, entries: entries, foundations: foundations, previewWidth: 768);

    const references = [
      (
        code: '403',
        message: 'Você não tem permissão para acessar esta área.',
        action: 'Voltar ao início',
      ),
      (
        code: '404',
        message: 'Não encontramos a página que você procura.',
        action: 'Voltar ao início',
      ),
      (code: '500', message: 'Não foi possível concluir esta ação.', action: 'Tentar novamente'),
      (
        code: '503',
        message: 'O Coelo está temporariamente indisponível.',
        action: 'Tentar novamente',
      ),
    ];

    for (final reference in references) {
      final option = find.byKey(Key('foundation-error-page-option-${reference.code}'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();

      final preview = find.byKey(const Key('foundation-error-page-preview'));
      expect(find.descendant(of: preview, matching: find.text(reference.code)), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.text(reference.message)), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.text(reference.action)), findsOneWidget);
      expect(find.bySemanticsLabel('Erro ${reference.code}. ${reference.message}'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.descendant(of: preview, matching: find.byType(TextButton)))
            .onPressed,
        isNotNull,
      );
    }
  });

  testWidgets('uses adaptive padding, max width and horizontal layout when wide', (tester) async {
    await _pumpFoundation(tester, entries: entries, foundations: foundations, previewWidth: 1024);

    final preview = find.byKey(const Key('foundation-error-page-preview'));
    final scroll = find.descendant(of: preview, matching: find.byType(SingleChildScrollView));
    final contentBox = find.descendant(
      of: scroll,
      matching: find.byWidgetPredicate(
        (widget) => widget is ConstrainedBox && widget.constraints.maxWidth == 720,
      ),
    );

    expect(
      tester.widget<SingleChildScrollView>(scroll).padding,
      const EdgeInsets.symmetric(horizontal: CoeloSpacing.space10, vertical: CoeloSpacing.space8),
    );
    expect(contentBox, findsOneWidget);
    expect(find.descendant(of: preview, matching: find.byType(VerticalDivider)), findsOneWidget);
    expect(find.descendant(of: preview, matching: find.byType(Divider)), findsNothing);
  });

  testWidgets('uses compact padding and vertical layout with text at 200 percent', (tester) async {
    await _pumpFoundation(
      tester,
      entries: entries,
      foundations: foundations,
      previewWidth: 1024,
      textScaler: const TextScaler.linear(2),
    );

    final preview = find.byKey(const Key('foundation-error-page-preview'));
    final scroll = find.descendant(of: preview, matching: find.byType(SingleChildScrollView));

    expect(
      tester.widget<SingleChildScrollView>(scroll).padding,
      const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4, vertical: CoeloSpacing.space8),
    );
    expect(find.descendant(of: preview, matching: find.byType(VerticalDivider)), findsNothing);
    expect(find.descendant(of: preview, matching: find.byType(Divider)), findsOneWidget);
  });
}

Future<void> _pumpFoundation(
  WidgetTester tester, {
  required Map<String, CatalogEntry> entries,
  required Map<String, CatalogFoundation> foundations,
  required double previewWidth,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final entry = entries['pattern.error-pages']!;
  final foundation = foundations['pattern.error-pages']!;

  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        );
      },
      home: CatalogFoundationPage(entry: entry, foundation: foundation, previewWidth: previewWidth),
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
