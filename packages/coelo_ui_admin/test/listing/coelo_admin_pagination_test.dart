import 'dart:ui' show SemanticsAction;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disables previous on first page and next on last page', (tester) async {
    await _pumpPagination(tester, currentPage: 1, totalPages: 3);
    expect(_button(tester, 'Anterior').onPressed, isNull);
    expect(_button(tester, 'Próxima').onPressed, isNotNull);
    expect(find.text('Página 1 de 3'), findsOneWidget);

    await _pumpPagination(tester, currentPage: 3, totalPages: 3);
    expect(_button(tester, 'Anterior').onPressed, isNotNull);
    expect(_button(tester, 'Próxima').onPressed, isNull);
  });

  testWidgets('honors null callbacks and exposes semantic labels', (tester) async {
    await _pumpPagination(tester, currentPage: 2, totalPages: 3, onPrevious: null, onNext: null);

    expect(_button(tester, 'Anterior').onPressed, isNull);
    expect(_button(tester, 'Próxima').onPressed, isNull);
    expect(tester.getSemantics(find.text('Anterior')).label, contains('Página anterior'));
    expect(tester.getSemantics(find.text('Próxima')).label, contains('Próxima página'));
    expect(
      tester.getSemantics(find.text('Anterior')).getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(
      tester.getSemantics(find.text('Próxima')).getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
  });

  testWidgets('activates focused controls with Enter and Space', (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;
    await _pumpPagination(
      tester,
      currentPage: 2,
      totalPages: 3,
      onPrevious: () => previousCalls += 1,
      onNext: () => nextCalls += 1,
    );

    expect(
      tester.getSemantics(find.text('Anterior')).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester.getSemantics(find.text('Próxima')).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(find.text('Anterior'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.text('Próxima'));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(previousCalls, 2);
    expect(nextCalls, 2);
  });

  testWidgets('keeps the approved public widget stateless', (tester) async {
    await _pumpPagination(tester, currentPage: 1, totalPages: 1);

    expect(
      tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)),
      isA<StatelessWidget>(),
    );
  });
}

OutlinedButton _button(WidgetTester tester, String label) {
  return tester.widget<OutlinedButton>(
    find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton)),
  );
}

Future<void> _pumpPagination(
  WidgetTester tester, {
  required int currentPage,
  required int totalPages,
  VoidCallback? onPrevious = _noop,
  VoidCallback? onNext = _noop,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: CoeloAdminPagination(
          currentPage: currentPage,
          totalPages: totalPages,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ),
    ),
  );
}

void _noop() {}
