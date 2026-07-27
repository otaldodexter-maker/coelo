import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'coelo_admin_table_column.dart';
import 'coelo_admin_table_controller.dart';

final class CoeloAdminResizableTable<T> extends StatefulWidget {
  const CoeloAdminResizableTable({
    required this.items,
    required this.rowKey,
    required this.pinnedColumn,
    required this.columns,
    required this.headerHeight,
    required this.rowHeight,
    this.onRowPressed,
    this.isSelected,
    this.controller,
    super.key,
  });

  final List<T> items;
  final Object Function(T item) rowKey;
  final CoeloAdminTableColumn<T> pinnedColumn;
  final List<CoeloAdminTableColumn<T>> columns;
  final double headerHeight;
  final double rowHeight;
  final ValueChanged<T>? onRowPressed;
  final bool Function(T item)? isSelected;
  final CoeloAdminTableController? controller;

  @override
  State<CoeloAdminResizableTable<T>> createState() => _CoeloAdminResizableTableState<T>();
}

final class _CoeloAdminResizableTableState<T> extends State<CoeloAdminResizableTable<T>> {
  final ScrollController _scrollController = ScrollController();
  final Map<Object, FocusNode> _rowFocusNodes = {};
  Object? _hoveredRowKey;
  Object? _focusedRowKey;
  late Map<String, double> _widths = {
    for (final column in _allColumns) column.id: column.initialWidth,
  };

