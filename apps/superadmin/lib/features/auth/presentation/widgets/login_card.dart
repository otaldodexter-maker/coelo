import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginCard extends StatelessWidget {
  const LoginCard({required this.isCompact, required this.child, super.key});

  final bool isCompact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visual = theme.extension<CoeloVisualColors>();
    final isLight = theme.brightness == Brightness.light;

    return Card(
      color: colors.surface,
      surfaceTintColor: visual?.loginCardSurfaceTint ?? (isLight ? colors.surface : null),
      elevation: CoeloElevation.level1,
      shadowColor: visual?.loginCardShadow ?? (isLight ? colors.shadow.withValues(alpha: 0.08) : null),
      shape: visual == null && !isLight
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              side: visual?.loginCardBorder ?? BorderSide.none,
            ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? CoeloSpacing.space6 : CoeloSpacing.space8),
        child: child,
      ),
    );
  }
}
