import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/support_ticket.dart';

final class SupportMessageBubble extends StatelessWidget {
  const SupportMessageBubble({required this.message, required this.requesterName, super.key});

  final SupportMessage message;
  final String requesterName;

  @override
  Widget build(BuildContext context) {
    final sent = message.author == SupportMessageAuthor.support;
    final colors = Theme.of(context).colorScheme;
    final author = sent ? 'Equipe Coelo' : requesterName;
    final time =
        '${message.sentAt.hour.toString().padLeft(2, '0')}:'
        '${message.sentAt.minute.toString().padLeft(2, '0')}';
    final delivery = _deliveryLabel(message.deliveryState);

    return Semantics(
      container: true,
      label: '$author. ${message.text}. $time. $delivery',
      child: Align(
        alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CoeloSize.touchMin * 11),
          child: Container(
            key: const Key('support-message-bubble-surface'),
            margin: const EdgeInsets.only(bottom: CoeloSpacing.space2),
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space3,
              vertical: CoeloSpacing.space2,
            ),
            decoration: BoxDecoration(
              color: sent ? colors.primaryContainer : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(author, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: CoeloSpacing.space1),
                Text(message.text),
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  '$time · $delivery',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _deliveryLabel(SupportMessageDeliveryState state) => switch (state) {
  SupportMessageDeliveryState.sent => 'Enviada',
  SupportMessageDeliveryState.delivered => 'Entregue',
  SupportMessageDeliveryState.read => 'Lida',
};
