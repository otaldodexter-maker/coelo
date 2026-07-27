import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../domain/institution_directory_item.dart';
import '../../domain/institution_directory_repository.dart';
import '../view_models/institution_directory_view_model.dart';
import 'institution_file_actions.dart';

enum InstitutionDirectoryDisplay { cards, table }

final class InstitutionDirectoryToolbar extends StatelessWidget {
  const InstitutionDirectoryToolbar({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.onDisplayChanged,
    required this.onClearFilters,
    super.key,
  });

  final InstitutionDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final InstitutionDirectoryDisplay display;
  final ValueChanged<InstitutionDirectoryDisplay> onDisplayChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final stateOptions = [...viewModel.filterOptions.states]..sort(_compareStateOptions);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final compactFileAction = compact || constraints.maxWidth < 1000;
        final filterWidth = compact ? (constraints.maxWidth - CoeloSpacing.space3) / 2 : 160.0;
        final searchWidth = compact
            ? constraints.maxWidth
            : compactFileAction
            ? 216.0
            : 300.0;
        final filters = Wrap(
          key: const Key('institution-filter-controls'),
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: searchWidth,
              height: CoeloSize.touchMin,
              child: CoeloSearchField(
                controller: searchController,
                hintText: 'Buscar por nome',
                semanticLabel: 'Buscar por nome',
                onChanged: viewModel.setSearch,
              ),
            ),
            SizedBox(
              width: filterWidth,
              child: _DirectoryFilterMenu<String>(
                triggerKey: const Key('institution-type-filter'),
                anchorKey: const Key('institution-type-filter-anchor'),
                values: viewModel.query.typeIds,
                allLabel: viewModel.filterOptions.types.isEmpty
                    ? 'Sem tipos cadastrados'
                    : 'Todos os tipos',
                items: viewModel.filterOptions.types
                    .map((option) => _FilterMenuOption(value: option.id, label: option.label))
                    .toList(growable: false),
                onApply: viewModel.filterOptions.types.isEmpty ? null : viewModel.setTypes,
              ),
            ),
            SizedBox(
              width: filterWidth,
              child: _DirectoryFilterMenu<InstitutionStatus>(
                triggerKey: const Key('institution-status-filter'),
                anchorKey: const Key('institution-status-filter-anchor'),
                values: viewModel.query.statuses,
                allLabel: 'Todos os status',
                items: InstitutionStatus.values
                    .map((status) => _FilterMenuOption(value: status, label: status.label))
                    .toList(growable: false),
                onApply: viewModel.setStatuses,
              ),
            ),
            SizedBox(
              width: filterWidth,
              child: _DirectoryFilterMenu<String>(
                triggerKey: const Key('institution-state-filter'),
                anchorKey: const Key('institution-state-filter-anchor'),
                searchFieldKey: const Key('institution-state-filter-search'),
                searchHintText: 'Buscar UF',
                searchable: true,
                values: viewModel.query.states,
                allLabel: viewModel.hasLoadedFilterOptions && viewModel.filterOptions.states.isEmpty
                    ? 'Sem UFs cadastradas'
                    : 'Todas as UFs',
                selectedCountLabel: 'selecionadas',
                items: stateOptions
                    .map(
                      (option) => _FilterMenuOption(
                        value: option.id,
                        label: _statePresentationLabel(option),
                      ),
                    )
                    .toList(growable: false),
                onApply:
                    viewModel.hasLoadedFilterOptions && viewModel.filterOptions.states.isNotEmpty
                    ? viewModel.setStates
                    : null,
              ),
            ),
            if (viewModel.query.states.isNotEmpty)
              SizedBox(
                width: filterWidth,
                child: _DirectoryFilterMenu<String>(
                  triggerKey: const Key('institution-city-filter'),
                  anchorKey: const Key('institution-city-filter-anchor'),
                  searchFieldKey: const Key('institution-city-filter-search'),
                  searchHintText: 'Buscar município',
                  searchable: true,
                  values: viewModel.query.cities,
                  allLabel: 'Todos os municípios',
                  items: viewModel.filterOptions.cities
                      .map((option) => _FilterMenuOption(value: option.id, label: option.label))
                      .toList(growable: false),
                  onApply: viewModel.setCities,
                ),
              ),
            if (viewModel.query.cities.isNotEmpty)
              SizedBox(
                width: filterWidth,
                child: _DirectoryFilterMenu<String>(
                  triggerKey: const Key('institution-district-filter'),
                  anchorKey: const Key('institution-district-filter-anchor'),
                  searchFieldKey: const Key('institution-district-filter-search'),
                  searchHintText: 'Buscar bairro',
                  searchable: true,
                  values: viewModel.query.districts,
                  allLabel: 'Todos os bairros',
                  items: viewModel.filterOptions.districts
                      .map((option) => _FilterMenuOption(value: option.id, label: option.label))
                      .toList(growable: false),
                  onApply: viewModel.setDistricts,
                ),
              ),
            if (viewModel.query.hasActiveFilters)
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Limpar filtros'),
              ),
          ],
        );
        final actions = SizedBox(
          key: const Key('institution-toolbar-actions'),
          height: CoeloSize.touchMin,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const Key('institution-display-toggle'),
                height: CoeloSize.touchMin,
                child: SegmentedButton<InstitutionDirectoryDisplay>(
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size(CoeloSize.touchMin, CoeloSize.touchMin),
                    ),
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: InstitutionDirectoryDisplay.cards,
                      tooltip: 'Exibir como cards',
                      icon: Icon(key: Key('institution-view-cards'), Icons.grid_view_rounded),
                    ),
                    ButtonSegment(
                      value: InstitutionDirectoryDisplay.table,
                      tooltip: 'Exibir como tabela',
                      icon: Icon(key: Key('institution-view-table'), Icons.table_rows_rounded),
                    ),
                  ],
                  selected: {display},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => onDisplayChanged(selection.single),
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              InstitutionFileActions(
                activityController: activityController,
                compact: compactFileAction,
              ),
            ],
          ),
        );
        return CoeloAdminListingToolbar(
          key: const Key('institution-filter-toolbar'),
          search: filters,
          filters: const [],
          actions: [actions],
        );
      },
    );
  }
}

