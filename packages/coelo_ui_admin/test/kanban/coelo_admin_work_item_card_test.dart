import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps single tap and double tap distinct', (tester) async {
    var singleTaps = 0;
    var doubleTaps = 0;
    await _pumpCard(tester, onTap: () => singleTaps += 1, onDoubleTap: () => doubleTaps += 1);

    await tester.tap(find.byType(CoeloAdminWorkItemCard<String>));
    await tester.pump(kDoubleTapTimeout);
    expect(singleTaps, 1);
    expect(doubleTaps, 0);

    await tester.tap(find.byType(CoeloAdminWorkItemCard<String>));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(CoeloAdminWorkItemCard<String>));
    await tester.pump(kDoubleTapTimeout);
    expect(singleTaps, 1);
    expect(doubleTaps, 1);
  });

  testWidgets('starts drag only after a long press', (tester) async {
    var taps = 0;
    await _pumpCard(tester, onTap: () => taps += 1, dragData: 'ticket');

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CoeloAdminWorkItemCard<String>)),
    );
    await tester.pump(kLongPressTimeout - const Duration(milliseconds: 10));

    expect(find.text('Dragging ticket'), findsNothing);
    expect(taps, 0);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Dragging ticket'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('uses clean semantic surfaces and exposes optional footer slots', (tester) async {
    await _pumpCard(tester, selected: true);

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CoeloAdminWorkItemCard<String>),
            matching: find.byType(Material),
          )
          .first,
    );
    final shape = material.shape! as RoundedRectangleBorder;

    expect(material.color, CoeloColorSchemes.light.surface);
    expect(shape.borderRadius, BorderRadius.circular(CoeloRadius.lg));
    expect(shape.side.color, CoeloColorSchemes.light.primary);
    expect(find.text('Equipe'), findsOneWidget);
    expect(find.text('Atualizado hoje'), findsOneWidget);
    expect(find.text('2 alertas'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('menu'))).shortestSide, greaterThanOrEqualTo(48));
    expect(tester.widget<Text>(find.text('Título curto')).maxLines, 2);
    expect(tester.widget<Text>(find.text('Resumo curto')).maxLines, 2);
    expect(tester.widget<Text>(find.text('Atualizado hoje')).maxLines, 1);
  });

  testWidgets('uses dark theme tokens without changing geometry', (tester) async {
    await _pumpCard(tester, theme: CoeloTheme.dark, selected: true);

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CoeloAdminWorkItemCard<String>),
            matching: find.byType(Material),
          )
          .first,
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(material.color, CoeloColorSchemes.dark.surface);
    expect(shape.side.color, CoeloColorSchemes.dark.primary);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  VoidCallback? onTap,
  VoidCallback? onDoubleTap,
  String? dragData,
  bool selected = false,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CoeloTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: CoeloAdminWorkItemCard<String>(
              eyebrow: 'Origem',
              title: 'Título curto',
              summary: 'Resumo curto',
              metadata: const ['Atualizado hoje'],
              assignees: const Text('Equipe'),
              indicators: const Text('2 alertas'),
              trailingMenu: const SizedBox.square(
                key: Key('menu'),
                dimension: CoeloSize.touchMin,
                child: Icon(Icons.more_vert_rounded),
              ),
              onTap: onTap ?? () {},
              onDoubleTap: onDoubleTap,
              dragData: dragData,
              dragFeedback: dragData == null ? null : Material(child: Text('Dragging $dragData')),
              selected: selected,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
