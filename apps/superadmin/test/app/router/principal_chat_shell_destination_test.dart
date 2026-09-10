import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/chat/data/development_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_superadmin/features/principal_chat/presentation/principal_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// A rota `/principal-conversations` entrou no shell persistente sem destino
/// correspondente em `_destinationForLocation`, e a folha `principal-chat` do
/// menu Principal não tinha caso em `_navigateFromPersistentShell`. As duas
/// lacunas são invisíveis em teste de composição — a tela monta certo — e só
/// aparecem quando se olha o que o shell hospedeiro sabe sobre a localização.
void main() {
  testWidgets('the Principal chat route does not offer a launcher over itself', (tester) async {
    final router = _router(tester);

    router.go(SuperadminRoutes.principalConversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // Estando no chat, o launcher flutuante que serve para abrir o chat é
    // ruído: é a mesma regra que já suprimia o launcher em /communication/
    // conversations, e depende do shell reconhecer a localização.
    expect(find.byType(SuperadminChatLauncher), findsNothing);

    // Uma rota Principal vizinha continua oferecendo o launcher, senão este
    // caso passaria por supressão global em vez de reconhecimento da rota.
    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminChatLauncher), findsOneWidget);
  });

  testWidgets('navigating to the Principal chat preserves the host shell element', (tester) async {
    final router = _router(tester);

    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    final host = find.byKey(const Key('superadmin-persistent-shell'));
    expect(host, findsOneWidget);
    final hostElement = tester.element(host);

    router.go(SuperadminRoutes.principalConversations);
    await tester.pumpAndSettle();

    // A decisao do Owner de 09/09 e que o shell hospedeiro seja PRESERVADO e a
    // experiencia Principal fique no conteiner de conteudo. Preservar significa
    // o MESMO elemento, nao um shell novo com a mesma aparencia: se ele fosse
    // reconstruido, estado do hospedeiro se perderia na navegacao.
    expect(host, findsOneWidget);
    expect(tester.element(host), same(hostElement));
    expect(tester.widget<PrincipalChatPage>(find.byType(PrincipalChatPage)).embedded, isTrue);
    expect(tester.takeException(), isNull);

    // E a volta tambem: sair do chat nao pode trocar o hospedeiro.
    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpAndSettle();
    expect(tester.element(host), same(hostElement));
  });

  for (final origin in const [
    (query: 'from=for-you', back: SuperadminRoutes.principalForYou),
    (query: 'from=profile', back: SuperadminRoutes.principalProfile),
    (query: '', back: SuperadminRoutes.principalHappens),
    (query: 'from=inventado', back: SuperadminRoutes.principalHappens),
  ]) {
    testWidgets('back from the Principal chat returns to "${origin.query}"', (tester) async {
      final router = _router(tester);
      final path = origin.query.isEmpty
          ? SuperadminRoutes.principalConversations
          : '${SuperadminRoutes.principalConversations}?${origin.query}';

      router.go(path);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('principal-chat-back')));
      await tester.pumpAndSettle();

      // Tres superficies levam para o chat do Principal. Sem o `from`, todas
      // voltavam para Acontece e quem entrou pelo Perfil perdia o lugar onde
      // estava. Origem desconhecida volta para Acontece, que e a superficie
      // inicial: um valor inesperado nao pode travar o voltar.
      expect(router.routeInformationProvider.value.uri.path, origin.back);
    });
  }

  testWidgets('the Principal menu Chat leaf reaches the Principal chat route', (tester) async {
    final router = _router(tester);

    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // A folha existe em superadmin_navigation.dart desde antes desta rota. Sem
    // caso correspondente no shell de produção ela era inerte: clicar não
    // levava a lugar nenhum e nada falhava.
    final shell = tester.widget<SuperadminShell>(
      find.byKey(const Key('superadmin-persistent-shell')),
    );
    shell.onDestinationSelected!('principal-chat');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.principalConversations,
    );
  });
}

GoRouter _router(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.reset);
  final session = SuperadminSession()..signInForTesting();
  final router = createSuperadminRouter(
    session: session,
    login: (_) async => const LoginResult.success(),
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    chatRepository: DevelopmentChatRepository(),
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  return router;
}
