import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_preview_page.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps Para você on a dedicated development route', () {
    expect(SuperadminRoutes.devPrincipalForYou, '/dev/principal-for-you');
    expect(SuperadminRoutes.devPrincipalForYouName, 'dev-principal-for-you');
  });

  testWidgets('opens Para você from Acontece and returns through its navigation', (tester) async {
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

    await tester.tap(find.byTooltip('Para você'));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalForYouPreviewPage), findsOneWidget);
    expect(
      tester.widget<PrincipalForYouPreviewPage>(find.byType(PrincipalForYouPreviewPage)).embedded,
      isTrue,
    );
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalForYou);

    await tester.tap(find.byKey(const Key('superadmin-mobile-menu')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-navigation-search')), 'Acontece');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-principal-happens')));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
  });

  testWidgets('opens Momentos from Para você and restores its exact origin focus', (tester) async {
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
    router.go(SuperadminRoutes.devPrincipalForYou);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    final originPage = find.byType(PrincipalForYouPreviewPage);
    final originControl = find.byKey(const Key('principal-for-you-context-trigger')).first;
    final focus = await _tabTo(tester, originControl);

    tester.widget<PrincipalForYouPreviewPage>(originPage).onOpenMoments!.call();
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalMomentsPreviewPage), findsOneWidget);
    expect(Navigator.of(tester.element(find.byType(PrincipalMomentsPreviewPage))).canPop(), isTrue);

    await tester.tap(find.byKey(const Key('principal-moments-back')));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalForYouPreviewPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalForYou);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('keeps Para você embedded in one responsive shell at 200 percent text', (
    tester,
  ) async {
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
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      router.go(SuperadminRoutes.devPrincipalForYou);
      await tester.pumpWidget(
        MaterialApp.router(
          key: ValueKey(width),
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      final page = tester.widget<PrincipalForYouPreviewPage>(
        find.byType(PrincipalForYouPreviewPage),
      );
      expect(page.embedded, isTrue, reason: '$width');
      expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
      final content = find.byKey(const Key('superadmin-content-transition'));
      expect(content, findsOneWidget);
      expect(
        find.descendant(of: content, matching: find.byType(PrincipalForYouPreviewPage)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsNothing);
      expect(find.byKey(const Key('principal-for-you-mobile-nav')), findsNothing);
      final hero = tester.getRect(find.byKey(const Key('principal-for-you-hero')));
      final heroTitle = tester.getRect(find.text('Feira Cultural hoje!'));
      final heroBody = tester.getRect(
        find.text('A partir das 16h, no pátio da unidade. Participe com sua família!'),
      );
      final heroAction = tester.getRect(find.text('Ver detalhes'));
      for (final child in [heroTitle, heroBody, heroAction]) {
        expect(child.left, greaterThanOrEqualTo(hero.left), reason: '$width');
        expect(child.right, lessThanOrEqualTo(hero.right), reason: '$width');
        expect(child.top, greaterThanOrEqualTo(hero.top), reason: '$width');
        expect(child.bottom, lessThanOrEqualTo(hero.bottom), reason: '$width');
      }
      expect(tester.takeException(), isNull, reason: '$width');

      if (width == 1440) {
        final sidebar = find.byKey(const Key('superadmin-sidebar'));
        expect(sidebar, findsOneWidget);
        expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
        expect(tester.getTopLeft(content).dx, greaterThan(tester.getTopRight(sidebar).dx));
      }
    }
  });
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
  if (context == null) return false;
  final targetElements = target.evaluate().toSet();
  if (targetElements.contains(context)) return true;
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
