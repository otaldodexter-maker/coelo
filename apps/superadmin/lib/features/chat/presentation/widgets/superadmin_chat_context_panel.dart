import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../chat_fixtures.dart';

final class SuperadminChatContextPanel extends StatelessWidget {
  const SuperadminChatContextPanel({
    required this.conversation,
    required this.collapsed,
    required this.onToggle,
    this.toggleFocusNode,
    super.key,
  });

  final SuperadminChatConversation conversation;
  final bool collapsed;
  final VoidCallback onToggle;
  final FocusNode? toggleFocusNode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        return KeyedSubtree(
          key: collapsed
              ? const Key('superadmin-chat-context-panel-collapsed')
              : const Key('superadmin-chat-context-panel'),
          child: CoeloAdminChatContextSummary(
            title: conversation.title,
            subtitle: conversation.context,
            metrics: conversation.metrics,
            collapsed: collapsed,
            onToggle: onToggle,
            toggleFocusNode: toggleFocusNode,
            expandedToggleIcon: compact ? Icons.arrow_back : Icons.chevron_right,
            expandedToggleTooltip: compact
                ? 'Voltar para a conversa'
                : 'Recolher painel contextual',
            image: CoeloChatAvatar(
              label: conversation.title,
              initials: conversation.initials,
              size: CoeloSize.avatarXl,
            ),
            footer: Row(
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
        );
      },
    );
  }
}
