import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloAdminPagination extends StatelessWidget {
  const CoeloAdminPagination({
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.onPageSelected,
    required this.onPageSizeChanged,
    this.onPrevious,
    this.onNext,
    super.key,
  }) : assert(currentPage > 0),
       assert(totalPages > 0),
       assert(currentPage <= totalPages),
       assert(pageSize > 0);

  final int currentPage;
  final int totalPages;
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final entries = _paginationEntries(
          currentPage: currentPage,
          totalPages: totalPages,
          compact: constraints.maxWidth < 600,
        );
        final previousAction = currentPage > 1 ? onPrevious : null;
        final nextAction = currentPage < totalPages ? onNext : null;

        return Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            _PageSizeDropdown(
              pageSize: pageSize,
              pageSizeOptions: pageSizeOptions,
              onChanged: onPageSizeChanged,
            ),
            _NavigationButton(
              label: 'Anterior',
              semanticLabel: 'Página anterior',
              icon: Icons.chevron_left,
              onPressed: previousAction,
            ),
            ...entries.map(
              (entry) => switch (entry) {
                _PageEntry(:final page) => _PageButton(
                  page: page,
                  isCurrent: page == currentPage,
                  onPressed: page == currentPage ? null : () => onPageSelected(page),
                ),
                _EllipsisEntry() => const _PaginationEllipsis(),
              },
            ),
            _NavigationButton(
              label: 'Próxima',
              semanticLabel: 'Próxima página',
              icon: Icons.chevron_right,
              onPressed: nextAction,
            ),
          ],
        );
      },
    );
  }
}

class _PageSizeDropdown extends StatelessWidget {
  const _PageSizeDropdown({
    required this.pageSize,
    required this.pageSizeOptions,
    required this.onChanged,
  });

  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<int>(
        key: const Key('coelo-pagination-page-size'),
        initialValue: pageSize,
        decoration: const InputDecoration(labelText: 'Itens por página'),
        items: pageSizeOptions
            .map((size) => DropdownMenuItem<int>(value: size, child: Text('$size')))
            .toList(),
        onChanged: (size) {
          if (size != null) {
            onChanged(size);
          }
        },
      ),
    );
  }
}

class _NavigationButton extends StatefulWidget {
  const _NavigationButton({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_NavigationButton> createState() => _NavigationButtonState();
}

class _NavigationButtonState extends State<_NavigationButton> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.onPressed == null
        ? null
        : () {
            _focusNode.requestFocus();
            widget.onPressed!();
          };

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      enabled: action != null,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        focusNode: _focusNode,
        onPressed: action,
        icon: Icon(widget.icon),
        label: Text(widget.label),
        style: _paginationButtonStyle,
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.page, required this.isCurrent, required this.onPressed});

  final int page;
  final bool isCurrent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isCurrent ? 'Página $page, atual' : 'Página $page',
      button: true,
      enabled: !isCurrent,
      selected: isCurrent,
      excludeSemantics: true,
      child: OutlinedButton(
        key: Key('coelo-pagination-page-$page'),
        onPressed: onPressed,
        style: _paginationButtonStyle,
        child: Text('$page'),
      ),
    );
  }
}

class _PaginationEllipsis extends StatelessWidget {
  const _PaginationEllipsis();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Páginas omitidas',
      child: const ExcludeSemantics(child: Text('…')),
    );
  }
}

final _paginationButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(48, 48),
  padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
);

sealed class _PaginationEntry {
  const _PaginationEntry();
}

final class _PageEntry extends _PaginationEntry {
  const _PageEntry(this.page);

  final int page;
}

final class _EllipsisEntry extends _PaginationEntry {
  const _EllipsisEntry();
}

List<_PaginationEntry> _paginationEntries({
  required int currentPage,
  required int totalPages,
  required bool compact,
}) {
  final nearbyPageCount = compact ? 1 : 2;
  final pages = <int>{
    1,
    totalPages,
    for (var page = currentPage - nearbyPageCount; page <= currentPage + nearbyPageCount; page += 1)
      if (page > 0 && page <= totalPages) page,
  }.toList()..sort();

  final entries = <_PaginationEntry>[];
  for (var index = 0; index < pages.length; index += 1) {
    final page = pages[index];
    if (index > 0 && page - pages[index - 1] > 1) {
      entries.add(const _EllipsisEntry());
    }
    entries.add(_PageEntry(page));
  }
  return entries;
}
