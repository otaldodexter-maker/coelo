import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the Agora preview on a dedicated development route', () {
    expect(SuperadminRoutes.devPrincipalNow, '/dev/principal-now');
    expect(SuperadminRoutes.devPrincipalNowName, 'dev-principal-now');
    expect(SuperadminRoutes.devPrincipalNowPublication, '/dev/principal-now/publication');
    expect(SuperadminRoutes.devPrincipalNowPublicationName, 'dev-principal-now-publication');
    expect(SuperadminRoutes.devPrincipalNow, isNot(SuperadminRoutes.devPrincipalHappens));
  });

  testWidgets('opens Agora from Acontece and closes back to Acontece', (tester) async {
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

    await tester.tap(find.text('Ver tudo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PrincipalNowPreviewPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalNow);

    await tester.tap(find.byKey(const Key('principal-now-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalHappens);
  });

  testWidgets('opens the Agora composer without replacing the viewer route', (tester) async {
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

    router.go(SuperadminRoutes.devPrincipalNowPublication);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalNowPublicationPage), findsOneWidget);
    expect(find.byType(PrincipalNowPreviewPage), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.devPrincipalNowPublication,
    );
  });
}
