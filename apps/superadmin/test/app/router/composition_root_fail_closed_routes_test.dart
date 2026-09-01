import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('model and Forms production routes stay fail-closed', (tester) async {
    final session = SuperadminSession()..signIn();
    final accessRepository = _TripwireAccessProfileRepository();
    final formsApi = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      accessProfileRepository: accessRepository,
      formsApi: formsApi,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in const [
      '/profile-models',
      '/profile-models/new/platform',
      '/profile-models/platform/model-1',
      '/profile-models/platform/model-1/edit',
      '/profile-models/platform/model-1/duplicate',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(find.byType(SuperadminErrorScreen), findsOneWidget, reason: path);
      expect(
        tester.widget<SuperadminErrorScreen>(find.byType(SuperadminErrorScreen)).kind,
        SuperadminErrorKind.unavailable,
        reason: path,
      );
      expect(
        find.bySemanticsLabel('Erro 503. O Coelo está temporariamente indisponível.'),
        findsOneWidget,
        reason: path,
      );
      expect(accessRepository.calls, 0, reason: path);
      expect(formsApi.calls, 0, reason: path);
    }

    router.go('/forms/form-1/files');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-operations-unavailable')), findsOneWidget);
    expect(formsApi.calls, 0);

    router.go('/forms/media/asset-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-media-unavailable')), findsOneWidget);
    expect(formsApi.calls, 0);
  });
}

final class _TripwireAccessProfileRepository implements AccessProfileRepository {
  var calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls += 1;
    throw StateError('AccessProfileRepository must stay unused on fail-closed routes.');
  }
}

final class _TripwireFormsApi implements FormsApi {
  var calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls += 1;
    throw StateError('FormsApi must stay unused on fail-closed routes.');
  }
}
