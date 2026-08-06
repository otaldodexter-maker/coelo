import 'dart:ui' show PointerDeviceKind, SemanticsAction, Tristate;

import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_underline_tabs.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
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
