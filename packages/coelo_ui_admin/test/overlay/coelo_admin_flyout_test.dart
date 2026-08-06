import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owns the approved shell and hover tones', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminFlyout<String>(
            items: const [
              CoeloAdminFlyoutItem(
                value: 'profile',
                label: 'Perfil',
                icon: Icons.person_outline,
                selected: true,
              ),
              CoeloAdminFlyoutItem(
                value: 'exit',
                label: 'Sair',
                icon: Icons.logout,
                startsGroup: true,
                tone: CoeloAdminFlyoutTone.negative,
              ),
            ],
            onSelected: (_) {},
            builder: (context, controller) =>
                TextButton(onPressed: controller.open, child: const Text('Abrir')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    final colors = CoeloTheme.light.colorScheme;
    expect(anchor.style!.backgroundColor!.resolve({}), colors.surface);
    expect(anchor.style!.surfaceTintColor!.resolve({}), Colors.transparent);
    expect(
      (anchor.style!.shape!.resolve({})! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(CoeloRadius.lg),
    );

    final items = tester.widgetList<MenuItemButton>(find.byType(MenuItemButton)).toList();
    expect(
      items.first.style!.backgroundColor!.resolve({WidgetState.hovered}),
      colors.primaryContainer,
    );
    expect(items.last.style!.foregroundColor!.resolve({}), colors.error);
    expect(
      items.last.style!.backgroundColor!.resolve({WidgetState.hovered}),
      colors.errorContainer,
    );
    expect(find.byType(Divider), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.selected == true),
      findsOneWidget,
    );
  });

  testWidgets('preserves the wide anatomy and separates adjacent highlighted items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminFlyout<String>(
            items: const [
              CoeloAdminFlyoutItem(value: 'grouped', label: 'Agrupado', selected: true),
              CoeloAdminFlyoutItem(value: 'units', label: 'Unidades'),
              CoeloAdminFlyoutItem(value: 'groups', label: 'Turmas'),
            ],
            onSelected: (_) {},
            builder: (context, controller) =>
                TextButton(onPressed: controller.open, child: const Text('Abrir')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final items = tester.widgetList<MenuItemButton>(find.byType(MenuItemButton)).toList();
    final itemFinders = find.byType(MenuItemButton).evaluate().toList();
    final firstRect = tester.getRect(find.byWidget(items[0]));
    final secondRect = tester.getRect(find.byWidget(items[1]));
    final colors = CoeloTheme.light.colorScheme;

    expect(itemFinders, hasLength(3));
    expect(firstRect.width, 220);
    expect(secondRect.width, 220);
    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    final expectedPanelWidth = 220 + (CoeloSpacing.space2 * 2);

    expect(anchor.style?.minimumSize?.resolve({})?.width, expectedPanelWidth);
    expect(anchor.style?.maximumSize?.resolve({})?.width, expectedPanelWidth);
    expect(anchor.style?.padding?.resolve({}), const EdgeInsets.all(CoeloSpacing.space2));
    expect(secondRect.top - firstRect.bottom, CoeloSpacing.space1);
    expect(items[0].style!.backgroundColor!.resolve({}), colors.primaryContainer);
    expect(
      items[1].style!.backgroundColor!.resolve({WidgetState.hovered}),
      colors.primaryContainer,
    );
  });

  testWidgets('supports custom icon color with an accessible item label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminFlyout<String>(
            items: const [
              CoeloAdminFlyoutItem(
                value: 'urgent',
                label: 'Urgente',
                semanticLabel: 'Bandeira vermelha: Urgente',
                icon: Icons.flag_rounded,
                iconColor: Colors.red,
              ),
            ],
            onSelected: (_) {},
            builder: (context, controller) =>
                TextButton(onPressed: controller.open, child: const Text('Abrir')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.flag_rounded));
    expect(icon.color, Colors.red);
    expect(find.bySemanticsLabel('Bandeira vermelha: Urgente'), findsOneWidget);
    expect(find.text('Urgente'), findsOneWidget);
  });
  testWidgets('returns the selected value and closes the flyout', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: Scaffold(
          body: CoeloAdminFlyout<String>(
            items: const [CoeloAdminFlyoutItem(value: 'tour', label: 'Fazer tour')],
            onSelected: (value) => selected = value,
            builder: (context, controller) =>
                TextButton(onPressed: controller.open, child: const Text('Abrir')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazer tour'));
    await tester.pumpAndSettle();

    expect(selected, 'tour');
    expect(find.text('Fazer tour'), findsNothing);
  });
}
