import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Título e subtítulo de página do Superadmin (cabeçalho do shell).
///
/// [singleLine] corta com reticências no desktop; no compacto o texto quebra.
final class SuperadminPageHeading extends StatelessWidget {
  const SuperadminPageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.singleLine = true,
  });

  final String title;
  final String subtitle;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: singleLine ? 1 : null,
          overflow: singleLine ? TextOverflow.ellipsis : null,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: CoeloSpacing.space1),
        Text(
          subtitle,
          maxLines: singleLine ? 1 : null,
          overflow: singleLine ? TextOverflow.ellipsis : null,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
