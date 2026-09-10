import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_notice.dart';
import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../../support/domain/support_ticket.dart';
import '../../domain/institution_directory_item.dart';
import '../../domain/institution_directory_repository.dart';
import '../institution_directory_table_view.dart';
import '../view_models/institution_directory_view_model.dart';
import '../widgets/institution_card.dart';
import '../widgets/institution_file_actions.dart';
import '../widgets/institution_filter_menu.dart';
import '../widgets/institution_table_rows.dart';

/// Diretório de Instituições: instância do `CoeloAdminDirectory` com o
/// conteúdo de domínio (busca, filtros, cards, tabela, abas de status).
class InstitutionDirectoryPage extends StatefulWidget {
  const InstitutionDirectoryPage({
    required this.repository,
    required this.logout,
    this.onHomeOpen,
    this.onUnitsOpen,
    this.onPeopleOpen,
    this.onCatalogOpen,
    this.onSupportOpen,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.onCreate,
    this.onEdit,
    this.successMessage,
    super.key,
  });

  final InstitutionDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onHomeOpen;
  final VoidCallback? onUnitsOpen;
  final VoidCallback? onPeopleOpen;
  final VoidCallback? onCatalogOpen;
  final VoidCallback? onSupportOpen;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final String? successMessage;

  @override
  State<InstitutionDirectoryPage> createState() => _InstitutionDirectoryPageState();
}

class _InstitutionDirectoryPageState extends State<InstitutionDirectoryPage> {
  late final InstitutionDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.cards;
  InstitutionDirectoryTableView _tableView = InstitutionDirectoryTableView.grouped;
  bool _noticeShown = false;
  double _footerHeight = 0;
  bool _paginationExpected = false;

  void _changeDisplay(CoeloAdminDirectoryDisplay display) {
    if (display == _display) return;
    setState(() => _display = display);
    _viewModel.setPageSize(
      display == CoeloAdminDirectoryDisplay.cards ? 11 : 8,
      resetSort: display == CoeloAdminDirectoryDisplay.cards,
    );
  }

  void _changeTableView(InstitutionDirectoryTableView view) {
    final wasCards = _display == CoeloAdminDirectoryDisplay.cards;
    setState(() {
      _display = CoeloAdminDirectoryDisplay.table;
      _tableView = view;
    });
    if (wasCards) _viewModel.setPageSize(8);
  }

  void _handleDirectoryChanged() {
    final expected =
        _viewModel.state == InstitutionDirectoryLoadState.success && _viewModel.page.totalCount > 0;
    if (expected == _paginationExpected || !mounted) return;
    setState(() => _paginationExpected = expected);
  }

  void _handleFooterHeightChanged(double height) {
    if ((_footerHeight - height).abs() < 0.5) return;
    setState(() => _footerHeight = height);
  }

