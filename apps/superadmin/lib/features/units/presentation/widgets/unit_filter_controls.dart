import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/unit_directory.dart';
import '../unit_directory_view_model.dart';

/// Filtros de domínio de Unidades, sem largura: o `CoeloAdminDirectory`
/// aplica a largura por breakpoint. Município e bairro dependem da UF.
List<Widget> unitFilterControls(UnitDirectoryViewModel viewModel) {
  final options = viewModel.filterOptions;

  Widget filter<T>({
    required Key key,
    required String label,
    required List<T> values,
    required Set<T> selected,
    required String Function(T) optionLabel,
    required ValueChanged<Set<T>> onChanged,
    String? searchHint,
  }) => CoeloAdminMultiSelectFilter<T>(
    key: key,
    label: label,
    options: values,
    selectedValues: selected,
    optionLabel: optionLabel,
    onChanged: onChanged,
    searchHintText: searchHint,
  );

  return [
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
      selected: options.types.where((item) => viewModel.query.typeIds.contains(item.id)).toSet(),
      optionLabel: (item) => item.label,
      onChanged: (items) => viewModel.setTypes(items.map((item) => item.id).toSet()),
    ),
    filter<UnitFilterOption>(
      key: const Key('unit-plan-filter'),
      label: 'Todos os planos',
      values: options.plans,
      selected: options.plans.where((item) => viewModel.query.planIds.contains(item.id)).toSet(),
      optionLabel: (item) => item.label,
      onChanged: (items) => viewModel.setPlans(items.map((item) => item.id).toSet()),
    ),
    filter<UnitFilterOption>(
      key: const Key('unit-state-filter'),
      label: 'Todas as UFs',
      values: options.states,
      selected: options.states.where((item) => viewModel.query.states.contains(item.id)).toSet(),
      optionLabel: (item) => item.label,
      onChanged: (items) => viewModel.setStates(items.map((item) => item.id).toSet()),
      searchHint: 'Buscar UF',
    ),
    if (viewModel.query.states.isNotEmpty)
      filter<UnitFilterOption>(
        key: const Key('unit-city-filter'),
        label: 'Todos os municípios',
        values: options.cities,
        selected: options.cities.where((item) => viewModel.query.cities.contains(item.id)).toSet(),
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
  ];
}
