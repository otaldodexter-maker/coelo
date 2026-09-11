import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/group_directory.dart';
import 'group_directory_view_model.dart';

enum GroupDirectoryTableView { grouped }

final class GroupDirectoryPage extends StatefulWidget {
  const GroupDirectoryPage({
    required this.repository,
    required this.logout,
    this.onCreate,
    this.onEdit,
    this.onView,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.successMessage,
    super.key,
  });

  final GroupDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onView;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final String? successMessage;

  @override
  State<GroupDirectoryPage> createState() => _GroupDirectoryPageState();
}

final class _GroupDirectoryPageState extends State<GroupDirectoryPage> {
  late final GroupDirectoryViewModel _viewModel;
  late final SuperadminActivityController _activityController;
  late final TextEditingController _searchController;
  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.cards;
  GroupDirectoryTableView _tableView = GroupDirectoryTableView.grouped;
  double _footerHeight = 0;
  bool _noticeShown = false;

  @override
  void initState() {
    super.initState();
    _viewModel = GroupDirectoryViewModel(widget.repository);
    _activityController = SuperadminActivityController();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant GroupDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.successMessage != widget.successMessage) _noticeShown = false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _setDisplay(CoeloAdminDirectoryDisplay display) {
    if (_display == display) return;
    setState(() => _display = display);
    _viewModel.setPageSize(display == CoeloAdminDirectoryDisplay.cards ? 11 : 8);
  }

  void _setTableView(GroupDirectoryTableView tableView) {
    final wasCards = _display == CoeloAdminDirectoryDisplay.cards;
    setState(() {
      _display = CoeloAdminDirectoryDisplay.table;
      _tableView = tableView;
    });
    if (wasCards) _viewModel.setPageSize(8);
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      activityController: _activityController,
      title: 'Turmas',
      subtitle: 'Gerencie as turmas da plataforma.',
      currentDestination: 'groups',
      chatLauncherBottomInset: _footerHeight,
      onDestinationSelected: widget.onDestinationSelected,
      onBugReportSubmitted: widget.onBugReportSubmitted,
      child: Builder(
        builder: (context) {
          final message = widget.successMessage;
          if (message != null && !_noticeShown) {
            _noticeShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showSuperadminNotice(context, message, icon: Icons.check_circle_outline_rounded);
              }
            });
          }
          return _GroupDirectoryContent(
            viewModel: _viewModel,
            searchController: _searchController,
            display: _display,
            tableView: _tableView,
            onDisplayChanged: _setDisplay,
            onTableViewChanged: _setTableView,
            onCreate: widget.onCreate,
            onEdit: widget.onEdit ?? widget.onView,
            onFooterHeightChanged: (height) {
              if ((_footerHeight - height).abs() >= .5) {
                setState(() => _footerHeight = height);
              }
            },
          );
        },
      ),
    );
  }
}

/// Diretório de Turmas: instância do `CoeloAdminDirectory` com o conteúdo de
/// domínio (busca, filtros, abas de status, cards e linhas da tabela).
final class _GroupDirectoryContent extends StatelessWidget {
  const _GroupDirectoryContent({
    required this.viewModel,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onFooterHeightChanged,
  });

  final GroupDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final CoeloAdminDirectoryDisplay display;
  final GroupDirectoryTableView tableView;
  final ValueChanged<CoeloAdminDirectoryDisplay> onDisplayChanged;
  final ValueChanged<GroupDirectoryTableView> onTableViewChanged;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<double> onFooterHeightChanged;

  void _showUnavailable(BuildContext context) {
    showSuperadminNotice(context, 'Disponível depois do MVP', icon: Icons.info_outline_rounded);
  }

