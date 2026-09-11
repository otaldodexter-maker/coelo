import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../domain/platform_notice.dart';

final class CommunicationTypeBadge extends StatelessWidget {
  const CommunicationTypeBadge({required this.type, super.key});

  final CommunicationType type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (type) {
      CommunicationType.notice => (
        Icons.campaign_outlined,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      CommunicationType.content => (
        Icons.article_outlined,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      CommunicationType.highlight => (
        Icons.star_outline_rounded,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      CommunicationType.forYou => (
        Icons.favorite_border_rounded,
        colors.surfaceContainerHighest,
        colors.onSurface,
      ),
    };
    return Semantics(
      label: 'Tipo: ${type.label}${type == CommunicationType.notice ? ', popup' : ''}',
      // Altura propria: dentro de uma celula esticada da tabela do composto a
      // pastilha nao pode crescer com a linha (achado R05, ui-19).
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          key: Key('communication-type-badge-${type.storageValue}'),
          width: 120,
          height: CoeloSpacing.space8,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space2,
              vertical: CoeloSpacing.space1,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(CoeloRadius.full),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: CoeloSize.iconSm, color: foreground),
                const SizedBox(width: CoeloSpacing.space1),
                Flexible(
                  child: Text(
                    type.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
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
