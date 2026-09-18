import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_widgets.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loaded development invites exposes labels for tappable controls', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      allowDevelopmentPreview: true,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      router.go('/dev/invites');
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      final cards = tester.widget<InviteDirectoryCards>(find.byType(InviteDirectoryCards));
      expect(cards.items, isNotEmpty);
      for (final element in tester.allElements) {
        final node = element.findRenderObject()?.debugSemantics;
        if (node != null && node.toString().contains('longPress') && node.label.isEmpty) {
          debugPrint('UNLABELED LONG PRESS: ${element.widget.runtimeType}: $node');
          var depth = 0;
          element.visitAncestorElements((ancestor) {
            debugPrint('  ancestor: ${ancestor.widget.runtimeType}');
            return ++depth < 12;
          });
        }
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
