import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expands four softly branded lanes edge-to-edge when they fit', (tester) async {
    await _pumpBoard(tester, width: 1200);

    final lanes = _Status.values.map(_laneFinder).toList(growable: false);
    for (final lane in lanes) {
      expect(tester.getSize(lane).width, 291);
      final decoration = tester.widget<DecoratedBox>(lane).decoration as BoxDecoration;
      expect(decoration.color, CoeloColorSchemes.light.primaryContainer);
    }
    expect(tester.getTopLeft(lanes.first).dx, 0);
    expect(tester.getBottomRight(lanes.last).dx, 1200);
  });

  testWidgets('scrolls horizontally with 280 pixel lanes when they do not fit', (tester) async {
    await _pumpBoard(tester, width: 800);

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('coelo-admin-kanban-scroll')),
    );
    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scroll.scrollDirection, Axis.horizontal);
    expect(scroll.controller!.position.maxScrollExtent, 356);
    expect(scrollbar.thumbVisibility, isTrue);
    for (final status in _Status.values) {
      expect(tester.getSize(_laneFinder(status)).width, 280);
    }
  });

  testWidgets('accepts a generic dragged item into a target status', (tester) async {
    String? acceptedItem;
    _Status? acceptedStatus;
    await _pumpBoard(
      tester,
      width: 800,
      itemBuilder: (context, item) => Draggable<String>(
        data: item,
        feedback: const Material(child: Text('dragging')),
        child: Text(item),
      ),
      onItemAccepted: (item, status) {
        acceptedItem = item;
        acceptedStatus = status;
      },
    );

    await tester.drag(find.text('Ticket 1'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(acceptedItem, 'Ticket 1');
    expect(acceptedStatus, _Status.doing);
  });

  testWidgets('shows one consumer-selected textual lane below compact breakpoint', (tester) async {
    _Status? requestedStatus;
    await _pumpBoard(
      tester,
      width: 500,
      selectedStatus: _Status.doing,
      onSelectedStatusChanged: (status) => requestedStatus = status,
    );

    expect(_laneFinder(_Status.doing), findsOneWidget);
    expect(_laneFinder(_Status.todo), findsNothing);

    await tester.tap(find.byType(DropdownButton<_Status>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluído').last);
    await tester.pumpAndSettle();
    expect(requestedStatus, _Status.done);
    expect(_laneFinder(_Status.doing), findsOneWidget);
  });

  testWidgets('lets a workspace keep horizontal lanes when its body is narrowed', (tester) async {
    await _pumpBoard(tester, width: 500, compact: false);

    for (final status in _Status.values) {
      expect(_laneFinder(status), findsOneWidget);
    }
    expect(find.byKey(const Key('coelo-admin-kanban-scroll')), findsOneWidget);
  });

  testWidgets('supports mouse touch stylus and trackpad dragging', (tester) async {
    await _pumpBoard(tester, width: 800);
    final configuration = tester.widget<ScrollConfiguration>(
      find.byKey(const Key('coelo-admin-kanban-scroll-configuration')),
    );
    expect(
      configuration.behavior.dragDevices,
      containsAll({
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      }),
    );
  });
}

enum _Status { todo, doing, review, done }

Finder _laneFinder(_Status status) =>
    find.byKey(ValueKey<(String, _Status)>(('coelo-admin-kanban-lane', status)));

Future<void> _pumpBoard(
  WidgetTester tester, {
  required double width,
  Widget Function(BuildContext context, String item)? itemBuilder,
  void Function(String item, _Status status)? onItemAccepted,
  _Status? selectedStatus,
  ValueChanged<_Status>? onSelectedStatusChanged,
  bool? compact,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 500,
          child: CoeloAdminKanbanBoard<String, _Status>(
            statuses: _Status.values,
            statusLabel: (status) => switch (status) {
              _Status.todo => 'A fazer',
              _Status.doing => 'Fazendo',
              _Status.review => 'Revisão',
              _Status.done => 'Concluído',
            },
            itemsForStatus: (status) => status == _Status.todo ? const ['Ticket 1'] : const [],
            itemBuilder: itemBuilder ?? (context, item) => Text(item),
            onItemAccepted: onItemAccepted ?? (item, status) {},
            selectedStatus: selectedStatus,
            onSelectedStatusChanged: onSelectedStatusChanged,
            compact: compact,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
