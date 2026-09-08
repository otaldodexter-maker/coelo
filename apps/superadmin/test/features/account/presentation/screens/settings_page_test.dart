import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/domain/user_preferences.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/settings_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final saving in [false, true]) {
        testWidgets('failure layout width=$width dark=$dark saving=$saving at text 200%', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final repository = _FailOncePreferencesRepository(failLoad: !saving, failSave: saving);
          final controller = UserPreferencesController(repository);
          addTearDown(controller.dispose);
          if (saving) {
            await controller.load();
            await expectLater(controller.setThemeMode(ThemeMode.dark), throwsA(isA<Exception>()));
          } else {
            await expectLater(controller.load(), throwsA(isA<Exception>()));
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? CoeloTheme.dark : CoeloTheme.light,
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
          expect(
            find.text(saving ? 'Tentar salvar novamente' : 'Tentar novamente'),
            findsOneWidget,
          );
        });
      }
    }
  }

  testWidgets('failed device save stays honest and retries the latest selection', (tester) async {
    final repository = _FailOncePreferencesRepository(failSave: true);
    final controller = UserPreferencesController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SettingsPage(
          controller: controller,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-theme-dark')));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar as preferências neste dispositivo.'), findsOneWidget);
    expect(repository.stored.themeMode, ThemeMode.system);
    await tester.tap(find.text('Tentar salvar novamente'));
    await tester.pumpAndSettle();
    expect(repository.stored.themeMode, ThemeMode.dark);
    expect(find.text('Não foi possível salvar as preferências neste dispositivo.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed device load offers a visible retry instead of an endless spinner', (
    tester,
  ) async {
    final repository = _FailOncePreferencesRepository(failLoad: true);
    final controller = UserPreferencesController(repository);
    addTearDown(controller.dispose);
    await expectLater(controller.load(), throwsA(isA<Exception>()));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SettingsPage(
          controller: controller,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('Não foi possível carregar as preferências deste dispositivo.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-theme-dark')), findsOneWidget);
    expect(controller.loaded, isTrue);
    expect(repository.loads, 2);
    expect(tester.takeException(), isNull);
  });

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
}

final class _FailOncePreferencesRepository implements UserPreferencesRepository {
  _FailOncePreferencesRepository({this.failLoad = false, this.failSave = false});
  final bool failLoad;
  final bool failSave;
  int loads = 0;
  int saves = 0;
  UserPreferences stored = const UserPreferences();

  @override
  Future<UserPreferences> load() async {
    if (++loads == 1 && failLoad) throw Exception('synthetic load failure');
    return stored;
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    if (++saves == 1 && failSave) throw Exception('synthetic save failure');
    stored = preferences;
  }
}
