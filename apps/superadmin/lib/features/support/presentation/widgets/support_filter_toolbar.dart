import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../domain/support_ticket.dart';
import '../view_models/support_prototype_controller.dart';

enum SupportDisplayMode { kanban, table }

enum SupportReadFilter { unread }

final class SupportFilterToolbar extends StatelessWidget {
  const SupportFilterToolbar({
    required this.controller,
    required this.searchController,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.readFilterFocusScopeNode,
    required this.onExportCsv,
    required this.onExportXlsx,
    super.key,
  });

  final SupportPrototypeController controller;
  final TextEditingController searchController;
  final SupportDisplayMode displayMode;
  final ValueChanged<SupportDisplayMode> onDisplayModeChanged;
  final FocusScopeNode readFilterFocusScopeNode;
  final ValueChanged<BuildContext> onExportCsv;
  final ValueChanged<BuildContext> onExportXlsx;

  @override
  Widget build(BuildContext context) {
    final menus = _values(controller.tickets.map((ticket) => ticket.menu));
    final selectedMenus = controller.filters.menus;
    final screens = _values(
      controller.tickets
          .where((ticket) => selectedMenus.contains(ticket.menu))
          .map((ticket) => ticket.screen),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final filterWidth = compact ? (constraints.maxWidth - CoeloSpacing.space3) / 2 : 132.0;
        final assigneeFilterWidth = compact ? filterWidth : 184.0;
        final controls = Wrap(
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              key: const Key('support-search'),
              width: compact ? constraints.maxWidth : 232,
              height: CoeloSize.touchMin,
              child: CoeloSearchField(
                controller: searchController,
                semanticLabel: 'Buscar chamados',
                hintText: 'Buscar chamados',
                onChanged: (search) => _update(search: search),
              ),
            ),
            SizedBox(
              width: filterWidth,
              child: CoeloAdminMultiSelectFilter<SupportTicketStatus>(
                key: const Key('support-status-filter'),
                label: 'Status',
                options: SupportTicketStatus.values,
                selectedValues: controller.filters.statuses,
                optionLabel: _statusLabel,
                onChanged: (statuses) => _update(statuses: statuses),
              ),
            ),
            SizedBox(
              width: filterWidth,
              child: CoeloAdminMultiSelectFilter<String>(
                key: const Key('support-menu-filter'),
                label: 'Menu',
                options: menus,
                selectedValues: selectedMenus,
                optionLabel: _menuLabel,
                onChanged: _setMenus,
              ),
            ),
            SizedBox(
              width: assigneeFilterWidth,
              child: CoeloAdminMultiSelectFilter<String>(
                key: const Key('support-assignee-filter'),
                label: 'Responsável',
                options: controller.teamMembers.map((member) => member.id).toList(growable: false),
                selectedValues: controller.filters.assigneeIds,
                optionLabel: (id) =>
                    controller.teamMembers.firstWhere((member) => member.id == id).name,
                onChanged: (assigneeIds) => _update(assigneeIds: assigneeIds),
                searchHintText: 'Buscar responsável',
              ),
            ),
            SizedBox(
              width: filterWidth,
              child: FocusScope(
                node: readFilterFocusScopeNode,
                child: CoeloAdminMultiSelectFilter<SupportReadFilter>(
                  key: const Key('support-read-filter'),
                  label: 'Leitura',
                  options: SupportReadFilter.values,
                  selectedValues: controller.filters.unreadOnly
                      ? const {SupportReadFilter.unread}
                      : const {},
                  optionLabel: (_) => 'Não lidas',
                  onChanged: (values) =>
                      _update(unreadOnly: values.contains(SupportReadFilter.unread)),
                ),
              ),
            ),
            if (selectedMenus.isNotEmpty)
              SizedBox(
                width: filterWidth,
                child: CoeloAdminMultiSelectFilter<String>(
                  key: const Key('support-screen-filter'),
                  label: 'Tela',
                  options: screens,
                  selectedValues: controller.filters.screens,
                  optionLabel: _screenLabel,
                  onChanged: (selectedScreens) => _update(screens: selectedScreens),
                ),
              ),
            if (controller.hasActiveFilters)
              TextButton.icon(
                key: const Key('support-clear-filters'),
                onPressed: () {
                  searchController.clear();
                  controller.clearFilters();
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Limpar filtros'),
              ),
          ],
        );
        return CoeloAdminListingToolbar(
          key: const Key('support-filter-toolbar'),
          search: controls,
          filters: const [],
          actions: [
            SizedBox(
              key: const Key('support-view-toggle'),
              height: CoeloSize.touchMin,
              child: SegmentedButton<SupportDisplayMode>(
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(CoeloSize.touchMin, CoeloSize.touchMin)),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: SupportDisplayMode.kanban,
                    tooltip: 'Exibir como kanban',
                    icon: Icon(Icons.view_kanban_rounded),
                  ),
                  ButtonSegment(
                    value: SupportDisplayMode.table,
                    tooltip: 'Exibir como tabela',
                    icon: Icon(Icons.table_rows_rounded),
                  ),
                ],
                selected: {displayMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => onDisplayModeChanged(selection.single),
              ),
            ),
            CoeloAdminFileActions(
              compact: compact,
              actions: [
                CoeloAdminFileAction(
                  key: const Key('support-files-export-csv'),
                  label: 'Exportar CSV',
                  icon: Icons.table_rows_outlined,
                  onPressed: () => onExportCsv(context),
                ),
                CoeloAdminFileAction(
                  key: const Key('support-files-export-xlsx'),
                  label: 'Exportar XLSX',
                  icon: Icons.grid_on_outlined,
                  onPressed: () => onExportXlsx(context),
                ),
              ],
            ),
          ],
        );
      },
    );
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

String _statusLabel(SupportTicketStatus status) => switch (status) {
  SupportTicketStatus.newRequest => 'Novo',
  SupportTicketStatus.inProgress => 'Em andamento',
  SupportTicketStatus.waitingRequester => 'Aguardando',
  SupportTicketStatus.completed => 'Concluído',
};

String _menuLabel(String menu) => switch (menu) {
  'Instituicoes' => 'Instituições',
  'Configuracoes' => 'Configurações',
  _ => menu,
};

String _screenLabel(String screen) => switch (screen) {
  'Diretorio' => 'Diretório',
  _ => screen,
};
