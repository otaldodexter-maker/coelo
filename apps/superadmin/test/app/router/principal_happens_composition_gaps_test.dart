import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_surfaces.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verificação de composição do Acontece pela ROTA REAL.
///
/// O primeiro caso prova a correcao do READ: a Circular do feed misto abre o
/// leitor Principal quando a capacidade existe e permanece honestamente
/// indisponivel quando nao existe. O segundo documenta uma divergência entre a
/// composição e o domínio, que precisa de decisão antes de virar defeito ou
/// estreitamento declarado. Nenhum dos dois aprova o comportamento atual. Os dois vivem
/// em `superadmin_router.dart`, que é arquivo reservado ao coordenador de
/// integração, então esta frente registra a evidência em vez de corrigir.
/// Quando a correção entrar, estes testes devem ser INVERTIDOS, não apagados.
void main() {
  testWidgets(
    'READ: real route projects authorized Circular without administrative navigation',
    (tester) async {
      final session = SuperadminSession()..signInForTesting();
      final mixed = _RecordingMixedFeedRepository();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        principalRuntimeContextRepository: const _GroupScopedContext(),
        principalHappensFeedRepository: _EmptyFeedRepository(),
        principalMixedFeedRepository: mixed,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);

      router.go(SuperadminRoutes.principalHappens);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      final page = tester.widget<PrincipalHappensPreviewPage>(
        find.byType(PrincipalHappensPreviewPage),
      );

      expect(page.mixedFeedRepository, same(mixed));
      expect(page.feedScope, isNull);
      expect(page.embedded, isTrue);
      expect(mixed.calls, hasLength(1));
      expect(mixed.calls.single.institutionId, 'institution-real');
      expect(mixed.calls.single.unitId, 'unit-real');
      expect(mixed.calls.single.groupId, 'group-real');
      expect(find.text('Circular autorizada'), findsOneWidget);
      // Teste INVERTIDO apos a correcao do leitor: sem a capacidade de leitura
      // composta a acao continua honestamente indisponivel, sem navegar para o
      // detalhe administrativo e sem virar um toque morto.
      final card = tester.widget<PrincipalCircularFeedCard>(find.byType(PrincipalCircularFeedCard));
      card.onOpen();
      await tester.pump();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        SuperadminRoutes.principalHappens,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('ainda não está disponível'), findsOneWidget);
      session.authorize(
        const SuperadminAuthContext(platformRoleCode: 'test-role', scopeKind: SuperadminAuthScopeKind.platform,
          permissionCodes: {'platform.read'}, aal: 'aal2'),
        sessionId: session.sessionId!,
      );
      await tester.pumpAndSettle();
      expect(mixed.calls, hasLength(2));
      expect(mixed.calls.last.institutionId, 'institution-real');
    },
  );

  testWidgets(
    'DIVERGÊNCIA: publicar no Acontece exige unidade e turma, então um ator de '
    'escopo institucional cai na composição indisponível',
    (tester) async {
      final session = SuperadminSession()..signInForTesting();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        principalRuntimeContextRepository: const _InstitutionScopedContext(),
        happensPublicationRepository: InMemoryHappensPublicationRepository(),
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);

      router.go(SuperadminRoutes.principalHappensPublish);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      // O repositório de publicação FOI fornecido; o que barra é a exigência de
      // unidade e turma não nulas. O esquema aceita publicação de escopo
      // institucional, com unit_id e group_id nulos, então a composição é mais
      // estrita que o domínio.
      expect(
        find.byType(PrincipalHappensPublicationPage),
        findsNothing,
        reason: 'observado: contexto institucional não compõe o publicador',
      );

      // Se o estreitamento for intencional para o MVP, a interface deveria
      // dizer isso em vez de devolver a mesma tela de composição indisponível
      // que sinaliza falha de configuração. Como está, o ator não distingue
      // "você não publica neste escopo" de "o app está quebrado".
    },
  );
  testWidgets(
    'DEFEITO: recusa de escopo e falha de configuração devolvem a MESMA tela, '
    'então o ator não distingue uma da outra',
    (tester) async {
      // Caso A: falha real de configuração — o repositório de publicação não
      // foi fornecido à composição.
      final brokenSession = SuperadminSession()..signInForTesting();
      final brokenRouter = createSuperadminRouter(
        session: brokenSession,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        principalRuntimeContextRepository: const _GroupScopedContext(),
        onThemeModeChanged: (_) {},
      );
      addTearDown(brokenRouter.dispose);
      addTearDown(brokenSession.dispose);

      brokenRouter.go(SuperadminRoutes.principalHappensPublish);
      await tester.pumpWidget(
        MaterialApp.router(theme: CoeloTheme.light, routerConfig: brokenRouter),
      );
      await tester.pumpAndSettle();

      final brokenScreens = tester.widgetList<SuperadminErrorScreen>(
        find.byType(SuperadminErrorScreen),
      );
      expect(brokenScreens, hasLength(1));
      final brokenKind = brokenScreens.single.kind;

      // Caso B: configuração correta, recusa legítima de escopo — o ator é
      // institucional e a composição exige unidade e turma.
      final scopedSession = SuperadminSession()..signInForTesting();
      final scopedRouter = createSuperadminRouter(
        session: scopedSession,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        principalRuntimeContextRepository: const _InstitutionScopedContext(),
        happensPublicationRepository: InMemoryHappensPublicationRepository(),
        onThemeModeChanged: (_) {},
      );
      addTearDown(scopedRouter.dispose);
      addTearDown(scopedSession.dispose);

      scopedRouter.go(SuperadminRoutes.principalHappensPublish);
      await tester.pumpWidget(
        MaterialApp.router(theme: CoeloTheme.light, routerConfig: scopedRouter),
      );
      await tester.pumpAndSettle();

      final scopedScreens = tester.widgetList<SuperadminErrorScreen>(
        find.byType(SuperadminErrorScreen),
      );
      expect(scopedScreens, hasLength(1));

      // Os dois fatos são diferentes e hoje recebem a mesma resposta.
      expect(
        scopedScreens.single.kind,
        brokenKind,
        reason: 'defeito observado: recusa de escopo usa a tela de indisponibilidade '
            'que sinaliza falha de configuração',
      );

      // Comportamento esperado depois da correção, para orientar a inversão:
      // o ator de escopo institucional deve receber uma resposta que diga que
      // ele não publica NESTE escopo, distinta da indisponibilidade técnica.
      // Se o estreitamento for revertido pelo Owner, este caso deixa de existir
      // e o teste deve ser removido junto com a regra.
    },
  );
  testWidgets(
    'DEFEITO: o mesmo beco existe em Publicar no Agora, e não só no Acontece',
    (tester) async {
      final session = SuperadminSession()..signInForTesting();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        principalRuntimeContextRepository: const _InstitutionScopedContext(),
        nowPublicationRepository: _StubNowPublicationRepository(),
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);

      router.go(SuperadminRoutes.principalNowPublication);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      // O repositório FOI fornecido. O que barra é a mesma exigência de unidade
      // e turma não nulas, e a resposta é a mesma tela de indisponibilidade.
      expect(find.byType(PrincipalNowPublicationPage), findsNothing);
      final screens = tester.widgetList<SuperadminErrorScreen>(
        find.byType(SuperadminErrorScreen),
      );
      expect(screens, hasLength(1));
      expect(
        screens.single.kind,
        SuperadminErrorKind.unavailable,
        reason: 'defeito observado: publicar no Agora repete o beco do Acontece '
            'para o ator de escopo institucional',
      );

      // Consequência de produto: a ação central do dock, "Publicar no Agora",
      // leva esse ator à tela de aplicativo quebrado. Duas rotas de publicação
      // do Principal com a mesma causa e a mesma resposta — é a superfície que
      // está errada, não um descuido pontual de uma tela.
    },
  );
}

