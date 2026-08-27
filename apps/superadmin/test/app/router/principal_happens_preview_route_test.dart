import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the Acontece preview on a dedicated development route', () {
    expect(SuperadminRoutes.devPrincipalHappens, '/dev/principal-happens');
    expect(SuperadminRoutes.devPrincipalHappensName, 'dev-principal-happens');
    expect(SuperadminRoutes.devPrincipalHappens, isNot(SuperadminRoutes.devPrincipalProfile));
  });

  testWidgets('opens Acontece and its Perfil tab navigates to the profile preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPrincipalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
    expect(
      tester.widget<PrincipalHappensPreviewPage>(find.byType(PrincipalHappensPreviewPage)).embedded,
      isTrue,
    );
    expect(find.byKey(const Key('principal-happens-local-title')), findsNothing);
    await tester.tap(find.byKey(const Key('principal-happens-tab-perfil')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalProfile);
  });

  testWidgets('composes the Acontece publisher inside the persistent shell container', (
    tester,
  ) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPrincipalHappensPublish);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final page = tester.widget<PrincipalHappensPublicationPage>(
      find.byType(PrincipalHappensPublicationPage),
    );
    expect(page.embedded, isTrue);
  });
}
