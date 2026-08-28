import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/meal_plans/data/dev/development_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_wizard_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('development meal plan routes embed one local wizard shell at 200 percent text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    expect(SuperadminRoutes.devMealPlanCreate, '/dev/meal-plans/new');
    expect(SuperadminRoutes.devMealPlanModelCreate, '/dev/meal-plans/models/new');

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        MaterialApp.router(
          key: ValueKey(width),
          theme: CoeloTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      );

      for (final path in const [
        SuperadminRoutes.devMealPlanCreate,
        SuperadminRoutes.devMealPlanModelCreate,
      ]) {
        router.go(path);
        await tester.pumpAndSettle();

        final reason = '$path at width $width';
        final shell = find.byKey(const Key('superadmin-persistent-shell'));
        expect(router.routeInformationProvider.value.uri.path, path, reason: reason);
        expect(shell, findsOneWidget, reason: reason);
        expect(
          find.descendant(of: shell, matching: find.byType(MealPlanWizardPage)),
          findsOneWidget,
          reason: reason,
        );
        for (final formComponent in [
          SuperadminFormFrame,
          SuperadminFormStepNavigation,
          SuperadminFormActionFooter,
        ]) {
          expect(
            find.descendant(of: shell, matching: find.byType(formComponent)),
            findsOneWidget,
            reason: '$formComponent: $reason',
          );
        }
        final page = tester.widget<MealPlanWizardPage>(find.byType(MealPlanWizardPage));
        expect(page.repository, isA<DevelopmentMealPlanRepository>(), reason: reason);
        expect(page.imageRepository, isA<UnavailableMealPlanImageRepository>(), reason: reason);
        expect(page.imageSelectionEnabled, isFalse, reason: reason);
        expect(find.text('Não foi possível carregar o cardápio'), findsNothing, reason: reason);
        expect(tester.takeException(), isNull, reason: '$reason with text at 200%');
      }
    }
  });
}
