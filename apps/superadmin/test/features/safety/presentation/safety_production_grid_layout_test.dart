import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/data/dev/dev_child_safety_repository.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the child directory grid on the PRODUCTION `/safety` route, with
/// records.
///
/// The grid used to wrap each row in `IntrinsicHeight`, and the card contains a
/// status indicator that is a `LayoutBuilder`, which cannot answer intrinsic
/// dimensions. The screen did not overflow -- it failed to lay out, twenty
/// exceptions per width, and one record was enough to trigger it. It was fixed
/// in `089c1fafc` by measuring the row with a `Table` instead.
///
/// This is the one MVP screen that renders children's data, so the guard mounts
/// the production route rather than the `/dev` mirror, and counts the cards
/// BEFORE reading the exception: an empty grid never exercises row measurement,
/// so a green with zero cards would prove nothing about the defect this file
/// exists for.
void main() {
  for (final width in [1440.0, 1024.0, 768.0, 375.0]) {
    testWidgets('the production child directory lays out with records at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final session = SuperadminSession()..signInForTesting();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
        childSafetyController: ChildSafetyController(DevChildSafetyRepository.content()),
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);

      router.go(SuperadminRoutes.safety);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      expect(
        find.byType(SafetyChildDirectoryCard),
        findsWidgets,
        reason:
            'no card rendered at $width, so this run never exercised the row '
            'measurement the guard is about',
      );
      expect(tester.takeException(), isNull, reason: 'the grid failed to lay out at $width');

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
