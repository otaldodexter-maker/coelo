import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../chat_fixtures.dart';
import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';
import 'superadmin_chat_composer.dart';
import 'superadmin_chat_flow_dialog.dart';
import 'superadmin_chat_message_bubble.dart';
import 'superadmin_chat_surface_primitives.dart';

final class SuperadminChatThreadBody extends StatefulWidget {
  const SuperadminChatThreadBody({
    required this.controller,
    required this.conversation,
    required this.onOpenContext,
    this.options = superadminChatContextOptions,
    this.onBack,
    this.compact = false,
    super.key,
  });

  final SuperadminChatController controller;
  final SuperadminChatConversation conversation;
  final VoidCallback onOpenContext;
  final List<SuperadminChatContextOption> options;
  final VoidCallback? onBack;
  final bool compact;

  @override
  State<SuperadminChatThreadBody> createState() => _SuperadminChatThreadBodyState();
}

final class _SuperadminChatThreadBodyState extends State<SuperadminChatThreadBody> {
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _send() {
    widget.controller.sendText(_composer.text);
    _composer.clear();
  }

  void _feedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          _ThreadHeader(
            conversation: widget.conversation,
            onBack: widget.onBack,
            onOpenContext: widget.onOpenContext,
            pinned: widget.controller.pinnedIds.contains(widget.conversation.id),
            onPin: () => widget.controller.togglePinned(widget.conversation.id),
            onCreateGroup: _openCreateGroupWith,
            onInviteToGroup: _openInviteToGroup,
            canInviteToGroup: widget.controller.conversations.any(
              (item) =>
                  item.kind == ChatContextKind.conversationGroup &&
                  item.id != widget.conversation.id,
            ),
            onDelete: () => _confirmDelete(context),
          ),
          Expanded(
            child: ListView(
              key: const Key('superadmin-chat-history'),
              reverse: true,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? CoeloSpacing.space3 : CoeloSpacing.space5,
                vertical: CoeloSpacing.space4,
              ),
              children: [
                for (final message in widget.conversation.messages.reversed)
                  SuperadminChatMessageBubble(message: message),
                const SizedBox(height: CoeloSpacing.space4),
                if (widget.conversation.unreadCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: colors.primary)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
                          child: Text(
                            '${widget.conversation.unreadCount} n\u00e3o lidas',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: colors.primary)),
                      ],
                    ),
                  ),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(CoeloRadius.full),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: CoeloSpacing.space3,
                        vertical: CoeloSpacing.space1,
                      ),
                      child: Text('Hoje'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SuperadminChatComposer(
            controller: _composer,
            compact: widget.compact,
            onSend: _send,
            onEmoji: () {
              widget.controller.sendEmoji('🙂');
              _feedback('Emoji adicionado à conversa simulada.');
            },
            onAudio: () {
              widget.controller.sendAttachment(ChatMessageKind.audio);
              _feedback('Áudio simulado adicionado.');
            },
            onImage: () {
              widget.controller.sendAttachment(ChatMessageKind.image);
              _feedback('Imagem simulada adicionada.');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateGroupWith() {
    return showDialog<bool>(
      context: context,
      builder: (_) => SuperadminChatCreateGroupDialog(
        controller: widget.controller,
        options: widget.options,
        initialSelectedIds: {widget.conversation.id},
      ),
    );
  }

  Future<void> _openInviteToGroup() {
    return showDialog<bool>(
      context: context,
      builder: (_) => SuperadminChatInviteToGroupDialog(
        controller: widget.controller,
        conversation: widget.conversation,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final isGroup = widget.conversation.kind == ChatContextKind.conversationGroup;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SuperadminChatDialogFrame(
        title: isGroup ? 'Excluir grupo?' : 'Excluir conversa?',
        subtitle: 'Demonstração local',
        compact: true,
        onClose: () => Navigator.pop(dialogContext, false),
        footer: SuperadminChatDialogActions(
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              child: Text(isGroup ? 'Excluir grupo' : 'Excluir conversa'),
            ),
          ],
        ),
        child: Text(
          isGroup
              ? 'O grupo e todo o histórico desta demonstração serão excluídos. '
                    'Esta ação não pode ser desfeita. Deseja continuar?'
              : 'A conversa e todo o histórico desta demonstração serão excluídos. '
                    'Esta ação não pode ser desfeita. Deseja continuar?',
        ),
      ),
    );
    if (confirmed == true) {
      isGroup
          ? widget.controller.deleteGroup(widget.conversation.id)
          : widget.controller.deleteConversation(widget.conversation.id);
    }
  }
}

final class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.conversation,
    required this.onOpenContext,
    required this.pinned,
    required this.onPin,
    required this.onCreateGroup,
    required this.onInviteToGroup,
    required this.canInviteToGroup,
    required this.onDelete,
    this.onBack,
  });

  final SuperadminChatConversation conversation;
  final VoidCallback onOpenContext;
  final bool pinned;
  final VoidCallback onPin;
  final VoidCallback onCreateGroup;
  final VoidCallback onInviteToGroup;
  final bool canInviteToGroup;
  final VoidCallback onDelete;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space3,
          vertical: CoeloSpacing.space2,
        ),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Voltar para conversas',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            SuperadminChatAvatar(
              label: conversation.title,
              initials: conversation.initials,
              size: CoeloSize.avatarMd,
            ),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      conversation.context,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Ver informações do perfil',
              onPressed: onOpenContext,
              icon: const Icon(Icons.badge_outlined),
            ),
            SuperadminChatActionMenu(
              tooltip: 'Ações da conversa',
              actions: [
                SuperadminChatMenuAction(
                  label: 'Criar grupo com…',
                  icon: Icons.group_add_outlined,
                  onPressed: onCreateGroup,
                ),
                if (canInviteToGroup)
                  SuperadminChatMenuAction(
                    label: 'Convidar para grupo',
                    icon: Icons.person_add_alt_1_outlined,
                    onPressed: onInviteToGroup,
                  ),
                SuperadminChatMenuAction(
                  label: pinned ? 'Desfixar' : 'Fixar',
                  icon: pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  onPressed: onPin,
                ),
                SuperadminChatMenuAction(
                  label: conversation.kind == ChatContextKind.conversationGroup
                      ? 'Excluir grupo'
                      : 'Excluir conversa',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  dividerBefore: true,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
