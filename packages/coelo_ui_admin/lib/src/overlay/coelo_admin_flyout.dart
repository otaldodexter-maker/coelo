import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

enum CoeloAdminFlyoutTone { standard, negative }

final class CoeloAdminFlyoutItem<T> {
  const CoeloAdminFlyoutItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.semanticLabel,
    this.selected = false,
    this.enabled = true,
    this.startsGroup = false,
    this.tone = CoeloAdminFlyoutTone.standard,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final String? semanticLabel;
  final bool selected;
  final bool enabled;
  final bool startsGroup;
  final CoeloAdminFlyoutTone tone;
}

/// Canonical Coelo flyout used by administrative menus and local actions.
///
/// Negative actions always use the semantic error palette, including hover.
final class CoeloAdminFlyout<T> extends StatefulWidget {
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
  State<CoeloAdminFlyout<T>> createState() => _CoeloAdminFlyoutState<T>();
}

final class _CoeloAdminFlyoutState<T> extends State<CoeloAdminFlyout<T>> {
  final MenuController _menuController = MenuController();
  FocusNode? _returnFocusNode;
  bool _restoreFocusOnClose = false;

  void _handleOpen() {
    _returnFocusNode = FocusManager.instance.primaryFocus;
    _restoreFocusOnClose = false;
    FocusManager.instance.addEarlyKeyEventHandler(_handleKeyEvent);
  }

  void _handleClose() {
    final returnFocusNode = _returnFocusNode;
    final restoreFocus = _restoreFocusOnClose;
    _restoreFocusOnClose = false;
    _returnFocusNode = null;
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKeyEvent);
    if (!restoreFocus ||
        returnFocusNode == null ||
        returnFocusNode.context == null ||
        !returnFocusNode.canRequestFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && returnFocusNode.context != null && returnFocusNode.canRequestFocus) {
        returnFocusNode.requestFocus();
      }
    });
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      _restoreFocusOnClose = true;
      _menuController.close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final radius = BorderRadius.circular(CoeloRadius.lg);
    const panelPadding = CoeloSpacing.space2 * 2;
    final safeLeft = math.max(mediaQuery.padding.left, mediaQuery.viewPadding.left);
    final safeTop = math.max(mediaQuery.padding.top, mediaQuery.viewPadding.top);
    final safeRight = math.max(mediaQuery.padding.right, mediaQuery.viewPadding.right);
    final safeBottom = math.max(mediaQuery.padding.bottom, mediaQuery.viewPadding.bottom);
    final desiredPanelWidth = widget.itemWidth + panelPadding;
    final availablePanelWidth = math.max(
      0.0,
      mediaQuery.size.width - safeLeft - safeRight - (CoeloSpacing.space2 * 2),
    );
    final availablePanelHeight = math.max(
      0.0,
      mediaQuery.size.height - safeTop - safeBottom - (CoeloSpacing.space2 * 2),
    );
    final panelWidth = math.min(desiredPanelWidth, availablePanelWidth);
    final effectiveItemWidth = math.max(0.0, panelWidth - panelPadding);
    final overlayPadding = EdgeInsets.fromLTRB(
      safeLeft + CoeloSpacing.space2,
      safeTop + CoeloSpacing.space2,
      safeRight + CoeloSpacing.space2,
      safeBottom + CoeloSpacing.space2,
    );
    final reservedPadding = EdgeInsets.fromLTRB(
      safeLeft + CoeloSpacing.space2,
      safeTop + CoeloSpacing.space2,
      safeRight + CoeloSpacing.space2,
      safeBottom + CoeloSpacing.space2,
    );
    final effectiveAlignmentOffset = Offset(
      widget.alignmentOffset.dx - safeRight - CoeloSpacing.space1,
      widget.alignmentOffset.dy,
    );
    return MediaQuery(
      data: mediaQuery.copyWith(padding: overlayPadding),
      child: MenuAnchor(
        controller: _menuController,
        useRootOverlay: true,
        crossAxisUnconstrained: false,
        onOpen: _handleOpen,
        onClose: _handleClose,
        reservedPadding: reservedPadding,
        alignmentOffset: effectiveAlignmentOffset,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(CoeloElevation.level2),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
          minimumSize: WidgetStatePropertyAll(Size(panelWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(panelWidth, availablePanelHeight)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: colors.outlineVariant),
            ),
          ),
        ),
        menuChildren: [
          for (var index = 0; index < widget.items.length; index++) ...[
            if (index > 0 && !widget.items[index].startsGroup)
              const SizedBox(height: CoeloSpacing.space1),
            if (widget.items[index].startsGroup)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
                child: Divider(height: 1, color: colors.outlineVariant),
              ),
            SizedBox(
              width: effectiveItemWidth,
              child: _FlyoutMenuItem<T>(item: widget.items[index], onSelected: widget.onSelected),
            ),
          ],
        ],
        builder: (context, controller, child) => widget.builder(context, controller),
      ),
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

    final customIconColor = item.enabled ? item.iconColor : item.iconColor?.withValues(alpha: 0.38);

    return Semantics(
      label: item.semanticLabel,
      selected: item.selected,
      child: MenuItemButton(
        onPressed: item.enabled ? () => onSelected(item.value) : null,
        leadingIcon: item.icon == null
            ? null
            : Icon(item.icon, size: CoeloSize.iconSm, color: customIconColor),
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
                states.contains(WidgetState.pressed) ||
                item.selected) {
              return hoverForeground;
            }
            return foreground;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed) ||
                item.selected) {
              return hoverBackground;
            }
            return Colors.transparent;
          }),
        ),
        child: item.semanticLabel == null
            ? Text(item.label)
            : ExcludeSemantics(child: Text(item.label)),
      ),
    );
  }
}
