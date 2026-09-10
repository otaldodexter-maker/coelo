import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/data/dev/dev_child_safety_repository.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpDirectory(WidgetTester tester, Size size) async {
  final controller = ChildSafetyController(
    DevChildSafetyRepository.content(),
    searchDebounce: Duration.zero,
  );
  addTearDown(controller.dispose);
  await controller.load();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: SafetyLandingPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
        onOpenChild: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(375, 900), Size(1440, 1000)]) {
    testWidgets('the child directory lays out at ${size.width}', (tester) async {
      await _pumpDirectory(tester, size);

      // The grid used to wrap each row in IntrinsicHeight while the canonical
      // status inside the cards is a LayoutBuilder, so nothing laid out at all.
      expect(tester.takeException(), isNull);
      expect(find.byType(SafetyChildDirectoryCard), findsWidgets);
    });

    testWidgets('the child directory labels and contrasts its own surface at ${size.width}', (
      tester,
    ) async {
      await _pumpDirectory(tester, size);
      final handle = tester.ensureSemantics();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // androidTapTargetGuideline is deliberately not asserted here: at 375 the
      // only node below the minimum is the shell's own user menu, "Abrir menu
      // do usuário", measuring 52x44. That belongs to every Superadmin screen,
      // not to this directory, and is reported separately.
      handle.dispose();
    });
  }

  testWidgets('the view toggle returns to a grid that lays out', (tester) async {
    await _pumpDirectory(tester, const Size(1440, 1000));
    expect(find.byType(SafetyChildDirectoryCard), findsWidgets);

    await tester.tap(find.byKey(const Key('safety-view-table')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SafetyChildDirectoryCard), findsNothing);

    await tester.tap(find.byKey(const Key('safety-view-cards')));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'coming back to cards must rebuild the grid, which is where it used to break',
    );
    expect(find.byType(SafetyChildDirectoryCard), findsWidgets);
  });
}
