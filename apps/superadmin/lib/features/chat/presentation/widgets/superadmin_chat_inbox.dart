import 'dart:ui' show PointerDeviceKind;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../chat_controller.dart';
import '../chat_fixtures.dart';
import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';
import 'superadmin_chat_flow_dialog.dart';
import 'superadmin_chat_surface_primitives.dart';

enum _QuickInboxFilter {
  pinned('Fixadas', Icons.push_pin_outlined),
  unread('N\u00e3o lidas', Icons.mark_chat_unread_outlined),
  flagged('Bandeiras', Icons.flag_outlined);

  const _QuickInboxFilter(this.label, this.icon);

  final String label;
  final IconData icon;
}

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
  final Set<_QuickInboxFilter> _quickFilters = {};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pinnedConversations = controller.pinnedConversations
        .where((item) => _matchesQuickFilter(item, pinned: true))
        .toList(growable: false);
    final groupConversations = controller.groupConversations
        .where((item) => _matchesQuickFilter(item, pinned: false))
        .toList(growable: false);
    final regularConversations = controller.regularConversations
        .where((item) => _matchesQuickFilter(item, pinned: false))
        .toList(growable: false);
    final quickFilterResultCount =
        pinnedConversations.length + groupConversations.length + regularConversations.length;
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
            child: SuperadminUnderlineTabs<ChatAudience>(
              tabs: const [
                SuperadminUnderlineTab(value: ChatAudience.all, label: 'Todos'),
                SuperadminUnderlineTab(value: ChatAudience.institutional, label: 'Institucional'),
                SuperadminUnderlineTab(value: ChatAudience.people, label: 'Pessoas'),
              ],
              selected: controller.audience,
              onSelected: controller.setAudience,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
            child: LayoutBuilder(
              key: const Key('superadmin-chat-quick-filters'),
              builder: (context, constraints) => SizedBox(
                width: constraints.maxWidth,
                child: Wrap(
                  spacing: CoeloSpacing.space1,
                  runSpacing: CoeloSpacing.space1,
                  children: [
                    for (final filter in _QuickInboxFilter.values)
                      FilterChip(
                        key: Key('superadmin-chat-quick-filter-${filter.name}'),
                        label: Text(filter.label),
                        avatar: Icon(filter.icon, size: 18),
                        selected: _quickFilters.contains(filter),
                        onSelected: (selected) {
                          setState(() {
                            selected ? _quickFilters.add(filter) : _quickFilters.remove(filter);
                          });
                        },
                        color: WidgetStateProperty.resolveWith((states) {
                          final highlighted =
                              states.contains(WidgetState.selected) ||
                              states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused);
                          return highlighted
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surface;
                        }),
                        showCheckmark: false,
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space2),
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
                if (pinnedConversations.isNotEmpty) ...[
                  const _SectionHeader(title: 'Fixados'),
                  for (final conversation in pinnedConversations)
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
                if (groupConversations.isNotEmpty) ...[
                  const _SectionHeader(title: 'Grupos'),
                  for (final conversation in groupConversations)
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
                for (final conversation in regularConversations)
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
                if (quickFilterResultCount == 0)
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

  bool _matchesQuickFilter(SuperadminChatConversation conversation, {required bool pinned}) {
    if (_quickFilters.contains(_QuickInboxFilter.pinned) && !pinned) return false;
    if (_quickFilters.contains(_QuickInboxFilter.unread) && conversation.unreadCount == 0) {
      return false;
    }
    if (_quickFilters.contains(_QuickInboxFilter.flagged) &&
        widget.controller.flagFor(conversation.id) == ChatFlag.none) {
      return false;
    }
    return true;
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
          child: Semantics(
            selected: widget.selected,
            button: true,
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
                      Container(
                        width: 3,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.selected ? colors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(CoeloRadius.full),
                        ),
                      ),
                      const SizedBox(width: CoeloSpacing.space2),
                      SuperadminChatAvatar(
                        label: conversation.title,
                        initials: conversation.initials,
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
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: widget.selected
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                    ),
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: CoeloSize.touchMin),
                                  child: Text(
                                    conversation.timestamp,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              conversation.context,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(height: CoeloSpacing.spaceHalf),
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
                      _ChatFlagControl(
                        key: Key('superadmin-chat-flag-${conversation.id}'),
                        flag: widget.flag,
                        conversationTitle: conversation.title,
                        onChanged: widget.onFlag,
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
      ),
    );
  }
}

final class _ChatFlagControl extends StatefulWidget {
  const _ChatFlagControl({
    required this.flag,
    required this.conversationTitle,
    required this.onChanged,
    super.key,
  });

  final ChatFlag flag;
  final String conversationTitle;
  final ValueChanged<ChatFlag> onChanged;

  @override
  State<_ChatFlagControl> createState() => _ChatFlagControlState();
}

final class _ChatFlagControlState extends State<_ChatFlagControl> {
  PointerDeviceKind? _pointerKind;

  void _openLegend(MenuController controller) {
    if (!controller.isOpen) controller.open();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CoeloAdminFlyout<ChatFlag>(
      itemWidth: 240,
      items: [
        for (final flag in ChatFlag.values.where((value) => value != ChatFlag.none))
          CoeloAdminFlyoutItem(
            value: flag,
            label: _flagLabel(flag),
            icon: Icons.flag_rounded,
            iconColor: _flagColor(colors, flag),
            semanticLabel: _flagSemanticLabel(flag),
            selected: widget.flag == flag,
          ),
        CoeloAdminFlyoutItem(
          value: ChatFlag.none,
          label: 'Remover bandeira',
          icon: Icons.flag_outlined,
          iconColor: colors.onSurfaceVariant,
          semanticLabel: 'Remover bandeira',
          startsGroup: true,
        ),
      ],
      onSelected: (flag) {
        widget.onChanged(flag);
        _pointerKind = null;
      },
      builder: (context, controller) => MouseRegion(
        onEnter: (_) => _openLegend(controller),
        child: Listener(
          onPointerDown: (event) => _pointerKind = event.kind,
          child: Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.space)) {
                _openLegend(controller);
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                controller.close();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: IconButton(
              tooltip:
                  '${_flagLabel(widget.flag)} em ${widget.conversationTitle}. Clique para alternar; '
                  'passe o mouse ou use Enter para ver a legenda.',
              onPressed: () {
                if (_pointerKind == PointerDeviceKind.touch) {
                  _openLegend(controller);
                  return;
                }
                widget.onChanged(_nextFlag(widget.flag));
              },
              color: _flagColor(colors, widget.flag),
              icon: Icon(widget.flag == ChatFlag.none ? Icons.flag_outlined : Icons.flag_rounded),
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
  ChatFlag.green => ChatFlag.blue,
  ChatFlag.blue => ChatFlag.pink,
  ChatFlag.pink => ChatFlag.restricted,
  ChatFlag.restricted => ChatFlag.none,
};

Color _flagColor(ColorScheme colors, ChatFlag flag) => switch (flag) {
  ChatFlag.none => colors.onSurfaceVariant,
  ChatFlag.red => colors.error,
  ChatFlag.yellow => colors.tertiary,
  ChatFlag.green => colors.secondary,
  ChatFlag.blue => colors.primary,
  ChatFlag.pink => Color.alphaBlend(colors.error.withValues(alpha: 0.42), colors.tertiary),
  ChatFlag.restricted => colors.inverseSurface,
};

String _flagLabel(ChatFlag flag) => switch (flag) {
  ChatFlag.none => 'Sem bandeira',
  ChatFlag.red => 'Urgente',
  ChatFlag.yellow => 'Acompanhar',
  ChatFlag.green => 'Resolvido',
  ChatFlag.blue => 'Aguardando retorno',
  ChatFlag.pink => 'Sens\u00edvel',
  ChatFlag.restricted => 'Restrito',
};

String _flagSemanticLabel(ChatFlag flag) => switch (flag) {
  ChatFlag.none => 'Sem bandeira',
  ChatFlag.red => 'Bandeira vermelha: Urgente',
  ChatFlag.yellow => 'Bandeira amarela: Acompanhar',
  ChatFlag.green => 'Bandeira verde: Resolvido',
  ChatFlag.blue => 'Bandeira azul: Aguardando retorno',
  ChatFlag.pink => 'Bandeira rosa: Sensível',
  ChatFlag.restricted => 'Bandeira restrita: Restrito',
};
