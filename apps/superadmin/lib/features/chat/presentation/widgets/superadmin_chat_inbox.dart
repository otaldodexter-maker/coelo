import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../chat_fixtures.dart';
import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';
import 'superadmin_chat_flow_dialog.dart';
import 'superadmin_chat_surface_primitives.dart';

final class SuperadminChatInbox extends StatefulWidget {
  const SuperadminChatInbox({
    required this.controller,
    required this.onOpenConversation,
    required this.onCreateGroup,
    required this.onNewMessage,
    required this.onFilter,
    this.options = superadminChatContextOptions,
    this.onCollapse,
    this.onBack,
    super.key,
  });

  final SuperadminChatController controller;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onCreateGroup;
  final VoidCallback onNewMessage;
  final VoidCallback onFilter;
  final List<SuperadminChatContextOption> options;
  final VoidCallback? onCollapse;
  final VoidCallback? onBack;

  @override
  State<SuperadminChatInbox> createState() => _SuperadminChatInboxState();
}

final class _SuperadminChatInboxState extends State<SuperadminChatInbox> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selectedId = controller.selectedConversation.id;
    return Material(
      key: const Key('superadmin-chat-inbox'),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CoeloSpacing.space3,
              CoeloSpacing.space3,
              CoeloSpacing.space2,
              CoeloSpacing.space2,
            ),
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    tooltip: 'Voltar',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    'Conversas',
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (widget.onCollapse != null)
                  IconButton(
                    tooltip: 'Recolher conversas',
                    onPressed: widget.onCollapse,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
            child: CoeloSearchField(
              key: const Key('superadmin-chat-search'),
              controller: _search,
              hintText: 'Buscar conversas',
              semanticLabel: 'Buscar conversas',
              onChanged: controller.setSearch,
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
            child: SegmentedButton<ChatAudience>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ChatAudience.all, label: Text('Todos')),
                ButtonSegment(value: ChatAudience.institutional, label: Text('Institucional')),
                ButtonSegment(value: ChatAudience.people, label: Text('Pessoas')),
              ],
              selected: {controller.audience},
              onSelectionChanged: (value) => controller.setAudience(value.first),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
            child: Row(
              children: [
                Expanded(
                  child: _InboxAction(
                    key: const Key('superadmin-chat-action-create-group'),
                    icon: Icons.group_add_outlined,
                    label: 'Criar grupo',
                    onTap: widget.onCreateGroup,
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space1),
                Expanded(
                  child: _InboxAction(
                    key: const Key('superadmin-chat-action-new-message'),
                    icon: Icons.edit_outlined,
                    label: 'Nova mensagem',
                    onTap: widget.onNewMessage,
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space1),
                Expanded(
                  child: _InboxAction(
                    key: const Key('superadmin-chat-action-filter'),
                    icon: Icons.tune_rounded,
                    label: 'Filtrar',
                    onTap: widget.onFilter,
                  ),
                ),
              ],
            ),
          ),
          if (controller.activeFilterValues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CoeloSpacing.space3,
                CoeloSpacing.space2,
                CoeloSpacing.space3,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in controller.visibleFilters)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: CoeloSpacing.space1),
                              child: InputChip(
                                label: Text(filter),
                                onDeleted: () => controller.toggleFilter(filter),
                              ),
                            ),
                          if (controller.hiddenFilterCount > 0)
                            Text('+${controller.hiddenFilterCount}'),
                        ],
                      ),
                    ),
                  ),
                  TextButton(onPressed: controller.clearFilters, child: const Text('Limpar')),
                ],
              ),
            ),
          const SizedBox(height: CoeloSpacing.space2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
              children: [
                if (controller.pinnedConversations.isNotEmpty) ...[
                  const _SectionHeader(title: 'Fixados'),
                  for (final conversation in controller.pinnedConversations)
                    _ConversationItem(
                      conversation: conversation,
                      selected: selectedId == conversation.id,
                      pinned: true,
                      onOpen: () => widget.onOpenConversation(conversation.id),
                      onPin: () => controller.togglePinned(conversation.id),
                      onCreateGroup: () => _openCreateGroupWith(conversation),
                      onInviteToGroup: () => _openInviteToGroup(conversation),
                      canInviteToGroup: _canInvite(conversation),
                      flag: controller.flagFor(conversation.id),
                      onFlag: (flag) => controller.setFlag(conversation.id, flag),
                      onDelete: () => _confirmDelete(conversation),
                    ),
                ],
                if (controller.groupConversations.isNotEmpty) ...[
                  const _SectionHeader(title: 'Grupos'),
                  for (final conversation in controller.groupConversations)
                    _ConversationItem(
                      conversation: conversation,
                      selected: selectedId == conversation.id,
                      pinned: false,
                      onOpen: () => widget.onOpenConversation(conversation.id),
                      onPin: () => controller.togglePinned(conversation.id),
                      onCreateGroup: () => _openCreateGroupWith(conversation),
                      onInviteToGroup: () => _openInviteToGroup(conversation),
                      canInviteToGroup: _canInvite(conversation),
                      flag: controller.flagFor(conversation.id),
                      onFlag: (flag) => controller.setFlag(conversation.id, flag),
                      onDelete: () => _confirmDelete(conversation),
                    ),
                ],
                _SectionHeader(title: _audienceLabel(controller.audience)),
                for (final conversation in controller.regularConversations)
                  _ConversationItem(
                    conversation: conversation,
                    selected: selectedId == conversation.id,
                    pinned: false,
                    onOpen: () => widget.onOpenConversation(conversation.id),
                    onPin: () => controller.togglePinned(conversation.id),
                    onCreateGroup: () => _openCreateGroupWith(conversation),
                    onInviteToGroup: () => _openInviteToGroup(conversation),
                    canInviteToGroup: _canInvite(conversation),
                    flag: controller.flagFor(conversation.id),
                    onFlag: (flag) => controller.setFlag(conversation.id, flag),
                    onDelete: () => _confirmDelete(conversation),
                  ),
                if (controller.visibleConversations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(CoeloSpacing.space5),
                    child: Text(
                      'Nenhuma conversa corresponde à busca e aos filtros.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canInvite(SuperadminChatConversation conversation) => widget.controller.conversations.any(
    (item) => item.kind == ChatContextKind.conversationGroup && item.id != conversation.id,
  );

  Future<void> _openCreateGroupWith(SuperadminChatConversation conversation) {
    return showDialog<bool>(
      context: context,
      builder: (_) => SuperadminChatCreateGroupDialog(
        controller: widget.controller,
        options: widget.options,
        initialSelectedIds: {conversation.id},
      ),
    );
  }

  Future<void> _openInviteToGroup(SuperadminChatConversation conversation) {
    return showDialog<bool>(
      context: context,
      builder: (_) => SuperadminChatInviteToGroupDialog(
        controller: widget.controller,
        conversation: conversation,
      ),
    );
  }

  Future<void> _confirmDelete(SuperadminChatConversation conversation) async {
    final isGroup = conversation.kind == ChatContextKind.conversationGroup;
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
    if (confirmed != true) return;
    isGroup
        ? widget.controller.deleteGroup(conversation.id)
        : widget.controller.deleteConversation(conversation.id);
  }
}

final class _InboxAction extends StatefulWidget {
  const _InboxAction({required this.icon, required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_InboxAction> createState() => _InboxActionState();
}

final class _InboxActionState extends State<_InboxAction> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlighted = _hovered || _focused;
    return FocusableActionDetector(
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: Material(
        color: highlighted ? colors.primaryContainer : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CoeloSpacing.space1,
                vertical: CoeloSpacing.space2,
              ),
              child: IconTheme(
                data: IconThemeData(color: highlighted ? colors.primary : colors.onSurface),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: highlighted ? colors.primary : colors.onSurface),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, size: 18),
                      const SizedBox(height: CoeloSpacing.space1),
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoeloSpacing.space3,
        CoeloSpacing.space3,
        CoeloSpacing.space3,
        CoeloSpacing.space1,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

final class _ConversationItem extends StatefulWidget {
  const _ConversationItem({
    required this.conversation,
    required this.selected,
    required this.pinned,
    required this.onOpen,
    required this.onPin,
    required this.onCreateGroup,
    required this.onInviteToGroup,
    required this.canInviteToGroup,
    required this.flag,
    required this.onFlag,
    required this.onDelete,
  });

  final SuperadminChatConversation conversation;
  final bool selected;
  final bool pinned;
  final VoidCallback onOpen;
  final VoidCallback onPin;
  final VoidCallback onCreateGroup;
  final VoidCallback onInviteToGroup;
  final bool canInviteToGroup;
  final ChatFlag flag;
  final ValueChanged<ChatFlag> onFlag;
  final VoidCallback onDelete;

  @override
  State<_ConversationItem> createState() => _ConversationItemState();
}

final class _ConversationItemState extends State<_ConversationItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final conversation = widget.conversation;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space2,
        vertical: CoeloSpacing.space1,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: widget.selected || _hovered ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('superadmin-chat-conversation-${conversation.id}'),
            onTap: widget.onOpen,
            hoverColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space2),
                child: Row(
                  children: [
                    SuperadminChatAvatar(
                      label: conversation.title,
                      initials: conversation.initials,
                      online: conversation.kind == ChatContextKind.person,
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                conversation.timestamp,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: CoeloSpacing.space1),
                          Text(
                            conversation.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (conversation.unreadCount > 0)
                      Badge(label: Text('${conversation.unreadCount}')),
                    IconButton(
                      key: Key('superadmin-chat-flag-${conversation.id}'),
                      tooltip: 'Sinalizar ${conversation.title}',
                      onPressed: () => widget.onFlag(_nextFlag(widget.flag)),
                      color: _flagColor(colors, widget.flag),
                      icon: Icon(
                        widget.flag == ChatFlag.none ? Icons.flag_outlined : Icons.flag_rounded,
                      ),
                    ),
                    SuperadminChatActionMenu(
                      tooltip: 'Ações de ${conversation.title}',
                      actions: [
                        SuperadminChatMenuAction(
                          label: 'Criar grupo com…',
                          icon: Icons.group_add_outlined,
                          onPressed: widget.onCreateGroup,
                        ),
                        if (widget.canInviteToGroup)
                          SuperadminChatMenuAction(
                            label: 'Convidar para grupo',
                            icon: Icons.person_add_alt_1_outlined,
                            onPressed: widget.onInviteToGroup,
                          ),
                        SuperadminChatMenuAction(
                          label: widget.pinned ? 'Desfixar' : 'Fixar',
                          icon: widget.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                          onPressed: widget.onPin,
                        ),
                        SuperadminChatMenuAction(
                          label: conversation.kind == ChatContextKind.conversationGroup
                              ? 'Excluir grupo'
                              : 'Excluir conversa',
                          icon: Icons.delete_outline_rounded,
                          destructive: true,
                          dividerBefore: true,
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _audienceLabel(ChatAudience audience) => switch (audience) {
  ChatAudience.all => 'Todos',
  ChatAudience.institutional => 'Institucional',
  ChatAudience.people => 'Pessoas',
};

ChatFlag _nextFlag(ChatFlag flag) => switch (flag) {
  ChatFlag.none => ChatFlag.red,
  ChatFlag.red => ChatFlag.yellow,
  ChatFlag.yellow => ChatFlag.green,
  ChatFlag.green => ChatFlag.none,
};

Color _flagColor(ColorScheme colors, ChatFlag flag) => switch (flag) {
  ChatFlag.none => colors.onSurfaceVariant,
  ChatFlag.red => colors.error,
  ChatFlag.yellow => colors.tertiary,
  ChatFlag.green => colors.secondary,
};
