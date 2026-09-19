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

enum StaffLeaveTableView { grouped }

enum _PeriodSegment { all, current, upcoming, past }

/// Acessos › Afastamentos: períodos que impedem o acesso no vínculo profissional.
final class StaffLeaveDirectoryPage extends StatefulWidget {
  const StaffLeaveDirectoryPage({
    required this.repository,
    required this.logout,
    this.onCreate,
    this.onOpen,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.successMessage,
    super.key,
  });

  final StaffAccessRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<StaffLeave>? onOpen;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final String? successMessage;

  @override
  State<StaffLeaveDirectoryPage> createState() => _StaffLeaveDirectoryPageState();
}

final class _StaffLeaveDirectoryPageState extends State<StaffLeaveDirectoryPage> {
  late StaffLeaveDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.cards;
  bool _noticeShown = false;
  double _paginationFooterHeight = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = StaffLeaveDirectoryViewModel(widget.repository);
    _searchController = TextEditingController();
    _activityController = SuperadminActivityController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant StaffLeaveDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _viewModel.dispose();
      _viewModel = StaffLeaveDirectoryViewModel(
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
        title: 'Afastamentos',
        subtitle: 'Períodos em que o funcionário não acessa o app naquele vínculo.',
        currentDestination: 'staff-leaves',
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
    final onCreate = widget.onCreate;
    final totalPages = page.totalCount == 0 ? 1 : (page.totalCount / viewModel.query.pageSize).ceil();
    final institutions = viewModel.filterOptions.institutions;
    final units = viewModel.filterOptions.units
        .where((u) => viewModel.query.institutionId == null || u.institutionId == viewModel.query.institutionId)
        .toList(growable: false);
    return CoeloAdminDirectory<StaffLeaveTableView>(
      scrollKey: const Key('staff-leave-directory-scroll'),
      toolbarKey: const Key('staff-leave-filter-toolbar'),
      filterControlsKey: const Key('staff-leave-filter-controls'),
      toggleKey: const Key('staff-leave-display-toggle'),
      cardsKey: const Key('staff-leave-view-cards'),
      tableKey: const Key('staff-leave-view-table'),
      gridKey: const Key('staff-leave-card-grid'),
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
        empty: 'Nenhum afastamento registrado.',
        emptyIcon: Icons.beach_access_outlined,
        noResults: 'Nenhum afastamento encontrado com estes filtros.',
        failure: 'Não foi possível carregar os afastamentos. Tente novamente.',
        unauthorized: 'Você não tem permissão para gerir afastamentos.',
      ),
      errorMessage: switch (viewModel.state) {
        StaffAccessLoadState.empty => 'Registre o primeiro afastamento para começar.',
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
        key: const Key('staff-leave-search'),
        controller: _searchController,
        hintText: 'Buscar por nome',
        semanticLabel: 'Buscar afastamento por nome do funcionário',
        onChanged: viewModel.setSearch,
      ),
      filters: [
        CoeloAdminSingleSelectField<String>(
          key: const Key('staff-leave-institution-filter'),
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
            key: const Key('staff-leave-unit-filter'),
            isFilter: true,
            unselectedValue: '',
            label: 'Unidade',
            value: viewModel.query.unitId ?? '',
            options: ['', for (final option in units) option.id],
            optionLabel: (id) =>
                id.isEmpty ? 'Todas' : units.where((o) => o.id == id).firstOrNull?.label ?? id,
            onChanged: (value) => viewModel.setUnit(value.isEmpty ? null : value),
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
      groupedTableView: StaffLeaveTableView.grouped,
      selectedTableView: StaffLeaveTableView.grouped,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(value: StaffLeaveTableView.grouped, label: 'Agrupado'),
      ],
      onTableViewSelected: (_) => _changeDisplay(CoeloAdminDirectoryDisplay.table),
      fileActions: null,
      tabs: CoeloAdminUnderlineTabs<_PeriodSegment>(
        key: const Key('staff-leave-period-tabs'),
        tabs: const [
          CoeloAdminUnderlineTab(value: _PeriodSegment.all, label: 'Todos'),
          CoeloAdminUnderlineTab(value: _PeriodSegment.current, label: 'Em curso'),
          CoeloAdminUnderlineTab(value: _PeriodSegment.upcoming, label: 'Futuros'),
          CoeloAdminUnderlineTab(value: _PeriodSegment.past, label: 'Encerrados'),
        ],
        selected: switch (viewModel.query.period) {
          null => _PeriodSegment.all,
          StaffLeavePeriod.current => _PeriodSegment.current,
          StaffLeavePeriod.upcoming => _PeriodSegment.upcoming,
          StaffLeavePeriod.past => _PeriodSegment.past,
        },
        onSelected: (segment) => viewModel.setPeriod(switch (segment) {
          _PeriodSegment.all => null,
          _PeriodSegment.current => StaffLeavePeriod.current,
          _PeriodSegment.upcoming => StaffLeavePeriod.upcoming,
          _PeriodSegment.past => StaffLeavePeriod.past,
        }),
      ),
      create: onCreate == null
          ? null
          : CoeloAdminDirectoryCreate(
              label: 'Registrar afastamento',
              description: 'Escolha o vínculo e o período.',
              icon: Icons.event_busy_outlined,
              onPressed: onCreate,
              tileKey: const Key('create-staff-leave-card'),
              bannerKey: const Key('create-staff-leave-banner'),
            ),
      cards: [
        for (final item in page.items)
          StaffLeaveCard(item: item, onPressed: onOpen == null ? null : () => onOpen(item)),
      ],
      table: StaffLeaveTableRows(items: page.items, onEdit: onOpen),
      pagination: viewModel.state == StaffAccessLoadState.success
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('staff-leave-directory-pagination-footer'),
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
