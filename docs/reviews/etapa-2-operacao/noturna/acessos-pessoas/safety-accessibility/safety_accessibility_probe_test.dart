import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/data/dev/dev_child_safety_repository.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Nunito Sans')
      ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
    await font.load();
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final bytes = File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)));
    await icons.load();
  });
  for (final route in [true, false]) {
    for (final entry in {
      'label': labeledTapTargetGuideline,
      'android': androidTapTargetGuideline,
      'contrast': textContrastGuideline,
    }.entries) {
      testWidgets('Safety ${route ? "dev route" : "page"} ${entry.key} 1440 light', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1440, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final semantics = tester.ensureSemantics();
        try {
          if (route) {
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
            await tester.pumpWidget(
              MaterialApp.router(theme: CoeloTheme.light, routerConfig: router),
            );
            router.go('/dev/safety');
          } else {
            final controller = ChildSafetyController(DevChildSafetyRepository.content());
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              MaterialApp(
                theme: CoeloTheme.light,
                home: SafetyLandingPage(
                  controller: controller,
                  logout: unavailableSuperadminLogout,
                  onOpenChild: (_) {},
                ),
              ),
            );
          }
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull);
          expect(
            find.text('Alice Duarte'),
            findsOneWidget,
            reason: 'Probe must measure loaded Safety content',
          );
          await expectLater(tester, meetsGuideline(entry.value));
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
