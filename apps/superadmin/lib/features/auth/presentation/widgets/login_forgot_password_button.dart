import 'package:flutter/material.dart';

class LoginForgotPasswordButton extends StatelessWidget {
  const LoginForgotPasswordButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return colors.surface.withValues(alpha: 0);
          }
          if (states.contains(WidgetState.focused)) {
            return colors.primary.withValues(alpha: 0.12);
          }
          return null;
        }),
        textStyle: WidgetStateProperty.resolveWith((states) {
          final isEmphasized =
              states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
          return theme.textTheme.bodyMedium?.copyWith(
            decoration: isEmphasized ? TextDecoration.underline : TextDecoration.none,
            decorationColor: colors.primary,
          );
        }),
      ),
      child: const Text('Esqueci minha senha'),
    );
  }
}
