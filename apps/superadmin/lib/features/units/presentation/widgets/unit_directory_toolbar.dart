import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../domain/unit_directory.dart';
import '../unit_directory_view_model.dart';
import 'unit_file_actions.dart';

enum UnitDirectoryDisplay { cards, table }

final class UnitDirectoryToolbar extends StatelessWidget {
  const UnitDirectoryToolbar({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.onDisplayChanged,
    required this.onClearFilters,
    super.key,
  });

  final UnitDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final UnitDirectoryDisplay display;
  final ValueChanged<UnitDirectoryDisplay> onDisplayChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final compactFiles = compact || constraints.maxWidth < 1000;
        final filterWidth = compact ? (constraints.maxWidth - CoeloSpacing.space3) / 2 : 160.0;
        final searchWidth = compact
            ? constraints.maxWidth
            : compactFiles
            ? 216.0
            : 300.0;
        final options = viewModel.filterOptions;

        Widget filter<T>({
          required Key key,
          required String label,
          required List<T> values,
          required Set<T> selected,
          required String Function(T) optionLabel,
          required ValueChanged<Set<T>> onChanged,
          String? searchHint,
        }) {
          return SizedBox(
            key: key,
            width: filterWidth,
            child: CoeloAdminMultiSelectFilter<T>(
              label: label,
              options: values,
              selectedValues: selected,
              optionLabel: optionLabel,
              onChanged: onChanged,
              searchHintText: searchHint,
            ),
          );
        }

        final controls = Wrap(
          key: const Key('unit-filter-controls'),
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
                semanticLabel: 'Buscar unidade por nome',
                onChanged: viewModel.setSearch,
              ),
            ),
            filter<UnitFilterOption>(
              key: const Key('unit-institution-filter'),
              label: 'Todas as instituições',
              values: options.institutions,
              selected: options.institutions
                  .where((item) => viewModel.query.institutionIds.contains(item.id))
                  .toSet(),
              optionLabel: (item) => item.label,
              onChanged: (items) => viewModel.setInstitutions(items.map((item) => item.id).toSet()),
              searchHint: 'Buscar instituição',
            ),
            filter<UnitFilterOption>(
              key: const Key('unit-type-filter'),
              label: 'Todos os tipos',
              values: options.types,
              selected: options.types
                  .where((item) => viewModel.query.typeIds.contains(item.id))
                  .toSet(),
              optionLabel: (item) => item.label,
              onChanged: (items) => viewModel.setTypes(items.map((item) => item.id).toSet()),
            ),
            filter<UnitStatus>(
              key: const Key('unit-status-filter'),
              label: 'Todos os status',
              values: UnitStatus.values,
              selected: viewModel.query.statuses,
              optionLabel: (item) => item.label,
              onChanged: viewModel.setStatuses,
            ),
            filter<UnitFilterOption>(
              key: const Key('unit-plan-filter'),
              label: 'Todos os planos',
              values: options.plans,
              selected: options.plans
                  .where((item) => viewModel.query.planIds.contains(item.id))
                  .toSet(),
              optionLabel: (item) => item.label,
              onChanged: (items) => viewModel.setPlans(items.map((item) => item.id).toSet()),
            ),
            filter<UnitFilterOption>(
              key: const Key('unit-state-filter'),
              label: 'Todas as UFs',
              values: options.states,
              selected: options.states
                  .where((item) => viewModel.query.states.contains(item.id))
                  .toSet(),
              optionLabel: (item) => item.label,
              onChanged: (items) => viewModel.setStates(items.map((item) => item.id).toSet()),
              searchHint: 'Buscar UF',
            ),
            if (viewModel.query.states.isNotEmpty)
              filter<UnitFilterOption>(
                key: const Key('unit-city-filter'),
                label: 'Todos os municípios',
                values: options.cities,
                selected: options.cities
                    .where((item) => viewModel.query.cities.contains(item.id))
                    .toSet(),
                optionLabel: (item) => item.label,
                onChanged: (items) => viewModel.setCities(items.map((item) => item.id).toSet()),
                searchHint: 'Buscar município',
              ),
            if (viewModel.query.cities.isNotEmpty)
              filter<UnitFilterOption>(
                key: const Key('unit-district-filter'),
                label: 'Todos os bairros',
                values: options.districts,
                selected: options.districts
                    .where((item) => viewModel.query.districts.contains(item.id))
                    .toSet(),
                optionLabel: (item) => item.label,
                onChanged: (items) => viewModel.setDistricts(items.map((item) => item.id).toSet()),
                searchHint: 'Buscar bairro',
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
          key: const Key('unit-toolbar-actions'),
          height: CoeloSize.touchMin,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: CoeloSize.touchMin,
                child: SegmentedButton<UnitDirectoryDisplay>(
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
                      value: UnitDirectoryDisplay.cards,
                      tooltip: 'Exibir como cards',
                      icon: Icon(key: Key('unit-view-cards'), Icons.grid_view_rounded),
                    ),
                    ButtonSegment(
                      value: UnitDirectoryDisplay.table,
                      tooltip: 'Exibir como tabela',
                      icon: Icon(key: Key('unit-view-table'), Icons.table_rows_rounded),
                    ),
                  ],
                  selected: {display},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => onDisplayChanged(selection.single),
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              UnitFileActions(activityController: activityController, compact: compactFiles),
            ],
          ),
        );
        return CoeloAdminListingToolbar(
          key: const Key('unit-filter-toolbar'),
          search: controls,
          filters: const [],
          actions: [actions],
        );
      },
    );
  }
}
