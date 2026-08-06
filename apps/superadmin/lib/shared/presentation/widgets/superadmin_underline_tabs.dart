import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class SuperadminUnderlineTab<T> {
  const SuperadminUnderlineTab({required this.value, required this.label});

  final T value;
  final String label;
}

/// App-local selector for lightweight directory categories.
final class SuperadminUnderlineTabs<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              _SuperadminUnderlineTabItem<T>(
                tab: tab,
                selected: tab.value == selected,
                onTap: () => onSelected(tab.value),
              ),
          ],
        ),
      ),
    );
  }
}

final class _SuperadminUnderlineTabItem<T> extends StatefulWidget {
  const _SuperadminUnderlineTabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final SuperadminUnderlineTab<T> tab;
  final bool selected;
  final VoidCallback onTap;

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
          onFocusChange: (value) => setState(() => _focused = value),
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
