import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../domain/institution_directory_item.dart';
import '../../domain/institution_directory_query.dart';
import '../../domain/institution_directory_repository.dart';
import '../view_models/institution_directory_view_model.dart';
import '../widgets/institution_file_actions.dart';

enum _DirectoryDisplay { cards, table }

class InstitutionDirectoryPage extends StatefulWidget {
  const InstitutionDirectoryPage({required this.repository, required this.logout, super.key});

  final InstitutionDirectoryRepository repository;
  final LogoutAction logout;

  @override
  State<InstitutionDirectoryPage> createState() => _InstitutionDirectoryPageState();
}

class _InstitutionDirectoryPageState extends State<InstitutionDirectoryPage> {
  late final InstitutionDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  _DirectoryDisplay _display = _DirectoryDisplay.cards;

  @override
  void initState() {
    super.initState();
    _viewModel = InstitutionDirectoryViewModel(repository: widget.repository);
    _activityController = SuperadminActivityController();
    _searchController = TextEditingController()..addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  void _onSearchChanged() => _viewModel.setSearch(_searchController.text);

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _showFutureFlowMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      activityController: _activityController,
      child: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return _InstitutionDirectoryContent(
            viewModel: _viewModel,
            activityController: _activityController,
            searchController: _searchController,
            display: _display,
            onDisplayChanged: (display) => setState(() => _display = display),
            onCreate: () =>
                _showFutureFlowMessage('O cadastro de instituições será implementado em breve.'),
            onClearFilters: () {
              _searchController.clear();
              _viewModel.clearFilters();
            },
          );
        },
      ),
    );
  }
}

class _InstitutionDirectoryContent extends StatelessWidget {
  const _InstitutionDirectoryContent({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.onDisplayChanged,
    required this.onCreate,
    required this.onClearFilters,
  });

