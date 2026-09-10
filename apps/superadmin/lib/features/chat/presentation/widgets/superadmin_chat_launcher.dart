import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/chat_repository.dart';

/// Stores the launcher position independently from the authorised chat data.
final class SuperadminChatLauncherPositionController extends ValueNotifier<Offset?> {
  SuperadminChatLauncherPositionController({this.persist = false}) : super(null) {
    if (persist) unawaited(_load());
  }

  static const _xKey = 'coelo.superadmin.chat_launcher.x';
  static const _yKey = 'coelo.superadmin.chat_launcher.y';
  final bool persist;
  SharedPreferencesAsync? _preferences;
  Offset? _normalized;

  bool get hasSavedPosition => _normalized != null || value != null;

  Future<void> _load() async {
    final preferences = _localPreferences();
    if (preferences == null) return;
    try {
      final x = await preferences.getDouble(_xKey);
      final y = await preferences.getDouble(_yKey);
      if (x == null || y == null) return;
      _normalized = Offset(x.clamp(0, 1).toDouble(), y.clamp(0, 1).toDouble());
      notifyListeners();
    } catch (_) {
      // A local preference failure must not block the authorised chat route.
    }
  }

  SharedPreferencesAsync? _localPreferences() {
    if (!persist) return null;
    try {
      return _preferences ??= SharedPreferencesAsync();
    } on StateError {
      return null;
    }
  }

  Offset? resolve(Rect bounds) {
    final normalized = _normalized;
    if (normalized == null) return value;
    return Offset(
      bounds.left + bounds.width * normalized.dx,
      bounds.top + bounds.height * normalized.dy,
    );
  }

  void save(Offset position, Rect bounds) {
    final x = bounds.width <= 0
        ? 0.0
        : ((position.dx - bounds.left) / bounds.width).clamp(0, 1).toDouble();
    final y = bounds.height <= 0
        ? 0.0
        : ((position.dy - bounds.top) / bounds.height).clamp(0, 1).toDouble();
    _normalized = Offset(x, y);
    value = position;
    final preferences = _localPreferences();
    if (preferences == null) return;
    preferences.setDouble(_xKey, x).ignore();
    preferences.setDouble(_yKey, y).ignore();
  }

  void reset() {
    _normalized = null;
    value = null;
    final preferences = _localPreferences();
    if (preferences == null) return;
    preferences.remove(_xKey).ignore();
    preferences.remove(_yKey).ignore();
  }
}

/// Opens the authorised conversations route.
///
/// The launcher does not carry a conversation cache. That prevents the shell from
/// rendering a second, local inbox with fixture data; the route is the single source
/// of truth for inbox, unread state and permissions.
final class SuperadminChatLauncher extends StatefulWidget {
  const SuperadminChatLauncher({
    required this.onOpenConversations,
    this.bottomClearance = 0,
    this.positionController,
    this.unreadCount = 0,
    this.loadUnreadCount,
    this.loadRecentConversations,
    super.key,
  }) : assert(bottomClearance >= 0),
       assert(unreadCount >= 0);

  final VoidCallback onOpenConversations;
  final double bottomClearance;
  final SuperadminChatLauncherPositionController? positionController;

  /// A server-derived count supplied by the shell when available.
  ///
  /// The default is deliberately zero instead of a synthetic conversation count.
  final int unreadCount;

  /// Loads the current count through the server-authorised inbox projection.
  ///
  /// A missing loader or a loader failure intentionally leaves the existing real
  /// value in place. The launcher never substitutes fixture conversations.
  final Future<int> Function()? loadUnreadCount;

  /// Carrega as conversas recentes autorizadas para a faixa de iniciais do pill
  /// (referencia CHAT aprovada pelo Owner em 10/09/2026: "Mensagens" com a
  /// contagem e as iniciais das conversas). Sem carregador a faixa nao aparece;
  /// o launcher nunca inventa conversas.
  final Future<List<ChatConversationSummary>> Function()? loadRecentConversations;

  /// Quantidade maxima de iniciais exibidas na faixa do pill.
  static const recentAvatarLimit = 5;

  @override
  State<SuperadminChatLauncher> createState() => _SuperadminChatLauncherState();
}

