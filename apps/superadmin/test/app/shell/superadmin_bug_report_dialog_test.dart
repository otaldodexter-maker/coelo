import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/app/shell/superadmin_bug_report_dialog.dart';

void main() {
  testWidgets('keeps a long selector scrollable above compact safe insets and keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final devicePixelRatio = tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(
      top: 24 * devicePixelRatio,
      bottom: 16 * devicePixelRatio,
    );
    tester.view.viewInsets = FakeViewPadding(bottom: 240 * devicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSuperadminBugReportDialog(
              context,
              currentScreen: 'Tela 1',
              sections: {
                for (var index = 1; index <= 10; index += 1) 'Seção $index': ['Tela $index'],
                'Outros': const <String>[],
              },
            ),
            child: const Text('Relatar bug'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Relatar bug'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final dialogScroll = find
        .descendant(
          of: find.byKey(const Key('coelo-admin-dialog-keyboard-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final menuTrigger = find.byKey(const Key('superadmin-bug-menu'));
    await tester.scrollUntilVisible(menuTrigger, 120, scrollable: dialogScroll);
    await tester.tap(menuTrigger);
    await tester.pumpAndSettle();

    final lastOption = find.byKey(const Key('superadmin-bug-menu-option-Outros'));
    expect(lastOption, findsOneWidget);
    final menuScroll = find.byKey(const Key('superadmin-bug-select-scroll'));
    expect(menuScroll, findsOneWidget);
    expect(tester.getSize(menuScroll).height, lessThanOrEqualTo(404));
    expect(tester.takeException(), isNull);

    final menuScrollable = find.descendant(of: menuScroll, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(lastOption, 160, scrollable: menuScrollable);
    await tester.tap(lastOption);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-bug-other-subject')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
