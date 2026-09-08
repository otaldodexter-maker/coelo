import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/shell/superadmin_activity_center.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(SuperadminActivityController? controller) => MaterialApp(
    theme: CoeloTheme.light,
    home: SuperadminShell(
      logout: () async => const LogoutResult.success(),
      activityController: controller,
      showChatLauncher: false,
    ),
  );

  for (final change in ['external-to-external', 'external-to-local', 'local-to-external']) {
    testWidgets('shell follows activity controller $change without disposing external owners', (
      tester,
    ) async {
      final first = _TrackedController();
      final second = _TrackedController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      first.completeDemoExport(SuperadminExportFormat.csv, fileBaseName: 'first');
      second.completeDemoExport(SuperadminExportFormat.xlsx, fileBaseName: 'second');
      final before = change == 'local-to-external' ? null : first;
      final after = change == 'external-to-local' ? null : second;
      await tester.pumpWidget(host(before));
      final previous = tester
          .widget<SuperadminActivityCenter>(find.byType(SuperadminActivityCenter))
          .controller;
      await tester.tap(find.byKey(const Key('superadmin-notifications')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(after));
      await tester.pumpAndSettle();
      final current = tester
          .widget<SuperadminActivityCenter>(find.byType(SuperadminActivityCenter))
          .controller;
      expect(identical(previous, current), isFalse);
      if (after != null) expect(identical(current, second), isTrue);
      expect(find.text('first.csv'), findsNothing);
      if (after != null) expect(find.text('second.xlsx'), findsOneWidget);
      if (before == null) {
        expect(() => ChangeNotifier.debugAssertNotDisposed(previous), throwsFlutterError);
      } else {
        first.completeDemoExport(SuperadminExportFormat.csv, fileBaseName: 'late-first');
        expect(first.unreadCount, 1);
      }
      expect(first.disposeCalls, 0);
      expect(second.disposeCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(first.disposeCalls, 0);
      expect(second.disposeCalls, 0);
      expect(tester.takeException(), isNull);
      if (after == null) {
        expect(() => ChangeNotifier.debugAssertNotDisposed(current), throwsFlutterError);
      }
    });
  }
}

class _TrackedController extends SuperadminActivityController {
  var disposeCalls = 0;
  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }
}
