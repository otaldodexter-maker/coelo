import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares only production access profile routes', () {
    expect(SuperadminRoutes.profiles, '/profiles');
    expect(SuperadminRoutes.profileCreate, '/profiles/new/:domain');
    expect(SuperadminRoutes.profileDetail, '/profiles/:domain/:profileId');
    expect(SuperadminRoutes.profileModels, '/profile-models');
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

  testWidgets('deep-link creation selects visible profile parents', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    for (final entry in <String, String>{
      '/profiles/new/platform': 'profiles',
      '/profile-models/new/platform': 'profile-models',
    }.entries) {
      router.go(entry.key);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final destination = find.byKey(Key('superadmin-navigation-${entry.value}'));
      expect(destination, findsOneWidget, reason: entry.key);
      final container = tester.widget<Container>(destination);
      expect(
        (container.decoration! as BoxDecoration).color,
        Theme.of(tester.element(destination)).colorScheme.primaryContainer,
        reason: entry.key,
      );
    }
  });

  testWidgets('invalid or Principal write domains render not found', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go('/profiles/principal/profile-id');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('404'), findsOneWidget);
    expect(find.text('Não encontramos a página que você procura.'), findsOneWidget);
  });
}
