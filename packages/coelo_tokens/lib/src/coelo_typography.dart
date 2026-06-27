import 'package:flutter/material.dart';

abstract final class CoeloTypography {
  static const fontFamily = 'Nunito Sans';

  static TextTheme textTheme({required Color primaryText, required Color secondaryText}) {
    const base = TextStyle(fontFamily: fontFamily, letterSpacing: 0);

    return TextTheme(
      displayLarge: base.copyWith(
        color: primaryText,
        fontSize: 48,
        height: 56 / 48,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: base.copyWith(
        color: primaryText,
        fontSize: 40,
        height: 48 / 40,
        fontWeight: FontWeight.w800,
      ),
      headlineLarge: base.copyWith(
        color: primaryText,
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: base.copyWith(
        color: primaryText,
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.copyWith(
        color: primaryText,
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.copyWith(
        color: primaryText,
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.copyWith(
        color: primaryText,
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.copyWith(
        color: primaryText,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.copyWith(
        color: secondaryText,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: base.copyWith(
        color: secondaryText,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.copyWith(
        color: primaryText,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.copyWith(
        color: primaryText,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
