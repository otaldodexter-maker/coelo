import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginSecurityNotice extends StatelessWidget {
  const LoginSecurityNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: CoeloSize.iconSm, color: colors.onPrimaryContainer),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(
              child: Text(
                'Acesso restrito à equipe autorizada. Ações sensíveis podem ser auditadas.',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
