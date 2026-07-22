import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/app/theme/superadmin_theme_mode_scope.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('starts on guarded login with Coelo themes and router', (tester) async {
    await tester.pumpWidget(const SuperadminApp());
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

  testWidgets('disables the global theme transition when reduced motion is requested', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const SuperadminApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationStyle, same(AnimationStyle.noAnimation));
  });
}
