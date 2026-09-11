import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decisao 7 do Owner (10/09/2026): sem balao de chat em criar, editar e
/// publicar. No shell hospedeiro quem desenha o launcher e o host, entao a flag
/// da pagina embutida precisa chegar ate ele (regressao vista em Criar
/// instituicao a 1920 px, com o launcher cobrindo o botao Continuar).
void main() {
  Widget host({required bool showChatLauncher}) => MaterialApp(
    theme: CoeloTheme.light,
    home: SuperadminShell.host(
      logout: _logout,
      currentDestination: 'institutions',
      onDestinationSelected: (_) {},
      child: SuperadminShell(
        logout: _logout,
        currentDestination: 'institutions',
        showChatLauncher: showChatLauncher,
        child: const SizedBox.expand(),
      ),
    ),
  );

  testWidgets('a hosted page with showChatLauncher false hides the host launcher', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(showChatLauncher: false));
    await _settle(tester);

    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
  });

  testWidgets('a hosted page with the default flag keeps the single host launcher', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(showChatLauncher: true));
    await _settle(tester);

    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
  });

  testWidgets('leaving a page without launcher restores the host launcher', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(showChatLauncher: false));
    await _settle(tester);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);

    await tester.pumpWidget(host(showChatLauncher: true));
    await _settle(tester);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
  });

  // As paginas do Principal nao embutem um shell proprio: o hospedeiro decide
  // pelo destino (Decisao 7: Agora aberto, Momentos aberto e publicar sem balao).
  for (final destination in const [
    'principal-now',
    'principal-now-publish',
    'principal-happens-publish',
    'principal-moments',
    'principal-moments-publish',
  ]) {
    testWidgets('the host hides the launcher on $destination', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: SuperadminShell.host(
            logout: _logout,
            currentDestination: destination,
            onDestinationSelected: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      await _settle(tester);

      expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
    });
  }

  testWidgets('the host keeps the launcher on the Acontece feed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: _logout,
          currentDestination: 'principal-happens',
          onDestinationSelected: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

/// Pumps determinísticos em vez de pumpAndSettle: o hospedeiro no desktop
/// mantém animações que não assentam e o pumpAndSettle só estoura aos 10 min.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}
