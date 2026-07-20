import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginFeedback extends StatelessWidget {
  const LoginFeedback({
    required this.message,
    this.semanticLabelPrefix = 'Erro de autenticação',
    super.key,
  });

  final String message;
  final String semanticLabelPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      container: true,
      liveRegion: true,
      excludeSemantics: true,
      label: '$semanticLabelPrefix: $message',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colors.onErrorContainer, size: CoeloSize.iconSm),
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
