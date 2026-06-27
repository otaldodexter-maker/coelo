import 'package:flutter/material.dart';

@immutable
final class CoeloStatusColors extends ThemeExtension<CoeloStatusColors> {
  const CoeloStatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  static const light = CoeloStatusColors(
    success: Color(0xFF18864B),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFE9F7EF),
    onSuccessContainer: Color(0xFF0D5C32),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDECEA),
    onErrorContainer: Color(0xFF7A1A12),
    warning: Color(0xFF8A4F00),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFF3D6),
    onWarningContainer: Color(0xFF6A3A00),
    info: Color(0xFF0B6E99),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFE6F4FA),
    onInfoContainer: Color(0xFF064B69),
  );

  static const dark = CoeloStatusColors(
    success: Color(0xFF62D394),
    onSuccess: Color(0xFF062A18),
    successContainer: Color(0xFF0B5A31),
    onSuccessContainer: Color(0xFFB9F6D2),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    warning: Color(0xFFFFB95C),
    onWarning: Color(0xFF3E2700),
    warningContainer: Color(0xFF6E4300),
    onWarningContainer: Color(0xFFFFDEA5),
    info: Color(0xFF7DD0F2),
    onInfo: Color(0xFF003546),
    infoContainer: Color(0xFF00506C),
    onInfoContainer: Color(0xFFBEE9FA),
  );

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  @override
  CoeloStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return CoeloStatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  CoeloStatusColors lerp(ThemeExtension<CoeloStatusColors>? other, double t) {
    if (other is! CoeloStatusColors) {
      return this;
    }

    return CoeloStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer: Color.lerp(onErrorContainer, other.onErrorContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}
