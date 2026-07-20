import 'package:flutter/material.dart';

import 'coelo_palette.dart';
import 'coelo_status_colors.dart';
import 'coelo_scales.dart';
import 'coelo_typography.dart';

abstract final class CoeloTheme {
  static final light = _buildTheme(
    colorScheme: CoeloColorSchemes.light,
    scaffoldBackgroundColor: CoeloSemanticColors.lightBackground,
    statusColors: CoeloStatusColors.light,
    actionColors: const CoeloActionColors(primaryHover: CoeloPalette.orange600),
    secondaryText: CoeloSemanticColors.lightTextSecondary,
  );

  static final dark = _buildTheme(
    colorScheme: CoeloColorSchemes.dark,
    scaffoldBackgroundColor: CoeloSemanticColors.darkBackground,
    statusColors: CoeloStatusColors.dark,
    actionColors: const CoeloActionColors(primaryHover: CoeloPalette.orange400),
    secondaryText: CoeloSemanticColors.darkTextSecondary,
  );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required CoeloStatusColors statusColors,
    required CoeloActionColors actionColors,
    required Color secondaryText,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final surface = colorScheme.surface;
    final border = colorScheme.outline;
    final borderStrong = colorScheme.outlineVariant;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      canvasColor: scaffoldBackgroundColor,
      fontFamily: CoeloTypography.fontFamily,
      textTheme: CoeloTypography.textTheme(
        primaryText: colorScheme.onSurface,
        secondaryText: secondaryText,
      ),
      extensions: <ThemeExtension<dynamic>>[
        statusColors,
        actionColors,
        CoeloSurfaceColors(
          background: scaffoldBackgroundColor,
          surface: surface,
          surfaceSubtle: colorScheme.surfaceContainer,
          surfaceRaised: colorScheme.surfaceContainerHighest,
          surfaceTint: colorScheme.surfaceTint,
          borderSubtle: border,
          borderStrong: borderStrong,
          iconMuted: secondaryText,
        ),
        CoeloShapeTokens(
          xs: CoeloRadius.xs,
          sm: CoeloRadius.sm,
          md: CoeloRadius.md,
          lg: CoeloRadius.lg,
          xl: CoeloRadius.xl,
          full: CoeloRadius.full,
        ),
      ],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: CoeloSpacing.space4),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: CoeloElevation.level0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(colorScheme.surfaceContainer),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.primaryContainer;
          }
          return null;
        }),
        dividerThickness: 1,
        headingTextStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurface,
          secondaryText: secondaryText,
        ).labelLarge,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.primaryContainer,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainer,
        secondarySelectedColor: colorScheme.secondaryContainer,
        deleteIconColor: colorScheme.onSurfaceVariant,
        labelStyle: TextStyle(
          fontFamily: CoeloTypography.fontFamily,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space3,
          vertical: CoeloSpacing.space1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.full)),
        side: BorderSide(color: border),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurface,
          secondaryText: secondaryText,
        ).titleLarge,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: CoeloSize.iconMd),
      primaryIconTheme: IconThemeData(color: colorScheme.onSurface, size: CoeloSize.iconMd),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface,
        contentTextStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurface,
          secondaryText: secondaryText,
        ).bodyMedium,
        actionTextColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.xl)),
        titleTextStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurface,
          secondaryText: secondaryText,
        ).titleLarge,
        contentTextStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurface,
          secondaryText: secondaryText,
        ).bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        showDragHandle: true,
        modalBarrierColor: colorScheme.scrim.withValues(alpha: 0.32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(CoeloRadius.xl)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colorScheme.surfaceContainer : colorScheme.surface,
        labelStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurface,
          secondaryText: secondaryText,
        ).labelMedium,
        hintStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurfaceVariant,
          secondaryText: colorScheme.onSurfaceVariant,
        ).bodyMedium,
        helperStyle: CoeloTypography.textTheme(
          primaryText: secondaryText,
          secondaryText: secondaryText,
        ).bodySmall,
        errorStyle: CoeloTypography.textTheme(
          primaryText: statusColors.error,
          secondaryText: statusColors.error,
        ).bodySmall,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space4,
          vertical: CoeloSpacing.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          borderSide: BorderSide(color: statusColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          borderSide: BorderSide(color: statusColors.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainer,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          textStyle: CoeloTypography.textTheme(
            primaryText: colorScheme.onPrimary,
            secondaryText: colorScheme.onPrimary,
          ).labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space4,
            vertical: CoeloSpacing.space3,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
          minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainer,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          textStyle: CoeloTypography.textTheme(
            primaryText: colorScheme.onPrimary,
            secondaryText: colorScheme.onPrimary,
          ).labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space4,
            vertical: CoeloSpacing.space3,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
          minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: borderStrong),
          textStyle: CoeloTypography.textTheme(
            primaryText: colorScheme.onSurface,
            secondaryText: secondaryText,
          ).labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space4,
            vertical: CoeloSpacing.space3,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
          minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: CoeloTypography.textTheme(
            primaryText: colorScheme.primary,
            secondaryText: colorScheme.primary,
          ).labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space3,
            vertical: CoeloSpacing.space2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.sm)),
          minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          CoeloTypography.textTheme(
            primaryText: colorScheme.onSurface,
            secondaryText: secondaryText,
          ).labelMedium,
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: CoeloSize.iconMd,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurface,
          secondaryText: secondaryText,
        ).labelMedium,
        unselectedLabelTextStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurfaceVariant,
          secondaryText: secondaryText,
        ).labelMedium,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.xs)),
        side: BorderSide(color: borderStrong),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStatePropertyAll(borderStrong),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        labelStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurface,
          secondaryText: secondaryText,
        ).labelLarge,
        unselectedLabelStyle: CoeloTypography.textTheme(
          primaryText: colorScheme.onSurfaceVariant,
          secondaryText: secondaryText,
        ).labelLarge,
      ),
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

