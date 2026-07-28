import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';

final class SuperadminChatContextPanel extends StatelessWidget {
  const SuperadminChatContextPanel({
    required this.conversation,
    required this.onClose,
    this.compact = false,
    super.key,
  });

  final SuperadminChatConversation conversation;
  final VoidCallback onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Material(
      key: const Key('superadmin-chat-context-panel'),
      color: colors.surface,
      child: SafeArea(
        left: false,
        child: ListView(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          children: [
            Row(
              children: [
                Expanded(child: Text('Contexto', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Fechar contexto',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Center(
              child: SuperadminChatAvatar(
                label: conversation.title,
                initials: conversation.initials,
                size: CoeloSize.touchMin + CoeloSpacing.space4,
                online: conversation.kind == ChatContextKind.person,
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              conversation.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              conversation.context,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: conversation.metrics.length.clamp(0, 6),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: CoeloSpacing.space2,
                crossAxisSpacing: CoeloSpacing.space2,
                mainAxisExtent: textScale > 1.5
                    ? CoeloSize.touchMin * 3
                    : CoeloSize.touchMin * 2 + CoeloSpacing.space4,
              ),
              itemBuilder: (context, index) {
                final metric = conversation.metrics[index];
                return DecoratedBox(
                  key: const Key('superadmin-chat-context-metric'),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(CoeloRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(CoeloSpacing.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${metric.value}', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          metric.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Text('Compartilhados', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: CoeloSpacing.space2),
            _SharedItem(
              icon: Icons.image_outlined,
              title: 'Fotos',
              subtitle: '8 arquivos simulados',
            ),
            _SharedItem(
              icon: Icons.description_outlined,
              title: 'Documentos',
              subtitle: '3 arquivos simulados',
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: CoeloSize.iconSm,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: CoeloSpacing.space2),
                const Expanded(child: Text('Dados simulados')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _SharedItem extends StatelessWidget {
  const _SharedItem({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: CoeloSize.touchMin,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
