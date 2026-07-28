import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloAdminPagination extends StatelessWidget {
  const CoeloAdminPagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    this.onPageSelected,
    this.pageSize,
    this.pageSizeOptions = const [],
    this.onPageSizeChanged,
    super.key,
  }) : assert(currentPage > 0),
       assert(totalPages > 0),
       assert(currentPage <= totalPages),
       assert(pageSize == null || pageSizeOptions != const <int>[]),
       assert(onPageSizeChanged == null || pageSize != null);

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int>? onPageSelected;
  final int? pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int>? onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    assert(pageSize == null || pageSizeOptions.contains(pageSize));
    return _CoeloAdminPaginationContent(
      currentPage: currentPage,
      totalPages: totalPages,
      onPrevious: onPrevious,
      onNext: onNext,
      onPageSelected: onPageSelected,
      pageSize: pageSize,
      pageSizeOptions: pageSizeOptions,
      onPageSizeChanged: onPageSizeChanged,
    );
  }
}

class _CoeloAdminPaginationContent extends StatefulWidget {
  const _CoeloAdminPaginationContent({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSelected,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.onPageSizeChanged,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int>? onPageSelected;
  final int? pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int>? onPageSizeChanged;

  @override
  State<_CoeloAdminPaginationContent> createState() => _CoeloAdminPaginationContentState();
}

class _CoeloAdminPaginationContentState extends State<_CoeloAdminPaginationContent> {
  final FocusNode _previousFocusNode = FocusNode();
  final FocusNode _nextFocusNode = FocusNode();

  @override
  void dispose() {
    _previousFocusNode.dispose();
    _nextFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previousCallback = widget.currentPage > 1 ? widget.onPrevious : null;
    final nextCallback = widget.currentPage < widget.totalPages ? widget.onNext : null;
    final previousAction = previousCallback == null
        ? null
        : () {
            _previousFocusNode.requestFocus();
            previousCallback();
          };
    final nextAction = nextCallback == null
        ? null
        : () {
            _nextFocusNode.requestFocus();
            nextCallback();
          };

    return Wrap(
      key: const Key('coelo-admin-pagination-content'),
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        if (widget.pageSize case final pageSize?)
          _PageSizeSelector(
            value: pageSize,
            options: widget.pageSizeOptions,
            onChanged: widget.onPageSizeChanged,
          ),
        Semantics(
          label: 'Página anterior',
          button: true,
          enabled: previousCallback != null,
          onTap: previousAction,
          excludeSemantics: true,
          child: OutlinedButton.icon(
            focusNode: _previousFocusNode,
            onPressed: previousAction,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Anterior'),
          ),
        ),
        Text('Página ${widget.currentPage} de ${widget.totalPages}'),
        ..._visiblePages(widget.currentPage, widget.totalPages).map(
          (page) => page == null
              ? const Text('…')
              : Semantics(
                  label: 'Ir para a página $page',
                  button: true,
                  selected: page == widget.currentPage,
                  child: OutlinedButton(
                    key: Key('coelo-admin-pagination-page-$page'),
                    onPressed: page == widget.currentPage || widget.onPageSelected == null
                        ? null
                        : () => widget.onPageSelected!(page),
                    child: Text('$page'),
                  ),
                ),
        ),
        Semantics(
          label: 'Próxima página',
          button: true,
          enabled: nextCallback != null,
          onTap: nextAction,
          excludeSemantics: true,
          child: OutlinedButton.icon(
            focusNode: _nextFocusNode,
            onPressed: nextAction,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Próxima'),
          ),
        ),
      ],
    );
  }
}

final class _PageSizeSelector extends StatefulWidget {
  const _PageSizeSelector({required this.value, required this.options, required this.onChanged});

  final int value;
  final List<int> options;
  final ValueChanged<int>? onChanged;

  @override
  State<_PageSizeSelector> createState() => _PageSizeSelectorState();
}

final class _PageSizeSelectorState extends State<_PageSizeSelector> {
  static const _width = CoeloSpacing.space20;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null;
    return Semantics(
      label: 'Quantidade de itens por página',
      value: '${widget.value}',
      enabled: enabled,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Itens por p\u00e1gina'),
          const SizedBox(width: CoeloSpacing.space2),
          MenuAnchor(
            key: const Key('coelo-admin-pagination-page-size-anchor'),
            childFocusNode: _focusNode,
            crossAxisUnconstrained: false,
            alignmentOffset: const Offset(0, CoeloSpacing.space1),
            onClose: _focusNode.requestFocus,
            style: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(colors.surface),
              surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
              elevation: const WidgetStatePropertyAll(CoeloElevation.level3),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: const WidgetStatePropertyAll(Size(_width, 0)),
              maximumSize: const WidgetStatePropertyAll(Size(_width, double.infinity)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  side: BorderSide(color: colors.outlineVariant),
                ),
              ),
            ),
            menuChildren: [
              for (final option in widget.options)
                SizedBox(
                  width: _width,
                  child: Semantics(
                    selected: option == widget.value,
                    child: MenuItemButton(
                      key: Key('coelo-admin-pagination-page-size-$option'),
                      onPressed: enabled ? () => widget.onChanged!(option) : null,
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.fromHeight(CoeloSize.touchMin),
                        ),
                        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              option == widget.value ||
                                  states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused)
                              ? colors.primary
                              : colors.onSurface,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              option == widget.value ||
                                  states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused)
                              ? colors.primaryContainer
                              : colors.surface,
                        ),
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      ),
                      child: Text('$option'),
                    ),
                  ),
                ),
            ],
            builder: (context, menu, child) {
              final active = menu.isOpen;
              return OutlinedButton(
                key: const Key('coelo-admin-pagination-page-size'),
                focusNode: _focusNode,
                onPressed: enabled ? () => active ? menu.close() : menu.open() : null,
                style: ButtonStyle(
                  fixedSize: const WidgetStatePropertyAll(Size(_width, CoeloSize.touchMin)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                  ),
                  shape: const WidgetStatePropertyAll(StadiumBorder()),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        active ||
                            states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        active ||
                            states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)
                        ? colors.primaryContainer
                        : colors.surface,
                  ),
                  side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      color:
                          active ||
                              states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused)
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                  ),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${widget.value}'),
                    Icon(
                      active ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

List<int?> _visiblePages(int currentPage, int totalPages) {
  if (totalPages <= 7) {
    return [for (var page = 1; page <= totalPages; page++) page];
  }
  if (currentPage <= 4) {
    return [1, 2, 3, 4, 5, null, totalPages];
  }
  if (currentPage >= totalPages - 3) {
    return [1, null, for (var page = totalPages - 4; page <= totalPages; page++) page];
  }
  return [1, null, currentPage - 1, currentPage, currentPage + 1, null, totalPages];
}