class _FilterMenuOption<T> {
  const _FilterMenuOption({required this.value, required this.label});

  final T value;
  final String label;
}

String _statePresentationLabel(InstitutionDirectoryFilterOption option) {
  final name = _brazilianStateNames[option.id];
  return name == null ? option.label : '${option.id} — $name';
}

int _compareStateOptions(
  InstitutionDirectoryFilterOption first,
  InstitutionDirectoryFilterOption second,
) {
  if (first.id == 'SP') {
    return second.id == 'SP' ? 0 : -1;
  }
  if (second.id == 'SP') {
    return 1;
  }
  return first.id.compareTo(second.id);
}

const _brazilianStateNames = <String, String>{
  'AC': 'Acre',
  'AL': 'Alagoas',
  'AP': 'Amapá',
  'AM': 'Amazonas',
  'BA': 'Bahia',
  'CE': 'Ceará',
  'DF': 'Distrito Federal',
  'ES': 'Espírito Santo',
  'GO': 'Goiás',
  'MA': 'Maranhão',
  'MT': 'Mato Grosso',
  'MS': 'Mato Grosso do Sul',
  'MG': 'Minas Gerais',
  'PA': 'Pará',
  'PB': 'Paraíba',
  'PR': 'Paraná',
  'PE': 'Pernambuco',
  'PI': 'Piauí',
  'RJ': 'Rio de Janeiro',
  'RN': 'Rio Grande do Norte',
  'RS': 'Rio Grande do Sul',
  'RO': 'Rondônia',
  'RR': 'Roraima',
  'SC': 'Santa Catarina',
  'SP': 'São Paulo',
  'SE': 'Sergipe',
  'TO': 'Tocantins',
};

class _DirectoryFilterMenu<T> extends StatefulWidget {
  const _DirectoryFilterMenu({
    required this.triggerKey,
    required this.anchorKey,
    required this.values,
    required this.allLabel,
    required this.items,
    required this.onApply,
    this.searchable = false,
    this.searchFieldKey,
    this.searchHintText,
    this.selectedCountLabel = 'selecionados',
    super.key,
  }) : assert(!searchable || searchFieldKey != null),
       assert(!searchable || searchHintText != null);

  final Key triggerKey;
  final Key anchorKey;
  final Set<T> values;
  final String allLabel;
  final List<_FilterMenuOption<T>> items;
  final ValueChanged<Set<T>>? onApply;
  final bool searchable;
  final Key? searchFieldKey;
  final String? searchHintText;
  final String selectedCountLabel;

  @override
  State<_DirectoryFilterMenu<T>> createState() => _DirectoryFilterMenuState<T>();
}

class _DirectoryFilterMenuState<T> extends State<_DirectoryFilterMenu<T>> {
  final MenuController _menuController = MenuController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _triggerFocusNode = FocusNode();
  late Set<T> _draftValues = Set.of(widget.values);
  String _searchQuery = '';
  bool _appliedWhileOpen = false;

  @override
  void didUpdateWidget(covariant _DirectoryFilterMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_menuController.isOpen && !_setsEqual(oldWidget.values, widget.values)) {
      _draftValues = Set.of(widget.values);
    }
    if (oldWidget.items != widget.items && _searchQuery.isNotEmpty) {
      _clearSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _triggerFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    if (_searchQuery.isEmpty || !mounted) {
      return;
    }
    setState(() => _searchQuery = '');
  }

