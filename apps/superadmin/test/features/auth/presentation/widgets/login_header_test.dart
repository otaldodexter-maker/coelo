import 'package:coelo_superadmin/app/theme/superadmin_theme_mode_scope.dart';
import 'package:coelo_superadmin/features/auth/presentation/widgets/login_header.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('D01 reduced motion completes auth brand theme changes without animation', (
    tester,
  ) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          // Isolate the header transition from the host app's theme animation.
          themeAnimationDuration: Duration.zero,
          theme: mode == ThemeMode.light ? CoeloTheme.light : CoeloTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SuperadminThemeModeScope(
              mode: mode,
              onChanged: (_) {},
              // The header needs no Material ancestor. A Scaffold would add
              // its own animated physical model and default text style.
              child: const LoginHeader(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
      expect(find.byKey(const Key('superadmin-brand-mark')), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    }
  });

  testWidgets('uses the official circular brand assets in light and dark themes', (tester) async {
    for (final configuration in [
      (
        theme: CoeloTheme.light,
        mode: ThemeMode.light,
        asset: 'assets/brand/logo-coelo-white.svg',
        background: CoeloPalette.orange500,
      ),
      (
        theme: CoeloTheme.dark,
        mode: ThemeMode.dark,
        asset: 'assets/brand/logo-coelo-orange.svg',
        background: CoeloPalette.neutral0,
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: configuration.theme,
          home: SuperadminThemeModeScope(
            mode: configuration.mode,
            onChanged: (_) {},
            child: const Scaffold(body: LoginHeader()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mark = tester.widget<Container>(find.byKey(const Key('superadmin-brand-mark')));
      final decoration = mark.decoration! as BoxDecoration;
      final logo = tester.widget<SvgPicture>(find.byKey(const Key('superadmin-brand-logo')));
      final loader = logo.bytesLoader as SvgAssetLoader;

      expect(tester.getSize(find.byKey(const Key('superadmin-brand-mark'))), const Size.square(80));
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, configuration.background);
      expect(loader.assetName, configuration.asset);
      expect(logo.colorFilter, isNull);
      expect(logo.semanticsLabel, 'Coelo');
    }
  });
}
