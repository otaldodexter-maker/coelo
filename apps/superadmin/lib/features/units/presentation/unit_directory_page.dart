import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/unit_directory.dart';
import 'unit_directory_view_model.dart';

enum UnitDirectoryDisplay { cards, table }

final class UnitDirectoryPage extends StatefulWidget {
  const UnitDirectoryPage({
    required this.repository,
    required this.logout,
    this.onCreate,
    this.onEdit,
    this.onDestinationSelected,
    this.successMessage,
    super.key,
  });

  final UnitDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onDestinationSelected;
  final String? successMessage;

  @override
  State<UnitDirectoryPage> createState() => _UnitDirectoryPageState();
}

final class _UnitDirectoryPageState extends State<UnitDirectoryPage> {
  late final UnitDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  UnitDirectoryDisplay _display = UnitDirectoryDisplay.cards;
  bool _noticeShown = false;

  @override
  void initState() {
    super.initState();
    _viewModel = UnitDirectoryViewModel(widget.repository);
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UnitDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.successMessage != widget.successMessage) {
      _noticeShown = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.successMessage;
    if (message != null && !_noticeShown) {
      _noticeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showSuperadminNotice(context, message, icon: Icons.check_circle_outline_rounded);
        }
      });
    }
    return SuperadminShell(
      logout: widget.logout,
      title: 'Unidades',
      subtitle: 'Gerencie as unidades da plataforma.',
      currentDestination: 'units',
      onDestinationSelected: widget.onDestinationSelected,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          return ListView(
            key: const Key('unit-directory-scroll'),
            padding: EdgeInsets.all(padding),
            children: [
              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, _) => _UnitToolbar(
                  viewModel: _viewModel,
                  searchController: _searchController,
                  display: _display,
                  onDisplayChanged: (value) => setState(() => _display = value),
                  onClear: () {
                    _searchController.clear();
                    _viewModel.clearFilters();
                  },
                ),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, _) => _UnitResults(
                  viewModel: _viewModel,
                  display: _display,
                  onCreate: widget.onCreate ?? () {},
                  onEdit: widget.onEdit ?? (_) {},
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _UnitToolbar extends StatelessWidget {
  const _UnitToolbar({
    required this.viewModel,
    required this.searchController,
    required this.display,
    required this.onDisplayChanged,
    required this.onClear,
  });

  final UnitDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final UnitDirectoryDisplay display;
  final ValueChanged<UnitDirectoryDisplay> onDisplayChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
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
        width: 170,
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

    final options = viewModel.filterOptions;
    final filters = <Widget>[
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
          onPressed: onClear,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Limpar filtros'),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => CoeloAdminListingToolbar(
        key: const Key('unit-filter-toolbar'),
        search: SizedBox(
          width: constraints.maxWidth < CoeloBreakpoints.medium.minWidth
              ? constraints.maxWidth
              : 300,
          child: CoeloSearchField(
            controller: searchController,
            hintText: 'Buscar por nome',
            semanticLabel: 'Buscar unidade por nome',
            onChanged: viewModel.setSearch,
          ),
        ),
        filters: filters,
        actions: [
          SegmentedButton<UnitDirectoryDisplay>(
            segments: const [
              ButtonSegment(
                value: UnitDirectoryDisplay.cards,
                icon: Icon(key: Key('unit-view-cards'), Icons.grid_view_rounded),
                tooltip: 'Exibir como cards',
              ),
              ButtonSegment(
                value: UnitDirectoryDisplay.table,
                icon: Icon(key: Key('unit-view-table'), Icons.table_rows_rounded),
                tooltip: 'Exibir como tabela',
              ),
            ],
            selected: {display},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onDisplayChanged(selection.single),
          ),
          PopupMenuButton<String>(
            tooltip: 'Arquivos de unidades',
            onSelected: (action) {
              final message = action == 'template'
                  ? 'Modelo CSV de unidades preparado.'
                  : 'Exportação local de unidades preparada.';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'template', child: Text('Baixar modelo CSV')),
              PopupMenuItem(value: 'export', child: Text('Exportar unidades')),
            ],
            child: const SizedBox(
              height: CoeloSize.touchMin,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined),
                    SizedBox(width: CoeloSpacing.space2),
                    Text('Arquivos'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _UnitResults extends StatelessWidget {
  const _UnitResults({
    required this.viewModel,
    required this.display,
    required this.onCreate,
    required this.onEdit,
  });

  final UnitDirectoryViewModel viewModel;
  final UnitDirectoryDisplay display;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading) {
      return const LinearProgressIndicator();
    }
    if (viewModel.state == UnitDirectoryLoadState.failure) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar as unidades',
        message: 'Tente novamente.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: viewModel.retry,
      );
    }
    if (viewModel.state == UnitDirectoryLoadState.unauthorized) {
      return const CoeloStatePanel(
        title: 'Acesso não autorizado',
        message: 'Você não tem permissão para ver as unidades.',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (viewModel.state == UnitDirectoryLoadState.empty ||
        viewModel.state == UnitDirectoryLoadState.noResults) {
      return CoeloStatePanel(
        title: viewModel.state == UnitDirectoryLoadState.empty
            ? 'Nenhuma unidade cadastrada'
            : 'Nenhuma unidade encontrada',
        message: viewModel.state == UnitDirectoryLoadState.empty
            ? 'Crie a primeira unidade da plataforma.'
            : 'Ajuste ou limpe os filtros.',
        icon: Icons.apartment_outlined,
        actionLabel: viewModel.state == UnitDirectoryLoadState.empty
            ? 'Criar unidade'
            : 'Limpar filtros',
        onAction: viewModel.state == UnitDirectoryLoadState.empty
            ? onCreate
            : viewModel.clearFilters,
      );
    }
    final content = display == UnitDirectoryDisplay.cards
        ? _UnitCards(items: viewModel.page.items, onCreate: onCreate, onEdit: onEdit)
        : Column(
            children: [
              SizedBox(
                height: 132,
                child: CoeloAdminCreateAction(
                  label: 'Criar unidade',
                  icon: Icons.apartment_rounded,
                  onPressed: onCreate,
                ),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _UnitTable(items: viewModel.page.items, onEdit: onEdit),
            ],
          );
    final totalPages = (viewModel.page.totalCount / UnitDirectoryQuery.pageSize).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (totalPages > 1) ...[
          const SizedBox(height: CoeloSpacing.space4),
          Align(
            alignment: Alignment.centerRight,
            child: CoeloAdminPagination(
              currentPage: viewModel.page.page + 1,
              totalPages: totalPages,
              onPrevious: viewModel.page.page == 0
                  ? null
                  : () => viewModel.goToPage(viewModel.page.page - 1),
              onNext: viewModel.page.page + 1 >= totalPages
                  ? null
                  : () => viewModel.goToPage(viewModel.page.page + 1),
              onPageSelected: (page) => viewModel.goToPage(page - 1),
            ),
          ),
        ],
      ],
    );
  }
}

final class _UnitCards extends StatelessWidget {
  const _UnitCards({required this.items, required this.onCreate, required this.onEdit});

  final List<UnitDirectoryItem> items;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      CoeloAdminCreateAction(
        key: const Key('create-unit-card'),
        label: 'Criar unidade',
        icon: Icons.apartment_rounded,
        onPressed: onCreate,
      ),
      for (final item in items) _UnitCard(item: item, onPressed: () => onEdit(item.id)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1320
            ? 4
            : constraints.maxWidth >= 920
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final width = (constraints.maxWidth - CoeloSpacing.space4 * (columns - 1)) / columns;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final cardHeight = 216.0 + (textScale - 1).clamp(0.0, 1.0) * 208.0;
        return Wrap(
          spacing: CoeloSpacing.space4,
          runSpacing: CoeloSpacing.space4,
          children: [
            for (final child in children) SizedBox(width: width, height: cardHeight, child: child),
          ],
        );
      },
    );
  }
}

final class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.item, required this.onPressed});

  final UnitDirectoryItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('unit-card-${item.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        overlayColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primaryContainer),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Text(item.initials)),
                  const SizedBox(width: CoeloSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          [
                            item.district,
                            '${item.city}/${item.state}',
                          ].where((value) => value.isNotEmpty && value != '/').join(', '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _UnitStatusDot(status: item.status),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Row(
                children: [
                  Text('Instituição', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(
                    child: Text(
                      item.institutionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              const Divider(height: CoeloSpacing.space5),
              _DetailRow(
                first: _Detail(icon: Icons.category_outlined, label: 'Tipo', value: item.typeName),
                second: _Detail(
                  icon: Icons.sell_outlined,
                  label: 'Plano',
                  value: item.effectivePlan.label,
                ),
              ),
              const SizedBox(height: CoeloSpacing.space3),
              _DetailRow(
                first: _Detail(
                  icon: Icons.groups_outlined,
                  label: 'Grupos',
                  value: '${item.groupsCount}',
                ),
                second: _Detail(
                  icon: Icons.local_activity_outlined,
                  label: 'Atividades',
                  value: '${item.activitiesCount}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: first),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(child: second),
    ],
  );
}

final class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: CoeloSize.iconSm),
      const SizedBox(width: CoeloSpacing.space2),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}

final class _UnitStatusDot extends StatelessWidget {
  const _UnitStatusDot({required this.status});
  final UnitStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _unitStatusColors(context, status);
    return Tooltip(
      message: status.label,
      child: Semantics(
        label: 'Status: ${status.label}',
        child: Container(
          width: CoeloSpacing.space6,
          height: CoeloSpacing.space6,
          decoration: BoxDecoration(
            color: colors.$1,
            shape: BoxShape.circle,
            border: Border.all(color: colors.$2.withValues(alpha: .3)),
          ),
        ),
      ),
    );
  }
}

final class _UnitTable extends StatelessWidget {
  const _UnitTable({required this.items, required this.onEdit});
  final List<UnitDirectoryItem> items;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    CoeloAdminTableColumn<UnitDirectoryItem> column(
      String id,
      String label,
      String Function(UnitDirectoryItem) value, {
      double width = 150,
    }) {
      return CoeloAdminTableColumn(
        id: id,
        label: label,
        initialWidth: width,
        minWidth: 80,
        maxWidth: 360,
        cellBuilder: (context, item) =>
            Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }

    return CoeloAdminResizableTable<UnitDirectoryItem>(
      key: const Key('unit-directory-table'),
      items: items,
      rowKey: (item) => item.id,
      headerHeight: 56,
      rowHeight: 64,
      onRowPressed: (item) => onEdit(item.id),
      pinnedColumn: column('unit', 'Unidade', (item) => item.name, width: 220),
      columns: [
        column('institution', 'Instituição', (item) => item.institutionName, width: 220),
        column('type', 'Tipo', (item) => item.typeName, width: 180),
        column('groups', 'Grupos', (item) => '${item.groupsCount}', width: 100),
        column('activities', 'Atividades', (item) => '${item.activitiesCount}', width: 110),
        column('plan', 'Plano', (item) => item.effectivePlan.label),
        CoeloAdminTableColumn(
          id: 'status',
          label: 'Status',
          initialWidth: 150,
          minWidth: 120,
          maxWidth: 200,
          cellBuilder: (context, item) {
            final colors = _unitStatusColors(context, item.status);
            return Align(
              alignment: Alignment.centerLeft,
              child: CoeloStatusChip(
                label: item.status.label,
                backgroundColor: colors.$1,
                foregroundColor: colors.$2,
              ),
            );
          },
        ),
        column('email', 'E-mail', (item) => item.contactEmail, width: 220),
        column('phone', 'Telefone', (item) => item.contactPhone, width: 180),
        column('mobile', 'Celular', (item) => item.contactMobilePhone, width: 180),
        column('street', 'Logradouro', (item) => item.street, width: 220),
        column('number', 'Número', (item) => item.addressNumber, width: 100),
        column('complement', 'Complemento', (item) => item.complement, width: 160),
        column('district', 'Bairro', (item) => item.district),
        column('postal-code', 'CEP', (item) => item.postalCode, width: 120),
        column('city', 'Município', (item) => item.city, width: 170),
        column('state', 'UF', (item) => item.state, width: 80),
      ],
    );
  }
}

(Color, Color) _unitStatusColors(BuildContext context, UnitStatus status) {
  final theme = Theme.of(context);
  final statusColors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  return switch (status) {
    UnitStatus.active => (statusColors.successContainer, statusColors.onSuccessContainer),
    UnitStatus.suspended => (statusColors.errorContainer, statusColors.onErrorContainer),
    UnitStatus.draft => (statusColors.warningContainer, statusColors.onWarningContainer),
    UnitStatus.inactive ||
    UnitStatus.archived => (theme.colorScheme.surfaceContainer, theme.colorScheme.onSurfaceVariant),
  };
}
