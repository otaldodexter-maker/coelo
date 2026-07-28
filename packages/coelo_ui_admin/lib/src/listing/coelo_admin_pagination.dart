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
       assert(currentPage <= totalPages);

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
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        if (widget.pageSize case final pageSize?)
          Semantics(
            label: 'Quantidade de itens por página',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Itens por página'),
                const SizedBox(width: CoeloSpacing.space2),
                DropdownButton<int>(
                  key: const Key('coelo-admin-pagination-page-size'),
                  value: pageSize,
                  items: widget.pageSizeOptions
                      .map((option) => DropdownMenuItem<int>(value: option, child: Text('$option')))
                      .toList(growable: false),
                  onChanged: widget.onPageSizeChanged == null
                      ? null
                      : (value) {
                          if (value != null) {
                            widget.onPageSizeChanged!(value);
                          }
                        },
                ),
              ],
            ),
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
