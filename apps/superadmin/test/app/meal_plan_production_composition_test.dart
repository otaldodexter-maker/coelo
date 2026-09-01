import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/data/dev/development_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_directory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('app forwards meal plan adapters to the production router', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = DevelopmentMealPlanRepository();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      SuperadminApp(
        session: session,
        mealPlanRepository: repository,
        mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
        authorizedMealPlanTenantId: 'tenant-authorized-by-server',
        userPreferencesRepository: InMemoryUserPreferencesRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
    router.go(SuperadminRoutes.mealPlans);
    await tester.pumpAndSettle();

    expect(find.byType(MealPlanDirectoryPage), findsOneWidget);
    expect(
      tester.widget<MealPlanDirectoryPage>(find.byType(MealPlanDirectoryPage)).repository,
      same(repository),
    );
  });
}
