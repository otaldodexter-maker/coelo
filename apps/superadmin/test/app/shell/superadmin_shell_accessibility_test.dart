import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final collapsed in [false, true]) {
    testWidgets('sidebar toggle names its actionable node when collapsed=$collapsed', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final toggle = find.byKey(const Key('superadmin-sidebar-collapse'));
      if (collapsed) {
        await tester.tap(toggle);
        await tester.pumpAndSettle();
      }
      final label = collapsed ? 'Expandir menu' : 'Recolher menu';
      // An ancestor label alone does not name a separate actionable child.
      expect(find.bySemanticsLabel(label), findsOneWidget);
      final data = tester.getSemantics(toggle).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains(label));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact shell exposes names for every tappable node', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-sidebar-collapse')), findsNothing);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester.takeException(), isNull);
  });
}

Widget _shell() => MaterialApp(
  theme: CoeloTheme.light,
  home: SuperadminShell(
    logout: () async => const LogoutResult.success(),
    onDestinationSelected: (_) {},
    child: const SizedBox.expand(),
  ),
);
