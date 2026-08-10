import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('fits the safe viewport at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(200, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(200, 600),
            padding: EdgeInsets.symmetric(horizontal: 12),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: CoeloAdminFlyout<String>(
                items: const [
                  CoeloAdminFlyoutItem(value: 'settings', label: 'Configurações da instituição'),
                ],
                onSelected: (_) {},
                builder: (context, controller) =>
                    TextButton(onPressed: controller.open, child: const Text('Abrir')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    final itemRect = tester.getRect(find.byType(MenuItemButton));
    const expectedPanelWidth = 200 - (12 * 2) - (CoeloSpacing.space2 * 2);
    const expectedItemWidth = expectedPanelWidth - (CoeloSpacing.space2 * 2);
    expect(anchor.style!.minimumSize!.resolve({})!.width, expectedPanelWidth);
    expect(anchor.style!.maximumSize!.resolve({})!.width, expectedPanelWidth);
    expect(itemRect.width, expectedItemWidth);
    expect(itemRect.left, greaterThanOrEqualTo(12 + CoeloSpacing.space2 * 2));
    expect(itemRect.right, lessThanOrEqualTo(200 - 12 - CoeloSpacing.space2 * 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape closes the flyout and restores trigger focus', (tester) async {
    final triggerFocus = FocusNode();
    addTearDown(triggerFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminFlyout<String>(
            items: const [CoeloAdminFlyoutItem(value: 'profile', label: 'Perfil')],
            onSelected: (_) {},
            builder: (context, controller) => TextButton(
              focusNode: triggerFocus,
              onPressed: controller.open,
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    triggerFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Perfil'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Perfil'), findsNothing);
    expect(triggerFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('normal selection preserves focus acquired by the destination', (tester) async {
    final triggerFocus = FocusNode();
    final destinationFocus = FocusNode();
    addTearDown(triggerFocus.dispose);
    addTearDown(destinationFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              CoeloAdminFlyout<String>(
                items: const [CoeloAdminFlyoutItem(value: 'import', label: 'Importar')],
                onSelected: (_) => destinationFocus.requestFocus(),
                builder: (context, controller) => TextButton(
                  focusNode: triggerFocus,
                  onPressed: controller.open,
                  child: const Text('Abrir'),
                ),
              ),
              TextButton(
                focusNode: destinationFocus,
                onPressed: () {},
                child: const Text('Destino'),
              ),
            ],
          ),
        ),
      ),
    );

    triggerFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('Importar'), findsNothing);
    expect(destinationFocus.hasPrimaryFocus, isTrue);
    expect(triggerFocus.hasPrimaryFocus, isFalse);
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
