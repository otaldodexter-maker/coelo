import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
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

  testWidgets('renders authenticated support with the active destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.support);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(SupportPage), findsOneWidget);
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-navigation-support')), findsOneWidget);
  });

  testWidgets('protects dev support without a session', (tester) async {
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.devSupport);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
    expect(find.byType(SupportPage), findsNothing);
  });

  testWidgets('keeps reports and navigation in one injected support session', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
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

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-governance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-support')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.support);

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-institutions')));
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