@immutable
final class CoeloActionColors extends ThemeExtension<CoeloActionColors> {
  const CoeloActionColors({required this.primaryHover});

  final Color primaryHover;

  @override
  CoeloActionColors copyWith({Color? primaryHover}) {
    return CoeloActionColors(primaryHover: primaryHover ?? this.primaryHover);
  }

  @override
  CoeloActionColors lerp(ThemeExtension<CoeloActionColors>? other, double t) {
    if (other is! CoeloActionColors) {
      return this;
    }

    return CoeloActionColors(primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!);
  }
}

@immutable
final class CoeloSurfaceColors extends ThemeExtension<CoeloSurfaceColors> {
  const CoeloSurfaceColors({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.surfaceTint,
    required this.borderSubtle,
    required this.borderStrong,
    required this.iconMuted,
  });

  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color surfaceTint;
  final Color borderSubtle;
  final Color borderStrong;
  final Color iconMuted;

  @override
  CoeloSurfaceColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceRaised,
    Color? surfaceTint,
    Color? borderSubtle,
    Color? borderStrong,
    Color? iconMuted,
  }) {
    return CoeloSurfaceColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      iconMuted: iconMuted ?? this.iconMuted,
    );
  }

  @override
  CoeloSurfaceColors lerp(ThemeExtension<CoeloSurfaceColors>? other, double t) {
    if (other is! CoeloSurfaceColors) {
      return this;
    }

    return CoeloSurfaceColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
    );
  }
}

@immutable
final class CoeloShapeTokens extends ThemeExtension<CoeloShapeTokens> {
  const CoeloShapeTokens({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.full,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  @override
  CoeloShapeTokens copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? full,
  }) {
    return CoeloShapeTokens(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      full: full ?? this.full,
    );
  }

  @override
  CoeloShapeTokens lerp(ThemeExtension<CoeloShapeTokens>? other, double t) {
    if (other is! CoeloShapeTokens) {
      return this;
    }

    return CoeloShapeTokens(
      xs: xs + (other.xs - xs) * t,
      sm: sm + (other.sm - sm) * t,
      md: md + (other.md - md) * t,
      lg: lg + (other.lg - lg) * t,
      xl: xl + (other.xl - xl) * t,
      full: full + (other.full - full) * t,
    );
  }
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
