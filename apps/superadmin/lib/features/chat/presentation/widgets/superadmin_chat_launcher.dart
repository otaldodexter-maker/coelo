import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

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
  final _layerLink = LayerLink();
  final _focusNode = FocusNode(debugLabel: 'Launcher de conversas');
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
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.72,
          child: _CompactLauncherContent(
            controller: _controller,
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
    _entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Stack(
          children: [
            GestureDetector(behavior: HitTestBehavior.translucent, onTap: _closeOverlay),
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.topRight,
              followerAnchor: Alignment.bottomRight,
              offset: const Offset(0, -CoeloSpacing.space2),
              child: Material(
                key: const Key('superadmin-chat-launcher-panel'),
                elevation: 4,
                shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.16),
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(CoeloRadius.xl),
                child: SizedBox(
                  width: CoeloSize.touchMin * 8,
                  height: CoeloSize.touchMin * 11,
                  child: _CompactLauncherContent(
                    controller: _controller,
                    onOpenConversations: widget.onOpenConversations,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _closeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_compactSheetOpen) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final highlighted = _hovered || _focused;
    final compact = MediaQuery.sizeOf(context).width < CoeloBreakpoints.expanded.minWidth;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(CoeloSize.touchMin, CoeloSize.touchMin)),
      fixedSize: compact ? const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)) : null,
      shape: compact ? const WidgetStatePropertyAll(CircleBorder()) : null,
      backgroundColor: WidgetStatePropertyAll(
        highlighted ? colors.primary : colors.surfaceContainerHighest,
      ),
      foregroundColor: WidgetStatePropertyAll(highlighted ? colors.onPrimary : colors.onSurface),
    );
    final icon = Icon(
      Icons.forum_outlined,
      color: highlighted ? colors.onPrimary : colors.onSurface,
    );
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: 'Abrir conversas',
          child: Semantics(
            button: true,
            label: 'Abrir conversas',
            child: compact
                ? FilledButton.tonal(
                    key: const Key('superadmin-chat-launcher-surface'),
                    focusNode: _focusNode,
                    onPressed: _open,
                    style: style,
                    child: icon,
                  )
                : FilledButton.tonalIcon(
                    key: const Key('superadmin-chat-launcher-surface'),
                    focusNode: _focusNode,
                    onPressed: _open,
                    style: style,
                    icon: icon,
                    label: Text(
                      'Mensagens',
                      style: TextStyle(color: highlighted ? colors.onPrimary : colors.onSurface),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

final class _CompactLauncherContent extends StatefulWidget {
  const _CompactLauncherContent({required this.controller, required this.onOpenConversations});

  final SuperadminChatController controller;
  final VoidCallback onOpenConversations;

  @override
  State<_CompactLauncherContent> createState() => _CompactLauncherContentState();
}

final class _CompactLauncherContentState extends State<_CompactLauncherContent> {
  final _composer = TextEditingController();
  String? _threadId;

  @override
  void dispose() {
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CoeloSpacing.space4,
                CoeloSpacing.space3,
                CoeloSpacing.space2,
                CoeloSpacing.space2,
              ),
              child: Row(
                children: [
                  if (thread != null)
                    IconButton(
                      tooltip: 'Voltar para conversas',
                      onPressed: () => setState(() => _threadId = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Text(
                      thread?.title ?? 'Conversas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenConversations,
                    child: const Text('Abrir tela'),
                  ),
                ],
              ),
            ),
            Expanded(child: thread == null ? _inbox() : _thread(thread)),
          ],
        );
      },
    );
  }

  Widget _inbox() {
    return ListView.builder(
      padding: const EdgeInsets.all(CoeloSpacing.space2),
      itemCount: widget.controller.conversations.take(4).length,
      itemBuilder: (context, index) {
        final conversation = widget.controller.conversations[index];
        return ListTile(
          minTileHeight: CoeloSize.touchMin + CoeloSpacing.space2,
          leading: SuperadminChatAvatar(
            label: conversation.title,
            initials: conversation.initials,
            size: CoeloSize.avatarMd,
          ),
          title: Text(conversation.title),
          subtitle: Text(conversation.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(conversation.timestamp),
          onTap: () {
            widget.controller.selectConversation(conversation.id);
            setState(() => _threadId = conversation.id);
          },
        );
      },
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
