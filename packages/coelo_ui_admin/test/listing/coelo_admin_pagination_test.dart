import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows numbered pages and reports page and size selections', (tester) async {
    final selectedPages = <int>[];
    final selectedSizes = <int>[];

    await _pumpPagination(
      tester,
      currentPage: 7,
      totalPages: 20,
      onPageSelected: selectedPages.add,
      onPageSizeChanged: selectedSizes.add,
    );

    expect(find.text('Itens por página'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('…'), findsWidgets);

    await tester.tap(find.byKey(const Key('coelo-pagination-page-8')));
    expect(selectedPages, [8]);

    await tester.tap(find.byKey(const Key('coelo-pagination-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50').last);
    expect(selectedSizes, [50]);
  });

  testWidgets('handles the single-page boundary state', (tester) async {
    await _pumpPagination(tester, currentPage: 1, totalPages: 1);

    expect(find.byKey(const Key('coelo-pagination-page-1')), findsOneWidget);
    expect(_button(tester, 'Anterior').onPressed, isNull);
    expect(_button(tester, 'Próxima').onPressed, isNull);
  });

  testWidgets('disables navigation at page boundaries', (tester) async {
    await _pumpPagination(tester, currentPage: 1, totalPages: 3);
    expect(_button(tester, 'Anterior').onPressed, isNull);
    expect(_button(tester, 'Próxima').onPressed, isNotNull);

    await _pumpPagination(tester, currentPage: 3, totalPages: 3);
    expect(_button(tester, 'Anterior').onPressed, isNotNull);
    expect(_button(tester, 'Próxima').onPressed, isNull);
  });

  testWidgets('does not select the current page and exposes selected semantics', (tester) async {
    final selectedPages = <int>[];
    await _pumpPagination(tester, currentPage: 2, totalPages: 3, onPageSelected: selectedPages.add);

    final currentPage = find.byKey(const Key('coelo-pagination-page-2'));
    expect(_outlinedButton(tester, currentPage).onPressed, isNull);
    expect(tester.getSemantics(currentPage).hasFlag(SemanticsFlag.isSelected), isTrue);

    await tester.tap(currentPage);
    expect(selectedPages, isEmpty);
  });

  testWidgets('uses a smaller page window at compact widths', (tester) async {
    await _pumpPagination(tester, currentPage: 7, totalPages: 20, width: 320);

    expect(find.byKey(const Key('coelo-pagination-page-6')), findsOneWidget);
    expect(find.byKey(const Key('coelo-pagination-page-8')), findsOneWidget);
    expect(find.byKey(const Key('coelo-pagination-page-5')), findsNothing);
    expect(find.text('…'), findsWidgets);
  });

  testWidgets('keeps ellipses non-focusable and without tap semantics', (tester) async {
    await _pumpPagination(tester, currentPage: 7, totalPages: 20);

    final ellipsis = find.text('…').first;
    expect(
      tester.getSemantics(ellipsis).getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(find.descendant(of: ellipsis, matching: find.byType(Focus)), findsNothing);
  });

  testWidgets('activates focused previous and next controls with Enter and Space', (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;
    await _pumpPagination(
      tester,
      currentPage: 2,
      totalPages: 3,
      onPrevious: () => previousCalls += 1,
      onNext: () => nextCalls += 1,
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

  test('rejects invalid pagination configuration', () {
    expect(() => _pagination(currentPage: 0, totalPages: 1), throwsA(isA<AssertionError>()));
    expect(() => _pagination(currentPage: 2, totalPages: 1), throwsA(isA<AssertionError>()));
    expect(() => _pagination(pageSize: 0), throwsA(isA<AssertionError>()));
  });
}

OutlinedButton _button(WidgetTester tester, String label) {
  return _outlinedButton(
    tester,
    find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton)),
  );
}

OutlinedButton _outlinedButton(WidgetTester tester, Finder finder) {
  return tester.widget<OutlinedButton>(finder);
}

Future<void> _pumpPagination(
  WidgetTester tester, {
  required int currentPage,
  required int totalPages,
  double width = 800,
  int pageSize = 10,
  List<int> pageSizeOptions = const [10, 50, 100, 500],
  ValueChanged<int> onPageSelected = _noopPageSelection,
  ValueChanged<int> onPageSizeChanged = _noopPageSelection,
  VoidCallback? onPrevious = _noop,
  VoidCallback? onNext = _noop,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: CoeloAdminPagination(
            currentPage: currentPage,
            totalPages: totalPages,
            pageSize: pageSize,
            pageSizeOptions: pageSizeOptions,
            onPageSelected: onPageSelected,
            onPageSizeChanged: onPageSizeChanged,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
        ),
      ),
    ),
  );
}

CoeloAdminPagination _pagination({
  int currentPage = 1,
  int totalPages = 1,
  int pageSize = 10,
  List<int> pageSizeOptions = const [10, 50, 100],
}) {
  return CoeloAdminPagination(
    currentPage: currentPage,
    totalPages: totalPages,
    pageSize: pageSize,
    pageSizeOptions: pageSizeOptions,
    onPageSelected: _noopPageSelection,
    onPageSizeChanged: _noopPageSelection,
  );
}

void _noop() {}

void _noopPageSelection(int _) {}
