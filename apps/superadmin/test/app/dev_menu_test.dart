import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'offers the floating dev menu on the login screen and opens fake institution preview',
    (tester) async {
      // O gatilho so existe em build local nao-release
      // (SuperadminAppConfig.allowDevelopmentPreview); o teste liga a chave no
      // router em vez de depender de --dart-define=COELO_APP_ENV=local.
      final session = SuperadminSession();
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

      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

      await tester.tap(find.byTooltip('Abrir menu de desenvolvimento'));
      await tester.pumpAndSettle();

      expect(find.text('Instituições'), findsOneWidget);
      await tester.tap(find.text('Instituições'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutions);
      expect(find.text('Instituto Aurora'), findsOneWidget);
    },
  );
}