  List<CoeloAdminTableColumn<T>> get _allColumns => [widget.pinnedColumn, ...widget.columns];

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(_focusRow);
    _reconcileRowFocusNodes();
  }

  @override
  void didUpdateWidget(covariant CoeloAdminResizableTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(_focusRow);
      widget.controller?.attach(_focusRow);
    }
    _reconcileRowFocusNodes();
    _widths = {
      for (final column in _allColumns)
        column.id: (_widths[column.id] ?? column.initialWidth)
            .clamp(column.minWidth, column.maxWidth)
            .toDouble(),
    };
  }

  @override
  void dispose() {
    widget.controller?.detach(_focusRow);
    for (final focusNode in _rowFocusNodes.values) {
      focusNode.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableWidth = _allColumns.fold<double>(0, (width, column) => width + _widths[column.id]!);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Stack(
          children: [
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: const Key('coelo-admin-table-scroll'),
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _headerRow(context),
                      ...widget.items.map((item) => _dataRow(context, item)),
                      const SizedBox(height: CoeloSpacing.space3),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: _widths[widget.pinnedColumn.id],
              height: widget.headerHeight + widget.items.length * (widget.rowHeight + 1),
              child: IgnorePointer(
                key: const Key('coelo-admin-table-pinned-column'),
                child: ExcludeSemantics(child: _pinnedColumn(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: _allColumns.map((column) => _headerCell(context, column)).toList(growable: false),
      ),
    );
  }

  Widget _headerCell(BuildContext context, CoeloAdminTableColumn<T> column, {bool pinned = false}) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: Key('coelo-admin-table-header-${column.id}${pinned ? '-pinned' : ''}'),
      width: _widths[column.id],
      height: widget.headerHeight,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                column.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).dataTableTheme.headingTextStyle,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: pinned
                ? _ColumnResizeIndicator(
                    indicatorKey: Key('coelo-admin-table-resizer-indicator-${column.id}-pinned'),
                    color: colors.outlineVariant,
                  )
                : _ColumnResizeHandle(
                    indicatorKey: Key('coelo-admin-table-resizer-indicator-${column.id}'),
                    label: 'Redimensionar coluna ${column.label}',
                    idleColor: colors.outlineVariant,
                    focusColor: Theme.of(context).extension<CoeloActionColors>()!.focusRing,
                    onResize: (delta) => _resize(column, delta),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pinnedColumn(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: colors.surfaceContainer,
            child: _headerCell(context, widget.pinnedColumn, pinned: true),
          ),
          ...widget.items.map((item) => _pinnedRow(context, item)),
        ],
      ),
    );
  }

  Widget _pinnedRow(BuildContext context, T item) {
    final key = widget.rowKey(item);
    return KeyedSubtree(
      key: ValueKey<(String, Object)>(('pinned', key)),
      child: _rowBackground(
        context,
        key: Key('coelo-admin-table-pinned-row-background-$key'),
        highlighted: _isHighlighted(item),
        height: widget.rowHeight + 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
          child: widget.pinnedColumn.cellBuilder(context, item),
        ),
      ),
    );
  }

  Widget _dataRow(BuildContext context, T item) {
    final key = widget.rowKey(item);
    return Semantics(
      key: _rowElementKey(key),
      selected: widget.isSelected?.call(item),
      button: widget.onRowPressed != null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredRowKey = key),
        onExit: (_) {
          if (_hoveredRowKey == key) {
            setState(() => _hoveredRowKey = null);
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            focusNode: _rowFocusNodes[key],
            onFocusChange: (focused) {
              setState(() => _focusedRowKey = focused ? key : null);
            },
            overlayColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primaryContainer),
            onTap: widget.onRowPressed == null ? null : () => widget.onRowPressed!(item),
            child: Container(
              key: Key('coelo-admin-table-row-background-$key'),
              height: widget.rowHeight + 1,
              decoration: BoxDecoration(
                color: (widget.isSelected?.call(item) ?? false) || _focusedRowKey == key
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: _allColumns
                    .map(
                      (column) => SizedBox(
                        key: Key('coelo-admin-table-cell-${column.id}-$key'),
                        width: _widths[column.id],
                        height: widget.rowHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                          child: column.cellBuilder(context, item),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowBackground(
    BuildContext context, {
    required Key key,
    required bool highlighted,
    required double height,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: highlighted ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.fast,
      builder: (context, progress, child) => Container(
        key: key,
        height: height,
        decoration: BoxDecoration(
          color: Color.lerp(colors.surface, colors.primaryContainer, progress),
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: child,
      ),
      child: child,
    );
  }

  bool _isHighlighted(T item) {
    final key = widget.rowKey(item);
    return _hoveredRowKey == key ||
        _focusedRowKey == key ||
        (widget.isSelected?.call(item) ?? false);
  }

  void _reconcileRowFocusNodes() {
    final rowKeys = widget.items.map(widget.rowKey).toSet();
    for (final key in _rowFocusNodes.keys.where((key) => !rowKeys.contains(key)).toList()) {
      _rowFocusNodes.remove(key)?.dispose();
    }
    for (final key in rowKeys) {
      _rowFocusNodes.putIfAbsent(key, () => FocusNode(debugLabel: 'coelo-admin-table-row-$key'));
    }
  }

  bool _focusRow(Object rowKey) {
    final focusNode = _rowFocusNodes[rowKey];
    if (!mounted || focusNode == null || !focusNode.canRequestFocus) {
      return false;
    }
    setState(() => _focusedRowKey = rowKey);
    focusNode.requestFocus();
    return true;
  }

  void _resize(CoeloAdminTableColumn<T> column, double delta) {
    setState(() {
      _widths[column.id] = (_widths[column.id]! + delta)
          .clamp(column.minWidth, column.maxWidth)
          .toDouble();
    });
  }
}

Key _rowElementKey(Object value) {
  return switch (value) {
    Key key => key,
    String string => Key(string),
    _ => ValueKey<Object>(value),
  };
}

final class _ColumnResizeHandle extends StatefulWidget {
  const _ColumnResizeHandle({
    required this.indicatorKey,
    required this.label,
    required this.idleColor,
    required this.focusColor,
    required this.onResize,
  });

  final Key indicatorKey;
  final String label;
  final Color idleColor;
  final Color focusColor;
  final ValueChanged<double> onResize;

  @override
  State<_ColumnResizeHandle> createState() => _ColumnResizeHandleState();
}

final class _ColumnResizeIndicator extends StatelessWidget {
  const _ColumnResizeIndicator({required this.indicatorKey, required this.color});

  final Key indicatorKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CoeloSpacing.space3,
      child: Center(
        child: Container(
          key: indicatorKey,
          width: 1,
          height: CoeloSpacing.space6,
          decoration: BoxDecoration(color: color),
        ),
      ),
    );
  }
}

final class _ColumnResizeHandleState extends State<_ColumnResizeHandle> {
  final FocusNode _focusNode = FocusNode();
  var _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      onIncrease: () => widget.onResize(CoeloSpacing.space2),
      onDecrease: () => widget.onResize(-CoeloSpacing.space2),
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onResize(CoeloSpacing.space2);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.onResize(-CoeloSpacing.space2);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focusNode.requestFocus,
            onHorizontalDragStart: (_) => _focusNode.requestFocus(),
            onHorizontalDragUpdate: (details) => widget.onResize(details.delta.dx),
            child: _ColumnResizeIndicator(
              indicatorKey: widget.indicatorKey,
              color: _focused ? widget.focusColor : widget.idleColor,
            ),
          ),
        ),
      ),
    );
  }
}
