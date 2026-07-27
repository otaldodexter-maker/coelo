import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_fixtures.dart';
import 'superadmin_chat_scope_filters.dart';
import 'superadmin_chat_thread_body.dart';

enum _LauncherView { inbox, thread }

final class SuperadminChatLauncher extends StatefulWidget {
  const SuperadminChatLauncher({required this.onExpand, super.key});

  final VoidCallback onExpand;

  @override
  State<SuperadminChatLauncher> createState() => _SuperadminChatLauncherState();
}

final class _SuperadminChatLauncherState extends State<SuperadminChatLauncher> {
  final _launcherFocusNode = FocusNode(debugLabel: 'Mensagens');
  final _searchController = TextEditingController();
  final _scopeSelections = <SuperadminChatScopeKind, String>{};
  var _open = false;
  var _highlighted = false;
  var _view = _LauncherView.inbox;
  var _selectedIndex = 0;

  SuperadminChatConversation get _selected => superadminChatConversations[_selectedIndex];

  @override
  void dispose() {
    _launcherFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _close() {
    setState(() {
      _open = false;
      _view = _LauncherView.inbox;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _launcherFocusNode.requestFocus();
      }
    });
  }

  void _handleEscape() {
    if (_view == _LauncherView.thread) {
      setState(() => _view = _LauncherView.inbox);
    } else {
      _close();
    }
  }

  void _updateScope(SuperadminChatScopeKind kind, String? value) {
    final next = updatedSuperadminChatScope(_scopeSelections, kind, value);
    setState(() {
      _scopeSelections
        ..clear()
        ..addAll(next);
    });
  }

  List<SuperadminChatConversation> get _visibleConversations {
    final query = _searchController.text.trim().toLowerCase();
    return superadminChatConversations
        .where(
          (conversation) =>
              matchesSuperadminChatScope(conversation, _scopeSelections) &&
              (query.isEmpty ||
                  conversation.title.toLowerCase().contains(query) ||
                  conversation.context.toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return _CollapsedLauncher(
        focusNode: _launcherFocusNode,
        highlighted: _highlighted,
        onHighlightChanged: (value) {
          if (_highlighted != value) {
            setState(() => _highlighted = value);
          }
        },
        onPressed: () => setState(() => _open = true),
      );
    }

    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(460.0, math.max(0.0, viewport.width - 32));
    final height = math.min(600.0, math.max(0.0, viewport.height - 96));
    final colors = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _handleEscape},
      child: Focus(
        autofocus: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CoeloRadius.xl),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            elevation: 0,
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoeloRadius.xl),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: _view == _LauncherView.inbox ? _buildInbox(context) : _buildThread(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInbox(BuildContext context) {
    return Column(
      children: [
        _LauncherHeader(title: 'Conversas', onExpand: widget.onExpand, onClose: _close),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space3,
            CoeloSpacing.space3,
            CoeloSpacing.space3,
            CoeloSpacing.space2,
          ),
          child: Row(
            children: [
              Expanded(
                child: CoeloSearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  semanticLabel: 'Buscar conversas no popup',
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              IconButton(
                tooltip: 'Nova conversa',
                onPressed: widget.onExpand,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        SuperadminChatScopeFilters(selections: _scopeSelections, onChanged: _updateScope),
        const SizedBox(height: CoeloSpacing.space1),
        Expanded(
          child: _visibleConversations.isEmpty
              ? const CoeloStatePanel(
                  title: 'Nenhuma conversa',
                  message: 'Ajuste a busca ou os filtros contextuais.',
                  icon: Icons.filter_alt_off_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
                  itemCount: _visibleConversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _visibleConversations[index];
                    return CoeloConversationTile(
                      avatar: CoeloChatAvatar(
                        label: conversation.title,
                        initials: conversation.initials,
                        size: CoeloSize.avatarMd,
                        nowState: conversation.nowState,
                        presence: conversation.presence,
                      ),
                      title: conversation.title,
                      preview: conversation.preview,
                      timestamp: conversation.timestamp,
                      unreadCount: conversation.unreadCount,
                      onPressed: () => setState(() {
                        _selectedIndex = superadminChatConversations.indexOf(conversation);
                        _view = _LauncherView.thread;
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildThread(BuildContext context) {
    return Column(
      key: const Key('superadmin-chat-launcher-thread'),
      children: [
        _LauncherHeader(
          title: _selected.title,
          subtitle: _selected.context,
          avatar: CoeloChatAvatar(
            label: _selected.title,
            initials: _selected.initials,
            size: CoeloSize.avatarMd,
            nowState: _selected.nowState,
            presence: _selected.presence,
          ),
          onBack: () => setState(() => _view = _LauncherView.inbox),
          onExpand: widget.onExpand,
          onClose: _close,
        ),
        const Divider(height: 1),
        Expanded(child: SuperadminChatThreadBody(conversation: _selected, compact: true)),
      ],
    );
  }
}

final class _CollapsedLauncher extends StatelessWidget {
  const _CollapsedLauncher({
    required this.focusNode,
    required this.highlighted,
    required this.onHighlightChanged,
    required this.onPressed,
  });

  final FocusNode focusNode;
  final bool highlighted;
  final ValueChanged<bool> onHighlightChanged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Mensagens, 3 não lidas',
      button: true,
      child: Container(
        key: const Key('superadmin-chat-launcher-surface'),
        decoration: BoxDecoration(
          color: highlighted ? colors.primaryContainer : colors.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.full),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(CoeloRadius.full),
          child: InkWell(
            focusNode: focusNode,
            onFocusChange: onHighlightChanged,
            onHover: onHighlightChanged,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(CoeloRadius.full),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space3,
                  vertical: CoeloSpacing.space1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Badge(label: Text('3'), child: Icon(Icons.send_outlined)),
                    const SizedBox(width: CoeloSpacing.space2),
                    const Text('Mensagens'),
                    const SizedBox(width: CoeloSpacing.space2),
                    const _LauncherAvatarStack(),
                    const SizedBox(width: CoeloSpacing.space1),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colors.surfaceContainerHighest,
                      foregroundColor: colors.onSurfaceVariant,
                      child: const Icon(Icons.more_horiz, size: CoeloSize.iconSm),
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

final class _LauncherAvatarStack extends StatelessWidget {
  const _LauncherAvatarStack();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      height: 30,
      child: Stack(
        children: [
          for (var index = 0; index < 3; index++)
            Positioned(
              left: index * 18,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: colors.surface,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: index == 0
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  child: Text(
                    superadminChatConversations[index].initials,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _LauncherHeader extends StatelessWidget {
  const _LauncherHeader({
    required this.title,
    required this.onExpand,
    required this.onClose,
    this.subtitle,
    this.avatar,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? avatar;
  final VoidCallback? onBack;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const Key('superadmin-chat-launcher-header'),
      color: colors.primary,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Voltar para conversas',
                  onPressed: onBack,
                  color: colors.onPrimary,
                  icon: const Icon(Icons.arrow_back),
                ),
              if (avatar != null) ...[avatar!, const SizedBox(width: CoeloSpacing.space2)],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: colors.onPrimary),
                    ),
                    if (subtitle case final value?)
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.onPrimary),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Expandir conversas',
                onPressed: onExpand,
                color: colors.onPrimary,
                icon: const Icon(Icons.open_in_full),
              ),
              IconButton(
                tooltip: 'Fechar conversas',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  foregroundColor: colors.error,
                  backgroundColor: colors.surface,
                  hoverColor: colors.errorContainer,
                  focusColor: colors.errorContainer,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
