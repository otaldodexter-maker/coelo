import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';

import '../../support/activities/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('keeps one shell instance and its geometry between protected destinations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.institutions);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    final shell = find.byKey(const Key('superadmin-persistent-shell'));
    final initialState = tester.state(shell);
    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);

    router.go(SuperadminRoutes.support);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(tester.state(shell), same(initialState));
    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
  });

  testWidgets('swaps protected content without a perceptible opacity transition', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.go(SuperadminRoutes.support);
    await tester.pumpAndSettle();
    final content = find.byKey(const Key('superadmin-content-transition'));
    expect(content, findsOneWidget);
    expect(tester.widget(content), isA<KeyedSubtree>());
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
  });

  testWidgets('switches protected content immediately under reduced motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router, disableAnimations: true));
    await tester.pump();

    router.go(SuperadminRoutes.support);
    await tester.pump();
    await tester.pump();

    final content = find.byKey(const Key('superadmin-content-transition'));
    expect(content, findsOneWidget);
    expect(tester.widget(content), isA<KeyedSubtree>());
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
  });

  testWidgets('opens institution forms without route movement', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      SuperadminApp(
        session: session,
        institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
        activityDirectoryRepository: FakeActivityDirectoryRepository(),
        userPreferencesRepository: InMemoryUserPreferencesRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
    router.go(SuperadminRoutes.institutions);
    await tester.pumpAndSettle();

    router.go(SuperadminRoutes.institutionCreate);
    await tester.pump();
    await tester.pump();

    final form = find.byKey(const Key('institution-form-scroll'));
    expect(form, findsOneWidget);
    final slides = tester.widgetList<SlideTransition>(
      find.ancestor(of: form, matching: find.byType(SlideTransition)),
    );
    final fades = tester.widgetList<FadeTransition>(
      find.ancestor(of: form, matching: find.byType(FadeTransition)),
    );
    final scales = tester.widgetList<ScaleTransition>(
      find.ancestor(of: form, matching: find.byType(ScaleTransition)),
    );
    expect(slides.map((transition) => transition.position.value), everyElement(Offset.zero));
    expect(fades.map((transition) => transition.opacity.value), everyElement(1));
    expect(scales.map((transition) => transition.scale.value), everyElement(1));
  });

  testWidgets('propagates the activity footer inset through the persistent host', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.devActivityCreate);
    await tester.pumpWidget(_app(router));
    final footer = find.byKey(const Key('activity-form-footer-surface'));
    await _pumpUntilFound(tester, footer);
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    expect(launcher, findsOneWidget);
    expect(
      tester.getBottomLeft(launcher).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
    );
  });

  testWidgets('uses the wide activity frame inset inside the persistent host', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.devActivityCreate);
    await tester.pumpWidget(_app(router));
    final navigation = find.byType(SuperadminFormStepNavigation);
    await _pumpUntilFound(tester, navigation);
    final surface = find.byKey(const Key('superadmin-floating-content'));
    expect(surface, findsOneWidget);
    expect(navigation, findsOneWidget);
    final surfaceRect = tester.getRect(surface);
    final navigationRect = tester.getRect(navigation);
    expect(navigationRect.width, 248);
    expect(navigationRect.left - surfaceRect.left, closeTo(CoeloSpacing.space10, 2));
  });

  testWidgets('keeps one shell while navigating non-linearly between development routes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    final shell = find.byKey(const Key('superadmin-persistent-shell'));
    expect(shell, findsOneWidget);
    final initialState = tester.state(shell);

    Future<void> selectDestination({
      required String section,
      required String destination,
      required String expectedPath,
    }) async {
      var destinationFinder = find.byKey(Key('superadmin-navigation-$destination'));
      if (destinationFinder.evaluate().isEmpty) {
        final sectionFinder = find.byKey(Key('superadmin-navigation-section-$section'));
        await Scrollable.ensureVisible(tester.element(sectionFinder), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(sectionFinder.hitTestable());
        await tester.pumpAndSettle();
        destinationFinder = find.byKey(Key('superadmin-navigation-$destination'));
      }
      await Scrollable.ensureVisible(tester.element(destinationFinder), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(destinationFinder.hitTestable());
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, expectedPath);
      expect(tester.state(shell), same(initialState));
    }

    await selectDestination(
      section: 'access',
      destination: 'people',
      expectedPath: SuperadminRoutes.devPeople,
    );
    await selectDestination(
      section: 'monitoring',
      destination: 'daily-routine',
      expectedPath: SuperadminRoutes.devDailyRoutine,
    );
    await selectDestination(
      section: 'structure',
      destination: 'activities',
      expectedPath: SuperadminRoutes.devActivities,
    );

    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);

    final contentTransition = find.byKey(const Key('superadmin-content-transition'));
    expect(contentTransition, findsOneWidget);
    expect(tester.widget(contentTransition), isA<KeyedSubtree>());
  });

  testWidgets('keeps Principal previews inside the shell content surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(_app(router));

    for (final route in const [
      SuperadminRoutes.devPrincipalHappens,
      SuperadminRoutes.devPrincipalForYou,
      SuperadminRoutes.devPrincipalMoments,
      SuperadminRoutes.devPrincipalNow,
      SuperadminRoutes.devPrincipalProfile,
      SuperadminRoutes.devPrincipalHappensPublish,
      SuperadminRoutes.devPrincipalMomentsPublish,
      SuperadminRoutes.devPrincipalNowPublication,
    ]) {
      router.go(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final sidebar = find.byKey(const Key('superadmin-sidebar'));
      final content = find.byKey(const Key('superadmin-floating-content'));
      expect(sidebar, findsOneWidget, reason: route);
      expect(content, findsOneWidget, reason: route);
      expect(
        tester.getRect(content).left,
        greaterThan(tester.getRect(sidebar).right),
        reason: route,
      );
    }
  });

  testWidgets('injects content fixtures only in the development Notices route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devNotices);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
    expect(find.text('Volta às aulas com acolhimento'), findsWidgets);
  });

  testWidgets('keeps the development preview trigger available in conversations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.devConversations);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Abrir menu de desenvolvimento'), findsOneWidget);
  });

  testWidgets('keeps the development preview trigger available on login in development', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.login);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Abrir menu de desenvolvimento'), findsOneWidget);
  });

  testWidgets('hides the development preview trigger in production', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Abrir menu de desenvolvimento'), findsNothing);
  });

  testWidgets('routes Support and Catalog consistently from the persistent navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.unitCreate);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    Future<void> selectDestination({required String query, required String destination}) async {
      final search = find.byKey(const Key('superadmin-navigation-search'));
      await tester.enterText(search, query);
      await tester.pumpAndSettle();
      final destinationFinder = find.byKey(Key('superadmin-navigation-$destination'));
      await Scrollable.ensureVisible(tester.element(destinationFinder), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(destinationFinder.hitTestable());
      await tester.pumpAndSettle();
    }

    await selectDestination(query: 'Suporte', destination: 'support');
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.support);

    await selectDestination(query: 'Catálogo', destination: 'catalog');
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.governanceCatalog);
  });
}

GoRouter _router(SuperadminSession session) => createSuperadminRouter(
  session: session,
  login: (_) async => const LoginResult.success(),
  logout: unavailableSuperadminLogout,
  requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
  institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
  activityDirectoryRepository: FakeActivityDirectoryRepository(),
  supportController: SupportPrototypeController(),
  onThemeModeChanged: (_) {},
);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 400 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 25));
  }
  await tester.pumpAndSettle();
  expect(finder, findsOneWidget);
}

Widget _app(GoRouter router, {bool disableAnimations = false}) {
  return MaterialApp.router(
    theme: CoeloTheme.light,
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
  );
}
