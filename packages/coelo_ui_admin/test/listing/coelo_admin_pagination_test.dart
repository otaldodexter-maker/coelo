import 'dart:ui' show SemanticsAction, Tristate;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox, RenderWrap;
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
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size-50')));
    await tester.pumpAndSettle();
    expect(selectedPageSize, 50);
  });

  testWidgets('centers the pagination content and wrapped runs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(520, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(
          body: CoeloAdminPagination(
            currentPage: 5,
            totalPages: 10,
            onPrevious: _noop,
            onNext: _noop,
            pageSize: 20,
            pageSizeOptions: [11, 20, 50, 100],
          ),
        ),
      ),
    );

    final content = tester.widget<Wrap>(find.byKey(const Key('coelo-admin-pagination-content')));
    expect(content.alignment, WrapAlignment.center);
  });

  testWidgets('centers every pagination run across the required viewport and theme matrix', (
    tester,
  ) async {
    const widths = [375.0, 768.0, 1024.0, 1440.0];
    final themes = [CoeloTheme.light, CoeloTheme.dark];
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final theme in themes) {
      for (final width in widths) {
        await tester.binding.setSurfaceSize(Size(width, 600));
        await tester.pump();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: CoeloAdminPagination(
                currentPage: 5,
                totalPages: 10,
                onPrevious: _noop,
                onNext: _noop,
                pageSize: 20,
                pageSizeOptions: [11, 20, 50, 100],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: '\${theme.brightness} at \$width px');
        final content = find.byKey(const Key('coelo-admin-pagination-content'));
        expect(tester.widget<Wrap>(content).alignment, WrapAlignment.center);
        final contentCenter = tester.getRect(content).center.dx;

        for (final bounds in _paginationRunBounds(tester)) {
          expect(
            bounds.center.dx,
            moreOrLessEquals(contentCenter, epsilon: 1),
            reason: 'centered run at \$width px',
          );
        }
      }
    }
  });

  testWidgets('uses the approved compact single-select surface', (tester) async {
    var selectedPageSize = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminPagination(
            currentPage: 1,
            totalPages: 2,
            onPrevious: null,
            onNext: _noop,
            pageSize: 20,
            pageSizeOptions: const [11, 20, 50, 100],
            onPageSizeChanged: (value) => selectedPageSize = value,
          ),
        ),
      ),
    );

    final trigger = find.byKey(const Key('coelo-admin-pagination-page-size'));
    expect(find.byType(DropdownButton<int>), findsNothing);
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    final anchor = tester.widget<MenuAnchor>(
      find.byKey(const Key('coelo-admin-pagination-page-size-anchor')),
    );
    final triggerWidth = tester.getSize(trigger).width;
    expect(anchor.crossAxisUnconstrained, isFalse);
    expect(anchor.style!.backgroundColor!.resolve({}), CoeloTheme.light.colorScheme.surface);
    expect(anchor.style!.surfaceTintColor!.resolve({}), Colors.transparent);
    expect(anchor.style!.minimumSize!.resolve({})!.width, triggerWidth);
    expect(anchor.style!.maximumSize!.resolve({})!.width, triggerWidth);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    final selected = tester.widget<MenuItemButton>(
      find.byKey(const Key('coelo-admin-pagination-page-size-20')),
    );
    expect(
      selected.style!.backgroundColor!.resolve({}),
      CoeloTheme.light.colorScheme.primaryContainer,
    );
    final selectedOption = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.selected == true &&
          widget.child is MenuItemButton &&
          widget.child?.key == const Key('coelo-admin-pagination-page-size-20'),
    );
    final unselectedOption = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.selected == false &&
          widget.child is MenuItemButton &&
          widget.child?.key == const Key('coelo-admin-pagination-page-size-50'),
    );
    expect(
      tester.getSemantics(selectedOption).getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(unselectedOption).getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );

    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size-50')));
    await tester.pumpAndSettle();
    expect(selectedPageSize, 50);
  });

  testWidgets('closes the page-size menu with Escape and returns focus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminPagination(
            currentPage: 1,
            totalPages: 2,
            onPrevious: null,
            onNext: _noop,
            pageSize: 20,
            pageSizeOptions: const [11, 20, 50, 100],
            onPageSizeChanged: (_) {},
          ),
        ),
      ),
    );

    final trigger = find.byKey(const Key('coelo-admin-pagination-page-size'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton), findsNothing);
    expect(tester.widget<OutlinedButton>(trigger).focusNode!.hasFocus, isTrue);
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

List<Rect> _paginationRunBounds(WidgetTester tester) {
  final wrap = tester.renderObject<RenderWrap>(
    find.byKey(const Key('coelo-admin-pagination-content')),
  );
  final childBounds = <Rect>[];
  wrap.visitChildren((child) {
    final box = child as RenderBox;
    childBounds.add(box.localToGlobal(Offset.zero) & box.size);
  });
  childBounds.sort((left, right) => left.center.dy.compareTo(right.center.dy));

  final runs = <List<Rect>>[];
  for (final bounds in childBounds) {
    if (runs.isEmpty || (bounds.center.dy - runs.last.first.center.dy).abs() > 1) {
      runs.add([bounds]);
    } else {
      runs.last.add(bounds);
    }
  }

  return [
    for (final run in runs)
      Rect.fromLTRB(
        run.map((bounds) => bounds.left).reduce((left, right) => left < right ? left : right),
        run.map((bounds) => bounds.top).reduce((top, bottom) => top < bottom ? top : bottom),
        run.map((bounds) => bounds.right).reduce((left, right) => left > right ? left : right),
        run.map((bounds) => bounds.bottom).reduce((top, bottom) => top > bottom ? top : bottom),
      ),
  ];
}
