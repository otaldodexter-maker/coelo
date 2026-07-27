import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloAdminPagination extends StatelessWidget {
  const CoeloAdminPagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    super.key,
  }) : assert(currentPage > 0),
       assert(totalPages > 0),
       assert(currentPage <= totalPages);

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return _CoeloAdminPaginationContent(
      currentPage: currentPage,
      totalPages: totalPages,
      onPrevious: onPrevious,
      onNext: onNext,
    );
  }
}

class _CoeloAdminPaginationContent extends StatefulWidget {
  const _CoeloAdminPaginationContent({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

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
