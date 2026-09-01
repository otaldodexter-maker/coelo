import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens reusable file actions and invokes the selected operation', (tester) async {
    var exports = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminFileActions(
            compact: true,
            actions: [
              CoeloAdminFileAction(
                label: 'Exportar CSV',
                icon: Icons.table_rows_outlined,
                onPressed: () => exports += 1,
              ),
            ],
          ),
        ),
      ),
    );

    final trigger = find.byKey(const Key('coelo-admin-files-action'));
    expect(trigger, findsOneWidget);
    expect(find.byType(CoeloAdminFlyout<CoeloAdminFileAction>), findsOneWidget);
    expect(
      tester
          .widget<CoeloAdminFlyout<CoeloAdminFileAction>>(
            find.byType(CoeloAdminFlyout<CoeloAdminFileAction>),
          )
          .itemWidth,
      220,
    );
    expect(tester.getSize(trigger).height, greaterThanOrEqualTo(CoeloSize.touchMin));

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Exportar CSV'), findsOneWidget);
    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    expect(anchor.style?.surfaceTintColor?.resolve({}), Colors.transparent);
    expect(anchor.alignmentOffset?.dy, CoeloSpacing.spaceHalf);

    await tester.tap(find.text('Exportar CSV'));
    await tester.pump();
    expect(exports, 1);
  });

  testWidgets('keeps unavailable operations visible and disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(
          body: CoeloAdminFileActions(
            actions: [
              CoeloAdminFileAction(
                label: 'Importar',
                icon: Icons.upload_file_outlined,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();

    final item = tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Importar'));
    expect(item.onPressed, isNull);
    expect(find.text('Importar'), findsOneWidget);
  });
}
