import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dialogs always use a neutral untinted surface', () {
    for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
      expect(theme.dialogTheme.backgroundColor, theme.colorScheme.surface);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
    }
  });
  group('CoeloPalette', () {
    test('exposes the official brand primitives', () {
      expect(CoeloPalette.orange500, const Color(0xFFD63C00));
      expect(CoeloPalette.neutral700, const Color(0xFF3F4549));
      expect(CoeloPalette.peach100, const Color(0xFFFFE0D5));
      expect(CoeloPalette.forest500, const Color(0xFF2D8A4E));
    });
  });

  group('CoeloTheme', () {
    test('maps the official light semantic colors into ColorScheme', () {
      final scheme = CoeloTheme.light.colorScheme;

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, CoeloPalette.orange500);
      expect(scheme.onPrimary, Colors.white);
      expect(scheme.surface, CoeloPalette.neutral0);
      expect(scheme.onSurface, CoeloPalette.neutral900);
      expect(scheme.primaryContainer, CoeloPalette.orange50);
      expect(scheme.onPrimaryContainer, CoeloPalette.orange800);
    });

    test('maps the official dark semantic colors into ColorScheme', () {
      final scheme = CoeloTheme.dark.colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, CoeloPalette.orange300);
      expect(scheme.onPrimary, CoeloPalette.orange950);
      expect(scheme.surface, const Color(0xFF181C1F));
      expect(scheme.onSurface, const Color(0xFFF5F7F8));
      expect(scheme.primaryContainer, CoeloPalette.orange800);
      expect(scheme.onPrimaryContainer, CoeloPalette.peach100);
    });

    test('uses Nunito Sans and the official body scale', () {
      final textTheme = CoeloTheme.light.textTheme;

      expect(textTheme.bodyLarge?.fontFamily, 'Nunito Sans');
      expect(textTheme.bodyLarge?.fontSize, 16);
      expect(textTheme.bodyLarge?.height, 1.5);
      expect(textTheme.labelLarge?.fontWeight, FontWeight.w700);
    });

    test('exposes semantic status colors through a ThemeExtension', () {
      final status = CoeloTheme.light.extension<CoeloStatusColors>();

      expect(status?.success, const Color(0xFF18864B));
      expect(status?.successContainer, const Color(0xFFE9F7EF));
      expect(status?.warning, const Color(0xFF8A4F00));
      expect(status?.infoContainer, const Color(0xFFE6F4FA));
    });

    test('exposes approved action and overlay aliases in light and dark themes', () {
      final lightActions = CoeloTheme.light.extension<CoeloActionColors>()!;
      final darkActions = CoeloTheme.dark.extension<CoeloActionColors>()!;
      final lightOverlay = CoeloTheme.light.extension<CoeloOverlayColors>()!;
      final darkOverlay = CoeloTheme.dark.extension<CoeloOverlayColors>()!;

      expect(lightActions.actionLink, CoeloSemanticColors.lightActionLink);
      expect(lightActions.primaryPressed, CoeloPalette.orange700);
      expect(lightActions.focusRing, CoeloTheme.light.colorScheme.primary);
      expect(darkActions.actionLink, CoeloSemanticColors.darkActionLink);
      expect(darkActions.primaryPressed, CoeloPalette.orange500);
      expect(darkActions.focusRing, CoeloTheme.dark.colorScheme.primary);
      expect(lightOverlay.scrim, CoeloTheme.light.colorScheme.scrim.withValues(alpha: 0.32));
      expect(darkOverlay.scrim, CoeloTheme.dark.colorScheme.scrim.withValues(alpha: 0.32));
      expect(CoeloTheme.light.bottomSheetTheme.modalBarrierColor, lightOverlay.scrim);
      expect(CoeloTheme.dark.bottomSheetTheme.modalBarrierColor, darkOverlay.scrim);
    });

    test('copies and interpolates all action and overlay aliases', () {
      final lightActions = CoeloTheme.light.extension<CoeloActionColors>()!;
      final darkActions = CoeloTheme.dark.extension<CoeloActionColors>()!;
      final copied = lightActions.copyWith(actionLink: Colors.blue);
      final middle = lightActions.lerp(darkActions, 0.5);

      expect(copied.actionLink, Colors.blue);
      expect(copied.primaryHover, lightActions.primaryHover);
      expect(copied.primaryPressed, lightActions.primaryPressed);
      expect(copied.focusRing, lightActions.focusRing);
      expect(middle.actionLink, Color.lerp(lightActions.actionLink, darkActions.actionLink, 0.5));
      expect(
        middle.primaryPressed,
        Color.lerp(lightActions.primaryPressed, darkActions.primaryPressed, 0.5),
      );

      final lightOverlay = CoeloTheme.light.extension<CoeloOverlayColors>()!;
      final darkOverlay = CoeloTheme.dark.extension<CoeloOverlayColors>()!;
      expect(lightOverlay.copyWith(scrim: Colors.red).scrim, Colors.red);
      expect(
        lightOverlay.lerp(darkOverlay, 0.5).scrim,
        Color.lerp(lightOverlay.scrim, darkOverlay.scrim, 0.5),
      );
    });

    test('keeps established component theme mappings unchanged', () {
      for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
        final scheme = theme.colorScheme;
        final focusedBorder = theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;

        expect(focusedBorder.borderSide, BorderSide(color: scheme.primary, width: 2));
        expect(theme.filledButtonTheme.style?.backgroundColor?.resolve({}), scheme.primary);
        expect(
          theme.filledButtonTheme.style?.backgroundColor?.resolve({WidgetState.disabled}),
          scheme.surfaceContainer,
        );
        expect(theme.outlinedButtonTheme.style?.foregroundColor?.resolve({}), scheme.primary);
        expect(theme.textButtonTheme.style?.foregroundColor?.resolve({}), scheme.primary);
        expect(theme.chipTheme.backgroundColor, scheme.primaryContainer);
        expect(theme.cardTheme.color, scheme.surface);
        expect(theme.dataTableTheme.headingRowColor?.resolve({}), scheme.surfaceContainer);
        expect(
          theme.dataTableTheme.dataRowColor?.resolve({WidgetState.hovered}),
          scheme.primaryContainer,
        );
      }
    });

    test('interpolates component visuals without a brightness midpoint jump', () {
      CoeloVisualColors visualOf(ThemeData theme) => theme.extension<CoeloVisualColors>()!;

      final light = visualOf(CoeloTheme.light);
      final dark = visualOf(CoeloTheme.dark);
      final middle = visualOf(ThemeData.lerp(CoeloTheme.light, CoeloTheme.dark, 0.5));

      expect(
        middle.brandMarkBackground,
        Color.lerp(light.brandMarkBackground, dark.brandMarkBackground, 0.5),
      );
      expect(
        middle.brandMarkForeground,
        Color.lerp(light.brandMarkForeground, dark.brandMarkForeground, 0.5),
      );
      expect(middle.eggBase, Color.lerp(light.eggBase, dark.eggBase, 0.5));
      expect(middle.carrotLeaf, Color.lerp(light.carrotLeaf, dark.carrotLeaf, 0.5));
      expect(
        middle.loginCardSurfaceTint,
        Color.lerp(light.loginCardSurfaceTint, dark.loginCardSurfaceTint, 0.5),
      );
      expect(
        middle.loginCardBorder,
        BorderSide.lerp(light.loginCardBorder, dark.loginCardBorder, 0.5),
      );
    });
  });

  group('Coelo scales', () {
    test('exposes spacing, radius, motion, size, and breakpoint tokens', () {
      expect(CoeloSpacing.space4, 16);
      expect(CoeloRadius.md, 12);
      expect(CoeloMotion.standard, const Duration(milliseconds: 220));
      expect(CoeloSize.touchMin, 48);
      expect(CoeloBreakpoints.compact.maxWidth, 599);
      expect(CoeloBreakpoints.expanded.columns, 12);
    });
  });
}
