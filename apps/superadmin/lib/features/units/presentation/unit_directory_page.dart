import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/unit_backend_commands.dart';
import '../domain/unit_directory.dart';
import 'unit_directory_table_view.dart';
import 'unit_directory_view_model.dart';
import 'widgets/unit_card.dart';
import 'widgets/unit_filter_controls.dart';
import 'widgets/unit_table_rows.dart';

enum _UnitStatusSegment { all, active, onboarding, inactive }

final class UnitDirectoryPage extends StatefulWidget {
  const UnitDirectoryPage({
    required this.repository,
    required this.logout,
    this.backendCommands,
    this.requestIdFactory,
    this.onCreate,
    this.onEdit,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.successMessage,
    super.key,
  });

  final UnitDirectoryRepository repository;
  final UnitBackendCommandsGateway? backendCommands;
  final String Function()? requestIdFactory;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final String? successMessage;

  @override
  State<UnitDirectoryPage> createState() => _UnitDirectoryPageState();
}

final class _UnitDirectoryPageState extends State<UnitDirectoryPage> {
  late UnitDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.cards;
  UnitDirectoryTableView _tableView = UnitDirectoryTableView.grouped;
  bool _noticeShown = false;
  double _paginationFooterHeight = 0;

  void _changeDisplay(CoeloAdminDirectoryDisplay display) {
    if (display == _display) {
      return;
    }
    setState(() => _display = display);
    _viewModel.setPageSize(
      display == CoeloAdminDirectoryDisplay.cards ? 11 : 8,
      resetSort: display == CoeloAdminDirectoryDisplay.cards,
    );
  }

  void _changeTableView(UnitDirectoryTableView view) {
    final wasCards = _display == CoeloAdminDirectoryDisplay.cards;
    setState(() {
      _display = CoeloAdminDirectoryDisplay.table;
      _tableView = view;
    });
    if (wasCards) {
      _viewModel.setPageSize(8, resetSort: false);
    }
  }

  void _handlePaginationFooterHeightChanged(double height) {
    if ((_paginationFooterHeight - height).abs() < .5) {
      return;
    }
    setState(() => _paginationFooterHeight = height);
  }

  @override
  void initState() {
    super.initState();
    _viewModel = UnitDirectoryViewModel(widget.repository);
    _searchController = TextEditingController();
    _activityController = SuperadminActivityController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant UnitDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _viewModel.dispose();
      _viewModel = UnitDirectoryViewModel(
        widget.repository,
        initialPageSize: _display == CoeloAdminDirectoryDisplay.cards ? 11 : 8,
      );
      _searchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _viewModel.load();
      });
    }
    if (oldWidget.successMessage != widget.successMessage) {
      _noticeShown = false;
    }
  }

  @override
  void dispose() {
    _activityController.dispose();
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(scaffoldBackgroundColor: theme.colorScheme.surface),
      child: SuperadminShell(
        logout: widget.logout,
        title: 'Unidades',
        subtitle: 'Gerencie as unidades da plataforma.',
        currentDestination: 'units',
        activityController: _activityController,
        showChatLauncher: widget.onConversationsOpen != null,
        chatLauncherBottomInset: _paginationFooterHeight,
        onBugReportSubmitted: widget.onBugReportSubmitted,
        onOpenConversations: widget.onConversationsOpen,
        onDestinationSelected: widget.onDestinationSelected,
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
            return _UnitDirectoryContent(
              viewModel: _viewModel,
              searchController: _searchController,
              display: _display,
              tableView: _tableView,
              onDisplayChanged: _changeDisplay,
              onTableViewChanged: _changeTableView,
              onCreate: widget.onCreate,
              onEdit: widget.onEdit,
              onFooterHeightChanged: _handlePaginationFooterHeightChanged,
              onClearFilters: () {
                _searchController.clear();
                _viewModel.clearFilters();
              },
            );
          },
        ),
      ),
    );
  }
}

