import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Image.asset(
          'assets/brand/logo-coelo-orange-complete.png',
          width: CoeloSize.brandSignatureMd,
          cacheWidth: 360,
          fit: BoxFit.contain,
          color: isDark ? colors.onSurface : null,
          colorBlendMode: isDark ? BlendMode.srcIn : null,
          semanticLabel: 'Coelo',
        ),
        const SizedBox(
          key: ValueKey('superadmin-login-gap-logo-chip'),
          height: CoeloSpacing.space1,
        ),
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
        const SizedBox(
          key: ValueKey('superadmin-login-gap-chip-title'),
          height: CoeloSpacing.space2,
        ),
        Text('Acesse sua conta', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(
          key: ValueKey('superadmin-login-gap-title-subtitle'),
          height: CoeloSpacing.space1,
        ),
        Text(
          'Ambiente interno da operação Coelo.',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(
          key: ValueKey('superadmin-login-gap-subtitle-divider'),
          height: CoeloSpacing.space3,
        ),
        Divider(
          key: const ValueKey('superadmin-login-header-divider'),
          height: 1,
          color: colors.outlineVariant,
        ),
      ],
    );
  }
}
