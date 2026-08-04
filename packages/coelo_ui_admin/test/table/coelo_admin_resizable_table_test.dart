import 'dart:ui' show SemanticsAction, Tristate;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the natural table width when columns are narrower than the viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: CoeloAdminResizableTable<TestRow>(
              items: const [TestRow('row-1', 'Alpha', 'Ativa')],
              rowKey: (row) => row.id,
              pinnedColumn: _nameColumn,
              columns: [_statusColumn],
              headerHeight: 56,
              rowHeight: 64,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Card)).width, 340);
    expect(
      tester.getCenter(find.byType(Card)).dx,
      closeTo(tester.getCenter(find.byType(CoeloAdminResizableTable<TestRow>)).dx, 0.01),
    );
  });

  testWidgets('centers natural width and keeps the scrollbar across responsive widths', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [300.0, 375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 600));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: CoeloAdminResizableTable<TestRow>(
              items: const [TestRow('row-1', 'Alpha', 'Ativa')],
              rowKey: (row) => row.id,
              pinnedColumn: _nameColumn,
              columns: const [_statusColumn],
              headerHeight: 56,
              rowHeight: 64,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final table = find.byType(CoeloAdminResizableTable<TestRow>);
      final card = find.byType(Card);
      final scrollbar = find.byType(Scrollbar);
      expect(tester.getSize(card).width, width < 340 ? width : 340, reason: 'viewport $width');
      expect(
        tester.getCenter(card).dx,
        closeTo(tester.getCenter(table).dx, 0.01),
        reason: 'viewport $width',
      );
      expect(
        tester.getSize(scrollbar).width,
        tester.getSize(card).width,
        reason: 'viewport $width',
      );
      expect(
        tester.getTopLeft(scrollbar).dx,
        closeTo(tester.getTopLeft(card).dx, 0.01),
        reason: 'viewport $width',
      );
    }
  });

  testWidgets('keeps a pinned duplicate over a horizontally scrollable table', (tester) async {
    await _pumpTable(tester);

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('coelo-admin-table-scroll')),
    );
    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));

    expect(scroll.scrollDirection, Axis.horizontal);
    expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
    expect(scrollbar.thumbVisibility, isTrue);
    expect(scrollbar.trackVisibility, isTrue);
    expect(
      find.ancestor(
        of: find.byKey(const Key('coelo-admin-table-pinned-column')),
        matching: find.byType(Scrollbar),
      ),
      findsOneWidget,
    );
    expect(find.byType(Card), findsOneWidget);
    expect(tester.widget<Card>(find.byType(Card)).clipBehavior, Clip.antiAlias);
    expect(
      find.descendant(
        of: find.byKey(const Key('coelo-admin-table-pinned-column')),
        matching: find.text('Alpha'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('coelo-admin-table-row-background-row-1'))).height,
      65,
    );
    expect(
      tester.getSize(find.byKey(const Key('coelo-admin-table-pinned-row-background-row-1'))).height,
      65,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('coelo-admin-table-pinned-row-background-row-1'))).dy,
      tester.getTopLeft(find.byKey(const Key('coelo-admin-table-row-background-row-1'))).dy,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byKey(const Key('row-1'))));
    await tester.pumpAndSettle();
    expect(
      _decorationColor(tester, const Key('coelo-admin-table-pinned-row-background-row-1')),
      CoeloColorSchemes.light.primaryContainer,
    );
  });

  testWidgets('keeps an idle main row background transparent', (tester) async {
    await _pumpTable(tester);

    final row = tester.widget<Container>(
      find.byKey(const Key('coelo-admin-table-row-background-row-1')),
    );

    expect((row.decoration! as BoxDecoration).color, isNull);
  });

  testWidgets('aligns pinned and main rows in a wide overflowing table', (tester) async {
    final columns = List.generate(
      16,
      (index) => CoeloAdminTableColumn<TestRow>(
        id: 'column-$index',
        label: 'Coluna $index',
        initialWidth: 180,
        minWidth: 120,
        maxWidth: 240,
        cellBuilder: _statusCell,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 1096,
            child: CoeloAdminResizableTable<TestRow>(
              items: const [TestRow('wide-row', 'Alpha', 'Ativa')],
              rowKey: (row) => row.id,
              pinnedColumn: _nameColumn,
              columns: columns,
              headerHeight: 56,
              rowHeight: 64,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.byKey(const Key('coelo-admin-table-pinned-row-background-wide-row')))
          .dy,
      tester.getTopLeft(find.byKey(const Key('coelo-admin-table-row-background-wide-row'))).dy,
    );
  });

  testWidgets('aligns headers and cells and keeps row keys stable', (tester) async {
    await _pumpTable(tester);

    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 160);
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-cell-name-row-1'))).width, 160);
    expect(find.byKey(const Key('row-1')), findsOneWidget);

    await _pumpTable(tester, rows: const [TestRow('row-1', 'Alpha atualizada', 'Ativa')]);

    expect(find.byKey(const Key('row-1')), findsOneWidget);
    expect(find.text('Alpha atualizada'), findsNWidgets(2));
  });

  testWidgets('keeps state attached to row identity when rows reorder', (tester) async {
    final rows = ValueNotifier<List<TestRow>>(const [
      TestRow('row-1', 'Alpha', 'Ativa'),
      TestRow('row-2', 'Beta', 'Pendente'),
    ]);
    addTearDown(rows.dispose);
    await _pumpTable(tester, rowsListenable: rows, pinnedColumn: _statefulNameColumn);
    expect(find.text('row-1:Alpha:0'), findsNWidgets(2));
    expect(find.text('row-2:Beta:0'), findsNWidgets(2));
    await tester.tap(find.text('row-1:Alpha:0').first);
    await tester.pump();
    expect(find.text('row-1:Alpha:1'), findsOneWidget);

    rows.value = const [TestRow('row-2', 'Beta', 'Pendente'), TestRow('row-1', 'Alpha', 'Ativa')];
    await tester.pumpAndSettle();

    expect(find.text('row-1:Alpha:1'), findsOneWidget);
    expect(find.text('row-1:Alpha:0'), findsOneWidget);
    expect(find.text('row-2:Beta:0'), findsNWidgets(2));
  });

  testWidgets('synchronizes hover and selected highlights and handles row taps', (tester) async {
    var pressed = 0;
    await _pumpTable(
      tester,
      onRowPressed: (_) => pressed += 1,
      isSelected: (row) => row.id == 'row-2',
    );

    final selectedMain = _decorationColor(
      tester,
      const Key('coelo-admin-table-row-background-row-2'),
    );
    final selectedPinned = _decorationColor(
      tester,
      const Key('coelo-admin-table-pinned-row-background-row-2'),
    );
    expect(selectedMain, CoeloColorSchemes.light.primaryContainer);
    expect(selectedPinned, selectedMain);
    expect(
      tester.getSemantics(find.byKey(const Key('row-2'))).flagsCollection.isSelected,
      Tristate.isTrue,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byKey(const Key('row-1'))));
    await tester.pumpAndSettle();

    final hoveredMain = tester.widget<InkWell>(
      find.ancestor(
        of: find.byKey(const Key('coelo-admin-table-row-background-row-1')),
        matching: find.byType(InkWell),
      ),
    );
    final hoveredPinned = _decorationColor(
      tester,
      const Key('coelo-admin-table-pinned-row-background-row-1'),
    );
    expect(
      hoveredMain.overlayColor?.resolve({WidgetState.hovered}),
      CoeloColorSchemes.light.primaryContainer,
    );
    expect(hoveredPinned, CoeloColorSchemes.light.primaryContainer);

    await tester.tap(find.byKey(const Key('row-1')));
    expect(pressed, 1);
  });

  testWidgets('exposes accessible resize handles and resizes in eight pixel steps', (tester) async {
    await _pumpTable(tester);

    final handle = find.bySemanticsLabel('Redimensionar coluna Nome');
    expect(handle, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('coelo-admin-table-pinned-column')),
        matching: handle,
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(handle).getSemanticsData().hasAction(SemanticsAction.increase),
      isTrue,
    );
    expect(
      tester.getSemantics(handle).getSemanticsData().hasAction(SemanticsAction.decrease),
      isTrue,
    );

    await tester.tap(handle);
    await tester.pump();
    final focusIndicator = tester.widget<Container>(
      find.byKey(const Key('coelo-admin-table-resizer-indicator-name-pinned')),
    );
    expect(
      (focusIndicator.decoration! as BoxDecoration).color,
      Theme.of(tester.element(handle)).extension<CoeloActionColors>()!.focusRing,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 168);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 160);
  });

  testWidgets('clamps drag resizing to the configured minimum and maximum', (tester) async {
    await _pumpTable(tester);

    final handle = find.bySemanticsLabel('Redimensionar coluna Nome');
    await tester.drag(handle, const Offset(500, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 200);

    await tester.drag(handle, const Offset(-500, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 120);
  });

  testWidgets('reconciles widths when column identifiers change', (tester) async {
    var pinnedColumn = _nameColumn;
    var columns = const [_statusColumn, _cityColumn];
    late StateSetter updateTable;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateTable = setState;
              return SizedBox(
                width: 300,
                child: CoeloAdminResizableTable<TestRow>(
                  key: const Key('dynamic-columns-table'),
                  items: const [TestRow('row-1', 'Alpha', 'Ativa')],
                  rowKey: (row) => row.id,
                  pinnedColumn: pinnedColumn,
                  columns: columns,
                  headerHeight: 56,
                  rowHeight: 64,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Redimensionar coluna Nome'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 168);

    updateTable(() {
      pinnedColumn = _codeColumn;
      columns = const [_nameColumn, _districtColumn];
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-code'))).width, 140);
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 168);
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-district'))).width, 210);
    expect(find.byKey(const Key('coelo-admin-table-header-status')), findsNothing);
    expect(find.byKey(const Key('coelo-admin-table-header-city')), findsNothing);
  });

  testWidgets('clamps preserved width when column constraints change', (tester) async {
    var pinnedColumn = _nameColumn;
    late StateSetter updateTable;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateTable = setState;
              return SizedBox(
                width: 300,
                child: CoeloAdminResizableTable<TestRow>(
                  items: const [TestRow('row-1', 'Alpha', 'Ativa')],
                  rowKey: (row) => row.id,
                  pinnedColumn: pinnedColumn,
                  columns: const [_statusColumn],
                  headerHeight: 56,
                  rowHeight: 64,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Redimensionar coluna Nome'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 168);

    updateTable(() {
      pinnedColumn = CoeloAdminTableColumn<TestRow>(
        id: 'name',
        label: 'Nome',
        initialWidth: 140,
        minWidth: 120,
        maxWidth: 150,
        cellBuilder: (context, row) => Text(row.name),
      );
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('coelo-admin-table-header-name'))).width, 150);
  });

  testWidgets('controller focuses the exact interactive row and keyboard reactivates it', (
    tester,
  ) async {
    final controller = CoeloAdminTableController();
    var pressed = 0;
    await _pumpTable(tester, controller: controller, onRowPressed: (_) => pressed += 1);

    expect(controller.focusRow('row-2'), isTrue);
    await tester.pump();

    final rowInkWell = tester.widget<InkWell>(
      find.ancestor(
        of: find.byKey(const Key('coelo-admin-table-row-background-row-2')),
        matching: find.byType(InkWell),
      ),
    );
    expect(rowInkWell.focusNode!.hasFocus, isTrue);
    expect(
      _decorationColor(tester, const Key('coelo-admin-table-row-background-row-2')),
      CoeloColorSchemes.light.primaryContainer,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('coelo-admin-table-pinned-row-background-row-2')),
        matching: find.byType(Focus),
      ),
      findsNothing,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pressed, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pressed, 2);

    expect(controller.focusRow('missing-row'), isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(controller.focusRow('row-2'), isFalse);
  });

  testWidgets('sorts a header by touch and keyboard with semantic direction', (tester) async {
    final sortedColumns = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: CoeloAdminResizableTable<TestRow>(
              items: const [TestRow('row-1', 'Alpha', 'Ativa')],
              rowKey: (row) => row.id,
              pinnedColumn: const CoeloAdminTableColumn<TestRow>(
                id: 'name',
                label: 'Nome',
                initialWidth: 160,
                minWidth: 120,
                maxWidth: 200,
                sortable: true,
                cellBuilder: _nameCell,
              ),
              columns: const [_statusColumn],
              headerHeight: 56,
              rowHeight: 64,
              sortColumnId: 'name',
              sortAscending: true,
              onSort: sortedColumns.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('coelo-admin-table-header-name-pinned'));
    expect(find.bySemanticsLabel('Nome, ordenado crescente'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets);

    await tester.tap(header);
    await tester.pump();
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: header, matching: find.byType(InkWell)),
    );
    for (var index = 0; index < 8 && !inkWell.focusNode!.hasFocus; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(inkWell.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(sortedColumns, ['name', 'name']);
  });

  testWidgets('uses the visible pinned header as the only sort target after scrolling', (
    tester,
  ) async {
    final sortedColumns = <String>[];
    await _pumpSortableTable(tester, sortedColumns.add);

    await tester.drag(find.byKey(const Key('coelo-admin-table-scroll')), const Offset(-180, 0));
    await tester.pumpAndSettle();

    final pinnedHeader = find.byKey(const Key('coelo-admin-table-header-name-pinned'));
    final underlyingHeader = find.byKey(const Key('coelo-admin-table-header-name'));
    expect(
      find.descendant(
        of: pinnedHeader,
        matching: find.bySemanticsLabel('Nome, ordenado crescente'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: underlyingHeader,
        matching: find.bySemanticsLabel('Nome, ordenado crescente'),
      ),
      findsNothing,
    );

    await tester.tap(pinnedHeader);
    await tester.pump();

    expect(sortedColumns, ['name']);
  });

  testWidgets('uses one InkWell focus stop with visible focus and native keyboard activation', (
    tester,
  ) async {
    final sortedColumns = <String>[];
    await _pumpSortableTable(tester, sortedColumns.add);

    final pinnedHeader = find.byKey(const Key('coelo-admin-table-header-name-pinned'));
    final sortInkWell = find.descendant(of: pinnedHeader, matching: find.byType(InkWell));
    expect(sortInkWell, findsOneWidget);

    final inkWell = tester.widget<InkWell>(sortInkWell);
    expect(inkWell.focusNode, isNotNull);
    expect(inkWell.overlayColor?.resolve({WidgetState.focused}), Colors.transparent);

    for (var index = 0; index < 8 && !inkWell.focusNode!.hasFocus; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(inkWell.focusNode!.hasFocus, isTrue);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('coelo-admin-table-sort-background-name-pinned')),
          )
          .color,
      CoeloColorSchemes.light.primaryContainer,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sortedColumns, ['name']);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(inkWell.focusNode!.hasFocus, isFalse);

    for (var index = 0; index < 8 && !inkWell.focusNode!.hasFocus; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(inkWell.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(sortedColumns, ['name', 'name']);
  });

  testWidgets('uses primary container for sortable-header hover and focus in light and dark', (
    tester,
  ) async {
    for (final (theme, colors) in [
      (CoeloTheme.light, CoeloColorSchemes.light),
      (CoeloTheme.dark, CoeloColorSchemes.dark),
    ]) {
      await _pumpSortableTable(tester, (_) {}, theme: theme);

      final pinnedHeader = find.byKey(const Key('coelo-admin-table-header-name-pinned'));
      final background = find.byKey(const Key('coelo-admin-table-sort-background-name-pinned'));
      final inkWell = tester.widget<InkWell>(
        find.descendant(of: pinnedHeader, matching: find.byType(InkWell)),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(pinnedHeader));
      await tester.pump();

      expect(tester.widget<ColoredBox>(background).color, colors.primaryContainer);
      expect(inkWell.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);

      await mouse.removePointer();
      await tester.pump();
      for (var index = 0; index < 8 && !inkWell.focusNode!.hasFocus; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      expect(inkWell.focusNode!.hasFocus, isTrue);
      expect(tester.widget<ColoredBox>(background).color, colors.primaryContainer);
    }
  });
}

Color? _decorationColor(WidgetTester tester, Key key) {
  final container = tester.widget<Container>(find.byKey(key));
  return (container.decoration! as BoxDecoration).color;
}

Future<void> _pumpTable(
  WidgetTester tester, {
  List<TestRow> rows = const [
    TestRow('row-1', 'Alpha', 'Ativa'),
    TestRow('row-2', 'Beta', 'Pendente'),
  ],
  ValueListenable<List<TestRow>>? rowsListenable,
  ValueChanged<TestRow>? onRowPressed,
  bool Function(TestRow row)? isSelected,
  CoeloAdminTableColumn<TestRow> pinnedColumn = _nameColumn,
  CoeloAdminTableController? controller,
}) async {
  Widget table(List<TestRow> currentRows) {
    return CoeloAdminResizableTable<TestRow>(
      items: currentRows,
      rowKey: (row) => row.id,
      pinnedColumn: pinnedColumn,
      columns: const [_statusColumn],
      headerHeight: 56,
      rowHeight: 64,
      onRowPressed: onRowPressed,
      isSelected: isSelected,
      controller: controller,
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: rowsListenable == null
              ? table(rows)
              : ValueListenableBuilder<List<TestRow>>(
                  valueListenable: rowsListenable,
                  builder: (context, currentRows, child) => table(currentRows),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSortableTable(
  WidgetTester tester,
  ValueChanged<String> onSort, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CoeloTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: CoeloAdminResizableTable<TestRow>(
            items: const [TestRow('row-1', 'Alpha', 'Ativa')],
            rowKey: (row) => row.id,
            pinnedColumn: const CoeloAdminTableColumn<TestRow>(
              id: 'name',
              label: 'Nome',
              initialWidth: 160,
              minWidth: 120,
              maxWidth: 200,
              sortable: true,
              cellBuilder: _nameCell,
            ),
            columns: const [_statusColumn, _cityColumn],
            headerHeight: 56,
            rowHeight: 64,
            sortColumnId: 'name',
            sortAscending: true,
            onSort: onSort,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _nameColumn = CoeloAdminTableColumn<TestRow>(
  id: 'name',
  label: 'Nome',
  initialWidth: 160,
  minWidth: 120,
  maxWidth: 200,
  cellBuilder: _nameCell,
);

const _statusColumn = CoeloAdminTableColumn<TestRow>(
  id: 'status',
  label: 'Status',
  initialWidth: 180,
  minWidth: 140,
  maxWidth: 220,
  cellBuilder: _statusCell,
);

const _cityColumn = CoeloAdminTableColumn<TestRow>(
  id: 'city',
  label: 'Cidade',
  initialWidth: 190,
  minWidth: 140,
  maxWidth: 240,
  cellBuilder: _statusCell,
);

const _codeColumn = CoeloAdminTableColumn<TestRow>(
  id: 'code',
  label: 'Código',
  initialWidth: 140,
  minWidth: 120,
  maxWidth: 180,
  cellBuilder: _nameCell,
);

const _districtColumn = CoeloAdminTableColumn<TestRow>(
  id: 'district',
  label: 'Bairro',
  initialWidth: 210,
  minWidth: 160,
  maxWidth: 260,
  cellBuilder: _statusCell,
);

const _statefulNameColumn = CoeloAdminTableColumn<TestRow>(
  id: 'name',
  label: 'Nome',
  initialWidth: 160,
  minWidth: 120,
  maxWidth: 200,
  cellBuilder: _statefulNameCell,
);

Widget _nameCell(BuildContext context, TestRow row) => Text(row.name);

Widget _statusCell(BuildContext context, TestRow row) => Text(row.status);

Widget _statefulNameCell(BuildContext context, TestRow row) => _StatefulNameCell(row: row);

final class _StatefulNameCell extends StatefulWidget {
  const _StatefulNameCell({required this.row});

  final TestRow row;

  @override
  State<_StatefulNameCell> createState() => _StatefulNameCellState();
}

final class _StatefulNameCellState extends State<_StatefulNameCell> {
  late final String _initialId = widget.row.id;
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _count += 1),
      child: Text('$_initialId:${widget.row.name}:$_count'),
    );
  }
}

final class TestRow {
  const TestRow(this.id, this.name, this.status);

  final String id;
  final String name;
  final String status;
}
