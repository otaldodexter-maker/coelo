import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares production and development access profile routes', () {
    expect(SuperadminRoutes.profiles, '/profiles');
    expect(SuperadminRoutes.profileCreate, '/profiles/new/:domain');
    expect(SuperadminRoutes.profileDetail, '/profiles/:domain/:profileId');
    expect(SuperadminRoutes.devProfiles, '/dev/profiles');
  });

  testWidgets('exposes Profiles as an active navigation destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'profiles',
          onDestinationSelected: (value) => selected = value,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final destination = find.byKey(const Key('superadmin-navigation-profiles'));
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    expect(selected, 'profiles');
  });

  testWidgets('production is protected and dev uses demonstration fixtures', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      accessProfileRepository: FakeAccessProfileRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.profiles);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.devProfiles);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devProfiles);
    expect(find.text('Perfis e permissões'), findsWidgets);
    expect(find.byKey(const Key('access-profile-demo-notice')), findsOneWidget);
  });

  testWidgets('invalid or Principal write domains render not found', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go('/dev/profiles/principal/profile-id');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('404'), findsOneWidget);
    expect(find.text('Não encontramos a página que você procura.'), findsOneWidget);
  });
}
