import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/settings_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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

  testWidgets('uses equal theme segments with semantic hover and no gray overlay', (tester) async {
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

    final finder = find.byType(SegmentedButton<ThemeMode>);
    final segmentedButton = tester.widget<SegmentedButton<ThemeMode>>(finder);
    final colors = Theme.of(tester.element(finder)).colorScheme;

    expect(segmentedButton.expandedInsets, EdgeInsets.zero);
    expect(
      segmentedButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.primaryContainer,
    );
    expect(segmentedButton.style?.foregroundColor?.resolve({WidgetState.hovered}), colors.primary);
    expect(segmentedButton.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
  });

  testWidgets('keeps the inherited Bug popup canonical at 200 percent text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = UserPreferencesController(InMemoryUserPreferencesRepository());
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: SettingsPage(
          controller: controller,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    final submit = find.byKey(const Key('superadmin-bug-submit'));
    expect(submit, findsOneWidget);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(tester.getSize(submit).width, greaterThan(200));
  });
}
