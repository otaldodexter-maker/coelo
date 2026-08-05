import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class SuperadminDirectoryTableViewOption<T> {
  const SuperadminDirectoryTableViewOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Private Superadmin composition for cards/table and table detail variants.
final class SuperadminDirectoryViewToggle<T> extends StatefulWidget {
  const SuperadminDirectoryViewToggle({
    required this.cardsSelected,
    required this.groupedView,
    required this.selectedTableView,
    required this.tableViews,
    required this.onCardsSelected,
    required this.onTableViewSelected,
    this.cardsKey,
    this.tableKey,
    super.key,
  });

  final bool cardsSelected;
  final T groupedView;
  final T selectedTableView;
  final List<SuperadminDirectoryTableViewOption<T>> tableViews;
  final VoidCallback onCardsSelected;
  final ValueChanged<T> onTableViewSelected;
  final Key? cardsKey;
  final Key? tableKey;

  @override
  State<SuperadminDirectoryViewToggle<T>> createState() => _SuperadminDirectoryViewToggleState<T>();
}

final class _SuperadminDirectoryViewToggleState<T> extends State<SuperadminDirectoryViewToggle<T>> {
  final _tableSegmentContentKey = GlobalKey();
  MenuController? _menuController;
  static const _segmentWidth = 64.0;
  static const _toggleWidth = _segmentWidth * 2;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_openForTableSegmentFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_openForTableSegmentFocus);
    super.dispose();
  }

  void _selectTableView(T value) {
    widget.onTableViewSelected(value);
  }

  void _openMenu() {
    if (widget.tableViews.length <= 1) return;
    final controller = _menuController;
    if (controller != null && !controller.isOpen) controller.open();
  }

  void _openForTableSegmentFocus() {
    if (!HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.tab)) return;
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final tableContext = _tableSegmentContentKey.currentContext;
    if (focusedContext == null || tableContext == null) return;

    var tableSegmentFocused = focusedContext == tableContext;
    tableContext.visitAncestorElements((ancestor) {
      if (ancestor == focusedContext) {
        tableSegmentFocused = true;
        return false;
      }
      return true;
    });
    if (tableSegmentFocused) _openMenu();
  }

  bool _isTableHalf(double dx) => dx >= _segmentWidth;

  @override
  Widget build(BuildContext context) => CoeloAdminFlyout<T>(
    items: [
      for (final option in widget.tableViews)
        CoeloAdminFlyoutItem<T>(
          value: option.value,
          label: option.label,
          selected: option.value == widget.selectedTableView,
        ),
    ],
    itemWidth: 220,
    onSelected: _selectTableView,
    builder: (context, controller) {
      _menuController = controller;
      return Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              HardwareKeyboard.instance.isAltPressed &&
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _openMenu();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SizedBox(
          width: _toggleWidth,
          height: CoeloSize.touchMin,
          child: MouseRegion(
            onEnter: (event) {
              if (_isTableHalf(event.localPosition.dx)) _openMenu();
            },
            onHover: (event) {
              if (_isTableHalf(event.localPosition.dx)) _openMenu();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: (details) {
                if (_isTableHalf(details.localPosition.dx)) _openMenu();
              },
              child: SegmentedButton<bool>(
                style: ButtonStyle(
                  fixedSize: WidgetStatePropertyAll(Size(_segmentWidth, CoeloSize.touchMin)),
                  padding: WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: Semantics(
                      label: 'Exibir como cards',
                      child: Icon(key: widget.cardsKey, Icons.grid_view_rounded),
                    ),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: KeyedSubtree(
                      key: _tableSegmentContentKey,
                      child: Semantics(
                        label: 'Exibir como tabela',
                        child: Icon(key: widget.tableKey, Icons.table_rows_rounded),
                      ),
                    ),
                  ),
                ],
                selected: {widget.cardsSelected},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.single) {
                    widget.onCardsSelected();
                  } else {
                    _selectTableView(widget.groupedView);
                  }
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
