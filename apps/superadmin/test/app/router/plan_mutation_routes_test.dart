import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/plans/data/fake_plan_catalog_repository.dart';
import 'package:coelo_superadmin/features/plans/domain/plan_catalog_repository.dart';
import 'package:coelo_superadmin/features/plans/presentation/plan_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Planos: as RPCs superadmin_plans_list/plan_get/plan_save estao na baseline
/// de producao, entao a rota de mutacao segue o repositorio composto (R05):
/// sem catalogo real cai na pagina honesta; com ele, abre o formulario.
void main() {
  Future<GoRouter> pump(WidgetTester tester, {bool composed = false}) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      planCatalogRepository: composed
          ? FakePlanCatalogRepository(
              store: SuperadminPrototypeStore(
                activityController: SuperadminActivityController(),
              ),
            )
          : const UnavailablePlanCatalogRepository(),
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    return router;
  }

  testWidgets('sem catalogo composto, criar e editar plano caem na pagina honesta', (tester) async {
    final router = await pump(tester);
    for (final route in [SuperadminRoutes.planCreate, '/plans/33333333-3333-4333-8333-333333333333/edit']) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget, reason: route);
      expect(find.byType(PlanFormPage), findsNothing, reason: route);
    }
  });

  testWidgets('com o catalogo composto, criar plano abre o formulario', (tester) async {
    final router = await pump(tester, composed: true);
    router.go(SuperadminRoutes.planCreate);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsNothing);
    expect(find.byType(PlanFormPage), findsOneWidget);
  });
}
