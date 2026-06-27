import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
