import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../catalog/catalog_sync_status.dart';

final class CatalogStaleBanner extends StatelessWidget {
  const CatalogStaleBanner({required this.report, super.key});

  final CatalogSyncReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.isStale) {
      return const SizedBox.shrink();
    }
    final statusColors = Theme.of(context).extension<CoeloStatusColors>()!;
    return Semantics(
      key: const Key('catalog-stale-banner'),
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: statusColors.warningContainer,
          border: Border.all(color: statusColors.warning),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: statusColors.warning,
                semanticLabel: 'Aviso',
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Componente implementado; índice e catálogo desatualizados.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: statusColors.onWarningContainer),
                    ),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      'catálogo desatualizado',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: statusColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
