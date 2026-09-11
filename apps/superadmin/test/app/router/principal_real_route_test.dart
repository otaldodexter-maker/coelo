import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_now/domain/principal_now_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(1440, 900), Size(390, 844)]) {
    testWidgets('production Principal keeps its host at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = SuperadminSession()..signInForTesting();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
        principalRuntimeContextRepository: const _ContextRepository(),
        principalHappensFeedRepository: _RecordingFeedRepository(),
        principalMixedFeedRepository: _RecordingMixedFeedRepository(),
        principalNowFeedRepository: _EmptyNowRepository(),
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go(SuperadminRoutes.principalHappens);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      final host = find.byKey(const Key('superadmin-persistent-shell'));
      expect(host, findsOneWidget);
      final hostElement = tester.element(host);
      expect(
        tester
            .widget<PrincipalHappensPreviewPage>(find.byType(PrincipalHappensPreviewPage))
            .embedded,
        isTrue,
      );
      for (final path in const [
        SuperadminRoutes.principalNow,
        SuperadminRoutes.principalNowPublication,
        SuperadminRoutes.principalHappensPublish,
        SuperadminRoutes.principalMomentsPublish,
        SuperadminRoutes.principalForYou,
        SuperadminRoutes.principalMoments,
        SuperadminRoutes.principalProfile,
        SuperadminRoutes.principalHappens,
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, path);
        expect(host, findsOneWidget);
        expect(tester.element(host), same(hostElement));
        if (path == SuperadminRoutes.principalNow) {
          expect(
            tester.widget<PrincipalNowPreviewPage>(find.byType(PrincipalNowPreviewPage)).embedded,
            isTrue,
          );
          expect(find.text('Nada novo no Agora'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('real Acontece resolves authenticated context and never uses demo fixtures', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final feed = _RecordingFeedRepository();
    final mixed = _RecordingMixedFeedRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      principalHappensFeedRepository: feed,
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
    expect(page.data, same(PrincipalHappensPreviewData.empty));
    // O Acontece composto le o feed misto (posts + circulares) com o escopo real.
    expect(mixed.lastScope?.institutionId, 'institution-real');
    expect(mixed.lastScope?.unitId, 'unit-real');
    expect(mixed.lastScope?.groupId, 'group-real');
    expect(feed.lastScope, isNull);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.principalHappens);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);

    // P28: o "+" do dock publica no Acontece.
    await tester.tap(find.byKey(const Key('principal-happens-publish-now-action')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.principalHappensPublish,
    );
    expect(router.routeInformationProvider.value.uri.path, isNot(startsWith('/dev/')));

    router.go(SuperadminRoutes.principalMomentsPublish);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.principalMomentsPublish,
    );
    expect(router.routeInformationProvider.value.uri.path, isNot(startsWith('/dev/')));

    for (final path in const [
      SuperadminRoutes.principalForYou,
      SuperadminRoutes.principalMoments,
      SuperadminRoutes.principalProfile,
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(path, isNot(startsWith('/dev/')));
    }
  });

  testWidgets('real route opens the first context and offers the profile selector (P28)', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _MultipleContextRepository(),
      principalHappensFeedRepository: _RecordingFeedRepository(),
      principalMixedFeedRepository: _RecordingMixedFeedRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // P28 (Owner, 11/09): com mais de um vinculo o Principal abre no primeiro
    // e mostra o seletor de perfil (ate 5 inline, "Ver todos" em popup).
    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
    expect(find.byKey(const Key('principal-context-selector')), findsOneWidget);
    expect(find.textContaining('Instituição A'), findsWidgets);

    await tester.tap(find.byKey(const Key('principal-context-selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-context-membership-b')), findsOneWidget);
    await tester.tap(find.byKey(const Key('principal-context-membership-b')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Instituição B'), findsWidgets);
  });
}

final class _EmptyNowRepository implements PrincipalNowFeedRepository {
  @override
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope) async =>
      const [];

  @override
  Future<PrincipalNowMediaRead> resolveMedia({
    required PrincipalNowFeedScope scope,
    required String publicationId,
    required PrincipalNowMediaDescriptor media,
  }) => throw UnimplementedError();
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

final class _RecordingFeedRepository implements PrincipalHappensFeedRepository {
  PrincipalHappensFeedScope? lastScope;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async {
    lastScope = scope;
    return const [];
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) =>
      throw UnimplementedError();
}

final class _RecordingMixedFeedRepository implements PrincipalMixedFeedRepository {
  CircularScope? lastScope;

  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async {
    lastScope = scope;
    return const PrincipalHappensFeedPage(items: [], nextCursor: null);
  }
}

final class _MultipleContextRepository implements PrincipalRuntimeContextRepository {
  const _MultipleContextRepository();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => const [
    PrincipalRuntimeContext(
      membershipId: 'membership-a',
      personId: 'person-real',
      institutionId: 'institution-a',
      institutionName: 'Instituição A',
      roleCode: 'guardian',
      scopeKind: 'institution',
    ),
    PrincipalRuntimeContext(
      membershipId: 'membership-b',
      personId: 'person-real',
      institutionId: 'institution-b',
      institutionName: 'Instituição B',
      roleCode: 'guardian',
      scopeKind: 'institution',
    ),
  ];
}
