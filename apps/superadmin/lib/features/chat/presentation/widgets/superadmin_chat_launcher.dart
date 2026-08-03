import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_controller.dart';
import '../chat_fixtures.dart';
import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';
import 'superadmin_chat_composer.dart';
import 'superadmin_chat_flow_dialog.dart';
import 'superadmin_chat_message_bubble.dart';

final class SuperadminChatLauncherPositionController extends ValueNotifier<Offset?> {
  SuperadminChatLauncherPositionController() : super(null);

  void reset() => value = null;
}

final class SuperadminChatLauncher extends StatefulWidget {
  const SuperadminChatLauncher({
    required this.onOpenConversations,
    this.bottomClearance = 0,
    this.positionController,
    super.key,
  }) : assert(bottomClearance >= 0);

  final VoidCallback onOpenConversations;
  final double bottomClearance;
  final SuperadminChatLauncherPositionController? positionController;

  @override
  State<SuperadminChatLauncher> createState() => _SuperadminChatLauncherState();
}

final class _SuperadminChatLauncherState extends State<SuperadminChatLauncher> {
  late final SuperadminChatController _controller;
  final _focusNode = FocusNode(debugLabel: 'Launcher de conversas');
  final _overlayFocusNode = FocusNode(debugLabel: 'Painel de conversas');
  final _launcherKey = GlobalKey(debugLabel: 'Launcher móvel de conversas');
  OverlayEntry? _entry;
  var _hovered = false;
  var _focused = false;
  var _compactSheetOpen = false;
  var _positionOffset = Offset.zero;
  late final SuperadminChatLauncherPositionController _positionController;
  late final bool _ownsPositionController;

  @override
  void initState() {
    super.initState();
    _controller = SuperadminChatController(superadminChatConversations);
    _ownsPositionController = widget.positionController == null;
    _positionController = widget.positionController ?? SuperadminChatLauncherPositionController();
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
    if (_ownsPositionController) _positionController.dispose();
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
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _closeOverlay(restoreFocus: false),
              ),
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

  void _closeOverlay({bool restoreFocus = true}) {
    _entry?.remove();
    _entry = null;
    if (!mounted) return;
    if (restoreFocus) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() {});
    }
  }

  KeyEventResult _handleLauncherKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _resetPosition();
      return KeyEventResult.handled;
    }
    if (!HardwareKeyboard.instance.isAltPressed) return KeyEventResult.ignored;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => const Offset(-CoeloSpacing.space3, 0),
      LogicalKeyboardKey.arrowRight => const Offset(CoeloSpacing.space3, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -CoeloSpacing.space3),
      LogicalKeyboardKey.arrowDown => const Offset(0, CoeloSpacing.space3),
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;
    _moveBy(delta);
    return KeyEventResult.handled;
  }

  void _resetPosition() {
    if (_positionOffset == Offset.zero && _positionController.value == null) return;
    _positionController.reset();
    setState(() => _positionOffset = Offset.zero);
  }

  void _moveBy(Offset delta) {
    final renderObject = _launcherKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final media = MediaQuery.of(context);
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final minLeft = media.padding.left + CoeloSpacing.space2;
    final maxLeft = media.size.width - media.padding.right - CoeloSpacing.space2 - rect.width;
    final minTop = media.padding.top + CoeloSpacing.space2;
    final maxTop = media.size.height - media.padding.bottom - CoeloSpacing.space2 - rect.height;
    final clampedMaxLeft = maxLeft < minLeft ? minLeft : maxLeft;
    final clampedMaxTop = maxTop < minTop ? minTop : maxTop;
    final targetLeft = (rect.left + delta.dx).clamp(minLeft, clampedMaxLeft).toDouble();
    final targetTop = (rect.top + delta.dy).clamp(minTop, clampedMaxTop).toDouble();
    final applied = Offset(targetLeft - rect.left, targetTop - rect.top);
    if (applied != Offset.zero) setState(() => _positionOffset += applied);
    _positionController.value = Offset(targetLeft, targetTop);
  }

  void _restorePosition() {
    final desired = _positionController.value;
    if (desired == null) {
      _moveBy(Offset.zero);
      _positionController.reset();
      return;
    }
    final renderObject = _launcherKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final current = renderObject.localToGlobal(Offset.zero);
    _moveBy(desired - current);
  }

  @override
  Widget build(BuildContext context) {
    if (_compactSheetOpen) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
    final colors = Theme.of(context).colorScheme;
    final highlighted = _hovered || _focused || _entry != null;
    final compact = MediaQuery.sizeOf(context).width < CoeloBreakpoints.expanded.minWidth;
    final expanded = !compact && highlighted;
    final foreground = highlighted ? colors.onPrimary : colors.onSurface;
    return Transform.translate(
      offset: _positionOffset,
      child: GestureDetector(
        key: _launcherKey,
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => _moveBy(details.delta),
        child: Focus(
          onKeyEvent: _handleLauncherKey,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Tooltip(
              message: 'Abrir conversas',
              child: Semantics(
                button: true,
                label: 'Abrir conversas. 3 mensagens não lidas. Alt mais setas move.',
                child: Material(
                  key: const Key('superadmin-chat-launcher-surface'),
                  color: highlighted ? colors.primary : colors.surfaceContainerHighest,
                  shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
                  clipBehavior: Clip.none,
                  child: InkWell(
                    focusNode: _focusNode,
                    onTap: _open,
                    customBorder: const StadiumBorder(),
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    child: AnimatedSize(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : CoeloMotion.short,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: CoeloSize.touchMin,
                          minWidth: CoeloSize.touchMin,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
                          child: expanded
                              ? Row(
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
                                )
                              : Badge(
                                  label: const Text('3'),
                                  child: Icon(Icons.send_outlined, color: foreground),
                                ),
                        ),
                      ),
                    ),
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
          child: Row(
            children: [
              Expanded(
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
              const SizedBox(width: CoeloSpacing.space2),
              IconButton(
                key: const Key('superadmin-chat-launcher-new-message'),
                tooltip: 'Criar conversa',
                onPressed: _openNewMessage,
                color: Theme.of(context).colorScheme.primary,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                  ),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
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

  Future<void> _openNewMessage() async {
    widget.controller.clearRecipients();
    final completed = await showDialog<bool>(
      context: context,
      builder: (_) => SuperadminChatMessageDialog(
        controller: widget.controller,
        options: superadminChatContextOptions,
      ),
    );
    if (!mounted || completed != true) return;
    setState(() => _threadId = widget.controller.selectedConversation.id);
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
