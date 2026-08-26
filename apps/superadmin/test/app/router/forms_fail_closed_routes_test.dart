import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const productionPaths = [
    '/forms/new',
    '/forms/form-1/edit',
    '/forms/form-1/test',
    '/forms/form-1/monitor',
    '/forms/form-1/occurrences/occurrence-1/respond',
    '/forms/form-1/responses',
    '/forms/form-1/responses/response-1',
  ];
  const developmentPaths = [
    '/dev/forms/new',
    '/dev/forms/form-1/edit',
    '/dev/forms/form-1/test',
    '/dev/forms/form-1/monitor',
    '/dev/forms/form-1/occurrences/occurrence-1/respond',
    '/dev/forms/form-1/responses',
    '/dev/forms/form-1/responses/response-1',
  ];

  testWidgets('production and development dormant routes are 503 with zero API calls', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final api = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: api,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in [...productionPaths, ...developmentPaths]) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, path, reason: path);
      expect(find.byType(SuperadminErrorScreen), findsOneWidget, reason: path);
      expect(
        tester.widget<SuperadminErrorScreen>(find.byType(SuperadminErrorScreen)).kind,
        SuperadminErrorKind.unavailable,
        reason: path,
      );
      expect(api.calls, 0, reason: path);
    }
  });

  testWidgets('development Forms routes remain guarded when preview is disabled', (tester) async {
    final session = SuperadminSession()..signIn();
    final api = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: api,
      allowDevelopmentPreview: false,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go(developmentPaths.first);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, isNot(developmentPaths.first));
    expect(api.calls, 0);
  });
}

final class _TripwireFormsApi implements FormsApi {
  var calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls += 1;
    throw StateError('FormsApi must stay unused on fail-closed routes.');
  }
}
