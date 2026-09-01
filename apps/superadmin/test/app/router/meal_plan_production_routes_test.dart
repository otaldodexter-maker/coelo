import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/meal_plans/data/dev/development_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_directory_page.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_wizard_page.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('production meal plan directory uses the injected repository', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = DevelopmentMealPlanRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanRepository: repository,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go('/meal-plans');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(MealPlanDirectoryPage), findsOneWidget);
    expect(
      tester.widget<MealPlanDirectoryPage>(find.byType(MealPlanDirectoryPage)).repository,
      same(repository),
    );
  });

  testWidgets('production meal plan creation receives the authorized tenant context', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanRepository: DevelopmentMealPlanRepository(),
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      authorizedMealPlanTenantId: 'tenant-authorized-by-server',
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go('/meal-plans/new');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final wizard = tester.widget<MealPlanWizardPage>(find.byType(MealPlanWizardPage));
    expect(wizard.tenantId, 'tenant-authorized-by-server');
  });

  testWidgets('production meal plan mutation fails closed without an authorized tenant', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanRepository: DevelopmentMealPlanRepository(),
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go('/meal-plans/models/new');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminErrorScreen), findsOneWidget);
    expect(find.byKey(const Key('meal-plan-authorized-tenant-unavailable')), findsOneWidget);
    expect(find.byType(MealPlanWizardPage), findsNothing);
  });

  testWidgets('production meal plan wizard routes preserve their target identifiers', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanRepository: DevelopmentMealPlanRepository(),
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      authorizedMealPlanTenantId: 'tenant-authorized-by-server',
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final route in [
      (
        path: SuperadminRoutes.mealPlanCreate,
        mealPlanId: null,
        mealPlanModelId: null,
        isTemplate: false,
      ),
      (
        path: '/meal-plans/meal-plan-id/edit',
        mealPlanId: 'meal-plan-id',
        mealPlanModelId: null,
        isTemplate: false,
      ),
      (
        path: SuperadminRoutes.mealPlanModelCreate,
        mealPlanId: null,
        mealPlanModelId: null,
        isTemplate: true,
      ),
      (
        path: '/meal-plans/models/meal-plan-model-id/edit',
        mealPlanId: null,
        mealPlanModelId: 'meal-plan-model-id',
        isTemplate: true,
      ),
    ]) {
      router.go(route.path);
      await tester.pumpAndSettle();

      final wizard = tester.widget<MealPlanWizardPage>(find.byType(MealPlanWizardPage));
      expect(wizard.mealPlanId, route.mealPlanId, reason: route.path);
      expect(wizard.mealPlanModelId, route.mealPlanModelId, reason: route.path);
      expect(wizard.isTemplate, route.isTemplate, reason: route.path);
    }
  });
}
