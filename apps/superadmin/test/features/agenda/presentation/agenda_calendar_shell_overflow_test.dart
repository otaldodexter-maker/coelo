import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O calendário dentro do shell, em largura de telefone.
///
/// As matrizes de `agenda_calendar_page_test.dart` montam a página sozinha e com
/// 1200 ou 1600 de altura, então a célula de dia sempre coube. Dentro do
/// `SuperadminShell`, o cabeçalho e a navegação consomem altura e a célula fica
/// com menos de 40 pixels para empilhar o número do dia e as marcas de evento.
/// Este caso cobre a composição real, com texto a 100%.
void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'calendario no shell a 375 nao transborda em ${brightness.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final session = SuperadminSession()..signInForTesting();
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

        router.go('/dev/agenda');
        await tester.pumpWidget(
          MaterialApp.router(
            theme: brightness == Brightness.dark ? CoeloTheme.dark : CoeloTheme.light,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
      // Fechado em 11/09/2026 pela decisao do Owner de 10/09
      // (agenda_calendar_light_375, A: "retangulos muito amassados"): em
      // largura compacta a celula mostra o numero do dia e marcas em linha,
      // e a largura compacta passou a ser medida pelo LayoutBuilder da pagina
      // (dentro do shell o MediaQuery nao refletia os 375). Antes, a celula
      // tinha 39,6 de altura e transbordava 4,4 px em dez celulas e 42 em uma.
    );
  }
}
