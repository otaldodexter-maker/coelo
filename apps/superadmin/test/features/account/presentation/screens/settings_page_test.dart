import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/settings_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('persists theme and reduced motion selections', (tester) async {
    final repository = InMemoryUserPreferencesRepository();
    final controller = UserPreferencesController(repository);
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SettingsPage(
          controller: controller,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-theme-dark')));
    await tester.scrollUntilVisible(find.byKey(const Key('settings-reduce-motion')), 240);
    await tester.tap(find.byKey(const Key('settings-reduce-motion')));
    await tester.pumpAndSettle();

    expect((await repository.load()).themeMode, ThemeMode.dark);
    expect((await repository.load()).reduceMotion, isTrue);
  });

  testWidgets('uses a neutral reduced motion row without a hover surface', (tester) async {
    final controller = UserPreferencesController(InMemoryUserPreferencesRepository());
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SettingsPage(
          controller: controller,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('settings-reduce-motion-row'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.byType(SwitchListTile)), findsNothing);
    expect(find.descendant(of: row, matching: find.byType(InkWell)), findsNothing);
    expect(find.byKey(const Key('settings-reduce-motion')), findsOneWidget);
  });
}
