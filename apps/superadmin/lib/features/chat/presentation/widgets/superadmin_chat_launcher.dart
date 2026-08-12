import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_controller.dart';
import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';
import 'superadmin_chat_composer.dart';
import 'superadmin_chat_message_bubble.dart';

/// Compatibility holder while the shell migrates away from saved launcher positions.
/// The launcher is intentionally fixed to its safe-area anchor.
@Deprecated('The chat launcher is fixed; position is no longer configurable.')
final class SuperadminChatLauncherPositionController extends ChangeNotifier {
  SuperadminChatLauncherPositionController({bool persist = false});

  void reset() {}
}

final class SuperadminChatLauncher extends StatefulWidget {
  const SuperadminChatLauncher({
    required this.onOpenConversations,
    this.bottomClearance = 0,
    this.positionController,
    this.controller,
    super.key,
  }) : assert(bottomClearance >= 0);

  final VoidCallback onOpenConversations;
  final double bottomClearance;
  final SuperadminChatLauncherPositionController? positionController;

  /// The owner supplies production conversations. Without it, the panel stays
  /// empty and routes creation to the full, authorised conversations surface.
  final SuperadminChatController? controller;

  @override
  State<SuperadminChatLauncher> createState() => _SuperadminChatLauncherState();
}

final class _SuperadminChatLauncherState extends State<SuperadminChatLauncher> {
  late final SuperadminChatController _controller;
  late final bool _ownsController;
  final _focusNode = FocusNode(debugLabel: 'Launcher de conversas');
  final _overlayFocusNode = FocusNode(debugLabel: 'Painel de conversas');
  OverlayEntry? _entry;
  var _hovered = false;
  var _focused = false;
  var _compactSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SuperadminChatController(const []);
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _entry?.remove();
    _controller.removeListener(_handleControllerChanged);
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    _overlayFocusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _handleFocus() => setState(() => _focused = _focusNode.hasFocus);

  Future<void> _open() async {
    if (MediaQuery.sizeOf(context).width <= 600) {
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

  @override
  Widget build(BuildContext context) {
    if (_compactSheetOpen) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final highlighted = _hovered || _focused || _entry != null;
    final compact = MediaQuery.sizeOf(context).width <= 600;
    final unreadCount = _controller.conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
    final unreadLabel = switch (unreadCount) {
      0 => 'nenhuma mensagem não lida',
      1 => '1 mensagem não lida',
      _ => '$unreadCount mensagens não lidas',
    };
    final semanticsLabel = 'Abrir conversas, $unreadLabel';
    final shape = compact
        ? CircleBorder(
            side: BorderSide(color: highlighted ? colors.primary : colors.outlineVariant),
          )
        : StadiumBorder(
            side: BorderSide(
              color: highlighted ? colors.onPrimary.withValues(alpha: 0.72) : colors.primary,
            ),
          );
    final badge = Badge(
      isLabelVisible: true,
      label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
      backgroundColor: colors.error,
      textColor: colors.onError,
      child: Icon(
        compact ? Icons.forum_outlined : Icons.send_outlined,
        color: compact ? colors.primary : colors.onPrimary,
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: semanticsLabel,
        onTap: _open,
        child: Material(
          key: const Key('superadmin-chat-launcher-surface'),
          color: compact ? colors.surface : colors.primary,
          elevation: compact ? 2 : 0,
          shadowColor: colors.shadow.withValues(alpha: 0.18),
          shape: shape,
          clipBehavior: Clip.none,
          child: InkWell(
            focusNode: _focusNode,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onTap: _open,
            customBorder: shape,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: compact
                ? SizedBox.square(
                    dimension: CoeloSize.touchMin,
                    child: Center(child: badge),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: CoeloSize.touchMin,
                      minWidth: CoeloSize.touchMin,
                      maxWidth: 148,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          badge,
                          const SizedBox(width: CoeloSpacing.space2),
                          const Flexible(
                            child: Text(
                              'Mens.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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
    final conversations = controller.visibleConversations;
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
          child: conversations.isEmpty
              ? _EmptyInbox(
                  hasSearch: controller.search.trim().isNotEmpty,
                  onCreate: _openNewMessage,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
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

  void _openNewMessage() {
    widget.onClose();
    widget.onOpenConversations();
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
          onEmojiSelected: widget.controller.sendEmoji,
          onAudio: null,
          onImage: null,
        ),
      ],
    );
  }
}

final class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.hasSearch, required this.onCreate});

  final bool hasSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, color: colors.onSurfaceVariant),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              hasSearch ? 'Nenhuma conversa encontrada' : 'Nenhuma conversa ainda',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              hasSearch ? 'Tente ajustar sua busca.' : 'Comece uma conversa na tela completa.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            FilledButton.icon(
              key: const Key('superadmin-chat-launcher-empty-cta'),
              onPressed: onCreate,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Nova mensagem'),
            ),
          ],
        ),
      ),
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
