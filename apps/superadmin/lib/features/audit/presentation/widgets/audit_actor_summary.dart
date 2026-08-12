import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class AuditActorSummary extends StatelessWidget {
  const AuditActorSummary({
    required this.actorName,
    required this.actorRole,
    required this.actorContext,
    super.key,
  });

  final String actorName;
  final String actorRole;
  final String actorContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label: 'Ator $actorName, $actorRole, $actorContext',
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.person_outline_rounded, color: colors.primary),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(actorName, style: theme.textTheme.titleSmall),
                      const SizedBox(height: CoeloSpacing.space1),
                      Text(actorRole, style: theme.textTheme.bodyMedium),
                      Text(
                        actorContext,
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
