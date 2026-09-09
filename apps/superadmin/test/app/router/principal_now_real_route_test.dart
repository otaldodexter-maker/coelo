import 'dart:typed_data';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_now/domain/principal_now_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Verifies the production Agora routes (`/principal-now` and
/// `/principal-now/publication`), not the `/dev` preview twins.
///
/// The regression these tests guard against is composition plumbing that stops
/// short of the widget: a repository can be built by the auth scope, forwarded
/// to `createSuperadminRouter`, and still never reach the page that needs it.
/// Every assertion below is therefore made on the widget the real route
/// actually mounts and on the calls the repository actually receives.
Widget _host(GoRouter router, ThemeData theme) => MaterialApp.router(
  theme: theme,
  routerConfig: router,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
);

void main() {
  testWidgets('agora.view: /principal-now entrega repositório e escopo do contexto autenticado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final feed = _RecordingNowFeedRepository(stories: [_story]);
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      principalNowFeedRepository: feed,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalNow);
    await tester.pumpWidget(_host(router, CoeloTheme.dark));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.principalNow);
    expect(router.routeInformationProvider.value.uri.path, isNot(startsWith('/dev/')));

    final page = tester.widget<PrincipalNowPreviewPage>(find.byType(PrincipalNowPreviewPage));
    // The capability object itself must arrive at the widget, not merely at the
    // router parameter.
    expect(page.feedRepository, same(feed));
    expect(page.feedScope?.institutionId, 'institution-real');
    expect(page.feedScope?.unitId, 'unit-real');
    expect(page.feedScope?.groupId, 'group-real');
    expect(page.embedded, isFalse);

    // And the widget must actually use it: one authorized read with the derived
    // scope, plus the remote story rendered instead of the demo fixture.
    expect(feed.scopes, hasLength(1));
    expect(feed.scopes.single.institutionId, 'institution-real');
    expect(feed.scopes.single.groupId, 'group-real');
    expect(find.text('Ciência em ação'), findsOneWidget);
    expect(find.text('Riverside School'), findsNothing);
    expect(feed.resolvedTickets, contains('ticket-1'));
  });

  testWidgets('agora.view: /principal-now falha fechado sem repositório de feed', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalNow);
    await tester.pumpWidget(_host(router, CoeloTheme.light));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalNowPreviewPage), findsNothing);
    expect(find.text('503'), findsOneWidget);
    // Never a silent fallback to the demo fixture.
    expect(find.text('Riverside School'), findsNothing);
  });

  // DEFEITO DOCUMENTADO (arquivo reservado: superadmin_router.dart).
  //
  // A rota real `/principal-happens` monta a página com
  // `data: PrincipalHappensPreviewData.empty`, cujo `nowItems` é vazio. O
  // trilho "Agora" da Acontece é alimentado por esse fixture e nunca pelo
  // `principalNowFeedRepository`, então nenhum `_NowCard` é construído e o
  // callback `onOpenNow` — a ÚNICA ligação para `principalNowName` em todo o
  // app — jamais dispara. `/principal-now` só existe como deep link.
  //
  // Este teste registra o comportamento ATUAL. Ele deve ser invertido quando a
  // Acontece real passar a projetar as histórias do Agora.
  testWidgets('DEFEITO ATUAL: a Acontece real não expõe card algum para abrir o Agora', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final feed = _RecordingNowFeedRepository(stories: [_story]);
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      principalHappensFeedRepository: _EmptyHappensFeedRepository(),
      principalNowFeedRepository: feed,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpWidget(_host(router, CoeloTheme.light));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);

    // O trilho existe e o card de publicar está lá...
    expect(find.text('Agora'), findsWidgets);
    expect(find.byKey(const Key('principal-happens-publish-now-action')), findsOneWidget);
    // ...mas não há nenhum card de história para abrir o visualizador.
    expect(find.byKey(const Key('principal-happens-now-card')), findsNothing);
    // E o repositório real do Agora não é lido em nenhum momento pela Acontece.
    expect(feed.scopes, isEmpty);
  });

  // DEFEITO DOCUMENTADO (arquivo reservado: superadmin_router.dart, linhas
  // 750-751). O builder real de `/principal-now` fixa o retorno em
  // `context.goNamed(principalHappensName)` para `onClose` e `onOpenHappens`,
  // enquanto a rota `/dev` equivalente usa `_closePrincipalViewer`, que faz
  // `pop()` quando há pilha. Com `go`, a origem é remontada em vez de
  // restaurada: o feed da Acontece é relido e o foco/scroll da origem se perde.
  testWidgets('DEFEITO ATUAL: fechar o Agora real remonta a Acontece em vez de retornar a ela', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final happens = _EmptyHappensFeedRepository();
    final feed = _RecordingNowFeedRepository(stories: [_story]);
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      principalHappensFeedRepository: happens,
      principalNowFeedRepository: feed,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpWidget(_host(router, CoeloTheme.dark));
    await tester.pumpAndSettle();
    expect(happens.reads, 1);

    // Empilha o visualizador como faria `onOpenNow` se houvesse card.
    router.push(SuperadminRoutes.principalNow);
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalNowPreviewPage), findsOneWidget);
    final readsBeforeClose = happens.reads;

    await tester.tap(find.byKey(const Key('principal-now-close')));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.principalHappens);
    // Comportamento atual: `go` descarta a pilha e remonta a origem, relendo o
    // feed. Com `pop` (correção pedida) `happens.reads` ficaria inalterado.
    expect(happens.reads, greaterThan(readsBeforeClose));
  });

  testWidgets('agora.create: /principal-now/publication monta o compositor com contexto real', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RecordingNowPublicationRepository();
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      principalHappensFeedRepository: _EmptyHappensFeedRepository(),
      nowPublicationRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    // Entry through the real Acontece action, not a direct deep link.
    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpWidget(_host(router, CoeloTheme.light));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-publish-now-action')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.principalNowPublication,
    );
    expect(find.byType(PrincipalNowPublicationPage), findsOneWidget);

    final page = tester.widget<PrincipalNowPublicationPage>(
      find.byType(PrincipalNowPublicationPage),
    );
    expect(page.repository, same(repository));
    expect(page.embedded, isFalse);
    final publicationContext = page.publicationContext;
    expect(publicationContext.tenantId, 'institution-real');
    expect(publicationContext.institutionId, 'institution-real');
    expect(publicationContext.unitId, 'unit-real');
    expect(publicationContext.groupId, 'group-real');
    expect(publicationContext.institutionName, 'Instituição Real');
    expect(publicationContext.unitName, 'Unidade Real');
    expect(publicationContext.groupName, 'Turma Real');
    expect(publicationContext, isNot(same(NowPublicationContext.demo)));
    expect(publicationContext.institutionId, isNot(NowPublicationContext.demo.institutionId));

    // The widget must actually exercise the repository with that context.
    expect(repository.loadContexts, hasLength(1));
    expect(repository.loadContexts.single.groupId, 'group-real');
    expect(find.text('Adicionar mídia'), findsOneWidget);
  });

  testWidgets('agora.create: /principal-now/publication falha fechado sem repositório', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalNowPublication);
    await tester.pumpWidget(_host(router, CoeloTheme.light));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalNowPublicationPage), findsNothing);
    expect(find.text('503'), findsOneWidget);
    expect(find.text('Colégio Coelo'), findsNothing);
  });

  testWidgets('agora.create: contexto sem turma ativa não monta o compositor', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _InstitutionOnlyContextRepository(),
      nowPublicationRepository: _RecordingNowPublicationRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalNowPublication);
    await tester.pumpWidget(_host(router, CoeloTheme.light));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalNowPublicationPage), findsNothing);
    expect(find.text('503'), findsOneWidget);
  });

  testWidgets('agora.publish: publica pelo compositor real e retorna para o Agora real', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final feed = _RecordingNowFeedRepository(stories: [_story]);
    final repository = _RecordingNowPublicationRepository(
      draft: NowPublicationDraft(
        id: 'publication-real',
        version: 3,
        caption: 'Passeio da turma',
        audiences: const {NowAudience.families},
        media: NowMediaDraft(
          localId: 'media-real',
          name: 'foto.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList(const [1, 2, 3]),
          remoteAssetId: 'asset-real',
        ),
      ),
    );
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      principalNowFeedRepository: feed,
      nowPublicationRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalNowPublication);
    await tester.pumpWidget(_host(router, CoeloTheme.dark));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalNowPublicationPage), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    final publish = find.widgetWithText(FilledButton, 'Publicar agora');
    expect(publish, findsOneWidget);
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await tester.pumpAndSettle();

    // The publish command reached the repository with the server-derived scope.
    expect(repository.publishedContexts, hasLength(1));
    expect(repository.publishedContexts.single.institutionId, 'institution-real');
    expect(repository.publishedContexts.single.unitId, 'unit-real');
    expect(repository.publishedContexts.single.groupId, 'group-real');
    expect(repository.publishedDrafts.single.id, 'publication-real');
    expect(repository.publishedDrafts.single.audiences, {NowAudience.families});
    // No blind re-upload of an asset already stored remotely.
    expect(repository.uploadedMedia, isEmpty);

    // And the completion callback landed on the real viewer, which reloaded.
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.principalNow);
    expect(find.byType(PrincipalNowPreviewPage), findsOneWidget);
    expect(feed.scopes, isNotEmpty);
    expect(feed.scopes.last.groupId, 'group-real');
  });

  testWidgets('agora.publish: o compositor real só oferece o público Famílias', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RecordingNowPublicationRepository();
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      nowPublicationRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalNowPublication);
    await tester.pumpWidget(_host(router, CoeloTheme.light));
    await tester.pumpAndSettle();

    final page = tester.widget<PrincipalNowPublicationPage>(
      find.byType(PrincipalNowPublicationPage),
    );
    // Declared MVP baseline: `list_my_principal_contexts` does not project the
    // server-authorized audiences, so the route narrows the client surface to
    // Famílias and the composer offers exactly that one chip. Widening the
    // route constant alone would not widen the UI.
    expect(page.publicationContext.allowedAudiences, {NowAudience.families});
    expect(NowAudience.values, hasLength(4));
  });
}