final class _SuperadminChatLauncherState extends State<SuperadminChatLauncher> {
  final _focusNode = FocusNode(debugLabel: 'Launcher de conversas');
  final _launcherKey = GlobalKey(debugLabel: 'Launcher móvel de conversas');
  var _hovered = false;
  var _focused = false;
  var _positionOffset = Offset.zero;
  var _restoreScheduled = false;
  late int _unreadCount;
  var _recentInitials = const <String>[];
  late final SuperadminChatLauncherPositionController _positionController;
  late final bool _ownsPositionController;

  @override
  void initState() {
    super.initState();
    _ownsPositionController = widget.positionController == null;
    _positionController = widget.positionController ?? SuperadminChatLauncherPositionController();
    _positionController.addListener(_handlePositionController);
    _unreadCount = widget.unreadCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshUnreadCount());
      unawaited(_refreshRecentConversations());
    });
  }

  @override
  void didUpdateWidget(covariant SuperadminChatLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unreadCount != widget.unreadCount) {
      _unreadCount = widget.unreadCount;
    }
    if (oldWidget.loadUnreadCount != widget.loadUnreadCount) {
      unawaited(_refreshUnreadCount());
    }
    if (oldWidget.loadRecentConversations != widget.loadRecentConversations) {
      unawaited(_refreshRecentConversations());
    }
  }

  Future<void> _refreshRecentConversations() async {
    final loadRecentConversations = widget.loadRecentConversations;
    if (loadRecentConversations == null) return;
    try {
      final conversations = await loadRecentConversations();
      if (!mounted) return;
      setState(() {
        _recentInitials = conversations
            .take(SuperadminChatLauncher.recentAvatarLimit)
            .map((conversation) => superadminChatInitials(conversation.title))
            .where((initials) => initials.isNotEmpty)
            .toList(growable: false);
      });
    } catch (_) {
      // Sem projecao autorizada a faixa fica como estava (ou vazia).
    }
  }

  Future<void> _refreshUnreadCount() async {
    final loadUnreadCount = widget.loadUnreadCount;
    if (loadUnreadCount == null) return;
    try {
      final loadedCount = await loadUnreadCount();
      if (!mounted) return;
      setState(() => _unreadCount = loadedCount < 0 ? 0 : loadedCount);
    } catch (_) {
      // The fail-safe state is the last server-derived value (or zero).
    }
  }

  void _openConversations() {
    unawaited(_refreshUnreadCount());
    widget.onOpenConversations();
  }

  void _handlePositionController() {
    if (!mounted) return;
    if (!_positionController.hasSavedPosition && _positionOffset != Offset.zero) {
      setState(() => _positionOffset = Offset.zero);
    }
    _schedulePositionRestore();
  }

  void _schedulePositionRestore() {
    if (_restoreScheduled) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (mounted) _restorePosition();
    });
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

  Rect _movementBounds(MediaQueryData media, Rect launcherRect) {
    final minLeft = media.padding.left + CoeloSpacing.space2;
    final maxLeft =
        media.size.width - media.padding.right - CoeloSpacing.space2 - launcherRect.width;
    final minTop = media.padding.top + CoeloSpacing.space2;
    final maxTop =
        media.size.height -
        media.padding.bottom -
        widget.bottomClearance -
        CoeloSpacing.space2 -
        launcherRect.height;
    return Rect.fromLTRB(
      minLeft,
      minTop,
      maxLeft < minLeft ? minLeft : maxLeft,
      maxTop < minTop ? minTop : maxTop,
    );
  }

  void _moveBy(Offset delta, {bool persist = true}) {
    final renderObject = _launcherKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final bounds = _movementBounds(MediaQuery.of(context), rect);
    final targetLeft = (rect.left + delta.dx).clamp(bounds.left, bounds.right).toDouble();
    final targetTop = (rect.top + delta.dy).clamp(bounds.top, bounds.bottom).toDouble();
    final applied = Offset(targetLeft - rect.left, targetTop - rect.top);
    if (applied != Offset.zero) setState(() => _positionOffset += applied);
    if (persist) _positionController.save(Offset(targetLeft, targetTop), bounds);
  }

  void _restorePosition() {
    final renderObject = _launcherKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final current = renderObject.localToGlobal(Offset.zero);
    final bounds = _movementBounds(MediaQuery.of(context), current & renderObject.size);
    final desired = _positionController.resolve(bounds);
    if (desired == null) {
      _moveBy(Offset.zero, persist: false);
      return;
    }
    _moveBy(desired - current, persist: false);
  }

  @override
  void dispose() {
    _positionController.removeListener(_handlePositionController);
    if (_ownsPositionController) _positionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedulePositionRestore();
    final colors = Theme.of(context).colorScheme;
    final highlighted = _hovered || _focused;
    final unreadCount = _unreadCount;
    final unreadLabel = switch (unreadCount) {
      0 => 'nenhuma mensagem nao lida',
      1 => '1 mensagem nao lida',
      _ => '$unreadCount mensagens nao lidas',
    };
    final isCompact = MediaQuery.sizeOf(context).width < CoeloBreakpoints.medium.minWidth;
    // Referencia CHAT (Owner, 10/09/2026): no mobile o launcher e um circulo
    // claro com o icone de conversas em laranja; nas demais larguras e o pill
    // laranja "Mensagens" com a contagem sobre o icone de envio e a faixa de
    // iniciais das conversas recentes.
    final surfaceColor = isCompact ? colors.surface : colors.primary;
    final foregroundColor = isCompact ? colors.primary : colors.onPrimary;
    final borderSide = BorderSide(
      color: highlighted
          ? (isCompact ? colors.primary : colors.onPrimary.withValues(alpha: 0.72))
          : colors.outlineVariant,
    );
    final OutlinedBorder shape = isCompact
        ? CircleBorder(side: borderSide)
        : StadiumBorder(side: borderSide);
    final badge = Badge(
      isLabelVisible: unreadCount > 0,
      label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
      backgroundColor: colors.error,
      textColor: colors.onError,
      child: Icon(isCompact ? Icons.forum_rounded : Icons.send_rounded, color: foregroundColor),
    );
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
            child: Semantics(
              button: true,
              excludeSemantics: true,
              label: 'Abrir conversas, $unreadLabel. Alt mais setas move. Home restaura.',
              onTap: _openConversations,
              child: Tooltip(
                message: 'Conversas — $unreadLabel',
                child: Material(
                  key: const Key('superadmin-chat-launcher-surface'),
                  color: surfaceColor,
                  elevation: 2,
                  shadowColor: colors.shadow.withValues(alpha: 0.18),
                  shape: shape,
                  clipBehavior: Clip.none,
                  child: InkWell(
                    focusNode: _focusNode,
                    onFocusChange: (focused) {
                      setState(() => _focused = focused);
                      if (focused) unawaited(_refreshUnreadCount());
                    },
                    onTap: _openConversations,
                    customBorder: shape,
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    child: SizedBox(
                      width: isCompact ? CoeloSize.touchMin : null,
                      height: CoeloSize.touchMin,
                      child: isCompact
                          ? Center(child: badge)
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  badge,
                                  const SizedBox(width: CoeloSpacing.space2),
                                  Text(
                                    'Mensagens',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: colors.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_recentInitials.isNotEmpty) ...[
                                    const SizedBox(width: CoeloSpacing.space3),
                                    _RecentAvatarStrip(initials: _recentInitials),
                                  ],
                                ],
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

/// Iniciais (ate duas) de um titulo de conversa, compartilhadas entre o pill do
/// launcher e a lista de Conversas.
String superadminChatInitials(String value) => value
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0])
    .join()
    .toUpperCase();

/// Faixa clara com as iniciais das conversas recentes, sobrepostas como na
/// referencia aprovada.
final class _RecentAvatarStrip extends StatelessWidget {
  const _RecentAvatarStrip({required this.initials});

  final List<String> initials;

  static const _avatarSize = 28.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final width = _avatarSize + (initials.length - 1) * (_avatarSize - _overlap);
    return ExcludeSemantics(
      child: Container(
        height: _avatarSize + CoeloSpacing.space1,
        padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space1 / 2),
        decoration: ShapeDecoration(color: colors.surface, shape: const StadiumBorder()),
        child: SizedBox(
          width: width,
          child: Stack(
            children: [
              for (var index = 0; index < initials.length; index++)
                Positioned(
                  left: index * (_avatarSize - _overlap),
                  top: CoeloSpacing.space1 / 2,
                  child: Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index.isEven ? colors.surfaceContainerHighest : colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 1.5),
                    ),
                    child: Text(initials[index], style: textStyle, maxLines: 1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