  final InstitutionDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final _DirectoryDisplay display;
  final ValueChanged<_DirectoryDisplay> onDisplayChanged;
  final VoidCallback onCreate;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return ListView(
          key: const Key('institution-directory-content-scroll'),
          padding: EdgeInsets.all(horizontalPadding),
          children: [
            _DirectoryToolbar(
              viewModel: viewModel,
              activityController: activityController,
              searchController: searchController,
              display: display,
              onDisplayChanged: onDisplayChanged,
              onClearFilters: onClearFilters,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            if (viewModel.isLoading) const LinearProgressIndicator(),
            if (viewModel.isLoading) const SizedBox(height: CoeloSpacing.space4),
            _DirectoryState(viewModel: viewModel, display: display, onCreate: onCreate),
            if (viewModel.state == InstitutionDirectoryLoadState.success &&
                (viewModel.page.totalCount / InstitutionDirectoryQuery.pageSize).ceil() > 1) ...[
              const SizedBox(height: CoeloSpacing.space4),
              Align(
                alignment: Alignment.centerRight,
                child: _PaginationControls(viewModel: viewModel),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DirectoryToolbar extends StatelessWidget {
  const _DirectoryToolbar({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.onDisplayChanged,
    required this.onClearFilters,
  });

  final InstitutionDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final _DirectoryDisplay display;
  final ValueChanged<_DirectoryDisplay> onDisplayChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
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
              child: TextField(
                controller: searchController,
                decoration: _pillInputDecoration(
                  context,
                  hintText: 'Buscar por nome',
                  prefixIcon: const Icon(Icons.search),
                ),
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
                allLabel: 'Todas as UFs',
                selectedCountLabel: 'selecionadas',
                items: _brazilStatesForMenu
                    .map(
                      (state) => _FilterMenuOption(
                        value: state.code,
                        label: '${state.code} — ${state.name}',
                      ),
                    )
                    .toList(growable: false),
                onApply: viewModel.setStates,
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
                child: SegmentedButton<_DirectoryDisplay>(
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
                      value: _DirectoryDisplay.cards,
                      tooltip: 'Exibir como cards',
                      icon: Icon(key: Key('institution-view-cards'), Icons.grid_view_rounded),
                    ),
                    ButtonSegment(
                      value: _DirectoryDisplay.table,
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
        if (compact) {
          return Column(
            key: const Key('institution-filter-toolbar'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filters,
              const SizedBox(height: CoeloSpacing.space3),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                  child: Align(alignment: Alignment.centerLeft, child: actions),
                ),
              ),
            ],
          );
        }
        return Row(
          key: const Key('institution-filter-toolbar'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: filters),
            const SizedBox(width: CoeloSpacing.space4),
            actions,
          ],
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

  void _clearDraft() {
    if (_draftValues.isNotEmpty) {
      setState(() => _draftValues = {});
    }
  }

  void _apply() {
    final values = Set<T>.unmodifiable(_draftValues);
    _appliedWhileOpen = true;
    _menuController.close();
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
        SizedBox(
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
                        onPressed: widget.onApply == null || _setsEqual(_draftValues, widget.values)
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
      ],
      builder: (context, controller, child) => OutlinedButton(
        key: widget.triggerKey,
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

class _DirectoryState extends StatelessWidget {
  const _DirectoryState({required this.viewModel, required this.display, required this.onCreate});

  final InstitutionDirectoryViewModel viewModel;
  final _DirectoryDisplay display;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.state) {
      case InstitutionDirectoryLoadState.initial:
      case InstitutionDirectoryLoadState.loading:
        return const Padding(
          padding: EdgeInsets.all(CoeloSpacing.space8),
          child: Center(child: CircularProgressIndicator()),
        );
      case InstitutionDirectoryLoadState.failure:
        return _MessageCard(
          icon: Icons.error_outline,
          message: viewModel.errorMessage ?? InstitutionDirectoryViewModel.genericErrorMessage,
          actionLabel: 'Tentar novamente',
          onAction: viewModel.retry,
        );
      case InstitutionDirectoryLoadState.unauthorized:
        return _MessageCard(
          icon: Icons.lock_outline,
          message: viewModel.errorMessage ?? InstitutionDirectoryViewModel.unauthorizedMessage,
        );
      case InstitutionDirectoryLoadState.empty:
        return const _MessageCard(
          icon: Icons.apartment_outlined,
          message: 'Ainda não há instituições cadastradas.',
        );
      case InstitutionDirectoryLoadState.noResults:
        return const _MessageCard(
          icon: Icons.search_off_outlined,
          message: 'Nenhuma instituição encontrada com estes filtros.',
        );
      case InstitutionDirectoryLoadState.success:
        return display == _DirectoryDisplay.table
            ? _InstitutionTable(items: viewModel.page.items, onCreate: onCreate)
            : _InstitutionCards(items: viewModel.page.items, onCreate: onCreate);
    }
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: CoeloSize.iconLg),
              const SizedBox(height: CoeloSpacing.space3),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: CoeloSpacing.space3),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateInstitutionCard extends StatelessWidget {
  const _CreateInstitutionCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('create-institution-card'),
      height: 216,
      child: _DashedAction(
        surfaceKey: const Key('create-institution-surface'),
        painterKey: const Key('create-institution-dashed-border'),
        onPressed: onPressed,
        builder: (highlighted) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CreateIcon(highlighted: highlighted),
            const SizedBox(height: CoeloSpacing.space3),
            const Text('Criar instituição'),
            const SizedBox(height: CoeloSpacing.space1),
            const Text('Adicionar nova instituição ao sistema.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CreateInstitutionBanner extends StatelessWidget {
  const _CreateInstitutionBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('create-institution-banner'),
      width: double.infinity,
      height: CoeloSpacing.space20,
      child: _DashedAction(
        surfaceKey: const Key('create-institution-banner-surface'),
        onPressed: onPressed,
        builder: (highlighted) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CreateIcon(compact: true, highlighted: highlighted),
            const SizedBox(width: CoeloSpacing.space3),
            const Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Criar instituição'),
                  Text(
                    'Adicionar nova instituição ao sistema.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateIcon extends StatelessWidget {
  const _CreateIcon({required this.highlighted, this.compact = false});

  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = compact ? CoeloSize.avatarMd : 56.0;
    return AnimatedContainer(
      duration: CoeloMotion.standard,
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlighted ? colors.primary : colors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? colors.primary.withValues(alpha: 0.15)
                : colors.shadow.withValues(alpha: 0.08),
            blurRadius: highlighted ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.add,
        color: highlighted ? colors.onPrimary : colors.primary,
        size: compact ? CoeloSize.iconSm : CoeloSize.iconMd,
      ),
    );
  }
}

class _DashedAction extends StatefulWidget {
  const _DashedAction({
    required this.onPressed,
    required this.builder,
    required this.surfaceKey,
    this.painterKey,
  });

  final VoidCallback onPressed;
  final Widget Function(bool highlighted) builder;
  final Key surfaceKey;
  final Key? painterKey;

  @override
  State<_DashedAction> createState() => _DashedActionState();
}

class _DashedActionState extends State<_DashedAction> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = _highlighted ? colors.primary : colors.outlineVariant;
    return MouseRegion(
      onEnter: (_) => setState(() => _highlighted = true),
      onExit: (_) => setState(() => _highlighted = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _highlighted = value),
        child: AnimatedContainer(
          key: widget.surfaceKey,
          duration: CoeloMotion.standard,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            boxShadow: _highlighted
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: CustomPaint(
            key: widget.painterKey,
            foregroundPainter: _DashedBorderPainter(color: borderColor),
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: Center(child: widget.builder(_highlighted)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(CoeloRadius.lg)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + CoeloSpacing.space2, metric.length)),
          paint,
        );
        distance += CoeloSpacing.space3;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

class _InstitutionCards extends StatelessWidget {
  const _InstitutionCards({required this.items, required this.onCreate});

  final List<InstitutionDirectoryItem> items;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, (constraints.maxWidth / 340).floor());
        final cardWidth = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
        return Wrap(
          key: const Key('institution-card-grid'),
          spacing: CoeloSpacing.space6,
          runSpacing: CoeloSpacing.space6,
          children: [
            SizedBox(
              width: cardWidth,
              child: _CreateInstitutionCard(onPressed: onCreate),
            ),
            ...items.map(
              (item) => SizedBox(
                width: cardWidth,
                child: _InstitutionCard(item: item),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InstitutionCard extends StatefulWidget {
  const _InstitutionCard({required this.item});

  final InstitutionDirectoryItem item;

  @override
  State<_InstitutionCard> createState() => _InstitutionCardState();
}

class _InstitutionCardState extends State<_InstitutionCard> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = widget.item;
    return SizedBox(
      key: Key('institution-card-${item.id}'),
      height: 216,
      child: MouseRegion(
        onEnter: (_) => setState(() => _highlighted = true),
        onExit: (_) => setState(() => _highlighted = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => _highlighted = value),
          child: AnimatedContainer(
            key: Key('institution-card-surface-${item.id}'),
            duration: CoeloMotion.standard,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              border: Border.all(
                color: _highlighted ? colors.primary.withValues(alpha: 0.5) : colors.outlineVariant,
                width: _highlighted ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _highlighted
                      ? colors.primary.withValues(alpha: 0.15)
                      : colors.shadow.withValues(alpha: 0.03),
                  blurRadius: _highlighted ? 12 : 8,
                  spreadRadius: _highlighted ? 2 : 0,
                  offset: _highlighted ? const Offset(0, 4) : const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space6,
                  vertical: CoeloSpacing.space4,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox.square(
                          key: Key('institution-avatar-${item.id}'),
                          dimension: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item.initials,
                              style: TextStyle(color: colors.onSecondaryContainer),
                            ),
                          ),
                        ),
                        const SizedBox(width: CoeloSpacing.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.publicName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _location(item.district, item.city, item.state),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: CoeloSpacing.space2),
                        _ExpandableStatusIndicator(itemId: item.id, status: item.status),
                      ],
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    const Divider(height: 1),
                    const SizedBox(height: CoeloSpacing.space4),
                    _CardDetailRow(
                      first: _CardDetail(
                        key: Key('institution-card-detail-type-${item.id}'),
                        icon: Icons.category_outlined,
                        label: 'Tipo',
                        value: item.typeName ?? 'Não informado',
                      ),
                      second: _CardDetail(
                        key: Key('institution-card-detail-plan-${item.id}'),
                        icon: Icons.sell_outlined,
                        label: 'Plano',
                        value: item.planName ?? 'Sem plano',
                      ),
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    _CardDetailRow(
                      first: _CardDetail(
                        key: Key('institution-card-detail-units-${item.id}'),
                        icon: Icons.apartment_outlined,
                        label: 'Unidades',
                        value: '${item.unitsCount}',
                      ),
                      second: _CardDetail(
                        key: Key('institution-card-detail-groups-${item.id}'),
                        icon: Icons.groups_outlined,
                        label: 'Grupos (Turmas)',
                        value: '${item.groupsCount}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyValueButton extends StatelessWidget {
  const _CopyValueButton({
    required this.itemId,
    required this.kind,
    required this.value,
    required this.label,
  });

  final String itemId;
  final String kind;
  final String value;
  final String label;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      key: Key('copy-$kind-$itemId'),
      onPressed: () => _copy(context),
      tooltip: 'Copiar $label',
      icon: const Icon(Icons.content_copy_rounded),
      iconSize: CoeloSize.iconSm,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: CoeloSpacing.space8,
        height: CoeloSpacing.space8,
      ),
      style: IconButton.styleFrom(
        foregroundColor: colors.onSurfaceVariant,
        backgroundColor: colors.surfaceContainer,
        minimumSize: const Size.square(CoeloSpacing.space8),
        maximumSize: const Size.square(CoeloSpacing.space8),
      ),
    );
  }
}

class _CardDetailRow extends StatelessWidget {
  const _CardDetailRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(child: second),
      ],
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.icon, required this.label, required this.value, super.key});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DetailIcon(icon: icon, colors: colors),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: CoeloSpacing.spaceHalf),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailIcon extends StatelessWidget {
  const _DetailIcon({required this.icon, required this.colors});

  final IconData icon;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CoeloSpacing.space8,
      height: CoeloSpacing.space8,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.sm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: CoeloSize.iconSm, color: colors.onSurfaceVariant),
    );
  }
}

class _InstitutionTable extends StatefulWidget {
  const _InstitutionTable({required this.items, required this.onCreate});

  final List<InstitutionDirectoryItem> items;
  final VoidCallback onCreate;

  @override
  State<_InstitutionTable> createState() => _InstitutionTableState();
}

class _InstitutionTableState extends State<_InstitutionTable> {
  final ScrollController _scrollController = ScrollController();
  String? _hoveredItemId;
  late final Map<_InstitutionColumn, double> _columnWidths = {
    for (final column in _InstitutionColumn.values) column: column.initialWidth,
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = _columnWidths.values.fold<double>(0, (sum, width) => sum + width);
        return Column(
          children: [
            SizedBox(
              width: constraints.maxWidth,
              child: _CreateInstitutionBanner(onPressed: widget.onCreate),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            SizedBox(
              key: const Key('institution-directory-table-viewport'),
              width: constraints.maxWidth,
              child: Card(
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
                          key: const Key('institution-directory-table-scroll'),
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            key: const Key('institution-directory-table'),
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
                        height: 56 + widget.items.length * 65,
                        width: _columnWidths[_InstitutionColumn.institution],
                        child: IgnorePointer(child: _pinnedInstitutionColumn(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _headerRow(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: _InstitutionColumn.values
            .map((column) => _headerCell(context, column))
            .toList(growable: false),
      ),
    );
  }

  Widget _headerCell(BuildContext context, _InstitutionColumn column, {bool pinned = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      key: Key('institution-column-header-${column.id}${pinned ? '-pinned' : ''}'),
      width: _columnWidths[column],
      height: 56,
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
                style: theme.dataTableTheme.headingTextStyle,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                key: Key('institution-column-resizer-${column.id}${pinned ? '-pinned' : ''}'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _columnWidths[column] = (_columnWidths[column]! + details.delta.dx).clamp(
                      column.minimumWidth,
                      600,
                    );
                  });
                },
                child: SizedBox(
                  width: CoeloSpacing.space3,
                  child: Center(
                    child: Container(width: 1, height: 24, color: colors.outlineVariant),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinnedInstitutionColumn(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const Key('institution-pinned-column'),
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: colors.surfaceContainer,
            child: _headerCell(context, _InstitutionColumn.institution, pinned: true),
          ),
          ...widget.items.map((item) => _pinnedInstitutionRow(context, item)),
        ],
      ),
    );
  }

  Widget _pinnedInstitutionRow(BuildContext context, InstitutionDirectoryItem item) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      key: Key('institution-pinned-row-${item.id}'),
      duration: CoeloMotion.fast,
      height: 65,
      decoration: BoxDecoration(
        color: _hoveredItemId == item.id ? colors.primaryContainer : colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
      child: _institutionCell(context, item),
    );
  }

  Widget _institutionCell(BuildContext context, InstitutionDirectoryItem item) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: colors.secondaryContainer, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(item.initials, style: TextStyle(color: colors.onSecondaryContainer)),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(item.publicName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _dataRow(BuildContext context, InstitutionDirectoryItem item) {
    final colors = Theme.of(context).colorScheme;
    final values = <_InstitutionColumn, Widget>{
      _InstitutionColumn.institution: _institutionCell(context, item),
      _InstitutionColumn.type: _cellText(item.typeName ?? 'Não informado'),
      _InstitutionColumn.units: _cellText('${item.unitsCount}'),
      _InstitutionColumn.groups: _cellText('${item.groupsCount}'),
      _InstitutionColumn.plan: _cellText(item.planName ?? 'Sem plano'),
      _InstitutionColumn.status: Align(
        alignment: Alignment.centerLeft,
        child: _StatusChip(status: item.status),
      ),
      _InstitutionColumn.email: _copyableContent(item, 'email', 'E-mail', item.contactEmail),
      _InstitutionColumn.phone: _copyableContent(item, 'phone', 'Telefone', item.contactPhone),
      _InstitutionColumn.mobile: _copyableContent(
        item,
        'mobile-phone',
        'Celular',
        item.contactMobilePhone,
      ),
      _InstitutionColumn.domain: _copyableContent(item, 'domain', 'Domínio', item.primaryDomain),
      _InstitutionColumn.street: _cellText(item.street ?? '—'),
      _InstitutionColumn.postalCode: _cellText(item.postalCode ?? '—'),
      _InstitutionColumn.number: _cellText(item.addressNumber ?? '—'),
      _InstitutionColumn.complement: _cellText(item.complement ?? '—'),
      _InstitutionColumn.district: _cellText(item.district ?? '—'),
      _InstitutionColumn.city: _cellText(item.city ?? '—'),
      _InstitutionColumn.state: _cellText(item.state ?? '—'),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('institution-table-row-${item.id}'),
        overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
        onHover: (hovered) {
          setState(() => _hoveredItemId = hovered ? item.id : null);
        },
        onTap: () {
          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Os detalhes da instituição serão implementados em breve.'),
              ),
            );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: _InstitutionColumn.values
                .map((column) {
                  return SizedBox(
                    width: _columnWidths[column],
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                      child: values[column],
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String value) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _copyableContent(InstitutionDirectoryItem item, String kind, String label, String? value) {
    return Row(
      children: [
        Expanded(child: Text(value ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (value != null) ...[
          const SizedBox(width: CoeloSpacing.space1),
          _CopyValueButton(itemId: item.id, kind: kind, value: value, label: label),
        ],
      ],
    );
  }
}

enum _InstitutionColumn {
  institution('institution', 'Instituição', 220, 180),
  type('type', 'Tipo', 190, 140),
  units('units', 'Unidades', 100, 88),
  groups('groups', 'Grupos', 100, 88),
  plan('plan', 'Plano', 150, 120),
  status('status', 'Status', 150, 120),
  email('email', 'E-mail', 240, 180),
  phone('phone', 'Telefone', 200, 160),
  mobile('mobile', 'Celular', 200, 160),
  domain('domain', 'Domínio', 220, 170),
  street('street', 'Logradouro', 220, 160),
  number('number', 'Número', 110, 88),
  complement('complement', 'Complemento', 170, 130),
  district('district', 'Bairro', 150, 120),
  postalCode('postal-code', 'CEP', 130, 110),
  city('city', 'Município', 170, 130),
  state('state', 'UF', 80, 64);

  const _InstitutionColumn(this.id, this.label, this.initialWidth, this.minimumWidth);

  final String id;
  final String label;
  final double initialWidth;
  final double minimumWidth;
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({required this.viewModel});

  final InstitutionDirectoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final page = viewModel.page;
    final totalPages = (page.totalCount / InstitutionDirectoryQuery.pageSize).ceil();
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        OutlinedButton.icon(
          onPressed: page.hasPrevious ? () => viewModel.goToPage(page.page - 1) : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Anterior'),
        ),
        Text('Página ${page.page + 1} de $totalPages'),
        OutlinedButton.icon(
          onPressed: page.hasNext ? () => viewModel.goToPage(page.page + 1) : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Próxima'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final InstitutionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = _institutionStatusColors(context, status);
    return Chip(
      label: Text(status.label),
      backgroundColor: background,
      labelStyle: theme.textTheme.labelSmall?.copyWith(color: foreground),
      side: BorderSide(color: foreground.withValues(alpha: 0.28)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ExpandableStatusIndicator extends StatefulWidget {
  const _ExpandableStatusIndicator({required this.itemId, required this.status});

  final String itemId;
  final InstitutionStatus status;

  @override
  State<_ExpandableStatusIndicator> createState() => _ExpandableStatusIndicatorState();
}

class _ExpandableStatusIndicatorState extends State<_ExpandableStatusIndicator> {
  bool _hovered = false;
  bool _focused = false;
  bool _expandedByTap = false;

  bool get _expanded => _hovered || _focused || _expandedByTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = _institutionStatusColors(context, widget.status);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: Semantics(
          button: true,
          label: 'Status: ${widget.status.label}',
          child: GestureDetector(
            onTap: () => setState(() => _expandedByTap = !_expandedByTap),
            child: AnimatedContainer(
              key: Key('institution-status-${widget.itemId}'),
              duration: CoeloMotion.standard,
              curve: Curves.easeOutCubic,
              width: _expanded ? math.max(56, 24 + widget.status.label.length * 6.5) : 24,
              height: CoeloSpacing.space6,
              padding: _expanded
                  ? const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2)
                  : EdgeInsets.zero,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(CoeloRadius.full),
                border: Border.all(
                  color: foreground.withValues(alpha: _focused ? 0.48 : 0.28),
                  width: _focused ? 2 : 1,
                ),
              ),
              child: _expanded
                  ? Text(
                      widget.status.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

(Color, Color) _institutionStatusColors(BuildContext context, InstitutionStatus status) {
  final theme = Theme.of(context);
  final statusColors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  final colors = theme.colorScheme;
  return switch (status) {
    InstitutionStatus.active => (statusColors.successContainer, statusColors.onSuccessContainer),
    InstitutionStatus.onboarding => (statusColors.infoContainer, statusColors.onInfoContainer),
    InstitutionStatus.suspended => (statusColors.errorContainer, statusColors.onErrorContainer),
    InstitutionStatus.draft => (statusColors.warningContainer, statusColors.onWarningContainer),
    InstitutionStatus.inactive ||
    InstitutionStatus.archived => (colors.surfaceContainer, colors.onSurfaceVariant),
  };
}

String _location(String? district, String? city, String? state) {
  if (district == null && city == null && state == null) {
    return 'Não informado';
  }
  final municipality = [city, state].whereType<String>().join('/');
  return [district, if (municipality.isNotEmpty) municipality].whereType<String>().join(', ');
}

final _brazilStates = <({String code, String name})>[
  (code: 'AC', name: 'Acre'),
  (code: 'AL', name: 'Alagoas'),
  (code: 'AP', name: 'Amapá'),
  (code: 'AM', name: 'Amazonas'),
  (code: 'BA', name: 'Bahia'),
  (code: 'CE', name: 'Ceará'),
  (code: 'DF', name: 'Distrito Federal'),
  (code: 'ES', name: 'Espírito Santo'),
  (code: 'GO', name: 'Goiás'),
  (code: 'MA', name: 'Maranhão'),
  (code: 'MT', name: 'Mato Grosso'),
  (code: 'MS', name: 'Mato Grosso do Sul'),
  (code: 'MG', name: 'Minas Gerais'),
  (code: 'PA', name: 'Pará'),
  (code: 'PB', name: 'Paraíba'),
  (code: 'PR', name: 'Paraná'),
  (code: 'PE', name: 'Pernambuco'),
  (code: 'PI', name: 'Piauí'),
  (code: 'RJ', name: 'Rio de Janeiro'),
  (code: 'RN', name: 'Rio Grande do Norte'),
  (code: 'RS', name: 'Rio Grande do Sul'),
  (code: 'RO', name: 'Rondônia'),
  (code: 'RR', name: 'Roraima'),
  (code: 'SC', name: 'Santa Catarina'),
  (code: 'SP', name: 'São Paulo'),
  (code: 'SE', name: 'Sergipe'),
  (code: 'TO', name: 'Tocantins'),
];

final _brazilStatesForMenu = [
  ..._brazilStates.where((state) => state.code == 'SP'),
  ..._brazilStates.where((state) => state.code != 'SP'),
];
