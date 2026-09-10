import 'package:coelo_tokens/coelo_tokens.dart';
import '../overlay/coelo_admin_flyout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class CoeloAdminDirectoryTableViewOption<T> {
  const CoeloAdminDirectoryTableViewOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Toggle Cards/Tabela em cápsula de 64 × 48 com flyout de visões da tabela.
final class CoeloAdminDirectoryViewToggle<T> extends StatefulWidget {
  const CoeloAdminDirectoryViewToggle({
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
  final List<CoeloAdminDirectoryTableViewOption<T>> tableViews;
  final VoidCallback onCardsSelected;
  final ValueChanged<T> onTableViewSelected;
  final Key? cardsKey;
  final Key? tableKey;

  @override
  State<CoeloAdminDirectoryViewToggle<T>> createState() => _CoeloAdminDirectoryViewToggleState<T>();
}

final class _CoeloAdminDirectoryViewToggleState<T> extends State<CoeloAdminDirectoryViewToggle<T>> {
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
            // O detector de pressionar-e-segurar publicava um no tocavel SEM
            // nome acessivel, enquanto os dois segmentos internos eram
            // rotulados. Atalho por gesto sem nome nao e anunciavel. O rotulo
            // aqui nao altera nada visualmente.
            child: Semantics(
              // container: true e obrigatorio. Sem ele, o rotulo e anexado ao no
              // de semantica ancestral mais proximo, que na barra de listagem
              // engloba o campo de busca: o no passa a ter o rotulo certo e
              // perde a flag isTextField, quebrando quem procura o campo por
              // semantica.
              container: true,
              label: 'Pressione e segure sobre a tabela para abrir as opções de exibição.',
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
        ),
      );
    },
  );
}
