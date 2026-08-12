import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Compatibility holder while the shell migrates away from saved launcher positions.
///
/// The launcher is deliberately anchored to the shell safe area. It exposes no drag
/// state because a floating, persisted position made the chat affordance unreliable.
@Deprecated('The chat launcher is fixed; position is no longer configurable.')
final class SuperadminChatLauncherPositionController extends ChangeNotifier {
  SuperadminChatLauncherPositionController({bool persist = false});

  void reset() {}
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

  @override
  State<SuperadminChatLauncher> createState() => _SuperadminChatLauncherState();
}

final class _SuperadminChatLauncherState extends State<SuperadminChatLauncher> {
  final _focusNode = FocusNode(debugLabel: 'Launcher de conversas');
  var _hovered = false;
  var _focused = false;
  late int _unreadCount;

  @override
  void initState() {
    super.initState();
    _unreadCount = widget.unreadCount;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refreshUnreadCount()));
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

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width <= 600;
    final highlighted = _hovered || _focused;
    final unreadCount = _unreadCount;
    final unreadLabel = switch (unreadCount) {
      0 => 'nenhuma mensagem nao lida',
      1 => '1 mensagem nao lida',
      _ => '$unreadCount mensagens nao lidas',
    };
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
      isLabelVisible: unreadCount > 0,
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
        label: 'Abrir conversas, $unreadLabel',
        onTap: _openConversations,
        child: Tooltip(
          message: 'Conversas — $unreadLabel',
          child: Material(
            key: const Key('superadmin-chat-launcher-surface'),
            color: compact ? colors.surface : colors.primary,
            elevation: compact ? 2 : 0,
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
      ),
    );
  }
}
