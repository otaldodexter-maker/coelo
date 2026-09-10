import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// TESTE VERMELHO PROPOSITAL. Nomeia um defeito conhecido de publicacoes-midia
/// que o dono mapeou e deliberadamente NAO corrigiu, porque a correcao e
/// afordancia visual e ele mantem o criterio de nao decidir composicao sozinho.
/// Escrito por chat-comunicacoes a pedido da coordenacao, para o bloco de
/// decisao do Owner receber prova em vez de descricao.
///
/// NAO e regressao e NAO deve ser "consertado" mexendo no teste. Ele fica verde
/// quando o feed misto passar a oferecer continuacao.
///
/// O DEFEITO: `PrincipalMixedFeedRepository.list` aceita `cursor` e `limit = 20`
/// e devolve `PrincipalHappensFeedPage(items, nextCursor)`. A tela chama `list`
/// sem cursor e guarda somente `items`, descartando o `nextCursor`. Acontece
/// mostra no maximo 20 itens e nao ha como alcancar os mais antigos, embora o
/// servidor saiba entregar.
///
/// A CONSEQUENCIA e do dono e e a que pesa: o feed e MISTO. Com teto de 20 e sem
/// paginacao, uma sequencia de publicacoes empurra Circulares para fora da
/// primeira pagina, e uma circular institucional some do Acontece sem aviso.
///
/// AVISO PARA QUEM FOR CORRIGIR, e vale mais que o teste: ao adicionar
/// paginacao, a recarga apos RETIRADA vai precisar de criterio de fronteira.
/// Recarregar so a primeira pagina trunca o que o leitor abriu; preservar tudo
/// faz o item retirado reaparecer como se existisse. O limite que funciona e o
/// CURSOR devolvido pelo servidor: dentro do alcance relido a pagina nova e a
/// autoridade, fora dele nao ha informacao nova. Isso foi descoberto em
/// chat-comunicacoes porque o caso adversarial falhou com o limite no ultimo
/// item da pagina — a distincao so aparece quando a pagina ENCOLHE.
void main() {
  testWidgets('RED: the mixed feed offers no way to reach what the server still has', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final repository = _MoreAvailableMixedFeedRepository();
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      principalRuntimeContextRepository: const _Context(),
      principalHappensFeedRepository: _EmptyFeedRepository(),
      principalMixedFeedRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // O servidor declarou que ha mais: devolveu nextCursor.
    expect(repository.calls, hasLength(1));
    expect(repository.calls.single, isNull, reason: 'a primeira leitura nao usa cursor');

    // A tela precisa oferecer alguma continuacao e, ao aciona-la, pedir a
    // proxima pagina COM o cursor. Hoje nao ha controle nenhum e a segunda
    // leitura nunca acontece: o conteudo mais antigo fica inalcancavel.
    final continuation = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != null && widget.data!.toLowerCase().contains('mais'),
    );
    expect(
      continuation,
      findsWidgets,
      reason: 'o feed misto nao oferece continuacao apesar de o servidor ter devolvido nextCursor',
    );
  });
}

final class _MoreAvailableMixedFeedRepository implements PrincipalMixedFeedRepository {
  final calls = <PrincipalHappensFeedCursor?>[];

  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async {
    calls.add(cursor);
    return PrincipalHappensFeedPage(
      items: [
        PrincipalHappensCircularItem(
          id: 'circular-1',
          publishedAt: DateTime.utc(2026, 9, 9),
          authorName: 'Institution',
          contextLabel: 'Group',
          summary: CircularSummary(
            id: 'circular-1',
            title: 'Circular autorizada',
            excerpt: 'Conteudo autorizado',
            authorName: 'Institution',
            contextLabel: 'Group',
            publishedAt: DateTime.utc(2026, 9, 9),
            attachmentCount: 0,
            questionCount: 0,
            responseState: CircularResponseState.unanswered,
          ),
        ),
      ],
      // O servidor diz que ha mais alem desta pagina.
      nextCursor: PrincipalHappensFeedCursor(
        publishedAt: DateTime.utc(2026, 9, 9),
        itemType: 'circular',
        itemId: 'circular-1',
      ),
    );
  }
}

final class _EmptyFeedRepository implements PrincipalHappensFeedRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Context implements PrincipalRuntimeContextRepository {
  const _Context();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => const [
    PrincipalRuntimeContext(
      membershipId: 'membership-real',
      personId: 'person-real',
      institutionId: 'institution-real',
      institutionName: 'Instituicao Real',
      roleCode: 'guardian',
      scopeKind: 'group',
      unitId: 'unit-real',
      unitName: 'Unidade Real',
      groupId: 'group-real',
      groupName: 'Turma Real',
    ),
  ];
}
