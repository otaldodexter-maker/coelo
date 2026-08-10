import 'dart:ui' show PointerDeviceKind, SemanticsAction, Tristate;

import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_underline_tabs.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inactive tab uses primary content on tonal hover', (tester) async {
    await tester.pumpWidget(_tabsApp());

    final selected = tester.widget<Container>(
      find.byKey(const ValueKey('superadmin-underline-tab-superadmin')),
    );
    expect((selected.decoration! as BoxDecoration).color, Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('Admin')));
    await tester.pumpAndSettle();

    final hovered = tester.widget<Container>(
      find.byKey(const ValueKey('superadmin-underline-tab-admin')),
    );
    final decoration = hovered.decoration! as BoxDecoration;
    final hoverInk = tester.widget<InkWell>(
      find.ancestor(of: find.text('Admin'), matching: find.byType(InkWell)),
    );
    expect(
      hoverInk.overlayColor!.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.primaryContainer.withValues(alpha: .48),
    );
    expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.md));
    expect(
      tester.widget<Text>(find.text('Admin')).style?.color,
      CoeloTheme.light.colorScheme.primary,
    );
  });

  testWidgets('keyboard focus uses primary content and a non-color-only outline', (tester) async {
    await tester.pumpWidget(_tabsApp());

    final adminInk = tester.widget<InkWell>(
      find.ancestor(of: find.text('Admin'), matching: find.byType(InkWell)),
    );
    adminInk.focusNode!.requestFocus();
    await tester.pump();

    final decoration =
        tester
                .widget<Container>(find.byKey(const ValueKey('superadmin-underline-tab-admin')))
                .decoration!
            as BoxDecoration;
    expect(
      tester.widget<Text>(find.text('Admin')).style?.color,
      CoeloTheme.light.colorScheme.primary,
    );
    expect(decoration.border?.top.width, 1);
    expect(decoration.border?.top.color, CoeloTheme.light.colorScheme.primary);
  });

  testWidgets('active tab keeps underline and exposes selected button semantics', (tester) async {
    await tester.pumpWidget(_tabsApp());

    final activeInk = tester.widget<InkWell>(
      find.ancestor(of: find.text('Superadmin'), matching: find.byType(InkWell)),
    );
    activeInk.focusNode!.requestFocus();
    await tester.pump();

    final underlineDecoration =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('superadmin-underline-tab-superadmin')),
                )
                .foregroundDecoration!
            as BoxDecoration;
    expect(underlineDecoration.border?.bottom.color, CoeloTheme.light.colorScheme.primary);
    expect(underlineDecoration.border?.bottom.width, 2);

    final semantics = tester.getSemantics(find.text('Superadmin'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('compact overflow supports mouse drag without a visible scrollbar', (tester) async {
    await tester.pumpWidget(_overflowTabsApp(selected: 'all'));
    final viewport = find.byType(SingleChildScrollView);
    final behavior = ScrollConfiguration.of(tester.element(viewport));
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(find.byType(Scrollbar), findsNothing);
    final position = tester
        .state<ScrollableState>(find.descendant(of: viewport, matching: find.byType(Scrollable)))
        .position;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(viewport));
    await mouse.down(tester.getCenter(viewport));
    await mouse.moveBy(const Offset(-20, 0));
    await tester.pump();
    await mouse.moveBy(const Offset(-180, 0));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('compact overflow exposes a discreet trailing fade', (tester) async {
    await tester.pumpWidget(_overflowTabsApp(selected: 'all'));
    await tester.pump();

    expect(find.byKey(const ValueKey('superadmin-underline-tabs-trailing-fade')), findsOneWidget);
  });

  testWidgets('keyboard focus reveals a hidden tab completely', (tester) async {
    await tester.pumpWidget(_overflowTabsApp(selected: 'all'));
    final tab = find.byKey(const ValueKey('superadmin-underline-tab-dual'));
    tester
        .widget<InkWell>(find.ancestor(of: tab, matching: find.byType(InkWell)))
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();
    _expectFullyVisible(tester, tab);
  });

  testWidgets('selection update reveals a hidden tab completely', (tester) async {
    await tester.pumpWidget(_overflowTabsApp(selected: 'all'));
    await tester.pumpWidget(_overflowTabsApp(selected: 'dual'));
    await tester.pumpAndSettle();
    _expectFullyVisible(tester, find.byKey(const ValueKey('superadmin-underline-tab-dual')));
  });

  testWidgets('shrinking constraints keeps the selected tab fully visible', (tester) async {
    await tester.pumpWidget(_tabsAtWidthApp(width: 900, selected: 'dual'));
    await tester.pumpWidget(_tabsAtWidthApp(width: 220, selected: 'dual'));
    await tester.pumpAndSettle();

    _expectFullyVisible(tester, find.byKey(const ValueKey('superadmin-underline-tab-dual')));
  });

  testWidgets('focused tab stays clear of the trailing fade when more tabs follow', (tester) async {
    await tester.pumpWidget(_overflowTabsApp(selected: 'all'));
    final tab = find.byKey(const ValueKey('superadmin-underline-tab-family'));
    tester
        .widget<InkWell>(find.ancestor(of: tab, matching: find.byType(InkWell)))
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();

    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    final tabRect = tester.getRect(tab);
    expect(tabRect.right, lessThanOrEqualTo(viewport.right - CoeloSpacing.space6));
    expect(find.byKey(const ValueKey('superadmin-underline-tabs-trailing-fade')), findsOneWidget);
  });

  testWidgets('Enter and Space select the focused tab', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(_overflowTabsApp(selected: 'all', onSelected: selected.add));
    final tab = find.byKey(const ValueKey('superadmin-underline-tab-team'));
    tester
        .widget<InkWell>(find.ancestor(of: tab, matching: find.byType(InkWell)))
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(selected, ['team', 'team']);
  });

  testWidgets('reduced motion reveals selection without animation', (tester) async {
    await tester.pumpWidget(_overflowTabsApp(selected: 'all', disableAnimations: true));
    await tester.pumpWidget(_overflowTabsApp(selected: 'dual', disableAnimations: true));
    await tester.pump();

    _expectFullyVisible(tester, find.byKey(const ValueKey('superadmin-underline-tab-dual')));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

Widget _tabsApp() => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: SuperadminUnderlineTabs<String>(
      tabs: const [
        SuperadminUnderlineTab(value: 'superadmin', label: 'Superadmin'),
        SuperadminUnderlineTab(value: 'admin', label: 'Admin'),
      ],
      selected: 'superadmin',
      onSelected: (_) {},
    ),
  ),
);

Widget _overflowTabsApp({
  required String selected,
  double width = 220,
  ValueChanged<String>? onSelected,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: SuperadminUnderlineTabs<String>(
          tabs: const [
            SuperadminUnderlineTab(value: 'all', label: 'Todos'),
            SuperadminUnderlineTab(value: 'team', label: 'Equipe institucional'),
            SuperadminUnderlineTab(value: 'family', label: 'Respons\u00e1veis'),
            SuperadminUnderlineTab(value: 'children', label: 'Crian\u00e7as'),
            SuperadminUnderlineTab(value: 'dual', label: 'Perfil duplo'),
          ],
          selected: selected,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  ),
);

Widget _tabsAtWidthApp({required double width, required String selected}) =>
    _overflowTabsApp(width: width, selected: selected);
void _expectFullyVisible(WidgetTester tester, Finder tab) {
  final viewport = tester.getRect(find.byType(SingleChildScrollView));
  final rect = tester.getRect(tab);
  expect(rect.left, greaterThanOrEqualTo(viewport.left));
  expect(rect.right, lessThanOrEqualTo(viewport.right));
}
