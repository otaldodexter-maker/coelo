import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginSubmitButton extends StatelessWidget {
  const LoginSubmitButton({required this.isLoading, required this.onPressed, super.key});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: CoeloSize.touchMin,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
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