  @override
  void initState() {
    super.initState();
    _viewModel = InstitutionDirectoryViewModel(repository: widget.repository);
    _activityController = SuperadminActivityController();
    _searchController = TextEditingController();
    _viewModel.addListener(_handleDirectoryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant InstitutionDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.successMessage != widget.successMessage) _noticeShown = false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.removeListener(_handleDirectoryChanged);
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      activityController: _activityController,
      showChatLauncher:
          widget.onConversationsOpen != null && (!_paginationExpected || _footerHeight > 0),
      chatLauncherBottomInset: _footerHeight,
      onBugReportSubmitted: widget.onBugReportSubmitted,
      onOpenConversations: widget.onConversationsOpen,
      onDestinationSelected: (destination) {
        if (destination == 'home') {
          widget.onHomeOpen?.call();
        } else if (destination == 'units') {
          widget.onUnitsOpen?.call();
        } else if (destination == 'people') {
          widget.onPeopleOpen?.call();
        } else if (destination == 'catalog') {
          widget.onCatalogOpen?.call();
        } else if (destination == 'support') {
          widget.onSupportOpen?.call();
        }
      },
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
          return AnimatedBuilder(
            animation: _viewModel,
            builder: (context, _) => _directory(context),
          );
        },
      ),
    );
  }

  Widget _directory(BuildContext context) {
    final viewModel = _viewModel;
    final page = viewModel.page;
    final onEdit = widget.onEdit;
    final onCreate = widget.onCreate;
    final showPagination =
        viewModel.state == InstitutionDirectoryLoadState.success && page.totalCount > 0;
    return CoeloAdminDirectory<InstitutionDirectoryTableView>(
      scrollKey: const Key('institution-directory-content-scroll'),
      toolbarKey: const Key('institution-filter-toolbar'),
      filterControlsKey: const Key('institution-filter-controls'),
      actionsKey: const Key('institution-toolbar-actions'),
      toggleKey: const Key('institution-display-toggle'),
      cardsKey: const Key('institution-view-cards'),
      tableKey: const Key('institution-view-table'),
      gridKey: const Key('institution-card-grid'),
      status: _status(viewModel.state),
      refreshing: viewModel.isLoading,
      errorMessage: viewModel.errorMessage,
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Ainda não há instituições cadastradas.',
        emptyIcon: Icons.apartment_outlined,
        noResults: 'Nenhuma instituição encontrada com estes filtros.',
        failure: InstitutionDirectoryViewModel.genericErrorMessage,
        unauthorized: InstitutionDirectoryViewModel.unauthorizedMessage,
      ),
      onRetry: viewModel.retry,
      search: CoeloSearchField(
        key: const Key('institution-directory-search'),
        controller: _searchController,
        hintText: 'Buscar por nome',
        semanticLabel: 'Buscar por nome',
        onChanged: viewModel.setSearch,
      ),
      filters: institutionFilterControls(viewModel),
      trailing: [
        if (viewModel.query.hasActiveFilters)
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              viewModel.clearFilters();
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpar filtros'),
          ),
      ],
      display: _display,
      onDisplayChanged: _changeDisplay,
      groupedTableView: InstitutionDirectoryTableView.grouped,
      selectedTableView: _tableView,
      tableViews: [
        for (final view in InstitutionDirectoryTableView.values)
          CoeloAdminDirectoryTableViewOption(value: view, label: view.label),
      ],
      onTableViewSelected: _changeTableView,
      fileActions: institutionFileActions(context),
      tabs: _InstitutionStatusTabs(viewModel: viewModel),
      create: onCreate == null
          ? null
          : CoeloAdminDirectoryCreate(
              label: 'Criar instituição',
              description: 'Adicionar nova instituição ao sistema.',
              icon: Icons.add_business_outlined,
              onPressed: onCreate,
              tileKey: const Key('create-institution-card'),
              tileSurfaceKey: const Key('create-institution-surface'),
              bannerKey: const Key('create-institution-banner'),
              bannerSurfaceKey: const Key('create-institution-banner-surface'),
            ),
      cards: [
        for (final item in page.items)
          InstitutionCard(item: item, onPressed: onEdit == null ? null : () => onEdit(item.id)),
      ],
      table: InstitutionTableRows(
        items: page.items,
        view: _tableView,
        onEdit: onEdit == null ? null : (item) => onEdit(item.id),
        sortColumn: viewModel.query.sortColumn,
        sortAscending: viewModel.query.sortAscending,
        onSort: viewModel.setSort,
      ),
      pagination: showPagination
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('institution-directory-pagination-footer'),
              surfaceKey: const Key('institution-directory-pagination-footer-surface'),
              currentPage: page.page + 1,
              totalPages: (page.totalCount / viewModel.query.pageSize).ceil(),
              pageSize: viewModel.query.pageSize,
              pageSizeOptions: _display == CoeloAdminDirectoryDisplay.cards
                  ? const [11, 20, 50, 100]
                  : const [8, 20, 50, 100],
              onPageSelected: (value) => viewModel.goToPage(value - 1),
              onPageSizeChanged: viewModel.setPageSize,
            )
          : null,
      onFooterHeightChanged: _handleFooterHeightChanged,
    );
  }

  static CoeloAdminDirectoryStatus _status(InstitutionDirectoryLoadState state) => switch (state) {
    InstitutionDirectoryLoadState.initial ||
    InstitutionDirectoryLoadState.loading => CoeloAdminDirectoryStatus.loading,
    InstitutionDirectoryLoadState.failure => CoeloAdminDirectoryStatus.failure,
    InstitutionDirectoryLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
    InstitutionDirectoryLoadState.empty => CoeloAdminDirectoryStatus.empty,
    InstitutionDirectoryLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
    InstitutionDirectoryLoadState.success => CoeloAdminDirectoryStatus.success,
  };
}

/// Instituições é a exceção aprovada de abas de status: `Em Implantação`.
class _InstitutionStatusTabs extends StatelessWidget {
  const _InstitutionStatusTabs({required this.viewModel});

  final InstitutionDirectoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selected = viewModel.query.statuses.length == 1 ? viewModel.query.statuses.single : null;
    return CoeloAdminUnderlineTabs<InstitutionStatus?>(
      key: const Key('institution-status-tabs'),
      selected: selected,
      tabs: const [
        CoeloAdminUnderlineTab(value: null, label: 'Todos'),
        CoeloAdminUnderlineTab(value: InstitutionStatus.active, label: 'Ativos'),
        CoeloAdminUnderlineTab(value: InstitutionStatus.onboarding, label: 'Em Implantação'),
        CoeloAdminUnderlineTab(value: InstitutionStatus.inactive, label: 'Inativos'),
      ],
      onSelected: (status) => viewModel.setStatuses(status == null ? const {} : {status}),
    );
  }
}