final class _EmptyFeedRepository implements PrincipalHappensFeedRepository {
  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async =>
      const [];

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) =>
      throw UnimplementedError();
}

final class _RecordingMixedFeedRepository implements PrincipalMixedFeedRepository {
  final calls = <CircularScope>[];

  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async {
    calls.add(scope);
    return PrincipalHappensFeedPage(items: [PrincipalHappensCircularItem(
      id: 'circular-1', publishedAt: DateTime.utc(2026,9,9), authorName: 'Institution', contextLabel: 'Group',
      summary: CircularSummary(id: 'circular-1', title: 'Circular autorizada', excerpt: 'Authorized content',
        authorName: 'Institution', contextLabel: 'Group', publishedAt: DateTime.utc(2026,9,9),
        attachmentCount: 0, questionCount: 0, responseState: CircularResponseState.unanswered),
    )], nextCursor: null);
  }
}

final class _GroupScopedContext implements PrincipalRuntimeContextRepository {
  const _GroupScopedContext();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => const [
    PrincipalRuntimeContext(
      membershipId: 'membership-real',
      personId: 'person-real',
      institutionId: 'institution-real',
      institutionName: 'Instituição Real',
      roleCode: 'guardian',
      scopeKind: 'group',
      unitId: 'unit-real',
      unitName: 'Unidade Real',
      groupId: 'group-real',
      groupName: 'Turma Real',
    ),
  ];
}

final class _InstitutionScopedContext implements PrincipalRuntimeContextRepository {
  const _InstitutionScopedContext();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => const [
    PrincipalRuntimeContext(
      membershipId: 'membership-inst',
      personId: 'person-inst',
      institutionId: 'institution-real',
      institutionName: 'Instituição Real',
      roleCode: 'school_staff',
      scopeKind: 'institution',
    ),
  ];
}

final class _StubNowPublicationRepository implements NowPublicationRepository {
  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