/// Diretório de Unidades: instância do `CoeloAdminDirectory` com o conteúdo
/// de domínio (busca, filtros dependentes, abas de status, cards e tabela).
final class _UnitDirectoryContent extends StatelessWidget {
  const _UnitDirectoryContent({
    required this.viewModel,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onFooterHeightChanged,
    required this.onClearFilters,
  });

  final UnitDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final CoeloAdminDirectoryDisplay display;
  final UnitDirectoryTableView tableView;
  final ValueChanged<CoeloAdminDirectoryDisplay> onDisplayChanged;
  final ValueChanged<UnitDirectoryTableView> onTableViewChanged;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<double> onFooterHeightChanged;
  final VoidCallback onClearFilters;

  void _showDeferredFileNotice(BuildContext context) {
    showSuperadminNotice(context, 'Disponível depois do MVP', icon: Icons.info_outline_rounded);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: viewModel,
    builder: (context, _) {
      final page = viewModel.page;
      final onCreate = this.onCreate;
      final onEdit = this.onEdit;
      final totalPages = page.totalCount == 0
          ? 1
          : (page.totalCount / viewModel.query.pageSize).ceil();
      return CoeloAdminDirectory<UnitDirectoryTableView>(
        scrollKey: const Key('unit-directory-scroll'),
        toolbarKey: const Key('unit-filter-toolbar'),
        filterControlsKey: const Key('unit-filter-controls'),
        actionsKey: const Key('unit-toolbar-actions'),
        toggleKey: const Key('unit-display-toggle'),
        cardsKey: const Key('unit-view-cards'),
        tableKey: const Key('unit-view-table'),
        gridKey: const Key('unit-card-grid'),
        status: switch (viewModel.state) {
          UnitDirectoryLoadState.initial ||
          UnitDirectoryLoadState.loading => CoeloAdminDirectoryStatus.loading,
          UnitDirectoryLoadState.failure => CoeloAdminDirectoryStatus.failure,
          UnitDirectoryLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
          UnitDirectoryLoadState.empty => CoeloAdminDirectoryStatus.empty,
          UnitDirectoryLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
          UnitDirectoryLoadState.success => CoeloAdminDirectoryStatus.success,
        },
        refreshing: viewModel.isLoading,
        messages: const CoeloAdminDirectoryMessages(
          empty: 'Ainda não há unidades cadastradas.',
          emptyIcon: Icons.apartment_outlined,
          noResults: 'Nenhuma unidade encontrada com estes filtros.',
          failure: 'Não foi possível carregar as unidades. Tente novamente.',
          unauthorized: 'Você não tem permissão para ver as unidades.',
        ),
        onRetry: viewModel.retry,
        search: CoeloSearchField(
          controller: searchController,
          hintText: 'Buscar por nome',
          semanticLabel: 'Buscar unidade por nome',
          onChanged: viewModel.setSearch,
        ),
        filters: unitFilterControls(viewModel),
        trailing: [
          if (viewModel.query.hasActiveFilters)
            TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
        ],
        display: display,
        onDisplayChanged: onDisplayChanged,
        groupedTableView: UnitDirectoryTableView.grouped,
        selectedTableView: tableView,
        tableViews: const [
          CoeloAdminDirectoryTableViewOption(
            value: UnitDirectoryTableView.grouped,
            label: 'Agrupado',
          ),
          CoeloAdminDirectoryTableViewOption(
            value: UnitDirectoryTableView.groups,
            label: 'Por turmas',
          ),
          CoeloAdminDirectoryTableViewOption(
            value: UnitDirectoryTableView.activities,
            label: 'Por atividades',
          ),
        ],
        onTableViewSelected: onTableViewChanged,
        fileActions: [
          CoeloAdminFileAction(
            key: const Key('unit-files-import'),
            label: 'Importar',
            icon: Icons.upload_file_outlined,
            onPressed: () => _showDeferredFileNotice(context),
          ),
          CoeloAdminFileAction(
            key: const Key('unit-files-export-csv'),
            label: 'Exportar CSV',
            icon: Icons.table_rows_outlined,
            onPressed: () => _showDeferredFileNotice(context),
          ),
          CoeloAdminFileAction(
            key: const Key('unit-files-export-xlsx'),
            label: 'Exportar XLSX',
            icon: Icons.grid_on_outlined,
            onPressed: () => _showDeferredFileNotice(context),
          ),
        ],
        tabs: CoeloAdminUnderlineTabs<_UnitStatusSegment>(
          key: const Key('unit-status-tabs'),
          tabs: const [
            CoeloAdminUnderlineTab(value: _UnitStatusSegment.all, label: 'Todos'),
            CoeloAdminUnderlineTab(value: _UnitStatusSegment.active, label: 'Ativos'),
            CoeloAdminUnderlineTab(value: _UnitStatusSegment.onboarding, label: 'Em Implantação'),
            CoeloAdminUnderlineTab(value: _UnitStatusSegment.inactive, label: 'Inativos'),
          ],
          selected: _segmentFor(viewModel.query.statuses),
          onSelected: (segment) => viewModel.setStatuses(_statusesFor(segment)),
        ),
        create: onCreate == null
            ? null
            : CoeloAdminDirectoryCreate(
                label: 'Criar unidade',
                description: 'Adicionar nova unidade ao sistema.',
                icon: Icons.apartment_outlined,
                onPressed: onCreate,
                tileKey: const Key('create-unit-card'),
                bannerKey: const Key('create-unit-banner'),
                bannerSurfaceKey: const Key('create-unit-banner-surface'),
              ),
        cards: [
          for (final item in page.items)
            UnitCard(item: item, onPressed: onEdit == null ? null : () => onEdit(item.id)),
        ],
        table: UnitTableRows(
          items: page.items,
          onEdit: onEdit == null ? null : (item) => onEdit(item.id),
          sortColumn: viewModel.query.sortColumn,
          sortAscending: viewModel.query.sortAscending,
          onSort: viewModel.setSort,
          view: tableView,
        ),
        pagination: viewModel.state == UnitDirectoryLoadState.success
            ? CoeloAdminDirectoryPagination(
                footerKey: const Key('unit-directory-pagination-footer'),
                currentPage: page.page + 1,
                totalPages: totalPages,
                pageSize: viewModel.query.pageSize,
                pageSizeOptions: display == CoeloAdminDirectoryDisplay.cards
                    ? const [11, 20, 50, 100]
                    : const [8, 20, 50, 100],
                onPageSelected: (value) => viewModel.goToPage(value - 1),
                onPageSizeChanged: viewModel.setPageSize,
              )
            : null,
        onFooterHeightChanged: onFooterHeightChanged,
      );
    },
  );
}

_UnitStatusSegment _segmentFor(Set<UnitStatus> statuses) {
  if (statuses.length == 1 && statuses.contains(UnitStatus.active)) {
    return _UnitStatusSegment.active;
  }
  if (statuses.length == 1 && statuses.contains(UnitStatus.draft)) {
    return _UnitStatusSegment.onboarding;
  }
  if (statuses.length == 3 &&
      statuses.containsAll(const {
        UnitStatus.inactive,
        UnitStatus.suspended,
        UnitStatus.archived,
      })) {
    return _UnitStatusSegment.inactive;
  }
  return _UnitStatusSegment.all;
}

Set<UnitStatus> _statusesFor(_UnitStatusSegment segment) => switch (segment) {
  _UnitStatusSegment.all => const {},
  _UnitStatusSegment.active => const {UnitStatus.active},
  _UnitStatusSegment.onboarding => const {UnitStatus.draft},
  _UnitStatusSegment.inactive => const {
    UnitStatus.inactive,
    UnitStatus.suspended,
    UnitStatus.archived,
  },
};
