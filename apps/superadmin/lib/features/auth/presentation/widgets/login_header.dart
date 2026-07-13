import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Image.asset(
          'assets/brand/logo-coelo-orange.png',
          width: CoeloSize.avatarLg,
          height: CoeloSize.avatarLg,
          cacheWidth: 96,
          cacheHeight: 96,
          fit: BoxFit.contain,
          semanticLabel: 'Coelo',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space3,
              vertical: CoeloSpacing.space1,
            ),
            child: Text(
              'Superadmin',
              style: theme.textTheme.labelMedium?.copyWith(color: colors.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Acesse sua conta', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          'Ambiente interno da operação Coelo.',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
