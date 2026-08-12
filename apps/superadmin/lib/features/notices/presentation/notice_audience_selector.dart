import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

final class NoticeAudienceOption {
  const NoticeAudienceOption({
    required this.id,
    required this.label,
    required this.groupLabel,
    this.description,
  });

  final String id;
  final String label;
  final String groupLabel;
  final String? description;
}

final class NoticeAudiencePickerSelection {
  const NoticeAudiencePickerSelection.explicit([this.selectedIds = const {}])
    : allMatching = false,
      excludedIds = const {};

  const NoticeAudiencePickerSelection.allMatching({this.excludedIds = const {}})
    : allMatching = true,
      selectedIds = const {};

  final bool allMatching;
  final Set<String> selectedIds;
  final Set<String> excludedIds;

  bool contains(String id) => allMatching ? !excludedIds.contains(id) : selectedIds.contains(id);

  NoticeAudiencePickerSelection toggle(String id) {
    if (allMatching) {
      final exclusions = Set<String>.of(excludedIds);
      if (!exclusions.add(id)) exclusions.remove(id);
      return NoticeAudiencePickerSelection.allMatching(excludedIds: Set.unmodifiable(exclusions));
    }
    final selected = Set<String>.of(selectedIds);
    if (!selected.add(id)) selected.remove(id);
    return NoticeAudiencePickerSelection.explicit(Set.unmodifiable(selected));
  }
}

final class NoticeAudienceSelector extends StatefulWidget {
  const NoticeAudienceSelector({
    required this.options,
    required this.selection,
    this.onChanged,
    this.onQueryChanged,
    this.totalMatchingCount,
    this.hasMore = false,
    this.onLoadMore,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final List<NoticeAudienceOption> options;
  final NoticeAudiencePickerSelection selection;
  final ValueChanged<NoticeAudiencePickerSelection>? onChanged;
  final ValueChanged<String>? onQueryChanged;
  final int? totalMatchingCount;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<NoticeAudienceSelector> createState() => _NoticeAudienceSelectorState();
}

final class _NoticeAudienceSelectorState extends State<NoticeAudienceSelector> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NoticeAudienceOption> get _visibleOptions {
    final query = _normalize(_query);
    if (query.isEmpty) return widget.options;
    return widget.options
        .where(
          (option) =>
              _normalize(option.label).contains(query) ||
              _normalize(option.groupLabel).contains(query) ||
              _normalize(option.description ?? '').contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = _visibleOptions;
    final groups = <String, List<NoticeAudienceOption>>{};
    for (final option in visible) {
      groups.putIfAbsent(option.groupLabel, () => []).add(option);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoeloSearchField(
              key: const Key('notice-audience-search'),
              controller: _searchController,
              semanticLabel: 'Buscar no público do aviso',
              hintText: 'Buscar instituição, unidade ou turma',
              onChanged: (value) {
                setState(() => _query = value);
                widget.onQueryChanged?.call(value);
              },
            ),
            const SizedBox(height: CoeloSpacing.space3),
            if (widget.isLoading)
              const Center(
                child: Padding(
                  key: Key('notice-audience-loading'),
                  padding: EdgeInsets.all(CoeloSpacing.space4),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (widget.errorMessage case final message?)
              _Failure(message: message, onRetry: widget.onRetry)
            else if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(CoeloSpacing.space4),
                child: Text('Nenhum público encontrado.', textAlign: TextAlign.center),
              )
            else ...[
              _selectAllRow(colors, visible.length),
              const Divider(height: 1),
              for (final group in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CoeloSpacing.space3,
                    CoeloSpacing.space3,
                    CoeloSpacing.space3,
                    CoeloSpacing.space1,
                  ),
                  child: Text(group.key, style: Theme.of(context).textTheme.titleSmall),
                ),
                for (final option in group.value) _optionRow(option, colors),
              ],
              if (widget.hasMore) ...[
                const SizedBox(height: CoeloSpacing.space3),
                OutlinedButton(
                  key: const Key('notice-audience-load-more'),
                  onPressed: widget.onLoadMore,
                  child: const Text('Carregar mais resultados'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectAllRow(ColorScheme colors, int visibleCount) {
    final count = widget.totalMatchingCount ?? visibleCount;
    final selection = widget.selection;
    final checkboxValue = selection.allMatching
        ? selection.excludedIds.isEmpty
              ? true
              : null
        : selection.selectedIds.isEmpty
        ? false
        : null;
    final label = selection.allMatching
        ? 'Todos os $count resultados filtrados'
        : 'Selecionar todos os $count resultados filtrados';
    return Semantics(
      button: true,
      checked: selection.allMatching && selection.excludedIds.isEmpty,
      label: label,
      child: ExcludeSemantics(
        child: TextButton(
          key: const Key('notice-audience-select-all'),
          onPressed: widget.onChanged == null
              ? null
              : () => widget.onChanged!(
                  selection.allMatching
                      ? const NoticeAudiencePickerSelection.explicit()
                      : const NoticeAudiencePickerSelection.allMatching(),
                ),
          style: _rowStyle(colors),
          child: Row(
            children: [
              IgnorePointer(
                child: Checkbox(
                  tristate: true,
                  value: checkboxValue,
                  onChanged: (_) {},
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionRow(NoticeAudienceOption option, ColorScheme colors) {
    final selected = widget.selection.contains(option.id);
    return Semantics(
      button: true,
      checked: selected,
      label: option.description == null ? option.label : '${option.label}, ${option.description}',
      child: ExcludeSemantics(
        child: TextButton(
          key: Key('notice-audience-option-${option.id}'),
          onPressed: widget.onChanged == null
              ? null
              : () => widget.onChanged!(widget.selection.toggle(option.id)),
          style: _rowStyle(colors),
          child: Row(
            children: [
              IgnorePointer(
                child: Checkbox(
                  value: selected,
                  onChanged: (_) {},
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label),
                    if (option.description case final description?)
                      Text(description, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _rowStyle(ColorScheme colors) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: CoeloSpacing.space2)),
    alignment: AlignmentDirectional.centerStart,
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.primaryContainer
          : colors.surface,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.primary
          : colors.onSurface,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

final class _Failure extends StatelessWidget {
  const _Failure({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    child: Column(
      children: [
        Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: CoeloSpacing.space2),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: CoeloSpacing.space3),
          OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ],
    ),
  );
}

String _normalize(String value) => value.toLowerCase().trim();
