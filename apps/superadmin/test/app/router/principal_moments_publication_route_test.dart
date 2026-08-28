import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps Momentos publication on a dedicated development route', () {
    expect(SuperadminRoutes.devPrincipalMomentsPublish, '/dev/principal-moments/publish');
    expect(SuperadminRoutes.devPrincipalMomentsPublishName, 'dev-principal-moments-publish');
  });

  testWidgets('embeds the canonical Momentos form in one shell at 200 percent text', (
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
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPrincipalMomentsPublish);
    for (final width in [375.0, 1440.0]) {
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
      await tester.pumpAndSettle();

      final shell = find.byKey(const Key('superadmin-persistent-shell'));
      expect(shell, findsOneWidget, reason: 'width $width');
      expect(
        find.descendant(of: shell, matching: find.byType(PrincipalMomentsPublicationPage)),
        findsOneWidget,
        reason: 'width $width',
      );
      for (final formComponent in [
        SuperadminFormFrame,
        SuperadminFormStepNavigation,
        SuperadminFormActionFooter,
      ]) {
        expect(
          find.descendant(of: shell, matching: find.byType(formComponent)),
          findsOneWidget,
          reason: '$formComponent at width $width',
        );
      }
      expect(tester.takeException(), isNull, reason: 'width $width at 200% text');
    }
  });
}