  void _open() {
    _appliedWhileOpen = false;
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _draftValues = Set.of(widget.values);
    });
  }

  void _close() {
    _clearSearch();
    if (_appliedWhileOpen) {
      _appliedWhileOpen = false;
      return;
    }
    if (!_setsEqual(_draftValues, widget.values)) {
      setState(() => _draftValues = Set.of(widget.values));
    }
  }

  void _toggle(T value) {
    setState(() {
      _draftValues = Set.of(_draftValues);
      if (!_draftValues.add(value)) {
        _draftValues.remove(value);
      }
    });
  }

  void _closeAndRestoreFocus() {
    if (!_menuController.isOpen) {
      return;
    }
    _menuController.close();
    _triggerFocusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_menuController.isOpen ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _closeAndRestoreFocus();
    return KeyEventResult.handled;
  }

  void _clearDraft() {
    if (_draftValues.isNotEmpty) {
      setState(() => _draftValues = {});
    }
  }

  void _apply() {
    final values = Set<T>.unmodifiable(_draftValues);
    _appliedWhileOpen = true;
    _menuController.close();
    _triggerFocusNode.requestFocus();
    widget.onApply?.call(values);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedLabel = switch (widget.values.length) {
      0 => widget.allLabel,
      1 =>
        widget.items.where((item) => widget.values.contains(item.value)).firstOrNull?.label ??
            widget.allLabel,
      _ => '${widget.values.length} ${widget.selectedCountLabel}',
    };
    final normalizedQuery = _normalizeFilterSearch(_searchQuery);
    final visibleItems = normalizedQuery.isEmpty
        ? widget.items
        : widget.items
              .where((item) => _normalizeFilterSearch(item.label).contains(normalizedQuery))
              .toList(growable: false);
    final menuHeight = math.min(
      360.0,
      (widget.searchable ? 64.0 : 0.0) +
          math.max(CoeloSize.touchMin, visibleItems.length * CoeloSize.touchMin) +
          64.0,
    );
    return MenuAnchor(
      key: widget.anchorKey,
      controller: _menuController,
      onOpen: _open,
      onClose: _close,
      alignmentOffset: const Offset(0, CoeloSpacing.space1),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        maximumSize: const WidgetStatePropertyAll(Size(320, 360)),
      ),
      menuChildren: [
        Focus(
          autofocus: !widget.searchable,
          onKeyEvent: _handleKeyEvent,
          child: SizedBox(
            width: 300,
            height: menuHeight,
            child: Column(
              children: [
                if (widget.searchable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CoeloSpacing.space2,
                      CoeloSpacing.space2,
                      CoeloSpacing.space2,
                      CoeloSpacing.space1,
                    ),
                    child: TextField(
                      key: widget.searchFieldKey,
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: _pillInputDecoration(
                        context,
                        hintText: widget.searchHintText,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                Expanded(
                  child: visibleItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(CoeloSpacing.space4),
                            child: Text(
                              'Nenhuma opção encontrada.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView(
                          primary: false,
                          padding: EdgeInsets.zero,
                          children: visibleItems
                              .map((item) {
                                final selected = _draftValues.contains(item.value);
                                return Semantics(
                                  checked: selected,
                                  enabled: widget.onApply != null,
                                  child: MenuItemButton(
                                    closeOnActivate: false,
                                    onPressed: widget.onApply == null
                                        ? null
                                        : () => _toggle(item.value),
                                    style: _filterMenuItemStyle(colors, selected: selected),
                                    leadingIcon: _FilterSelectionIndicator(
                                      selected: selected,
                                      enabled: widget.onApply != null,
                                    ),
                                    child: Text(item.label),
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space2),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: widget.onApply == null || _draftValues.isEmpty
                              ? null
                              : _clearDraft,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                          ),
                          child: const Text('Limpar'),
                        ),
                      ),
                      const SizedBox(width: CoeloSpacing.space2),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              widget.onApply == null || _setsEqual(_draftValues, widget.values)
                              ? null
                              : _apply,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                          ),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => OutlinedButton(
        key: widget.triggerKey,
        focusNode: _triggerFocusNode,
        onPressed: widget.onApply == null
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(CoeloSize.touchMin),
              padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
              shape: const StadiumBorder(),
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed)) {
                  return colors.primary;
                }
                return colors.onSurfaceVariant;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                final highlighted =
                    states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                return BorderSide(color: highlighted ? colors.primary : colors.outlineVariant);
              }),
            ),
        child: Row(
          children: [
            Expanded(child: Text(selectedLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: CoeloSpacing.space1),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

bool _setsEqual<T>(Set<T> first, Set<T> second) {
  return first.length == second.length && first.containsAll(second);
}

String _normalizeFilterSearch(String value) {
  var normalized = value.toLowerCase().trim();
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  for (final replacement in replacements.entries) {
    normalized = normalized.replaceAll(replacement.key, replacement.value);
  }
  return normalized;
}

class _FilterSelectionIndicator extends StatelessWidget {
  const _FilterSelectionIndicator({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Checkbox(
          value: selected,
          onChanged: enabled ? (_) {} : null,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashRadius: 0,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

ButtonStyle _filterMenuItemStyle(ColorScheme colors, {required bool selected}) {
  return MenuItemButton.styleFrom().copyWith(
    shape: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(highlighted ? 0 : CoeloRadius.md),
      );
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return selected || highlighted ? colors.primary : colors.onSurface;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return selected || highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return highlighted ? colors.primaryContainer : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

InputDecoration _pillInputDecoration(BuildContext context, {String? hintText, Widget? prefixIcon}) {
  final colors = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(CoeloRadius.full),
    borderSide: BorderSide(color: colors.outline),
  );
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    isDense: true,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.primary, width: 2)),
  );
}
