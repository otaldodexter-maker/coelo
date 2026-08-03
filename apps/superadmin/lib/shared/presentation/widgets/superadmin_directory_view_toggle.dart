import 'package:coelo_tokens/coelo_tokens.dart';
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
  final _menuController = MenuController();

  void _selectTableView(T value) {
    widget.onTableViewSelected(value);
    _menuController.close();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, CoeloSpacing.space1),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(CoeloElevation.level2),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        for (final option in widget.tableViews)
          SizedBox(
            width: 220,
            child: MenuItemButton(
              onPressed: () => _selectTableView(option.value),
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  final highlighted =
                      option.value == widget.selectedTableView ||
                      states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused);
                  return highlighted ? colors.primary : colors.onSurfaceVariant;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  final highlighted =
                      option.value == widget.selectedTableView ||
                      states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused);
                  return highlighted ? colors.primaryContainer : Colors.transparent;
                }),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
                ),
              ),
              child: Text(option.label),
            ),
          ),
      ],
      builder: (context, controller, _) => Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              HardwareKeyboard.instance.isAltPressed &&
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            controller.open();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SegmentedButton<bool>(
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(CoeloSize.touchMin, CoeloSize.touchMin)),
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: CoeloSpacing.space3)),
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
              icon: MouseRegion(
                onEnter: (_) => controller.open(),
                child: GestureDetector(
                  onLongPress: controller.open,
                  child: Semantics(
                    label: 'Exibir como tabela',
                    child: Icon(key: widget.tableKey, Icons.table_rows_rounded),
                  ),
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
    );
  }
}
