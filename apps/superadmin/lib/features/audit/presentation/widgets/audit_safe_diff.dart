import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Renders values already allowlisted and masked by the audit backend.
final class AuditSafeDiff extends StatelessWidget {
  const AuditSafeDiff({required this.title, required this.values, super.key});

  final String title;
  final Map<String, Object?> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label: title,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: CoeloSpacing.space3),
              if (values.isEmpty)
                Text(
                  'Sem valores registrados.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                )
              else
                for (final entry in values.entries) ...[
                  Text(entry.key, style: theme.textTheme.labelMedium),
                  const SizedBox(height: CoeloSpacing.spaceHalf),
                  SelectableText('${entry.value ?? '—'}'),
                  if (entry.key != values.keys.last) const SizedBox(height: CoeloSpacing.space3),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
