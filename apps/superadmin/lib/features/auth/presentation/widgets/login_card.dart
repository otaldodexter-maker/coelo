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

    return Card(
      color: colors.surface,
      surfaceTintColor: theme.brightness == Brightness.light ? colors.surface : null,
      elevation: CoeloElevation.level1,
      child: Padding(
        padding: EdgeInsets.all(isCompact ? CoeloSpacing.space6 : CoeloSpacing.space8),
        child: child,
      ),
    );
  }
}
