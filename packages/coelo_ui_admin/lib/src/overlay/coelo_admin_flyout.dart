import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

enum CoeloAdminFlyoutTone { standard, negative }

final class CoeloAdminFlyoutItem<T> {
  const CoeloAdminFlyoutItem({
    required this.value,
    required this.label,
    this.icon,
    this.selected = false,
    this.enabled = true,
    this.startsGroup = false,
    this.tone = CoeloAdminFlyoutTone.standard,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final bool startsGroup;
  final CoeloAdminFlyoutTone tone;
}

/// Canonical Coelo flyout used by administrative menus and local actions.
///
/// Negative actions always use the semantic error palette, including hover.
final class CoeloAdminFlyout<T> extends StatelessWidget {
  const CoeloAdminFlyout({
    required this.items,
    required this.onSelected,
    required this.builder,
    this.itemWidth = 220,
    this.alignmentOffset = const Offset(0, CoeloSpacing.space1),
    super.key,
  });

  final List<CoeloAdminFlyoutItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget Function(BuildContext context, MenuController controller) builder;
  final double itemWidth;
  final Offset alignmentOffset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(CoeloRadius.lg);

    return MenuAnchor(
      alignmentOffset: alignmentOffset,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(CoeloElevation.level2),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
        minimumSize: WidgetStatePropertyAll(Size(itemWidth, 0)),
        maximumSize: WidgetStatePropertyAll(Size(itemWidth, double.infinity)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        for (final item in items) ...[
          if (item.startsGroup)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
              child: Divider(height: 1, color: colors.outlineVariant),
            ),
          _FlyoutMenuItem<T>(item: item, onSelected: onSelected),
        ],
      ],
      builder: (context, controller, child) => builder(context, controller),
    );
  }
}

final class _FlyoutMenuItem<T> extends StatelessWidget {
  const _FlyoutMenuItem({required this.item, required this.onSelected});

  final CoeloAdminFlyoutItem<T> item;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final negative = item.tone == CoeloAdminFlyoutTone.negative;
    final foreground = negative ? colors.error : colors.onSurface;
    final hoverBackground = negative ? colors.errorContainer : colors.primaryContainer;
    final hoverForeground = negative ? colors.error : colors.primary;

    return Semantics(
      selected: item.selected,
      child: MenuItemButton(
        onPressed: item.enabled ? () => onSelected(item.value) : null,
        leadingIcon: item.icon == null ? null : Icon(item.icon, size: CoeloSize.iconSm),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: CoeloSpacing.space3, vertical: CoeloSpacing.space2),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (!item.enabled) return colors.onSurface.withValues(alpha: 0.38);
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                item.selected) {
              return hoverForeground;
            }
            return foreground;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                item.selected) {
              return hoverBackground;
            }
            return Colors.transparent;
          }),
        ),
        child: Text(item.label),
      ),
    );
  }
}
