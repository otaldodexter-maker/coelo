import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/profile_page.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/settings_page.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    final brightness = width < 1024 ? Brightness.light : Brightness.dark;
    final themeName = brightness.name;

    testWidgets('profile $width $themeName', (tester) async {
      await _setViewport(tester, width);
      final activities = SuperadminActivityController();
      final controller = AccountController(
        repository: InMemoryAccountProfileRepository(),
        activities: activities,
      );
      await controller.load();
      addTearDown(() {
        controller.dispose();
        activities.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          darkTheme: CoeloTheme.dark,
          themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: ProfilePage(
            controller: controller,
            logout: () async => const LogoutResult.success(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ProfilePage),
        matchesGoldenFile('goldens/profile_${width.round()}_$themeName.png'),
      );
    });

    testWidgets('settings $width $themeName', (tester) async {
      await _setViewport(tester, width);
      final controller = UserPreferencesController(InMemoryUserPreferencesRepository());
      await controller.load();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          darkTheme: CoeloTheme.dark,
          themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: SettingsPage(
            controller: controller,
            logout: () async => const LogoutResult.success(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SettingsPage),
        matchesGoldenFile('goldens/settings_${width.round()}_$themeName.png'),
      );
    });
  }
}

Future<void> _setViewport(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, width < 768 ? 920 : 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
