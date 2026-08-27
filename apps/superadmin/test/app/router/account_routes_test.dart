import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/domain/user_preferences.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/settings_page.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares protected profile and settings locations', () {
    expect(SuperadminRoutes.profile, '/profile');
    expect(SuperadminRoutes.settings, '/settings');
  });

  testWidgets('dev settings uses an isolated in-memory controller', (tester) async {
    final session = SuperadminSession();
    final productionRepository = _TrackingPreferencesRepository();
    final production = UserPreferencesController(productionRepository);
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      userPreferencesController: production,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(production.dispose);

    router.go(SuperadminRoutes.devSettings);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SettingsPage>(find.byType(SettingsPage)).controller,
      isNot(same(production)),
    );
    expect(productionRepository.loadCalls, 0);
    expect(productionRepository.saveCalls, 0);

    await tester.tap(find.byKey(const Key('settings-theme-dark')));
    await tester.pumpAndSettle();
    expect(productionRepository.loadCalls, 0);
    expect(productionRepository.saveCalls, 0);
  });

  testWidgets('production settings lazily loads its injected controller once', (tester) async {
    final session = SuperadminSession()..signIn();
    final productionRepository = _TrackingPreferencesRepository();
    final production = UserPreferencesController(productionRepository);
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      userPreferencesController: production,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(production.dispose);

    expect(productionRepository.loadCalls, 0);
    router.go(SuperadminRoutes.settings);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(productionRepository.loadCalls, 1);
    expect(tester.widget<SettingsPage>(find.byType(SettingsPage)).controller, same(production));
  });
}

final class _TrackingPreferencesRepository implements UserPreferencesRepository {
  int loadCalls = 0;
  int saveCalls = 0;
  UserPreferences value = const UserPreferences();

  @override
  Future<UserPreferences> load() async {
    loadCalls += 1;
    return value;
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    saveCalls += 1;
    value = preferences;
  }
}
