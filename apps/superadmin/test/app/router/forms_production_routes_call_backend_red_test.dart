import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// TESTE VERMELHO PROPOSITAL. Nomeia um defeito MEDIDO, nao suspeitado.
///
/// FATOS MEDIDOS, com sonda instrumentada que CONTA chamadas em vez de apenas
/// lancar, sobre a rota de producao, com sessao autenticada e SEM capacidade de
/// Formularios:
///
///   /forms/form-1/files      -> 1 chamada  -> FormsApi.listFileJobs
///   /forms/form-1/responses  -> 2 chamadas -> FormsApi.listResponses
///
/// Nao sao chamadas abstratas: sao dois metodos de LEITURA, disparados no
/// initState so por navegar. A cadeia e `withFormsAuthorization`, que checa
/// apenas `session.isAuthenticated`, mais `_usesProductionApi`, que e verdadeiro
/// porque a rota sempre passa `api` nao nulo.
///
/// O QUE ESTE TESTE NAO AFIRMA, e isto importa tanto quanto o que ele afirma:
/// ele NAO afirma vazamento de dado. Quem decide se sai dado e o SERVIDOR, e as
/// RPCs de Formularios continuam sendo a autoridade. Se elas negarem sem
/// capacidade, nada sai e o custo e chamada inutil. O que o teste afirma e que
/// a defesa do CLIENTE nao esta segurando, e que a do servidor passou a ser a
/// unica. Ninguem deve ler este arquivo como prova de exposicao.
///
/// COMO ELE FICA VERDE: quando a rota de producao parar de compor a pagina com
/// api produtiva sem capacidade de Formularios. NAO quando alguem ajustar a
/// expectativa, trocar o metodo medido ou afrouxar a assercao — isso apagaria o
/// defeito do registro sem apaga-lo do produto.
///
/// A correcao pertence ao dono do composition root. Este arquivo e a prova,
/// escrito por chat-comunicacoes a pedido da coordenacao, sem tocar em nenhum
/// arquivo daquele recorte.
void main() {
  for (final route in const [
    (path: '/forms/form-1/files', metodo: 'listFileJobs'),
    (path: '/forms/form-1/responses', metodo: 'listResponses'),
  ]) {
    testWidgets('RED: ${route.path} calls the backend without Forms capability', (tester) async {
      final formsApi = _CountingFormsApi();
      final session = SuperadminSession()..signInForTesting();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        formsApi: formsApi,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);

      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      router.go(route.path);
      await tester.pumpAndSettle();

      expect(
        formsApi.methods,
        isNot(contains(route.metodo)),
        reason:
            'a rota ${route.path} chamou ${route.metodo} sem capacidade de Formularios; '
            'medido com sonda instrumentada em 10/09/2026',
      );
      expect(
        formsApi.calls,
        0,
        reason: 'nenhuma leitura de backend pode partir de uma rota declarada fechada',
      );
    });
  }
}

/// Conta e registra o nome do metodo antes de recusar. A versao que existia
/// apenas lancava, entao a assercao de contagem nunca chegava a ser avaliada e
/// a metade que importa ficava invisivel.
final class _CountingFormsApi implements FormsApi {
  var calls = 0;
  final methods = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls += 1;
    final name = invocation.memberName.toString();
    methods.add(name.substring(name.indexOf('"') + 1, name.lastIndexOf('"')));
    throw StateError('FormsApi must stay unused on fail-closed routes.');
  }
}