final class _ContextRepository implements PrincipalRuntimeContextRepository {
  const _ContextRepository();

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

final class _InstitutionOnlyContextRepository implements PrincipalRuntimeContextRepository {
  const _InstitutionOnlyContextRepository();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => const [
    PrincipalRuntimeContext(
      membershipId: 'membership-institution',
      personId: 'person-real',
      institutionId: 'institution-real',
      institutionName: 'Instituição Real',
      roleCode: 'guardian',
      scopeKind: 'institution',
    ),
  ];
}

final class _EmptyHappensFeedRepository implements PrincipalHappensFeedRepository {
  var reads = 0;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async {
    reads += 1;
    return const [];
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) =>
      throw UnimplementedError();
}

final class _RecordingNowFeedRepository implements PrincipalNowFeedRepository {
  _RecordingNowFeedRepository({this.stories = const []});

  final List<PrincipalNowFeedItem> stories;
  final scopes = <PrincipalNowFeedScope>[];
  final resolvedTickets = <String>[];

  @override
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope) async {
    scopes.add(scope);
    return stories;
  }

  @override
  Future<PrincipalNowMediaRead> resolveMedia({
    required PrincipalNowFeedScope scope,
    required String publicationId,
    required PrincipalNowMediaDescriptor media,
  }) async {
    resolvedTickets.add(media.readTicket);
    return PrincipalNowMediaRead(
      signedUrl: 'https://signed.test/${media.readTicket}',
      mimeType: media.mimeType,
      kind: media.kind,
      expiresIn: const Duration(seconds: 60),
    );
  }
}

