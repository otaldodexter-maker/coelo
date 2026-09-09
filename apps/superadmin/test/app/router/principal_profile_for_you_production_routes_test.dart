import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_preview_page.dart';
import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_route_page.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_preview_page.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_route_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/profile_about/domain/profile_about_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../features/notices/support/fake_notice_repository.dart';

void main() {
  Future<GoRouterHarness> pumpProductionRoute(
    WidgetTester tester,
    String path, {
    PrincipalRuntimeContextRepository runtimeContextRepository = const _AuthorizedContextRepository(),
    ProfileAboutRepository? aboutRepository,
    FakeNoticeRepository? noticeRepository,
    CircularRepository? principalCircularRepository,
    Size surface = const Size(1440, 1000),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: runtimeContextRepository,
      profileAboutRepository: aboutRepository,
      principalCircularRepository: principalCircularRepository,
      noticeRepository: noticeRepository ?? const UnavailableNoticeRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(path);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    return GoRouterHarness(router);
  }

  testWidgets('real /principal-profile mounts the profile composition root', (tester) async {
    final harness = await pumpProductionRoute(
      tester,
      SuperadminRoutes.principalProfile,
      aboutRepository: _EmptyAboutRepository(),
    );

    expect(harness.location, SuperadminRoutes.principalProfile);
    expect(harness.location, isNot(startsWith('/dev/')));
    expect(find.byType(SuperadminErrorScreen), findsNothing);
    expect(find.byType(PrincipalProfileRoutePage), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-content')), findsOneWidget);
    // The production route must never borrow the preview fixture identity.
    expect(find.text('Colégio Horizonte'), findsNothing);
    expect(find.text('Turma Real'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real /principal-profile reads circulars through the Principal projection', (
    tester,
  ) async {
    // Regression guard: the Circulares tab once received the administrative
    // repository, whose listProfile answers by Superadmin permission instead of
    // the actor's Principal visibility. Widget tests never caught it because
    // they inject the repository directly, so the guard lives at the route.
    // The administrative repository stays unavailable: had the tab reached for
    // it, listProfile would have failed instead of recording a Principal read.
    final principal = _RecordingCircularRepository();
    await pumpProductionRoute(
      tester,
      SuperadminRoutes.principalProfile,
      aboutRepository: _EmptyAboutRepository(),
      principalCircularRepository: principal,
    );

    await tester.ensureVisible(find.text('Circulares'));
    await tester.tap(find.text('Circulares'));
    await tester.pumpAndSettle();

    expect(principal.scopes, isNotEmpty);
    expect(principal.scopes.first.institutionId, 'institution-real');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real /principal-profile fails closed without an authorized context', (tester) async {
    await pumpProductionRoute(
      tester,
      SuperadminRoutes.principalProfile,
      runtimeContextRepository: const _UnauthorizedContextRepository(),
      aboutRepository: _EmptyAboutRepository(),
    );

    expect(find.text('Contexto indisponível'), findsOneWidget);
    expect(find.byType(PrincipalProfileRoutePage), findsNothing);
    expect(find.byType(PrincipalProfilePreviewPage), findsNothing);
    expect(find.byKey(const Key('principal-profile-content')), findsNothing);
    expect(find.text('Colégio Horizonte'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real /principal-profile fails closed when Sobre denies the actor', (tester) async {
    await pumpProductionRoute(
      tester,
      SuperadminRoutes.principalProfile,
      aboutRepository: _UnauthorizedAboutRepository(),
    );

    expect(find.byKey(const Key('principal-profile-unauthorized')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-content')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real /principal-for-you mounts the hub with an authorized repository', (
    tester,
  ) async {
    final notices = FakeNoticeRepository()
      ..seed(
        PlatformNotice(
          type: CommunicationType.forYou,
          id: 'for-you-real',
          title: 'Orientação real',
          message: 'Conteúdo autorizado de Comunicações.',
          priority: NoticePriority.important,
          status: NoticeStatus.active,
          startsAt: DateTime.now().subtract(const Duration(days: 1)),
          endsAt: null,
          audience: NoticeAudience.everyone,
          audienceLabel: 'Todos',
          behavior: NoticeBehavior.dismissible,
          targetDevice: NoticeTargetDevice.all,
          reach: 1,
        ),
      );

    final harness = await pumpProductionRoute(
      tester,
      SuperadminRoutes.principalForYou,
      noticeRepository: notices,
      surface: const Size(768, 1024),
    );

    expect(harness.location, SuperadminRoutes.principalForYou);
    expect(harness.location, isNot(startsWith('/dev/')));
    expect(find.byType(SuperadminErrorScreen), findsNothing);
    expect(find.byType(PrincipalForYouRoutePage), findsOneWidget);
    expect(find.byType(PrincipalForYouPreviewPage), findsOneWidget);
    expect(find.byKey(const Key('principal-for-you-empty')), findsNothing);
    expect(find.text('Orientação real'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real /principal-for-you stays fail-closed without a notice repository', (
    tester,
  ) async {
    await pumpProductionRoute(
      tester,
      SuperadminRoutes.principalForYou,
      surface: const Size(768, 1024),
    );

    expect(find.byType(SuperadminErrorScreen), findsOneWidget);
    expect(find.byType(PrincipalForYouRoutePage), findsNothing);
    expect(find.byType(PrincipalForYouPreviewPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('development previews keep working after the production wiring', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      allowDevelopmentPreview: true,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPrincipalProfile);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalProfilePreviewPage), findsOneWidget);
    expect(find.byType(SuperadminErrorScreen), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.devPrincipalProfile,
    );

    router.go(SuperadminRoutes.devPrincipalForYou);
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalForYouPreviewPage), findsOneWidget);
    expect(find.byType(SuperadminErrorScreen), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalForYou);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

final class GoRouterHarness {
  const GoRouterHarness(this.router);

  final GoRouter router;

  String get location => router.routeInformationProvider.value.uri.path;
}

final class _AuthorizedContextRepository implements PrincipalRuntimeContextRepository {
  const _AuthorizedContextRepository();

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

final class _UnauthorizedContextRepository implements PrincipalRuntimeContextRepository {
  const _UnauthorizedContextRepository();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() =>
      Future.error(const PrincipalRuntimeContextUnauthorized());
}

final class _EmptyAboutRepository implements ProfileAboutRepository {
  @override
  Future<ProfileAboutPage?> load(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) async => null;

  @override
  Future<ProfileAboutSaveResult> save(
    ProfileAboutPage page, {
    required String requestId,
    Map<ProfileAboutFieldKey, String> officialUpdates = const {},
  }) => throw UnimplementedError();
}

final class _UnauthorizedAboutRepository implements ProfileAboutRepository {
  @override
  Future<ProfileAboutPage?> load(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) => Future.error(ProfileAboutUnauthorizedException());

  @override
  Future<ProfileAboutSaveResult> save(
    ProfileAboutPage page, {
    required String requestId,
    Map<ProfileAboutFieldKey, String> officialUpdates = const {},
  }) => throw UnimplementedError();
}


final class _RecordingCircularRepository implements CircularRepository {
  final List<CircularScope> scopes = [];

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) async {
    scopes.add(scope);
    return const PrincipalCursorPage(items: <CircularSummary>[], nextCursor: null);
  }

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) => _unused();

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) => _unused();

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) => _unused();

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) => _unused();

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => _unused();

  Future<T> _unused<T>() =>
      Future<T>.error(StateError('the Perfil projection only reads listProfile'));
}
