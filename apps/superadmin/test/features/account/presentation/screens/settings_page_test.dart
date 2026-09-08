import 'dart:ui' as ui;

import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/domain/user_preferences.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/settings_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('375px theme labels stay on one line with the bundled Nunito Sans font', (
    tester,
  ) async {
    final font = FontLoader('Nunito Sans')
      ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
    await font.load();
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = UserPreferencesController(InMemoryUserPreferencesRepository());
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
    await tester.pumpAndSettle();
    for (final segment in ['system', 'light', 'dark']) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(Key('settings-theme-$segment')),
      );
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        textAlign: paragraph.textAlign,
        locale: paragraph.locale,
        textWidthBasis: paragraph.textWidthBasis,
        textHeightBehavior: paragraph.textHeightBehavior,
      );
      addTearDown(painter.dispose);
      painter.layout(maxWidth: paragraph.size.width);
      expect(painter.computeLineMetrics(), hasLength(1), reason: '$segment label at 375px');
    }
  });

  testWidgets('app settings retains keyboard focus across theme transitions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FailOncePreferencesRepository();
    await _openAppSettings(tester, repository);
    final light = find.byKey(const Key('settings-theme-light'));
    final dark = find.byKey(const Key('settings-theme-dark'));
    await _tabTo(tester, light);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(repository.stored.themeMode, ThemeMode.light);
    expect(_isFocused(tester, light), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_isFocused(tester, dark), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(repository.stored.themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(dark)).brightness, Brightness.dark);
    expect(_isFocused(tester, dark), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final motion = find.byKey(const Key('settings-reduce-motion'));
    expect(_isFocused(tester, motion), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(repository.stored.reduceMotion, isTrue);
    expect(repository.saves, 3);
    expect(tester.takeException(), isNull);
  });

  for (final systemReduceMotion in [false, true]) {
    testWidgets('app settings combines local motion toggle with system=$systemReduceMotion', (
      tester,
    ) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
        disableAnimations: systemReduceMotion,
      );
      addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final repository = _FailOncePreferencesRepository();
      await _openAppSettings(tester, repository);
      final motion = find.byKey(const Key('settings-reduce-motion'));
      await tester.ensureVisible(motion);
      await tester.pumpAndSettle();

      void expectMotion(bool local) {
        final effective = local || systemReduceMotion;
        expect(repository.stored.reduceMotion, local);
        expect(MediaQuery.disableAnimationsOf(tester.element(motion)), effective);
        final animation = tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationStyle;
        if (effective) {
          expect(animation, same(AnimationStyle.noAnimation));
        } else {
          expect(animation?.duration, const Duration(milliseconds: 420));
        }
      }

      expectMotion(false);
      await _semanticTap(tester, motion);
      expectMotion(true);
      await _semanticTap(tester, motion);
      expectMotion(false);
      expect(repository.saves, 2);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('semantic actions persist theme and toggle motion once at 200% dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FailOncePreferencesRepository();
      final controller = UserPreferencesController(repository);
      addTearDown(controller.dispose);
      await controller.load();
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

      final theme = find.byKey(const Key('settings-theme-dark'));
      expect(tester.getSemantics(theme).getSemanticsData().label, contains('Escuro'));
      await _semanticTap(tester, theme);
      expect(repository.stored.themeMode, ThemeMode.dark);
      expect(repository.saves, 1);

      final motion = find.byKey(const Key('settings-reduce-motion'));
      await tester.ensureVisible(motion);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(motion).getSemanticsData().label, contains('Reduzir animações'));
      await _semanticTap(tester, motion);
      expect(repository.stored.reduceMotion, isTrue);
      expect(repository.saves, 2);
      expect(
        tester.getSemantics(motion).getSemanticsData().flagsCollection.isToggled,
        ui.Tristate.isTrue,
      );
      await _semanticTap(tester, motion);
      expect(repository.stored.reduceMotion, isFalse);
      expect(repository.saves, 3);
      expect(
        tester.getSemantics(motion).getSemanticsData().flagsCollection.isToggled,
        ui.Tristate.isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Tab reaches theme and motion controls and keyboard persists each intent once', (
    tester,
  ) async {
    final repository = _FailOncePreferencesRepository();
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
    await tester.pumpAndSettle();

    await _tabTo(tester, find.byKey(const Key('settings-theme-dark')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(repository.stored.themeMode, ThemeMode.dark);
    expect(repository.saves, 1);

    final motion = find.byKey(const Key('settings-reduce-motion'));
    await _tabTo(tester, motion);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(repository.stored.reduceMotion, isTrue);
    expect(repository.saves, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(repository.stored.reduceMotion, isFalse);
    expect(repository.saves, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading exposes no preference controls before device values are available', (
    tester,
  ) async {
    final repository = _FailOncePreferencesRepository();
    final controller = UserPreferencesController(repository);
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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
    expect(find.byKey(const Key('settings-reduce-motion')), findsNothing);
    expect(repository.saves, 0);
    await controller.load();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await _semanticTap(tester, find.byKey(const Key('settings-theme-dark')));
    expect(repository.stored.themeMode, ThemeMode.dark);
    expect(repository.saves, 1);
  });

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

  testWidgets('reduced motion switch exposes its accessible name', (tester) async {
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
    final control = find.byKey(const Key('settings-reduce-motion'));
    await tester.scrollUntilVisible(control, 240);
    final accessibleLabel = tester.getSemantics(control).getSemanticsData().label;
    expect(RegExp('Reduzir animações').allMatches(accessibleLabel), hasLength(1));
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

Future<void> _semanticTap(WidgetTester tester, Finder finder) async {
  final node = tester.getSemantics(finder);
  expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
  tester.binding.performSemanticsAction(
    ui.SemanticsActionEvent(
      type: ui.SemanticsAction.tap,
      viewId: tester.view.viewId,
      nodeId: node.id,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAppSettings(WidgetTester tester, UserPreferencesRepository repository) async {
  final session = SuperadminSession()..signInForTesting();
  addTearDown(session.dispose);
  await tester.pumpWidget(SuperadminApp(session: session, userPreferencesRepository: repository));
  await tester.pumpAndSettle();
  final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
  (material.routerConfig! as GoRouter).go('/settings');
  await tester.pumpAndSettle();
  expect(find.byType(SettingsPage), findsOneWidget);
}

bool _isFocused(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData().flagsCollection.isFocused == ui.Tristate.isTrue;

Future<void> _tabTo(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    if (_isFocused(tester, finder)) {
      return;
    }
  }
  fail('Keyboard traversal did not reach $finder');
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
