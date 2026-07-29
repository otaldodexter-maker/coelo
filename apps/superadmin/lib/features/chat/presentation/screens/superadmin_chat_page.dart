import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../chat_controller.dart';
import '../chat_fixtures.dart';
import '../chat_models.dart';
import '../widgets/superadmin_chat_advanced_filters.dart';
import '../widgets/superadmin_chat_avatar.dart';
import '../widgets/superadmin_chat_context_panel.dart';
import '../widgets/superadmin_chat_flow_dialog.dart';
import '../widgets/superadmin_chat_inbox.dart';
import '../widgets/superadmin_chat_thread_body.dart';

final class SuperadminChatPage extends StatefulWidget {
  const SuperadminChatPage({
    required this.logout,
    this.onDestinationSelected,
    this.onBack,
    this.contextOptions = superadminChatContextOptions,
    super.key,
  });

  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onBack;
  final List<SuperadminChatContextOption> contextOptions;

  @override
  State<SuperadminChatPage> createState() => _SuperadminChatPageState();
}

final class _SuperadminChatPageState extends State<SuperadminChatPage> {
  late final SuperadminChatController _controller;
  var _mobileThreadOpen = false;
  var _inboxCollapsed = false;
  var _desktopContextOpen = true;
  var _overlayContextOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = SuperadminChatController(superadminChatConversations);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      title: 'Conversas',
      subtitle: 'Comunicação institucional privada e contextual.',
      currentDestination: 'conversations',
      onDestinationSelected: widget.onDestinationSelected,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          return DecoratedBox(
            key: const Key('superadmin-chat-workspace-surface'),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final windowWidth = MediaQuery.sizeOf(context).width;
                  final threePaneMinimum =
                      CoeloSize.touchMin * 7 + CoeloSize.touchMin * 10 + CoeloSize.touchMin * 6;
                  if (windowWidth >= CoeloBreakpoints.large.minWidth &&
                      constraints.maxWidth >= threePaneMinimum) {
                    return _desktopThreePane();
                  }
                  if (windowWidth >= CoeloBreakpoints.expanded.minWidth) {
                    return _desktopPriorityThread();
                  }
                  if (windowWidth >= CoeloBreakpoints.medium.minWidth) {
                    return _tabletThread();
                  }
                  return _phoneStack();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _desktopThreePane() {
    return Row(
      children: [
        if (_inboxCollapsed)
          _ConversationRail(
            conversations: _controller.visibleConversations,
            selectedId: _controller.selectedConversation.id,
            onOpenInbox: () => setState(() => _inboxCollapsed = false),
            onSelected: _controller.selectConversation,
          )
        else
          SizedBox(
            width: CoeloSize.touchMin * 7,
            child: _inbox(
              onBack: widget.onBack,
              onCollapse: () => setState(() => _inboxCollapsed = true),
            ),
          ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _thread(
            onOpenContext: () => setState(() => _desktopContextOpen = !_desktopContextOpen),
          ),
        ),
        if (_desktopContextOpen)
          Row(
            children: [
              const VerticalDivider(width: 1),
              SizedBox(
                width: CoeloSize.touchMin * 6,
                child: SuperadminChatContextPanel(
                  conversation: _controller.selectedConversation,
                  onClose: () => setState(() => _desktopContextOpen = false),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _desktopPriorityThread() {
    return Stack(
      children: [
        Row(
          children: [
            _ConversationRail(
              conversations: _controller.visibleConversations,
              selectedId: _controller.selectedConversation.id,
              onOpenInbox: () => _showInboxDrawer(),
              onSelected: (id) {
                _controller.selectConversation(id);
                setState(() => _mobileThreadOpen = true);
              },
            ),
            Expanded(
              child: _thread(onOpenContext: () => setState(() => _overlayContextOpen = true)),
            ),
          ],
        ),
        if (_overlayContextOpen)
          PositionedDirectional(
            top: 0,
            bottom: 0,
            end: 0,
            width: CoeloSize.touchMin * 6,
            child: Material(
              elevation: 8,
              shape: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              child: SuperadminChatContextPanel(
                conversation: _controller.selectedConversation,
                onClose: () => setState(() => _overlayContextOpen = false),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabletThread() {
    return _thread(onBack: _showInboxDrawer, onOpenContext: _showContextSheet);
  }

  Widget _phoneStack() {
    if (!_mobileThreadOpen) return _inbox(onBack: widget.onBack);
    return _thread(
      onBack: () => setState(() => _mobileThreadOpen = false),
      onOpenContext: _showContextSheet,
      compact: true,
    );
  }

  Widget _inbox({VoidCallback? onCollapse, VoidCallback? onBack}) {
    return SuperadminChatInbox(
      controller: _controller,
      onBack: onBack,
      onCollapse: onCollapse,
      onFilter: _openFilters,
      onCreateGroup: _openCreateGroupFlow,
      onNewMessage: _openRecipients,
      onOpenConversation: (id) {
        _controller.selectConversation(id);
        setState(() => _mobileThreadOpen = true);
      },
    );
  }

  Widget _thread({
    required VoidCallback onOpenContext,
    VoidCallback? onBack,
    bool compact = false,
  }) {
    return KeyedSubtree(
      key: const Key('superadmin-chat-thread'),
      child: SuperadminChatThreadBody(
        key: ValueKey(_controller.selectedConversation.id),
        controller: _controller,
        conversation: _controller.selectedConversation,
        onBack: onBack,
        onOpenContext: onOpenContext,
        compact: compact,
      ),
    );
  }

  Future<void> _showInboxDrawer() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _inbox(
          onBack: () {
            Navigator.pop(context);
            widget.onBack?.call();
          },
        ),
      ),
    );
  }

  Future<void> _showContextSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.86,
        child: SuperadminChatContextPanel(
          conversation: _controller.selectedConversation,
          compact: true,
          onClose: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  Future<void> _openFilters() {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          SuperadminChatAdvancedFilters(controller: _controller, options: widget.contextOptions),
    );
  }

  Future<void> _openRecipients() {
    _controller.clearRecipients();
    return showDialog<bool>(
      context: context,
      builder: (_) =>
          SuperadminChatMessageDialog(controller: _controller, options: widget.contextOptions),
    ).then((completed) {
      if (!mounted || completed != true || _controller.feedback == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_controller.feedback!)));
    });
  }

  Future<void> _openCreateGroupFlow() {
    return showDialog<bool>(
      context: context,
      builder: (_) =>
          SuperadminChatCreateGroupDialog(controller: _controller, options: widget.contextOptions),
    );
  }
}

final class _ConversationRail extends StatelessWidget {
  const _ConversationRail({
    required this.conversations,
    required this.selectedId,
    required this.onOpenInbox,
    required this.onSelected,
  });

  final List<SuperadminChatConversation> conversations;
  final String selectedId;
  final VoidCallback onOpenInbox;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('superadmin-chat-rail'),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: CoeloSize.touchMin + CoeloSpacing.space4,
        child: Column(
          children: [
            const SizedBox(height: CoeloSpacing.space2),
            IconButton(
              tooltip: 'Abrir conversas',
              onPressed: onOpenInbox,
              icon: const Icon(Icons.forum_outlined),
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Expanded(
              child: ListView(
                children: [
                  for (final conversation in conversations.take(7))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
                      child: IconButton(
                        key: Key('superadmin-chat-rail-${conversation.id}'),
                        tooltip: conversation.title,
                        isSelected: selectedId == conversation.id,
                        onPressed: () => onSelected(conversation.id),
                        icon: SuperadminChatAvatar(
                          label: conversation.title,
                          initials: conversation.initials,
                          size: CoeloSize.avatarMd,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
