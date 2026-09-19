import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/staff_access.dart';
import 'staff_access_directory_view_model.dart';
import 'staff_access_presentation.dart';

/// Acessos › Acesso de funcionários: uma linha por vínculo profissional, com o
/// estado calculado no servidor (livre, com horário, com vigência, afastado,
/// bloqueado agora). Abrir um vínculo edita a regra dele.
final class StaffAccessDirectoryPage extends StatefulWidget {
  const StaffAccessDirectoryPage({
    required this.repository,
    required this.logout,
    this.onOpen,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.successMessage,
    super.key,
  });

  final StaffAccessRepository repository;
  final LogoutAction logout;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final String? successMessage;

  @override
  State<StaffAccessDirectoryPage> createState() => _StaffAccessDirectoryPageState();
}

final class _StaffAccessDirectoryPageState extends State<StaffAccessDirectoryPage> {
  late StaffAccessDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.cards;
  bool _noticeShown = false;
  double _paginationFooterHeight = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = StaffAccessDirectoryViewModel(widget.repository);
    _searchController = TextEditingController();
    _activityController = SuperadminActivityController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant StaffAccessDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _viewModel.dispose();
      _viewModel = StaffAccessDirectoryViewModel(
        widget.repository,
        initialPageSize: _display == CoeloAdminDirectoryDisplay.cards ? 11 : 8,
      );
      _searchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _viewModel.load();
      });
    }
    if (oldWidget.successMessage != widget.successMessage) _noticeShown = false;
  }

  @override
  void dispose() {
    _activityController.dispose();
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _changeDisplay(CoeloAdminDirectoryDisplay display) {
    if (display == _display) return;
    setState(() => _display = display);
    _viewModel.setPageSize(display == CoeloAdminDirectoryDisplay.cards ? 11 : 8);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(scaffoldBackgroundColor: theme.colorScheme.surface),
      child: SuperadminShell(
        logout: widget.logout,
        title: 'Acesso de funcionários',
        subtitle: 'Horário, vigência, superfícies e popups por vínculo profissional.',
        currentDestination: 'staff-access',
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
            return AnimatedBuilder(
              animation: _viewModel,
              builder: (context, _) => _content(context),
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final viewModel = _viewModel;
    final page = viewModel.page;
    final onOpen = widget.onOpen;
    final totalPages = page.totalCount == 0 ? 1 : (page.totalCount / viewModel.query.pageSize).ceil();
    final institutions = viewModel.filterOptions.institutions;
    final units = viewModel.filterOptions.units
        .where((u) => viewModel.query.institutionId == null || u.institutionId == viewModel.query.institutionId)
        .toList(growable: false);
    return CoeloAdminDirectory<StaffAccessTableView>(
      scrollKey: const Key('staff-access-directory-scroll'),
      toolbarKey: const Key('staff-access-filter-toolbar'),
      filterControlsKey: const Key('staff-access-filter-controls'),
      toggleKey: const Key('staff-access-display-toggle'),
      cardsKey: const Key('staff-access-view-cards'),
      tableKey: const Key('staff-access-view-table'),
      gridKey: const Key('staff-access-card-grid'),
      status: switch (viewModel.state) {
        StaffAccessLoadState.initial ||
        StaffAccessLoadState.loading => CoeloAdminDirectoryStatus.loading,
        StaffAccessLoadState.failure => CoeloAdminDirectoryStatus.failure,
        StaffAccessLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
        StaffAccessLoadState.empty => CoeloAdminDirectoryStatus.empty,
        StaffAccessLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
        StaffAccessLoadState.success => CoeloAdminDirectoryStatus.success,
      },
      refreshing: viewModel.isLoading,
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Nenhum vínculo de funcionário sob a sua gestão.',
        emptyIcon: Icons.badge_outlined,
        noResults: 'Nenhum funcionário encontrado com estes filtros.',
        failure: 'Não foi possível carregar os acessos. Tente novamente.',
        unauthorized: 'Você não tem permissão para gerir o acesso de funcionários.',
      ),
      errorMessage: switch (viewModel.state) {
        StaffAccessLoadState.empty =>
          'Os vínculos aparecem aqui quando houver equipe cadastrada nas suas instituições.',
        StaffAccessLoadState.noResults => 'Revise a busca ou os filtros aplicados.',
        StaffAccessLoadState.unauthorized => 'É preciso a capacidade staff_access.manage no vínculo.',
        _ => null,
      },
      onRetry: viewModel.retry,
      onClearFilters: () {
        _searchController.clear();
        viewModel.clearFilters();
      },
      search: CoeloSearchField(
        key: const Key('staff-access-search'),
        controller: _searchController,
        hintText: 'Buscar por nome',
        semanticLabel: 'Buscar funcionário por nome',
        onChanged: viewModel.setSearch,
      ),
      filters: [
        CoeloAdminSingleSelectField<String>(
          key: const Key('staff-access-institution-filter'),
          isFilter: true,
          unselectedValue: '',
          label: 'Instituição',
          value: viewModel.query.institutionId ?? '',
          options: ['', for (final option in institutions) option.id],
          optionLabel: (id) => id.isEmpty
              ? 'Todas'
              : institutions.where((o) => o.id == id).firstOrNull?.label ?? id,
          onChanged: (value) => viewModel.setInstitution(value.isEmpty ? null : value),
        ),
        if (viewModel.query.institutionId != null)
          CoeloAdminSingleSelectField<String>(
            key: const Key('staff-access-unit-filter'),
            isFilter: true,
            unselectedValue: '',
            label: 'Unidade',
            value: viewModel.query.unitId ?? '',
            options: ['', for (final option in units) option.id],
            optionLabel: (id) =>
                id.isEmpty ? 'Todas' : units.where((o) => o.id == id).firstOrNull?.label ?? id,
            onChanged: (value) => viewModel.setUnit(value.isEmpty ? null : value),
          ),
        CoeloAdminMultiSelectFilter<StaffAccessState>(
          key: const Key('staff-access-state-filter'),
          label: 'Estado',
          options: StaffAccessState.values,
          selectedValues: viewModel.query.states,
          optionLabel: (state) => state.label,
          onChanged: viewModel.setStates,
        ),
      ],
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
      groupedTableView: StaffAccessTableView.grouped,
      selectedTableView: StaffAccessTableView.grouped,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(value: StaffAccessTableView.grouped, label: 'Agrupado'),
      ],
      onTableViewSelected: (_) => _changeDisplay(CoeloAdminDirectoryDisplay.table),
      fileActions: null,
      cards: [
        for (final item in page.items)
          StaffAccessCard(
            item: item,
            onPressed: onOpen == null ? null : () => onOpen(item.membershipId),
          ),
      ],
      table: StaffAccessTableRows(
        items: page.items,
        onEdit: onOpen == null ? null : (item) => onOpen(item.membershipId),
      ),
      pagination: viewModel.state == StaffAccessLoadState.success
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('staff-access-directory-pagination-footer'),
              currentPage: page.page + 1,
              totalPages: totalPages,
              pageSize: viewModel.query.pageSize,
              pageSizeOptions: _display == CoeloAdminDirectoryDisplay.cards
                  ? const [11, 20, 50, 100]
                  : const [8, 20, 50, 100],
              onPageSelected: (value) => viewModel.goToPage(value - 1),
              onPageSizeChanged: viewModel.setPageSize,
            )
          : null,
      onFooterHeightChanged: (height) {
        if ((_paginationFooterHeight - height).abs() < .5) return;
        setState(() => _paginationFooterHeight = height);
      },
    );
  }
}
