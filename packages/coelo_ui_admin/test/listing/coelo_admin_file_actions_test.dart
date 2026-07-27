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
            actions: [
              CoeloAdminFileAction(
                key: const Key('export'),
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
    expect(tester.getSize(trigger).height, greaterThanOrEqualTo(CoeloSize.touchMin));

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export')), findsOneWidget);
    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    expect(anchor.style?.surfaceTintColor?.resolve({}), Colors.transparent);
    expect(anchor.alignmentOffset?.dy, CoeloSpacing.spaceHalf);

    await tester.tap(find.byKey(const Key('export')));
    await tester.pump();
    expect(exports, 1);
  });
}