  void _clearFilters() {
    searchController.clear();
    viewModel.clearFilters();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: viewModel,
    builder: (context, _) {
      final options = viewModel.filterOptions;
      // P5: filtros indisponiveis ficam visiveis, vazios e nomeados como tal.
      final filterSuffix = viewModel.filterOptionsUnavailable ? ' (indisponível)' : '';
      final page = viewModel.page;
      final onCreate = this.onCreate;
      final totalPages = page.totalCount == 0
          ? 1
          : (page.totalCount / viewModel.query.pageSize).ceil();

      Widget filter<T>({
        required Key key,
        required String label,
        required List<T> options,
        required Set<T> selected,
        required String Function(T) optionLabel,
        required ValueChanged<Set<T>> onChanged,
        String? searchHintText,
      }) => CoeloAdminMultiSelectFilter<T>(
        key: key,
        label: label,
        options: options,
        selectedValues: selected,
        optionLabel: optionLabel,
        onChanged: onChanged,
        searchHintText: searchHintText,
      );

      return CoeloAdminDirectory<GroupDirectoryTableView>(
        scrollKey: const Key('group-directory-scroll'),
        toolbarKey: const Key('group-filter-toolbar'),
        filterControlsKey: const Key('group-filter-controls'),
        actionsKey: const Key('group-toolbar-actions'),
        cardsKey: const Key('group-view-cards'),
        tableKey: const Key('group-view-table'),
        gridKey: const Key('group-card-grid'),
        status: switch (viewModel.state) {
          GroupDirectoryLoadState.initial ||
          GroupDirectoryLoadState.loading => CoeloAdminDirectoryStatus.loading,
          GroupDirectoryLoadState.failure => CoeloAdminDirectoryStatus.failure,
          GroupDirectoryLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
          GroupDirectoryLoadState.empty => CoeloAdminDirectoryStatus.empty,
          GroupDirectoryLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
          GroupDirectoryLoadState.success => CoeloAdminDirectoryStatus.success,
        },
        messages: const CoeloAdminDirectoryMessages(
          empty: 'Nenhuma turma cadastrada',
          emptyIcon: Icons.groups_outlined,
          noResults: 'Nenhuma turma encontrada',
          failure: 'Não foi possível carregar as turmas',
          failureIcon: Icons.cloud_off_outlined,
          unauthorized: 'Acesso não autorizado',
          unauthorizedIcon: Icons.lock_outline_rounded,
        ),
        onRetry: viewModel.retry,
        onClearFilters: _clearFilters,
        search: CoeloSearchField(
          controller: searchController,
          hintText: 'Buscar por nome',
          semanticLabel: 'Buscar turma por nome',
          onChanged: viewModel.setSearch,
        ),
        filters: [
          filter<GroupDirectoryFilterOption>(
            key: const Key('group-institution-filter'),
            label: 'Instituições' + filterSuffix,
            options: options.institutions,
            selected: options.institutions
                .where((option) => viewModel.query.institutionIds.contains(option.id))
                .toSet(),
            optionLabel: (option) => option.label,
            onChanged: (value) => viewModel.setInstitutions(value.map((item) => item.id).toSet()),
            searchHintText: 'Buscar instituição',
          ),
          filter<GroupDirectoryFilterOption>(
            key: const Key('group-unit-filter'),
            label: 'Unidades' + filterSuffix,
            options: options.units,
            selected: options.units
                .where((option) => viewModel.query.unitIds.contains(option.id))
                .toSet(),
            optionLabel: (option) => option.label,
            onChanged: (value) => viewModel.setUnits(value.map((item) => item.id).toSet()),
            searchHintText: 'Buscar unidade',
          ),
          filter<GroupDirectoryFilterOption>(
            key: const Key('group-type-filter'),
            label: 'Tipo da turma' + filterSuffix,
            options: options.types,
            selected: options.types
                .where((option) => viewModel.query.typeIds.contains(option.id))
                .toSet(),
            optionLabel: (option) => option.label,
            onChanged: (value) => viewModel.setTypes(value.map((item) => item.id).toSet()),
          ),
        ],
        trailing: [
          if (viewModel.query.hasActiveFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
        ],
        display: display,
        onDisplayChanged: onDisplayChanged,
        groupedTableView: GroupDirectoryTableView.grouped,
        selectedTableView: tableView,
        tableViews: const [
          CoeloAdminDirectoryTableViewOption(
            value: GroupDirectoryTableView.grouped,
            label: 'Agrupado',
          ),
        ],
        onTableViewSelected: onTableViewChanged,
        fileActions: [
          CoeloAdminFileAction(
            key: const Key('group-files-import'),
            label: 'Importar',
            icon: Icons.upload_file_outlined,
            onPressed: () => _showUnavailable(context),
          ),
          CoeloAdminFileAction(
            key: const Key('group-files-export-csv'),
            label: 'Exportar CSV',
            icon: Icons.table_rows_outlined,
            onPressed: () => _showUnavailable(context),
          ),
          CoeloAdminFileAction(
            key: const Key('group-files-export-xlsx'),
            label: 'Exportar XLSX',
            icon: Icons.grid_on_outlined,
            onPressed: () => _showUnavailable(context),
          ),
        ],
        tabs: CoeloAdminUnderlineTabs<GroupDirectoryStatusCategory>(
          key: const Key('group-status-tabs'),
          tabs: [
            for (final category in GroupDirectoryStatusCategory.values)
              CoeloAdminUnderlineTab(value: category, label: category.label),
          ],
          selected: groupDirectoryStatusCategoryFrom(viewModel.query.statuses),
          onSelected: viewModel.setStatusCategory,
        ),
        create: onCreate == null
            ? null
            : CoeloAdminDirectoryCreate(
                label: 'Criar turma',
                description: 'Adicionar nova turma ao sistema.',
                icon: Icons.groups_rounded,
                onPressed: onCreate,
                tileKey: const Key('group-create-tile'),
                bannerKey: const Key('group-create-banner'),
                bannerSurfaceKey: const Key('group-create-banner-surface'),
              ),
        refreshing: viewModel.isLoading,
        cards: [
          for (final item in page.items)
            _GroupCard(item: item, onPressed: onEdit == null ? null : () => onEdit!(item.id)),
        ],
        table: _GroupTableRows(items: page.items, viewModel: viewModel, onEdit: onEdit),
        pagination: viewModel.state == GroupDirectoryLoadState.success
            ? CoeloAdminDirectoryPagination(
                footerKey: const Key('group-directory-pagination-footer'),
                currentPage: page.page + 1,
                totalPages: totalPages,
                pageSize: viewModel.query.pageSize,
                pageSizeOptions: display == CoeloAdminDirectoryDisplay.cards
                    ? const [11, 20, 50, 100]
                    : const [8, 20, 50, 100],
                onPageSelected: (value) => viewModel.setPage(value - 1),
                onPageSizeChanged: viewModel.setPageSize,
              )
            : null,
        onFooterHeightChanged: onFooterHeightChanged,
      );
    },
  );
}

final class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.item, required this.onPressed});

  final GroupDirectoryItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CoeloAdminInteractiveCard(
      key: Key('group-card-${item.id}'),
      surfaceKey: Key('group-card-surface-${item.id}'),
      // Observação do Owner (10/09/2026): o card tinha altura fixa de 336 e
      // sobrava espaço; passa a crescer com o conteúdo sobre o mínimo da família.
      minHeight: CoeloAdminDirectoryMetrics.cardMinHeight,
      onPressed: onPressed,
      semanticLabel: onPressed == null ? null : 'Abrir turma ${item.name}',
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
                  dimension: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.groups_rounded, color: colors.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      _CardContextLine(label: 'Unidade', value: item.unitName),
                      _CardContextLine(label: 'Instituição', value: item.institutionName),
                    ],
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                Builder(
                  builder: (context) {
                    final pair = _groupStatusColors(context, item.status);
                    return CoeloAdminExpandableStatusIndicator(
                      label: item.status.label,
                      backgroundColor: pair.$1,
                      foregroundColor: pair.$2,
                      semanticLabel: 'Status: ${item.status.label}',
                      surfaceKey: Key('group-status-${item.id}'),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space4),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - CoeloSpacing.space3) / 2;
                return Wrap(
                  spacing: CoeloSpacing.space3,
                  runSpacing: CoeloSpacing.space3,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _GroupDetail(
                        icon: Icons.category_outlined,
                        label: 'Tipo',
                        value: item.groupTypeLabel,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _GroupDetail(
                        icon: Icons.school_outlined,
                        label: 'Alunos',
                        value: '${item.studentCount}',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _GroupDetail(
                        icon: Icons.local_activity_outlined,
                        label: 'Atividades',
                        value: '${item.activityCount}',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _GroupDetail(
                        icon: Icons.supervisor_account_outlined,
                        label: 'Professores',
                        value: '${item.teacherOrResponsibleNames.length}',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final class _CardContextLine extends StatelessWidget {
  const _CardContextLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: value),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall,
  );
}

final class _GroupDetail extends StatelessWidget {
  const _GroupDetail({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: CoeloSpacing.space8,
          height: CoeloSpacing.space8,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.sm),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: CoeloSize.iconSm, color: colors.onSurfaceVariant),
        ),
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

/// Linhas e colunas de domínio das turmas sobre a tabela compartilhada.
final class _GroupTableRows extends StatelessWidget {
  const _GroupTableRows({required this.items, required this.viewModel, required this.onEdit});

  final List<GroupDirectoryItem> items;
  final GroupDirectoryViewModel viewModel;
  final ValueChanged<String>? onEdit;

  @override
  Widget build(BuildContext context) {
    CoeloAdminTableColumn<GroupDirectoryItem> column(
      String id,
      String label,
      String Function(GroupDirectoryItem) value, {
      double width = 180,
    }) => CoeloAdminTableColumn(
      id: id,
      label: label,
      initialWidth: width,
      minWidth: 100,
      maxWidth: 360,
      sortable: true,
      cellBuilder: (context, item) => Align(
        alignment: Alignment.centerLeft,
        child: Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: const Key('group-directory-table-viewport'),
        width: constraints.maxWidth,
        child: CoeloAdminResizableTable<GroupDirectoryItem>(
          key: const Key('group-directory-table'),
          items: items,
          rowKey: (item) => 'group-table-row-${item.id}',
          headerHeight: 56,
          rowHeight: 64,
          onRowPressed: onEdit == null ? null : (item) => onEdit!(item.id),
          sortColumnId: switch (viewModel.query.sortColumn) {
            GroupDirectorySortColumn.name => 'group',
            GroupDirectorySortColumn.institutionName => 'institution',
            GroupDirectorySortColumn.unitName => 'unit',
            GroupDirectorySortColumn.groupType => 'type',
            GroupDirectorySortColumn.status => 'status',
          },
          sortAscending: viewModel.query.sortAscending,
          onSort: (columnId) {
            final column = switch (columnId) {
              'institution' => GroupDirectorySortColumn.institutionName,
              'unit' => GroupDirectorySortColumn.unitName,
              'type' => GroupDirectorySortColumn.groupType,
              'status' => GroupDirectorySortColumn.status,
              _ => GroupDirectorySortColumn.name,
            };
            viewModel.setSort(
              column,
              viewModel.query.sortColumn == column ? !viewModel.query.sortAscending : true,
            );
          },
          pinnedColumn: CoeloAdminTableColumn(
            id: 'group',
            label: 'Turma',
            initialWidth: 260,
            minWidth: 180,
            maxWidth: 600,
            sortable: true,
            cellBuilder: (context, item) {
              final colors = Theme.of(context).colorScheme;
              return Row(
                children: [
                  Container(
                    width: CoeloSpacing.space8,
                    height: CoeloSpacing.space8,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.groups_rounded,
                      size: CoeloSize.iconSm,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              );
            },
          ),
          columns: [
            column('institution', 'Instituição', (item) => item.institutionName, width: 250),
            column('unit', 'Unidade', (item) => item.unitName, width: 230),
            column('type', 'Tipo', (item) => item.groupTypeLabel),
            CoeloAdminTableColumn(
              id: 'status',
              label: 'Status da turma',
              initialWidth: 176,
              minWidth: 120,
              maxWidth: 600,
              sortable: true,
              cellBuilder: (context, item) => Align(
                alignment: Alignment.centerLeft,
                child: _GroupStatusChip(status: item.status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _GroupStatusChip extends StatelessWidget {
  const _GroupStatusChip({required this.status});
  final GroupStatus status;

  @override
  Widget build(BuildContext context) {
    final pair = _groupStatusColors(context, status);
    return CoeloStatusChip(label: status.label, backgroundColor: pair.$1, foregroundColor: pair.$2);
  }
}

(Color, Color) _groupStatusColors(BuildContext context, GroupStatus status) {
  final theme = Theme.of(context);
  final colors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  return switch (status) {
    GroupStatus.active => (colors.successContainer, colors.onSuccessContainer),
    GroupStatus.suspended => (colors.errorContainer, colors.onErrorContainer),
    GroupStatus.draft => (colors.warningContainer, colors.onWarningContainer),
    GroupStatus.unknown || GroupStatus.inactive || GroupStatus.archived => (
      theme.colorScheme.surfaceContainer,
      theme.colorScheme.onSurfaceVariant,
    ),
  };
}
