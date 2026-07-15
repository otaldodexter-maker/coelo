import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginSubmitButton extends StatelessWidget {
  const LoginSubmitButton({required this.isLoading, required this.onPressed, super.key});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final primaryHover = theme.extension<CoeloActionColors>()?.primaryHover ?? colors.primary;

    return SizedBox(
      width: double.infinity,
      height: CoeloSize.touchMin,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.surfaceContainer;
            }
            if (states.contains(WidgetState.hovered)) {
              return primaryHover;
            }
            return colors.primary;
          }),
          foregroundColor: WidgetStatePropertyAll(colors.onPrimary),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return colors.onPrimary.withValues(alpha: 0);
            }
            if (states.contains(WidgetState.focused)) {
              return colors.onPrimary.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
        child: isLoading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: CoeloSize.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: CoeloSpacing.space2),
                  Text('Entrando...'),
                ],
              )
            : const Text('Entrar'),
      ),
    );
  }
}
