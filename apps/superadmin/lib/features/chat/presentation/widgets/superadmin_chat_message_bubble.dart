import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_models.dart';

final class SuperadminChatMessageBubble extends StatelessWidget {
  const SuperadminChatMessageBubble({required this.message, super.key});

  final SuperadminChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final delivery = switch (message.delivery) {
      ChatDeliveryState.sent => 'Enviada',
      ChatDeliveryState.delivered => 'Entregue',
      ChatDeliveryState.read => 'Lida',
    };
    final author = message.author ?? (message.sentByMe ? 'Você' : 'Participante');
    return Semantics(
      container: true,
      label: '$author. ${message.context ?? ''}. ${message.body}. ${message.time}. $delivery',
      child: Align(
        alignment: message.sentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CoeloSize.touchMin * 11),
          child: Container(
            key: Key('superadmin-chat-message-${message.id}'),
            margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space3,
              vertical: CoeloSpacing.space2,
            ),
            decoration: BoxDecoration(
              color: message.sentByMe ? colors.primaryContainer : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.author != null || message.context != null) ...[
                  Text(
                    [message.author, message.context].whereType<String>().join(' · '),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: CoeloSpacing.space1),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.kind == ChatMessageKind.audio)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(end: CoeloSpacing.space2),
                        child: Icon(Icons.play_circle_outline_rounded, size: CoeloSize.iconMd),
                      ),
                    if (message.kind == ChatMessageKind.image)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(end: CoeloSpacing.space2),
                        child: Icon(Icons.image_outlined, size: CoeloSize.iconMd),
                      ),
                    Flexible(child: Text(message.body)),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space1),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    message.sentByMe ? '${message.time} · $delivery' : message.time,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
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
