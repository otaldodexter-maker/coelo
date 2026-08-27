import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('keeps the Agora preview on a dedicated development route', () {
    expect(SuperadminRoutes.devPrincipalNow, '/dev/principal-now');
    expect(SuperadminRoutes.devPrincipalNowName, 'dev-principal-now');
    expect(SuperadminRoutes.devPrincipalNowPublication, '/dev/principal-now/publication');
    expect(SuperadminRoutes.devPrincipalNowPublicationName, 'dev-principal-now-publication');
    expect(SuperadminRoutes.devPrincipalNow, isNot(SuperadminRoutes.devPrincipalHappens));
  });

  testWidgets('opens Agora from its real card and restores keyboard focus on close', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final sourceRouter = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(sourceRouter.dispose);
    addTearDown(session.dispose);
    final observer = _RecordingNavigatorObserver();
    final sourceShell = sourceRouter.configuration.routes.whereType<ShellRoute>().single;
    final observedShell = ShellRoute(
      builder: sourceShell.builder,
      routes: sourceShell.routes,
      observers: [observer],
    );
    final router = GoRouter(
      initialLocation: SuperadminRoutes.devPrincipalHappens,
      routes: [observedShell],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
    observer.reset();

    final originCard = find.byKey(const Key('principal-happens-now-card'));
    final origin = find.descendant(of: originCard, matching: find.byType(TextButton));
    expect(tester.widget<TextButton>(origin).onPressed, isNotNull);
    final focus = await _tabTo(tester, origin);
    expect(_focusIsWithin(focus, origin), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpRouteTransition(tester);
    expect(find.byType(PrincipalNowPreviewPage), findsOneWidget);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalHappens);
    expect(Navigator.of(tester.element(find.byType(PrincipalNowPreviewPage))).canPop(), isTrue);
    expect(observer.didPushCount, 1);
    expect(observer.didPopCount, 0);
    expect(observer.didRemoveCount, 0);
    expect(observer.didReplaceCount, 0);

    await tester.tap(find.byKey(const Key('principal-now-close')));
    await _pumpUntilAbsent(tester, find.byType(PrincipalNowPreviewPage));
    expect(observer.didPushCount, 1);
    expect(observer.didPopCount, 1);
    expect(observer.didRemoveCount, 0);
    expect(observer.didReplaceCount, 0);
    expect(find.byType(PrincipalNowPreviewPage), findsNothing);
    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalHappens);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('opens Momentos from its real tab and Escape restores exact focus', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPrincipalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final origin = find.byKey(const Key('principal-happens-tab-momentos'));
    final focus = await _tabTo(tester, origin);
    expect(_focusIsWithin(focus, origin), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalMomentsPreviewPage), findsOneWidget);
    expect(
      tester.widget<PrincipalMomentsPreviewPage>(find.byType(PrincipalMomentsPreviewPage)).embedded,
      isTrue,
    );
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalMomentsPreviewPage), findsNothing);
    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalHappens);
    final restoredFocus = FocusManager.instance.primaryFocus;
    expect(restoredFocus, isNotNull);
    expect(_focusIsWithin(restoredFocus!, origin), isTrue);
  });

  testWidgets('a direct Agora link closes to Acontece through the fallback', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPrincipalNow);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await _pumpRouteTransition(tester);
    expect(find.byType(PrincipalNowPreviewPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalNow);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pumpUntilAbsent(tester, find.byType(PrincipalNowPreviewPage));
    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalHappens);
  });

  testWidgets('a direct Momentos link returns to Acontece through the host shell', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPrincipalMoments);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-mobile-menu')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-navigation-search')), 'Acontece');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-principal-happens')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalHappens);
  });

  testWidgets('opens the Agora composer without replacing the viewer route', (tester) async {
    final session = SuperadminSession();
    final productionRepository = _TripwireNowPublicationRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      nowPublicationRepository: productionRepository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPrincipalNowPublication);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalNowPublicationPage), findsOneWidget);
    expect(
      tester.widget<PrincipalNowPublicationPage>(find.byType(PrincipalNowPublicationPage)).embedded,
      isTrue,
    );
    expect(find.byType(PrincipalNowPreviewPage), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.devPrincipalNowPublication,
    );
    expect(productionRepository.calls, 0);
  });
}

final class _TripwireNowPublicationRepository implements NowPublicationRepository {
  var calls = 0;

  Future<T> _fail<T>() {
    calls++;
    return Future<T>.error(StateError('production Agora repository reached from /dev'));
  }

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) => _fail();

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) =>
      _fail();

  @override
  Future<NowPublicationDraft> saveDraft(NowPublicationContext context, NowPublicationDraft draft) =>
      _fail();

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) => _fail();

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) => _fail();
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> _pumpUntilAbsent(WidgetTester tester, Finder target) async {
  await tester.pump();
  for (var attempt = 0; attempt < 8 && target.evaluate().isNotEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(target, findsNothing);
}

Future<FocusNode> _tabTo(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && _focusIsWithin(focus, target)) {
      return focus;
    }
  }
  throw TestFailure('Tab did not reach the requested control.');
}

bool _focusIsWithin(FocusNode focus, Finder target) {
  final context = focus.context;
  if (context == null) {
    return false;
  }
  final targetElements = target.evaluate().toSet();
  if (targetElements.contains(context)) {
    return true;
  }
  var matched = false;
  context.visitAncestorElements((element) {
    if (targetElements.contains(element)) {
      matched = true;
      return false;
    }
    return true;
  });
  return matched;
}

final class _RecordingNavigatorObserver extends NavigatorObserver {
  int didPushCount = 0;
  int didPopCount = 0;
  int didRemoveCount = 0;
  int didReplaceCount = 0;

  void reset() {
    didPushCount = 0;
    didPopCount = 0;
    didRemoveCount = 0;
    didReplaceCount = 0;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPushCount += 1;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPopCount += 1;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didRemoveCount += 1;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    didReplaceCount += 1;
  }
}
