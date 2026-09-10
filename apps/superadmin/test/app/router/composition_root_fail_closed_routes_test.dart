import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('model routes stay fail-closed and Forms production routes read authorized', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final accessRepository = _TripwireAccessProfileRepository();
    final formsApi = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      accessProfileRepository: accessRepository,
      formsApi: formsApi,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in const [
      '/profile-models',
      '/profile-models/new/platform',
      '/profile-models/platform/model-1',
      '/profile-models/platform/model-1/edit',
      '/profile-models/platform/model-1/duplicate',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(find.byType(SuperadminErrorScreen), findsOneWidget, reason: path);
      expect(
        tester.widget<SuperadminErrorScreen>(find.byType(SuperadminErrorScreen)).kind,
        SuperadminErrorKind.unavailable,
        reason: path,
      );
      expect(
        find.bySemanticsLabel('Erro 503. O Coelo está temporariamente indisponível.'),
        findsOneWidget,
        reason: path,
      );
      expect(accessRepository.calls, 0, reason: path);
      expect(formsApi.calls, 0, reason: path);
    }

    // A decisao sobre esta rota mudou em 3f5449940, de 2026-09-08, "fix(forms):
    // bind normal routes and media lifetime to authorization": rotas normais de
    // Formularios passaram a fazer LEITURA AUTORIZADA, e so a midia ficou com o
    // tempo de vida amarrado a autorizacao. A asserção anterior aqui, calls == 0
    // com o painel de indisponibilidade, era de 2026-09-01 e sobreviveu sete dias
    // a decisao; forms_fail_closed_routes_test, escrito junto com a decisao,
    // afirma o contrario e passa. Duas asserções opostas sobre a mesma rota: o
    // vermelho nao dizia qual estava certa, e quem lia a falha concluia que o
    // fail-closed havia quebrado. A data fica escrita para que ninguem
    // "conserte" isto de volta.
    //
    // MEDIDO em 2026-09-10, nao inferido: a rota dispara exatamente uma leitura,
    // listFileJobs, e a pagina mostra a superficie de producao em estado de erro,
    // nao o painel de indisponibilidade. MEDIDO na mesma data, e nao assumido, que
    // a sessao deste teste
    // NAO tem capacidade de Formularios: signInForTesting concede apenas
    // permissionCodes {'platform.read'}, e withFormsAuthorization consulta
    // somente session.isAuthenticated. Ou seja, o contrato de 08/09 delega a
    // autorizacao de leitura de Formularios inteiramente ao servidor; a porta do
    // cliente e autenticacao, nao capacidade. Isso e decisao legitima, mas e
    // diferente de "o cliente verifica capacidade", e por isso fica registrado.
    router.go('/forms/form-1/files');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-operations-unavailable')), findsNothing);
    expect(formsApi.calls, 1);

    // Midia continua fail-closed de verdade, e isto foi medido junto: calls nao
    // aumenta nesta rota e o painel honesto aparece. A familia nao e uma so.
    final callsBeforeMedia = formsApi.calls;
    router.go('/forms/media/asset-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-media-unavailable')), findsOneWidget);
    expect(formsApi.calls, callsBeforeMedia);
  });
}

final class _TripwireAccessProfileRepository implements AccessProfileRepository {
  var calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls += 1;
    throw StateError('AccessProfileRepository must stay unused on fail-closed routes.');
  }
}

final class _TripwireFormsApi implements FormsApi {
  var calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls += 1;
    throw StateError('FormsApi must stay unused on fail-closed routes.');
  }
}
