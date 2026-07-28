import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloAdminChatMetric {
  const CoeloAdminChatMetric(this.label, this.value);

  final String label;
  final int value;
}

final class CoeloAdminChatContextSummary extends StatelessWidget {
  const CoeloAdminChatContextSummary({
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.collapsed,
    required this.onToggle,
    this.image,
    this.footer,
    this.toggleFocusNode,
    this.expandedToggleIcon = Icons.chevron_right,
    this.expandedToggleTooltip = 'Recolher painel contextual',
    this.collapsedToggleTooltip = 'Mostrar detalhes do contexto',
    super.key,
  }) : assert(
         metrics.length >= 2 && metrics.length <= 6,
         'O resumo contextual exige de duas a seis métricas.',
       );

  final String title;
  final String subtitle;
  final List<CoeloAdminChatMetric> metrics;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget? image;
  final Widget? footer;
  final FocusNode? toggleFocusNode;
  final IconData expandedToggleIcon;
  final String expandedToggleTooltip;
  final String collapsedToggleTooltip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (collapsed) {
          return _CollapsedSummary(
            title: title,
            horizontal: constraints.maxWidth > constraints.maxHeight,
            onToggle: onToggle,
            toggleFocusNode: toggleFocusNode,
            tooltip: collapsedToggleTooltip,
          );
        }
        return _ExpandedSummary(
          title: title,
          subtitle: subtitle,
          metrics: metrics,
          image: image,
          footer: footer,
          onToggle: onToggle,
          toggleFocusNode: toggleFocusNode,
          toggleIcon: expandedToggleIcon,
          tooltip: expandedToggleTooltip,
        );
      },
    );
  }
}

final class _ExpandedSummary extends StatelessWidget {
  const _ExpandedSummary({
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.image,
    required this.footer,
    required this.onToggle,
    required this.toggleFocusNode,
    required this.toggleIcon,
    required this.tooltip,
  });

  final String title;
  final String subtitle;
  final List<CoeloAdminChatMetric> metrics;
  final Widget? image;
  final Widget? footer;
  final VoidCallback onToggle;
  final FocusNode? toggleFocusNode;
  final IconData toggleIcon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('coelo-admin-chat-context-summary'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null) ...[
                  Semantics(
                    key: const Key('coelo-admin-chat-context-image'),
                    image: true,
                    label: 'Imagem de contexto de $title',
                    excludeSemantics: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(CoeloRadius.lg),
                      child: SizedBox.square(dimension: CoeloSize.avatarXl, child: image),
                    ),
                  ),
                  const SizedBox(width: CoeloSpacing.space3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contexto', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: CoeloSpacing.space1),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: CoeloSpacing.space1),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                IconButton(
                  key: const Key('coelo-admin-chat-context-toggle-expanded'),
                  tooltip: tooltip,
                  focusNode: toggleFocusNode,
                  onPressed: onToggle,
                  icon: Icon(toggleIcon),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: CoeloSize.touchMin * 3 + CoeloSpacing.space4,
                mainAxisExtent: MediaQuery.textScalerOf(context).scale(CoeloSize.touchMin * 4),
                mainAxisSpacing: CoeloSpacing.space2,
                crossAxisSpacing: CoeloSpacing.space2,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CoeloSpacing.space4,
                CoeloSpacing.space2,
                CoeloSpacing.space4,
                CoeloSpacing.space4,
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}

final class _CollapsedSummary extends StatelessWidget {
  const _CollapsedSummary({
    required this.title,
    required this.horizontal,
    required this.onToggle,
    required this.toggleFocusNode,
    required this.tooltip,
  });

  final String title;
  final bool horizontal;
  final VoidCallback onToggle;
  final FocusNode? toggleFocusNode;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final action = IconButton(
      key: const Key('coelo-admin-chat-context-toggle-collapsed'),
      tooltip: tooltip,
      focusNode: toggleFocusNode,
      onPressed: onToggle,
      icon: const Icon(Icons.info_outline),
    );
    return Material(
      key: const Key('coelo-admin-chat-context-summary-collapsed'),
      color: Theme.of(context).colorScheme.surface,
      shape: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      child: horizontal
          ? Row(
              children: [
                action,
                const SizedBox(width: CoeloSpacing.space1),
                Expanded(
                  child: Text(
                    'Detalhes de $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
              ],
            )
          : Center(child: action),
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final CoeloAdminChatMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '${metric.label}: ${metric.value}',
      excludeSemantics: true,
      child: Container(
        key: const Key('coelo-admin-chat-context-metric'),
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${metric.value}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: CoeloSpacing.space2),
            Text(metric.label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
