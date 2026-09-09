import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/chat/data/development_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O launcher de conversas expõe um badge de não lidas alimentado por
/// `SuperadminShell.chatUnreadCountLoader`. A vertical inteira existia — RPC,
/// método de repositório, parâmetro do shell e renderização — mas nenhum caller
/// fornecia o parâmetro, então o badge era sempre zero. Estes casos prendem a
/// fiação nos shells construídos pelo router, que é o que esta rodada corrigiu.
///
/// Escopo honesto: existem ~60 construções de `SuperadminShell` em `lib/`, a
/// maioria dentro das próprias páginas de feature, e essas continuam sem o
/// loader. O badge só é alimentado onde o shell vem do router. A correção geral
/// é arquitetural (um escopo herdado que forneça o loader) e atinge todas as
/// frentes; está registrada como pendência, não como resolvida.
void main() {
  testWidgets('the real route feeds the launcher badge from the injected repository', (
    tester,
  ) async {
    final repository = DevelopmentChatRepository();
    final expected = await repository.fetchUnreadTotal();
    expect(expected, greaterThan(0), reason: 'a fixture precisa ter não lidas para provar algo');

    // `/notices` é construída por `productionOperationalPage`, um dos shells
    // que o router monta — e portanto um dos corrigidos.
    final shells = await _shellsAt(tester, SuperadminRoutes.notices, repository: repository);

    expect(shells, isNotEmpty);
    for (final shell in shells) {
      expect(shell.chatUnreadCountLoader, isNotNull);
      expect(await shell.chatUnreadCountLoader!(), expected);
    }
  });

  testWidgets('an unavailable repository makes the launcher claim no count at all', (tester) async {
    // Sem repositório autorizado o loader precisa ser nulo: `Unavailable`
    // devolve 0, e um zero silencioso afirmaria "não há não lidas".
    final shells = await _shellsAt(tester, SuperadminRoutes.notices);

    expect(shells, isNotEmpty);
    for (final shell in shells) {
      expect(shell.chatUnreadCountLoader, isNull);
    }
  });

  testWidgets('the dev conversations preview exercises the same media dependencies', (
    tester,
  ) async {
    final session = SuperadminSession();
    final reader = _RecordingMediaReader();
    final mediaSession = MediaSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      allowDevelopmentPreview: true,
      mediaReader: reader,
      mediaSession: mediaSession,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devConversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final page = tester.widget<SuperadminChatPage>(find.byType(SuperadminChatPage));
    // Uma preview que não exerce a capacidade vira evidência falsa.
    expect(identical(page.mediaReader, reader), isTrue);
    expect(identical(page.mediaSession, mediaSession), isTrue);
  });
}

final class _RecordingMediaReader implements MediaReader {
  @override
  Future<MediaReadResult> read(MediaReadRequest request) =>
      Future<MediaReadResult>.error(UnimplementedError());
}

Future<List<SuperadminShell>> _shellsAt(
  WidgetTester tester,
  String location, {
  DevelopmentChatRepository? repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final session = SuperadminSession()..signInForTesting();
  final router = createSuperadminRouter(
    session: session,
    login: (_) async => const LoginResult.success(),
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    chatRepository: repository ?? const UnavailableChatRepository(),
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);

  router.go(location);
  await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
  await tester.pumpAndSettle();
  return tester.widgetList<SuperadminShell>(find.byType(SuperadminShell)).toList();
}
