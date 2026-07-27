import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_fixtures.dart';

final class SuperadminChatContextPanel extends StatelessWidget {
  const SuperadminChatContextPanel({
    required this.conversation,
    required this.collapsed,
    required this.onToggle,
    super.key,
  });

  final SuperadminChatConversation conversation;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    assert(
      conversation.metrics.length >= 2 && conversation.metrics.length <= 6,
      'O painel contextual exige de duas a seis métricas.',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (collapsed) {
          return _CollapsedContextPanel(
            conversation: conversation,
            horizontal: constraints.maxWidth > constraints.maxHeight,
            onToggle: onToggle,
          );
        }

        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        return Container(
          key: const Key('superadmin-chat-context-panel'),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Contexto', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: CoeloSpacing.space1),
                          Text(
                            conversation.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: CoeloSpacing.space1),
                          Text(
                            conversation.context,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    IconButton(
                      tooltip: compact ? 'Voltar para a conversa' : 'Recolher painel contextual',
                      onPressed: onToggle,
                      icon: Icon(compact ? Icons.arrow_back : Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: CoeloSize.touchMin * 3 + CoeloSpacing.space4,
                    mainAxisExtent: MediaQuery.textScalerOf(context).scale(CoeloSize.touchMin * 4),
                    mainAxisSpacing: CoeloSpacing.space2,
                    crossAxisSpacing: CoeloSpacing.space2,
                  ),
                  itemCount: conversation.metrics.length,
                  itemBuilder: (context, index) {
                    return _ContextMetricCard(metric: conversation.metrics[index]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CoeloSpacing.space4,
                  CoeloSpacing.space2,
                  CoeloSpacing.space4,
                  CoeloSpacing.space4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: CoeloSize.iconSm,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(
                      child: Text(
                        'Dados simulados',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _CollapsedContextPanel extends StatelessWidget {
  const _CollapsedContextPanel({
    required this.conversation,
    required this.horizontal,
    required this.onToggle,
  });

  final SuperadminChatConversation conversation;
  final bool horizontal;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final action = IconButton(
      tooltip: 'Mostrar detalhes do contexto',
      onPressed: onToggle,
      icon: const Icon(Icons.info_outline),
    );

    return Material(
      key: const Key('superadmin-chat-context-panel-collapsed'),
      color: Theme.of(context).colorScheme.surface,
      shape: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      child: horizontal
          ? Row(
              children: [
                action,
                const SizedBox(width: CoeloSpacing.space1),
                Expanded(
                  child: Text(
                    'Detalhes de ${conversation.title}',
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

final class _ContextMetricCard extends StatelessWidget {
  const _ContextMetricCard({required this.metric});

  final SuperadminChatMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '${metric.label}: ${metric.value}',
      child: Container(
        key: const Key('chat-context-metric'),
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
