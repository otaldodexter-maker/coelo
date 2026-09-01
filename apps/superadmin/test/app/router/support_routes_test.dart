import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_superadmin/features/support/presentation/screens/support_page.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('redirects an unauthenticated support route to login', (tester) async {
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.support);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });

  testWidgets('fails closed when authenticated support has no production backend', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.support);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminErrorScreen), findsOneWidget);
    expect(find.byType(SupportPage), findsNothing);
    expect(find.byKey(const Key('support-page-content')), findsNothing);
    expect(find.byKey(const Key('superadmin-navigation-support')), findsOneWidget);
  });

  testWidgets('opens dev support without a session', (tester) async {
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.devSupport);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devSupport);
    expect(find.byType(SupportPage), findsOneWidget);
  });

  testWidgets('dev support never reuses the injected production controller', (tester) async {
    final session = SuperadminSession();
    final production = SupportPrototypeController(initialTickets: const <SupportTicket>[]);
    final router = _router(session, supportController: production);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(production.dispose);
    router.go(SuperadminRoutes.devSupport);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SupportPage>(find.byType(SupportPage)).controller,
      isNot(same(production)),
    );
    expect(production.tickets, isEmpty);
  });

  testWidgets('keeps reports and navigation in one injected support session', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final supportController = SupportPrototypeController(initialTickets: const <SupportTicket>[]);
    final router = _router(session, supportController: supportController);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(supportController.dispose);
    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('superadmin-bug-description')),
      'Table order is wrong',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-bug-submit')));
    await tester.pumpAndSettle();
    expect(supportController.tickets, hasLength(1));
    expect(supportController.tickets.single.description, 'Table order is wrong');

    await tester.enterText(find.byKey(const Key('superadmin-navigation-search')), 'Suporte');
    await tester.pumpAndSettle();
    final support = find.byKey(const Key('superadmin-navigation-support'));
    await tester.tap(support.hitTestable());
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.support);

    await tester.enterText(find.byKey(const Key('superadmin-navigation-search')), 'Instituições');
    await tester.pumpAndSettle();
    final institutions = find.byKey(const Key('superadmin-navigation-institutions'));
    await tester.tap(institutions.hitTestable());
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.institutions);
  });
}

GoRouter _router(SuperadminSession session, {SupportPrototypeController? supportController}) {
  return createSuperadminRouter(
    session: session,
    login: (_) async => const LoginResult.success(),
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
    supportController: supportController,
    onThemeModeChanged: (_) {},
  );
}
