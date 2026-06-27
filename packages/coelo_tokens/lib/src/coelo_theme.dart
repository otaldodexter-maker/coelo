import 'package:flutter/material.dart';

import 'coelo_palette.dart';
import 'coelo_status_colors.dart';
import 'coelo_typography.dart';

abstract final class CoeloTheme {
  static final light = _buildTheme(
    colorScheme: CoeloColorSchemes.light,
    scaffoldBackgroundColor: CoeloSemanticColors.lightBackground,
    statusColors: CoeloStatusColors.light,
    secondaryText: CoeloSemanticColors.lightTextSecondary,
  );

  static final dark = _buildTheme(
    colorScheme: CoeloColorSchemes.dark,
    scaffoldBackgroundColor: CoeloSemanticColors.darkBackground,
    statusColors: CoeloStatusColors.dark,
    secondaryText: CoeloSemanticColors.darkTextSecondary,
  );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required CoeloStatusColors statusColors,
    required Color secondaryText,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      fontFamily: CoeloTypography.fontFamily,
      textTheme: CoeloTypography.textTheme(
        primaryText: colorScheme.onSurface,
        secondaryText: secondaryText,
      ),
      extensions: <ThemeExtension<dynamic>>[statusColors],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
  }
}

abstract final class CoeloSemanticColors {
  static const lightBackground = Color(0xFFF7F8F8);
  static const lightSurfaceSubtle = Color(0xFFF1F3F4);
  static const lightTextSecondary = CoeloPalette.neutral600;
  static const lightTextTertiary = CoeloPalette.neutral500;
  static const lightBorderSubtle = CoeloPalette.neutral200;
  static const lightBorderStrong = CoeloPalette.neutral300;
  static const lightActionLink = CoeloPalette.orange600;

  static const darkBackground = CoeloPalette.neutral950;
  static const darkSurface = Color(0xFF181C1F);
  static const darkSurfaceSubtle = Color(0xFF202529);
  static const darkTextPrimary = Color(0xFFF5F7F8);
  static const darkTextSecondary = CoeloPalette.neutral300;
  static const darkTextTertiary = CoeloPalette.neutral400;
  static const darkBorderSubtle = CoeloPalette.neutral700;
  static const darkBorderStrong = CoeloPalette.neutral600;
  static const darkActionLink = CoeloPalette.peach300;
}

abstract final class CoeloColorSchemes {
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: CoeloPalette.orange500,
    onPrimary: Colors.white,
    primaryContainer: CoeloPalette.orange50,
    onPrimaryContainer: CoeloPalette.orange800,
    secondary: CoeloPalette.peach100,
    onSecondary: CoeloPalette.orange800,
    secondaryContainer: CoeloPalette.peach50,
    onSecondaryContainer: CoeloPalette.orange800,
    tertiary: CoeloPalette.forest500,
    onTertiary: Colors.white,
    tertiaryContainer: CoeloPalette.forest50,
    onTertiaryContainer: CoeloPalette.forest900,
    error: Color(0xFFB42318),
    onError: Colors.white,
    errorContainer: Color(0xFFFDECEA),
    onErrorContainer: Color(0xFF7A1A12),
    surface: CoeloPalette.neutral0,
    onSurface: CoeloPalette.neutral900,
    surfaceDim: CoeloSemanticColors.lightBackground,
    surfaceBright: CoeloPalette.neutral0,
    surfaceContainerLowest: CoeloPalette.neutral0,
    surfaceContainerLow: CoeloSemanticColors.lightBackground,
    surfaceContainer: CoeloSemanticColors.lightSurfaceSubtle,
    surfaceContainerHigh: CoeloPalette.neutral100,
    surfaceContainerHighest: CoeloPalette.neutral200,
    onSurfaceVariant: CoeloPalette.neutral600,
    outline: CoeloPalette.neutral300,
    outlineVariant: CoeloPalette.neutral200,
    shadow: CoeloPalette.neutral950,
    scrim: CoeloPalette.neutral950,
    inverseSurface: CoeloPalette.neutral900,
    onInverseSurface: CoeloPalette.neutral0,
    inversePrimary: CoeloPalette.orange300,
    surfaceTint: CoeloPalette.orange500,
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: CoeloPalette.orange300,
    onPrimary: CoeloPalette.orange950,
    primaryContainer: CoeloPalette.orange800,
    onPrimaryContainer: CoeloPalette.peach100,
    secondary: CoeloPalette.peach300,
    onSecondary: CoeloPalette.orange950,
    secondaryContainer: CoeloPalette.orange800,
    onSecondaryContainer: CoeloPalette.peach100,
    tertiary: CoeloPalette.forest300,
    onTertiary: Color(0xFF062A18),
    tertiaryContainer: Color(0xFF0B5A31),
    onTertiaryContainer: Color(0xFFB9F6D2),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: CoeloSemanticColors.darkSurface,
    onSurface: CoeloSemanticColors.darkTextPrimary,
    surfaceDim: CoeloPalette.neutral950,
    surfaceBright: CoeloPalette.neutral800,
    surfaceContainerLowest: CoeloPalette.neutral950,
    surfaceContainerLow: CoeloSemanticColors.darkSurface,
    surfaceContainer: CoeloSemanticColors.darkSurfaceSubtle,
    surfaceContainerHigh: CoeloPalette.neutral800,
    surfaceContainerHighest: CoeloPalette.neutral700,
    onSurfaceVariant: CoeloPalette.neutral300,
    outline: CoeloPalette.neutral600,
    outlineVariant: CoeloPalette.neutral700,
    shadow: CoeloPalette.neutral950,
    scrim: CoeloPalette.neutral950,
    inverseSurface: CoeloPalette.neutral0,
    onInverseSurface: CoeloPalette.neutral900,
    inversePrimary: CoeloPalette.orange600,
    surfaceTint: CoeloPalette.orange300,
  );
}
