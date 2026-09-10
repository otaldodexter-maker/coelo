import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/chat/data/development_chat_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// No estreito o chat administrativo mostra a conversa NO LUGAR da caixa de
/// entrada, e nao ao lado dela. Isso significa que existe exatamente um
/// caminho de volta a lista, e se ele falhar o operador fica preso na conversa
/// que a tela escolheu para ele — sem erro, sem tela vermelha e sem sintoma
/// nenhum num teste de composicao.
///
/// O que se mede aqui e o efeito operacional: no celular da para TROCAR de
/// conversa.
void main() {
  testWidgets('no estreito o operador consegue trocar de conversa', (tester) async {
    final router = _router(tester, const Size(375, 812));
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go('/communication/conversations');
    await _settle(tester);

    // Entrando, a tela ja abre uma conversa e a lista nao esta visivel.
    final primeira = _tituloDaConversaAberta(tester);
    expect(primeira, isNotNull, reason: 'nenhuma conversa aberta ao entrar no estreito');
    expect(_conversasListadas(tester), isEmpty, reason: 'a lista nao deveria dividir a tela no estreito');

    await tester.tap(find.byKey(const Key('superadmin-chat-back-to-inbox')));
    await _settle(tester);

    final listadas = _conversasListadas(tester);
    expect(listadas.length, greaterThan(1), reason: 'a volta precisa mostrar mais de uma conversa para haver troca');
    expect(
      router.routeInformationProvider.value.uri.path,
      '/communication/conversations',
      reason: 'voltar para a lista nao pode sair do chat',
    );

    // Abrir uma conversa DIFERENTE da que a tela tinha escolhido: e isso que
    // prova que o operador nao esta preso.
    final outra = listadas.firstWhere((id) => !id.endsWith(primeira!), orElse: () => listadas.last);
    await tester.tap(find.byKey(ValueKey(outra)));
    await _settle(tester);

    expect(_conversasListadas(tester), isEmpty, reason: 'abrir a conversa deveria substituir a lista no estreito');
    expect(_tituloDaConversaAberta(tester), isNotNull);
  });

  testWidgets('no largo a lista e a conversa convivem e nao ha volta a mostrar', (tester) async {
    final router = _router(tester, const Size(1440, 900));
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go('/communication/conversations');
    await _settle(tester);

    // O contraste importa: se o controle aparecesse tambem no largo, ele seria
    // ruido, e um teste que so olha o estreito nunca perceberia.
    expect(_conversasListadas(tester), isNotEmpty);
    expect(find.byKey(const Key('superadmin-chat-back-to-inbox')), findsNothing);
  });
}

GoRouter _router(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final session = SuperadminSession()..signInForTesting();
  final router = createSuperadminRouter(
    session: session,
    login: unavailableSuperadminLogin,
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    chatRepository: DevelopmentChatRepository(),
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  return router;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

List<String> _conversasListadas(WidgetTester tester) {
  final ids = <String>{};
  for (final w in tester.allWidgets) {
    final k = w.key;
    if (k is ValueKey<String> && k.value.startsWith('chat-real-conversation-')) ids.add(k.value);
  }
  return ids.toList()..sort();
}

String? _tituloDaConversaAberta(WidgetTester tester) {
  final composer = find.byKey(const Key('superadmin-chat-composer-field'));
  if (composer.evaluate().isEmpty) return null;
  for (final w in tester.allWidgets) {
    if (w is Text && (w.data ?? '').trim().isNotEmpty) {
      final d = w.data!.trim();
      if (d.length > 3 && d != 'Conversas') return d;
    }
  }
  return null;
}