final class _RecordingNowPublicationRepository implements NowPublicationRepository {
  _RecordingNowPublicationRepository({this.draft});

  final NowPublicationDraft? draft;
  final loadContexts = <NowPublicationContext>[];
  final publishedContexts = <NowPublicationContext>[];
  final publishedDrafts = <NowPublicationDraft>[];
  final uploadedMedia = <String>[];

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) async {
    loadContexts.add(context);
    return draft;
  }

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async => draft.copyWith(id: draft.id ?? 'publication-saved', version: draft.version + 1);

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) async {
    uploadedMedia.add(media.localId);
    return media.copyWith(remoteAssetId: 'asset-${media.localId}');
  }

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) async => audio.copyWith(remoteAssetId: 'audio-${audio.localId}');

  @override
  Future<NowPublication> publish(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async {
    publishedContexts.add(context);
    publishedDrafts.add(draft);
    return NowPublication(id: draft.id ?? 'publication-real', publishAt: draft.publishAt);
  }
}

final _story = PrincipalNowFeedItem(
  publicationId: 'publication-1',
  author: 'Colégio Coelo',
  authorInitials: 'CC',
  contextLabel: 'Turma Real',
  timeLabel: '2 h',
  caption: 'Ciência em ação',
  publishedAt: DateTime.utc(2026, 9, 9, 10),
  expiresAt: DateTime.utc(2026, 9, 10, 10),
  media: const PrincipalNowMediaDescriptor(
    readTicket: 'ticket-1',
    mimeType: 'image/webp',
    kind: PrincipalNowMediaKind.media,
  ),
);
