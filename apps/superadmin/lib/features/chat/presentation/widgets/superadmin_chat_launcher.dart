import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_controller.dart';
import '../chat_fixtures.dart';
import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';
import 'superadmin_chat_composer.dart';
import 'superadmin_chat_message_bubble.dart';

final class SuperadminChatLauncher extends StatefulWidget {
  const SuperadminChatLauncher({required this.onOpenConversations, super.key});

  final VoidCallback onOpenConversations;

  @override
  State<SuperadminChatLauncher> createState() => _SuperadminChatLauncherState();
}

final class _SuperadminChatLauncherState extends State<SuperadminChatLauncher> {
  late final SuperadminChatController _controller;
  final _focusNode = FocusNode(debugLabel: 'Launcher de conversas');
  final _overlayFocusNode = FocusNode(debugLabel: 'Painel de conversas');
  OverlayEntry? _entry;
  var _hovered = false;
  var _focused = false;
  var _compactSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = SuperadminChatController(superadminChatConversations);
    _focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _entry?.remove();
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    _overlayFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocus() => setState(() => _focused = _focusNode.hasFocus);

  Future<void> _open() async {
    if (MediaQuery.sizeOf(context).width < CoeloBreakpoints.expanded.minWidth) {
      setState(() => _compactSheetOpen = true);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FractionallySizedBox(
          heightFactor: 0.78,
          child: _CompactLauncherContent(
            controller: _controller,
            onClose: () => Navigator.pop(sheetContext),
            onOpenConversations: widget.onOpenConversations,
          ),
        ),
      );
      if (mounted) setState(() => _compactSheetOpen = false);
      return;
    }
    if (_entry != null) {
      _closeOverlay();
      return;
    }
    final viewport = MediaQuery.sizeOf(context);
    final anchorBox = context.findRenderObject()! as RenderBox;
    final anchorOrigin = anchorBox.localToGlobal(Offset.zero);
    final anchorRect = anchorOrigin & anchorBox.size;
    final panelWidth = (viewport.width - CoeloSpacing.space4).clamp(0, 460).toDouble();
    final panelHeight = (viewport.height - CoeloSpacing.space4).clamp(0, 600).toDouble();
    final top = (anchorRect.top - panelHeight - CoeloSpacing.space2)
        .clamp(CoeloSpacing.space2, viewport.height - panelHeight - CoeloSpacing.space2)
        .toDouble();
    final right = (viewport.width - anchorRect.right)
        .clamp(CoeloSpacing.space2, viewport.width - panelWidth - CoeloSpacing.space2)
        .toDouble();
    _entry = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: Focus(
          focusNode: _overlayFocusNode,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              _closeOverlay();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              GestureDetector(behavior: HitTestBehavior.translucent, onTap: _closeOverlay),
              Positioned(
                top: top,
                right: right,
                width: panelWidth,
                height: panelHeight,
                child: Material(
                  key: const Key('superadmin-chat-launcher-panel'),
                  color: Theme.of(overlayContext).colorScheme.surface,
                  elevation: 2,
                  shadowColor: Theme.of(overlayContext).colorScheme.shadow.withValues(alpha: 0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CoeloRadius.xl),
                    side: BorderSide(color: Theme.of(overlayContext).colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _CompactLauncherContent(
                    controller: _controller,
                    onClose: _closeOverlay,
                    onOpenConversations: () {
                      _closeOverlay();
                      widget.onOpenConversations();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
    _overlayFocusNode.requestFocus();
  }

  void _closeOverlay() {
    _entry?.remove();
    _entry = null;
    if (mounted) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_compactSheetOpen) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final highlighted = _hovered || _focused;
    final compact = MediaQuery.sizeOf(context).width < CoeloBreakpoints.expanded.minWidth;
    final foreground = highlighted ? colors.onPrimary : colors.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: 'Abrir conversas',
        child: Semantics(
          button: true,
          label: 'Abrir conversas. 3 mensagens não lidas.',
          child: Material(
            key: const Key('superadmin-chat-launcher-surface'),
            color: highlighted ? colors.primary : colors.surfaceContainerHighest,
            shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              focusNode: _focusNode,
              onTap: _open,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: CoeloSize.touchMin,
                  minWidth: CoeloSize.touchMin,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? CoeloSpacing.space3 : CoeloSpacing.space2,
                  ),
                  child: compact
                      ? Icon(Icons.forum_outlined, color: foreground)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              label: const Text('3'),
                              child: Icon(Icons.send_outlined, color: foreground),
                            ),
                            const SizedBox(width: CoeloSpacing.space2),
                            Text('Mensagens', style: TextStyle(color: foreground)),
                            const SizedBox(width: CoeloSpacing.space2),
                            _LauncherAvatars(foreground: foreground),
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

final class _LauncherAvatars extends StatelessWidget {
  const _LauncherAvatars({required this.foreground});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const labels = ['TG', 'UC', 'AN', 'MA', 'IA', 'PA'];
    return SizedBox(
      width: 116,
      height: 34,
      child: Stack(
        children: [
          for (var index = 0; index < labels.length; index++)
            Positioned(
              left: index * 16,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: index.isEven
                    ? colors.surfaceContainerLow
                    : colors.surfaceContainerHigh,
                child: Text(labels[index], style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
          Positioned(
            right: 0,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: colors.surface,
              child: Icon(Icons.more_horiz_rounded, size: 18, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

final class _CompactLauncherContent extends StatefulWidget {
  const _CompactLauncherContent({
    required this.controller,
    required this.onClose,
    required this.onOpenConversations,
  });

  final SuperadminChatController controller;
  final VoidCallback onClose;
  final VoidCallback onOpenConversations;

  @override
  State<_CompactLauncherContent> createState() => _CompactLauncherContentState();
}

final class _CompactLauncherContentState extends State<_CompactLauncherContent> {
  final _search = TextEditingController();
  final _composer = TextEditingController();
  String? _threadId;

  @override
  void dispose() {
    _search.dispose();
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final thread = _threadId == null
            ? null
            : widget.controller.conversations.where((item) => item.id == _threadId).firstOrNull;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Container(
                key: const Key('superadmin-chat-launcher-header'),
                color: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  CoeloSpacing.space3,
                  CoeloSpacing.space2,
                  CoeloSpacing.space2,
                  CoeloSpacing.space2,
                ),
                child: Row(
                  children: [
                    if (thread != null)
                      IconButton(
                        tooltip: 'Voltar para conversas',
                        onPressed: () => setState(() => _threadId = null),
                        color: Theme.of(context).colorScheme.onPrimary,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    Expanded(
                      child: Text(
                        thread?.title ?? 'Conversas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Abrir tela de conversas',
                      onPressed: widget.onOpenConversations,
                      color: Theme.of(context).colorScheme.onPrimary,
                      icon: const Icon(Icons.open_in_full_rounded),
                    ),
                    IconButton(
                      tooltip: 'Fechar conversas',
                      onPressed: widget.onClose,
                      color: Theme.of(context).colorScheme.onPrimary,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(child: thread == null ? _inbox() : _thread(thread)),
            ],
          ),
        );
      },
    );
  }

  Widget _inbox() {
    final controller = widget.controller;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space3,
            CoeloSpacing.space3,
            CoeloSpacing.space3,
            CoeloSpacing.space2,
          ),
          child: CoeloSearchField(
            key: const Key('superadmin-chat-launcher-search'),
            controller: _search,
            hintText: 'Buscar conversas',
            semanticLabel: 'Buscar conversas',
            onChanged: controller.setSearch,
          ),
        ),
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
        const SizedBox(height: CoeloSpacing.space2),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
            itemCount: controller.visibleConversations.length,
            itemBuilder: (context, index) {
              final conversation = controller.visibleConversations[index];
              return _CompactConversationItem(
                conversation: conversation,
                onTap: () {
                  controller.selectConversation(conversation.id);
                  setState(() => _threadId = conversation.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _thread(SuperadminChatConversation conversation) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            children: [
              for (final message in conversation.messages.take(3))
                SuperadminChatMessageBubble(message: message),
            ],
          ),
        ),
        SuperadminChatComposer(
          controller: _composer,
          compact: true,
          onSend: () {
            widget.controller.sendText(_composer.text);
            _composer.clear();
          },
          onEmoji: () => widget.controller.sendEmoji('🙂'),
          onAudio: () => widget.controller.sendAttachment(ChatMessageKind.audio),
          onImage: () => widget.controller.sendAttachment(ChatMessageKind.image),
        ),
      ],
    );
  }
}

final class _CompactConversationItem extends StatefulWidget {
  const _CompactConversationItem({required this.conversation, required this.onTap});

  final SuperadminChatConversation conversation;
  final VoidCallback onTap;

  @override
  State<_CompactConversationItem> createState() => _CompactConversationItemState();
}

final class _CompactConversationItemState extends State<_CompactConversationItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final conversation = widget.conversation;
    return Padding(
      key: Key('superadmin-chat-launcher-conversation-${conversation.id}'),
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: _hovered ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            minTileHeight: CoeloSize.touchMin + CoeloSpacing.space2,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            leading: SuperadminChatAvatar(
              label: conversation.title,
              initials: conversation.initials,
              size: CoeloSize.avatarMd,
            ),
            title: Text(conversation.title),
            subtitle: Text(conversation.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(conversation.timestamp),
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}
