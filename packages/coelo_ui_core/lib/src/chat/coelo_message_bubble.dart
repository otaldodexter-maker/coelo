import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'coelo_chat_types.dart';

final class CoeloMessageBubble extends StatelessWidget {
  const CoeloMessageBubble({
    required this.direction,
    required this.body,
    required this.timestamp,
    this.authorLabel,
    this.contextLabel,
    this.childLabels = const [],
    this.deliveryState = CoeloMessageDeliveryState.none,
    super.key,
  });

  final CoeloMessageDirection direction;
  final String body;
  final String timestamp;
  final String? authorLabel;
  final String? contextLabel;
  final List<String> childLabels;
  final CoeloMessageDeliveryState deliveryState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sent = direction == CoeloMessageDirection.sent;
    final contextText = [
      if (contextLabel case final label? when label.isNotEmpty) label,
      ...childLabels,
    ].join(' · ');
    final deliveryLabel = deliveryState.label;
    final semanticText = [
      sent ? 'Mensagem enviada' : 'Mensagem recebida',
      if (authorLabel case final label? when label.isNotEmpty) label,
      if (contextText.isNotEmpty) contextText,
      body,
      timestamp,
      if (deliveryLabel.isNotEmpty) deliveryLabel,
    ].join('. ');

    return Semantics(
      label: semanticText,
      excludeSemantics: true,
      child: Align(
        alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          decoration: BoxDecoration(
            color: sent ? colors.primaryContainer : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (authorLabel case final label? when label.isNotEmpty) ...[
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: CoeloSpacing.space1),
              ],
              if (contextText.isNotEmpty) ...[
                Text(
                  contextText,
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.primary),
                ),
                const SizedBox(height: CoeloSpacing.space1),
              ],
              Text(body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: CoeloSpacing.space1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timestamp,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  if (deliveryLabel.isNotEmpty) ...[
                    const SizedBox(width: CoeloSpacing.space1),
                    Text(
                      deliveryLabel,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
