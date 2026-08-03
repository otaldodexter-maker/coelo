import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares production and development activity routes', () {
    expect(SuperadminRoutes.activities, '/activities');
    expect(SuperadminRoutes.activityCreate, '/activities/new');
    expect(SuperadminRoutes.activityDetail, '/activities/:activityId');
    expect(SuperadminRoutes.activityEdit, '/activities/:activityId/edit');
    expect(SuperadminRoutes.devActivities, '/dev/activities');
    expect(SuperadminRoutes.devActivityCreate, '/dev/activities/new');
    expect(SuperadminRoutes.devActivityDetail, '/dev/activities/:activityId');
    expect(SuperadminRoutes.devActivityEdit, '/dev/activities/:activityId/edit');
  });

  testWidgets('exposes Activities as an active navigation destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selectedDestination;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'activities',
          onDestinationSelected: (destination) => selectedDestination = destination,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-navigation-activities')));
    await tester.pump();
    expect(selectedDestination, 'activities');
  });

  testWidgets('protects production and exposes development list and detail', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.activities);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.devActivities);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devActivities);
    expect(find.text('Consulte as atividades da plataforma.'), findsOneWidget);

    router.go(SuperadminRoutes.devActivityCreate);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-form-scroll')), findsOneWidget);
    expect(find.text('Criar atividade'), findsWidgets);

    router.go('/dev/activities/activity-1');
    await tester.pumpAndSettle();
    expect(find.text('Visualizar atividade'), findsOneWidget);
    expect(find.text('Editar atividade'), findsOneWidget);

    router.go('/dev/activities/activity-1/edit');
    await tester.pumpAndSettle();
    expect(find.text('Editar atividade'), findsOneWidget);
  });
}
