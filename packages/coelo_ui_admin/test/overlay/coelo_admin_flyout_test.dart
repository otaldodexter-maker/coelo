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
