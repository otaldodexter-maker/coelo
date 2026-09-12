import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/chat/data/development_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/features/principal_chat/presentation/principal_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the Principal messages launcher opens the Principal composition', (tester) async {
    final router = _router(tester);

    router.go(SuperadminRoutes.devPrincipalConversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.devPrincipalConversations,
    );
    // A superfície Principal deixou de ser a página administrativa: a rota
    // monta a composição da família Principal, e `?from=principal` some.
    expect(find.byType(PrincipalChatPage), findsOneWidget);
    expect(find.byType(SuperadminChatPage), findsNothing);
    expect(router.routeInformationProvider.value.uri.queryParameters['from'], isNull);
  });

  testWidgets('the Principal composition returns to the surface that opened it', (tester) async {
    final router = _router(tester);

    router.go(SuperadminRoutes.devPrincipalConversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('principal-chat-back')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalHappens);
  });

  testWidgets('the protected Principal chat route requires a session', (tester) async {
    final router = _router(tester);

    router.go(SuperadminRoutes.principalConversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });

  testWidgets('the protected Principal chat route fails closed without a repository', (
    tester,
  ) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    session.signInForTesting();

    router.go(SuperadminRoutes.principalConversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // Sem repository produtivo a rota não monta uma superfície sem backend
    // autorizado: falha fechada, como as demais rotas Principal reais.
    expect(find.byType(PrincipalChatPage), findsNothing);
  });

  testWidgets('the protected Principal chat route uses the injected repository', (tester) async {
    final session = SuperadminSession();
    final repository = DevelopmentChatRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
      chatRepository: repository,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    session.signInForTesting();

    router.go(SuperadminRoutes.principalConversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final page = tester.widget<PrincipalChatPage>(find.byType(PrincipalChatPage));
    expect(identical(page.chatRepository, repository), isTrue);
    expect(page.chatRepository, isNot(isA<UnavailableChatRepository>()));
  });
}

GoRouter _router(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final session = SuperadminSession();
  final router = createSuperadminRouter(
    session: session,
    login: unavailableSuperadminLogin,
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    allowDevelopmentPreview: true,
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  return router;
}
