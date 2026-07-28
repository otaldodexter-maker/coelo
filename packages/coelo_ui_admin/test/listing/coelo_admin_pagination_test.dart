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

  testWidgets('shows adaptive numbered pages with ellipses around the current page', (
    tester,
  ) async {
    await _pumpPagination(tester, currentPage: 5, totalPages: 10);

    for (final page in [1, 4, 5, 6, 10]) {
      expect(find.text('$page'), findsOneWidget);
    }
    for (final hiddenPage in [2, 3, 7, 8, 9]) {
      expect(find.text('$hiddenPage'), findsNothing);
    }
    expect(find.text('…'), findsNWidgets(2));
  });

  testWidgets('selects a numbered page and changes the accessible page size', (tester) async {
    var selectedPage = 0;
    var selectedPageSize = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminPagination(
            currentPage: 2,
            totalPages: 10,
            onPrevious: _noop,
            onNext: _noop,
            onPageSelected: (page) => selectedPage = page,
            pageSize: 20,
            pageSizeOptions: const [11, 20, 50, 100],
            onPageSizeChanged: (pageSize) => selectedPageSize = pageSize,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-5')));
    expect(selectedPage, 5);
    expect(find.text('Itens por página'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50').last);
    expect(selectedPageSize, 50);
  });

  test('requires page-size options when page size is provided', () {
    expect(
      () => CoeloAdminPagination(
        currentPage: 1,
        totalPages: 1,
        onPrevious: null,
        onNext: null,
        pageSize: 20,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('requires the selected page size to be one of the options while building', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoeloAdminPagination(
          currentPage: 1,
          totalPages: 1,
          onPrevious: null,
          onNext: null,
          pageSize: 20,
          pageSizeOptions: const [11, 50],
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  test('preserves const construction', () {
    const pagination = CoeloAdminPagination(
      currentPage: 1,
      totalPages: 1,
      onPrevious: null,
      onNext: null,
      pageSize: 11,
      pageSizeOptions: [11, 20],
    );

    expect(pagination.pageSize, 11);
  });

  test('requires page size when a page-size callback is provided', () {
    expect(
      () => CoeloAdminPagination(
        currentPage: 1,
        totalPages: 1,
        onPrevious: null,
        onNext: null,
        onPageSizeChanged: (_) {},
      ),
      throwsAssertionError,
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
