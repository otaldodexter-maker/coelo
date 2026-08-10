import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class SuperadminUnderlineTab<T> {
  const SuperadminUnderlineTab({required this.value, required this.label});

  final T value;
  final String label;
}

/// App-local selector for lightweight directory categories.
final class SuperadminUnderlineTabs<T> extends StatefulWidget {
  const SuperadminUnderlineTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<SuperadminUnderlineTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  State<SuperadminUnderlineTabs<T>> createState() => _SuperadminUnderlineTabsState<T>();
}

final class _SuperadminUnderlineTabsState<T> extends State<SuperadminUnderlineTabs<T>> {
  final ScrollController _controller = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<T, GlobalKey> _itemKeys = <T, GlobalKey>{};
  double? _lastViewportWidth;
  bool _showTrailingFade = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateTrailingFade);
  }

  @override
  void didUpdateWidget(covariant SuperadminUnderlineTabs<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _scheduleReveal(widget.selected);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateTrailingFade);
    _controller.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(T value) => _itemKeys.putIfAbsent(value, GlobalKey.new);

  void _scheduleReveal(T value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateTrailingFade();
      unawaited(_reveal(value));
    });
  }

  void _updateTrailingFade() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final show = position.maxScrollExtent - position.pixels > 0.5;
    if (show == _showTrailingFade) return;
    setState(() => _showTrailingFade = show);
  }

  Future<void> _reveal(T value) async {
    if (!_controller.hasClients) return;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    final item = _itemKeys[value]?.currentContext?.findRenderObject();
    if (viewport is! RenderBox || item is! RenderBox) return;
    final origin = item.localToGlobal(Offset.zero, ancestor: viewport);
    final right = origin.dx + item.size.width;
    final position = _controller.position;
    final itemContentRight = position.pixels + right;
    final contentWidth = position.maxScrollExtent + viewport.size.width;
    final hasContentAfterItem = itemContentRight < contentWidth - 0.5;
    final visibleRight = viewport.size.width - (hasContentAfterItem ? CoeloSpacing.space6 : 0);
    final delta = origin.dx < 0
        ? origin.dx
        : right > visibleRight
        ? right - visibleRight
        : 0.0;
    if (delta == 0) return;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(target);
    } else {
      await position.animateTo(target, duration: CoeloMotion.fast, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_lastViewportWidth != constraints.maxWidth) {
          _lastViewportWidth = constraints.maxWidth;
          _scheduleReveal(widget.selected);
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                  dragDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.invertedStylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: SingleChildScrollView(
                  key: _viewportKey,
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tab in widget.tabs)
                        SizedBox(
                          key: _keyFor(tab.value),
                          child: _SuperadminUnderlineTabItem<T>(
                            tab: tab,
                            selected: tab.value == widget.selected,
                            onFocused: () => _scheduleReveal(tab.value),
                            onTap: () => widget.onSelected(tab.value),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_showTrailingFade)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  bottom: 1,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: SizedBox(
                        key: const ValueKey('superadmin-underline-tabs-trailing-fade'),
                        width: CoeloSpacing.space6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: AlignmentDirectional.centerStart,
                              end: AlignmentDirectional.centerEnd,
                              colors: [colors.surface.withValues(alpha: 0), colors.surface],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

final class _SuperadminUnderlineTabItem<T> extends StatefulWidget {
  const _SuperadminUnderlineTabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onFocused,
  });

  final SuperadminUnderlineTab<T> tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onFocused;

  @override
  State<_SuperadminUnderlineTabItem<T>> createState() => _SuperadminUnderlineTabItemState<T>();
}

final class _SuperadminUnderlineTabItemState<T> extends State<_SuperadminUnderlineTabItem<T>> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlighted = _hovered || _focused || _pressed;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          focusNode: _focusNode,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (value) {
              widget.onFocused();
            }
          },
          onHighlightChanged: (value) => setState(() => _pressed = value),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)) {
              return colors.primaryContainer.withValues(alpha: .48);
            }
            return Colors.transparent;
          }),
          child: Container(
            key: ValueKey('superadmin-underline-tab-${widget.tab.value}'),
            constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
            alignment: Alignment.center,
            height: CoeloSize.touchMin,
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            decoration: BoxDecoration(
              border: _focused ? Border.all(color: colors.primary) : null,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              color: Colors.transparent,
            ),
            foregroundDecoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.selected ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              widget.tab.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: widget.selected || highlighted ? colors.primary : colors.onSurfaceVariant,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
