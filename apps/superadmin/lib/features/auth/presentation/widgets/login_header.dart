import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../../app/brand/superadmin_brand_mark.dart';
import '../../../../app/theme/superadmin_theme_mode_scope.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({
    this.title = 'Acesse sua conta',
    this.subtitle = 'Ambiente interno da operação Coelo.',
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeModeScope = SuperadminThemeModeScope.maybeOf(context);
    final requestedMode = themeModeScope?.mode;
    final isDark = switch (requestedMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system || null => theme.brightness == Brightness.dark,
    };
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final logo = SuperadminBrandMark(key: ValueKey(isDark), size: CoeloSize.brandMarkLg);

    return Column(
      children: [
        if (themeModeScope == null)
          logo
        else
          AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: logo,
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
        Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(
          key: ValueKey('superadmin-login-gap-title-subtitle'),
          height: CoeloSpacing.space1,
        ),
        Text(
          subtitle,
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
