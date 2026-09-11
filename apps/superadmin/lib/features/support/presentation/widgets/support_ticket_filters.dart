import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../domain/support_ticket.dart';
import '../view_models/support_prototype_controller.dart';

enum SupportReadFilter { unread }

/// Conteúdo de domínio da toolbar de Suporte para o `CoeloAdminDirectory`
/// (decisão do Owner de 10/09/2026): busca, filtros Status/Menu/Responsável/
/// Leitura (+ Tela quando há menu escolhido) e o `Limpar filtros`. Largura,
/// alinhamento e quebra de linha pertencem ao composto.
final class SupportTicketFilters {
  const SupportTicketFilters({
    required this.controller,
    required this.searchController,
    required this.readFilterFocusScopeNode,
  });

  final SupportPrototypeController controller;
  final TextEditingController searchController;
  final FocusScopeNode readFilterFocusScopeNode;

  Widget get search => CoeloSearchField(
    key: const Key('support-search'),
    controller: searchController,
    semanticLabel: 'Buscar chamados',
    hintText: 'Buscar chamados',
    onChanged: (search) => _update(search: search),
  );

  List<Widget> get filters {
    final menus = _values(controller.tickets.map((ticket) => ticket.menu));
    final selectedMenus = controller.filters.menus;
    final screens = _values(
      controller.tickets
          .where((ticket) => selectedMenus.contains(ticket.menu))
          .map((ticket) => ticket.screen),
    );
    return [
      CoeloAdminMultiSelectFilter<String>(
        key: const Key('support-menu-filter'),
        label: 'Menu',
        options: menus,
        selectedValues: selectedMenus,
        optionLabel: _menuLabel,
        onChanged: _setMenus,
      ),
      CoeloAdminMultiSelectFilter<String>(
        key: const Key('support-assignee-filter'),
        label: 'Responsável',
        options: controller.teamMembers.map((member) => member.id).toList(growable: false),
        selectedValues: controller.filters.assigneeIds,
        optionLabel: (id) =>
            controller.teamMembers
                .where((member) => member.id == id)
                .map((member) => member.name)
                .firstOrNull ??
            'Responsável fora da equipe',
        onChanged: (assigneeIds) => _update(assigneeIds: assigneeIds),
        searchHintText: 'Buscar responsável',
      ),
      FocusScope(
        node: readFilterFocusScopeNode,
        child: CoeloAdminMultiSelectFilter<SupportReadFilter>(
          key: const Key('support-read-filter'),
          label: 'Leitura',
          options: SupportReadFilter.values,
          selectedValues: controller.filters.unreadOnly
              ? const {SupportReadFilter.unread}
              : const {},
          optionLabel: (_) => 'Não lidas',
          onChanged: (values) => _update(unreadOnly: values.contains(SupportReadFilter.unread)),
        ),
      ),
      if (selectedMenus.isNotEmpty)
        CoeloAdminMultiSelectFilter<String>(
          key: const Key('support-screen-filter'),
          label: 'Tela',
          options: screens,
          selectedValues: controller.filters.screens,
          optionLabel: _screenLabel,
          onChanged: (selectedScreens) => _update(screens: selectedScreens),
        ),
    ];
  }

  List<Widget> get trailing => [
    if (controller.hasActiveFilters)
      TextButton.icon(
        key: const Key('support-clear-filters'),
        onPressed: clear,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('Limpar filtros'),
      ),
  ];

  void clear() {
    searchController.clear();
    controller.clearFilters();
  }

  void _setMenus(Set<String> menus) {
    final availableScreens = {
      for (final ticket in controller.tickets)
        if (menus.contains(ticket.menu)) ticket.screen,
    };
    _update(menus: menus, screens: controller.filters.screens.intersection(availableScreens));
  }

  void _update({
    String? search,
    Set<SupportTicketStatus>? statuses,
    Set<String>? menus,
    Set<String>? screens,
    Set<String>? assigneeIds,
    bool? unreadOnly,
  }) {
    final filters = controller.filters;
    controller.updateFilters(
      SupportFilters(
        search: search ?? filters.search,
        statuses: statuses ?? filters.statuses,
        menus: menus ?? filters.menus,
        screens: screens ?? filters.screens,
        assigneeIds: assigneeIds ?? filters.assigneeIds,
        unreadOnly: unreadOnly ?? filters.unreadOnly,
      ),
    );
  }
}

List<String> _values(Iterable<String> values) => values.toSet().toList()..sort();


String _menuLabel(String menu) => switch (menu) {
  'Instituicoes' => 'Instituições',
  'Configuracoes' => 'Configurações',
  _ => menu,
};

String _screenLabel(String screen) => switch (screen) {
  'Diretorio' => 'Diretório',
  _ => screen,
};
