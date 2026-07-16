import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginThemeToggleButton extends StatelessWidget {
  const LoginThemeToggleButton({required this.onThemeModeChanged, super.key});

  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: isDark ? 'Mudar para tema claro' : 'Mudar para tema escuro',
      child: IconButton.outlined(
        key: const ValueKey('superadmin-login-theme-toggle'),
        tooltip: isDark ? 'Tema claro' : 'Tema escuro',
        style: IconButton.styleFrom(
          minimumSize: const Size.square(CoeloSize.touchMin),
          maximumSize: const Size.square(CoeloSize.touchMin),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          onThemeModeChanged(isDark ? ThemeMode.light : ThemeMode.dark);
        },
        icon: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          size: CoeloSize.iconSm,
        ),
      ),
    );
  }
}
