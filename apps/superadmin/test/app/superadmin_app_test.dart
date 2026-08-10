import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/app/theme/superadmin_theme_mode_scope.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('starts on guarded login with Coelo themes and router', (tester) async {
    await tester.pumpWidget(
      SuperadminApp(userPreferencesRepository: InMemoryUserPreferencesRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesse sua conta'), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.routerConfig, isA<GoRouter>());
    expect(
      (app.routerConfig! as GoRouter).routeInformationProvider.value.uri.path,
      SuperadminRoutes.login,
    );
    expect(app.theme?.colorScheme.primary, CoeloPalette.orange500);
    expect(app.darkTheme?.colorScheme.primary, CoeloPalette.orange300);
    expect(app.theme?.scaffoldBackgroundColor, app.theme?.colorScheme.surface);
    expect(app.darkTheme?.scaffoldBackgroundColor, app.darkTheme?.colorScheme.surface);
    expect(
      app.theme?.dataTableTheme.dataRowColor?.resolve(<WidgetState>{WidgetState.hovered}),
      app.theme?.colorScheme.primaryContainer,
    );
    expect(app.themeMode, ThemeMode.system);
    expect(app.themeAnimationStyle?.duration, const Duration(milliseconds: 420));
    expect(app.themeAnimationStyle?.curve, Curves.easeInOut);
    expect(
      tester.widget<SuperadminThemeModeScope>(find.byType(SuperadminThemeModeScope)).mode,
      ThemeMode.system,
    );
  });

  testWidgets('uses instantaneous page transitions on every target platform in light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(
      SuperadminApp(userPreferencesRepository: InMemoryUserPreferencesRepository()),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.text('Acesse sua conta'));
    const child = SizedBox(key: Key('instant-page-child'));
    final route = MaterialPageRoute<void>(builder: (_) => child);
    addTearDown(route.dispose);

    for (final theme in [app.theme!, app.darkTheme!]) {
      for (final platform in TargetPlatform.values) {
        final builder = theme.pageTransitionsTheme.builders[platform]!;
        final result = builder.buildTransitions<void>(
          route,
          context,
          const AlwaysStoppedAnimation<double>(0.5),
          const AlwaysStoppedAnimation<double>(0.25),
          child,
        );
        expect(result, same(child), reason: '${theme.brightness} transition on $platform');
      }
    }
  });

  testWidgets('disables the global theme transition when reduced motion is requested', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      SuperadminApp(userPreferencesRepository: InMemoryUserPreferencesRepository()),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationStyle, same(AnimationStyle.noAnimation));
  });

  testWidgets('reverses an in-flight theme transition from the requested mode', (tester) async {
    await tester.pumpWidget(
      SuperadminApp(userPreferencesRepository: InMemoryUserPreferencesRepository()),
    );
    await tester.pumpAndSettle();

    void requestTheme(ThemeMode mode) => tester
        .widget<SuperadminThemeModeScope>(find.byType(SuperadminThemeModeScope))
        .onChanged(mode);
    requestTheme(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    requestTheme(ThemeMode.light);
    await tester.pumpAndSettle();

    expect(
      tester.widget<SuperadminThemeModeScope>(find.byType(SuperadminThemeModeScope)).mode,
      ThemeMode.light,
    );
    expect(Theme.of(tester.element(find.text('Acesse sua conta'))).brightness, Brightness.light);

    requestTheme(ThemeMode.dark);
    await tester.pumpAndSettle();
    requestTheme(ThemeMode.light);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    requestTheme(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(
      tester.widget<SuperadminThemeModeScope>(find.byType(SuperadminThemeModeScope)).mode,
      ThemeMode.dark,
    );
    expect(Theme.of(tester.element(find.text('Acesse sua conta'))).brightness, Brightness.dark);
  });
}
