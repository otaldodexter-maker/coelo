import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_event_form_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_events_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expõe as oito rotas locais da Agenda', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    const locations = <String>[
      SuperadminRoutes.devAgenda,
      SuperadminRoutes.devAgendaEvents,
      SuperadminRoutes.devAgendaEventCreate,
      '/dev/agenda/events/event-parents',
      '/dev/agenda/events/event-parents/edit',
      SuperadminRoutes.devAgendaRequests,
      SuperadminRoutes.devAgendaApprovals,
      SuperadminRoutes.devAgendaPermissions,
    ];
    for (final location in locations) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, location);
      expect(tester.takeException(), isNull, reason: location);
    }
  });

  testWidgets('rotas produtivas preservam composição e permanecem fail-closed', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final session = SuperadminSession()..signInForTesting();
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
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    const locations = <String>[
      SuperadminRoutes.agenda,
      SuperadminRoutes.agendaEventCreate,
      '/agenda/events/event-parents',
      '/agenda/events/event-parents/edit',
      SuperadminRoutes.agendaRequests,
      SuperadminRoutes.agendaApprovals,
      SuperadminRoutes.agendaPermissions,
    ];
    for (final location in locations) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, location, reason: location);
      if (location.endsWith('/new') || location.endsWith('/edit')) {
        expect(find.byType(AgendaEventFormPage), findsOneWidget, reason: location);
        expect(
          tester
              .widgetList<FilledButton>(find.byType(FilledButton))
              .every((button) => button.onPressed == null),
          isTrue,
          reason: location,
        );
      } else {
        expect(find.textContaining('indispon'), findsWidgets, reason: location);
      }
      if (location == '/agenda/events/event-parents') {
        expect(
          tester.widget<AgendaEventDetailPage>(find.byType(AgendaEventDetailPage)).store.items,
          isEmpty,
          reason: 'a rota produtiva não pode receber fixtures /dev',
        );
      }
      expect(tester.takeException(), isNull, reason: location);
    }
  });
}
