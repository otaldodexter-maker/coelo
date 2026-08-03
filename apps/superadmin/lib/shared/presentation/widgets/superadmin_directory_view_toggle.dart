import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

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
  final _cardsFocusNode = FocusNode(debugLabel: 'Exibir como cards');
  final _tableFocusNode = FocusNode(debugLabel: 'Exibir como tabela');

  @override
  void initState() {
    super.initState();
    _tableFocusNode.addListener(_openForTableFocus);
  }

  @override
  void dispose() {
    _tableFocusNode
      ..removeListener(_openForTableFocus)
      ..dispose();
    _cardsFocusNode.dispose();
    super.dispose();
  }

  void _openForTableFocus() {
    if (_tableFocusNode.hasFocus && mounted) {
      _menuController.open();
    }
  }

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
        elevation: const WidgetStatePropertyAll(4),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space1)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        for (final option in widget.tableViews)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
            child: MenuItemButton(
              onPressed: () => _selectTableView(option.value),
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(220, CoeloSize.touchMin)),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  final active = option.value == widget.selectedTableView;
                  return active ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primary
                      : colors.onSurface;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  final active = option.value == widget.selectedTableView;
                  return active ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primaryContainer
                      : Colors.transparent;
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
      builder: (context, controller, _) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.full),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              key: widget.cardsKey,
              focusNode: _cardsFocusNode,
              selected: widget.cardsSelected,
              tooltip: 'Exibir como cards',
              icon: Icons.grid_view_rounded,
              onTap: widget.onCardsSelected,
            ),
            SizedBox(
              height: CoeloSize.touchMin,
              child: VerticalDivider(width: 1, color: colors.outlineVariant),
            ),
            MouseRegion(
              onEnter: (_) => controller.open(),
              child: _Segment(
                key: widget.tableKey,
                focusNode: _tableFocusNode,
                selected: !widget.cardsSelected,
                tooltip: 'Exibir como tabela. Mantenha pressionado para escolher a visão.',
                icon: Icons.table_rows_rounded,
                onTap: () => _selectTableView(widget.groupedView),
                onLongPress: controller.open,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Segment extends StatelessWidget {
  const _Segment({
    required this.focusNode,
    required this.selected,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final FocusNode focusNode;
  final bool selected;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          child: InkWell(
            focusNode: focusNode,
            onTap: onTap,
            onLongPress: onLongPress,
            hoverColor: colors.primaryContainer,
            focusColor: colors.primaryContainer,
            splashColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: SizedBox.square(
              dimension: CoeloSize.touchMin,
              child: Icon(icon, color: selected ? colors.primary : colors.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
