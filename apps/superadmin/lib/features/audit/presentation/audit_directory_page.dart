import 'dart:async';

import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/audit.dart';
import 'audit_controller.dart';
import 'audit_detail_panel.dart';
import 'widgets/audit_directory_filters.dart';
import 'widgets/audit_event_views.dart';
import 'widgets/audit_timeline.dart';

/// Diretório de Auditoria sobre o composto `CoeloAdminDirectory` (decisão do
/// Owner de 10/09/2026): busca e filtros alinhados na toolbar, toggle
/// Cards/Tabela, Arquivos honesto e rodapé de paginação do composto. A
/// paginação do backend é por cursor: só o passo anterior/próximo existe, e
/// um salto de página anda um passo por vez.
final class AuditDirectoryPage extends StatefulWidget {
  const AuditDirectoryPage({
    required this.controller,
    required this.activityController,
    required this.logout,
    required this.openDownloadUrl,
    this.onDestinationSelected,
    this.clock = DateTime.now,
    super.key,
  });

  final AuditDirectoryController controller;
  final SuperadminActivityController activityController;
  final LogoutAction logout;
  final Future<bool> Function(String url) openDownloadUrl;
  final ValueChanged<String>? onDestinationSelected;
  final DateTime Function() clock;

  @override
  State<AuditDirectoryPage> createState() => _AuditDirectoryPageState();
}

final class _AuditDirectoryPageState extends State<AuditDirectoryPage> {
  final _searchController = TextEditingController();
  var _display = CoeloAdminDirectoryDisplay.table;
  String? _selectedEventId;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.controller.query.search;
    _loadInitial();
  }

  @override
  void didUpdateWidget(covariant AuditDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.dispose();
    _searchController.text = widget.controller.query.search;
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  int get _pageSize => _display == CoeloAdminDirectoryDisplay.cards ? 11 : 8;

  Future<void> _setDisplay(CoeloAdminDirectoryDisplay value) async {
    if (_display == value) return;
    setState(() => _display = value);
    await widget.controller.updateFilters(_withPageSize(widget.controller.query, _pageSize));
  }

  void _loadInitial() {
    final query = widget.controller.query;
    if (query.pageSize == _pageSize) {
      widget.controller.load();
      return;
    }
    widget.controller.updateFilters(_withPageSize(query, _pageSize));
  }

  Future<void> _goToPage(int target) async {
    final controller = widget.controller;
    // ponytail: cursor só anda um passo; salto de N páginas anda N vezes.
    while (controller.snapshot.pageNumber < target && controller.snapshot.hasNext) {
      await controller.next();
    }
    while (controller.snapshot.pageNumber > target && controller.snapshot.hasPrevious) {
      await controller.previous();
    }
  }

  void _clearFilters() {
    _searchController.clear();
    unawaited(widget.controller.updateFilters(AuditQuery(pageSize: _pageSize)));
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Auditoria',
    subtitle: 'Consulte a trilha protegida de eventos administrativos.',
    currentDestination: 'audit',
    showChatLauncher: false,
    activityController: widget.activityController,
    onDestinationSelected: widget.onDestinationSelected,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => CoeloAdminWorkspaceLayout(
          toolbar: const SizedBox.shrink(),
          body: _directory(context),
          detailVisible: widget.controller.detail.state != AuditDetailLoadState.idle,
          detail: widget.controller.detail.state == AuditDetailLoadState.idle
              ? null
              : Padding(
                  padding: EdgeInsets.all(
                    CoeloAdminDirectoryMetrics.horizontalPadding(constraints.maxWidth),
                  ),
                  child: AuditDetailPanel(
                    snapshot: widget.controller.detail,
                    onClose: () {
                      setState(() => _selectedEventId = null);
                      widget.controller.closeDetail();
                    },
                    onRetry: () {
                      final eventId = _selectedEventId;
                      if (eventId != null) widget.controller.loadDetail(eventId);
                    },
                  ),
                ),
        ),
      ),
    ),
  );

  Widget _directory(BuildContext context) {
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    final status = switch (snapshot.state) {
      AuditLoadState.loading => CoeloAdminDirectoryStatus.loading,
      AuditLoadState.content => CoeloAdminDirectoryStatus.success,
      AuditLoadState.empty => CoeloAdminDirectoryStatus.empty,
      AuditLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
      AuditLoadState.failure || AuditLoadState.notFound => CoeloAdminDirectoryStatus.failure,
      AuditLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
    };
    final selectedEventId = controller.detail.state == AuditDetailLoadState.idle
        ? null
        : _selectedEventId;
    void select(AuditEvent event) {
      setState(() => _selectedEventId = event.id);
      controller.loadDetail(event.id);
    }

    return CoeloAdminDirectory<CoeloAdminDirectoryDisplay>(
      key: const Key('audit-directory'),
      scrollKey: const Key('audit-directory-scroll'),
      toolbarKey: const Key('audit-toolbar'),
      filterControlsKey: const Key('audit-filter-controls'),
      cardsKey: const Key('audit-view-cards'),
      tableKey: const Key('audit-view-table'),
      gridKey: const Key('audit-card-list'),
      loadingKey: const Key('audit-state-loading'),
      status: status,
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Ainda não há eventos de auditoria disponíveis.',
        emptyIcon: Icons.history_rounded,
        noResults: 'Nenhum evento corresponde aos filtros aplicados.',
        noResultsIcon: Icons.search_off_rounded,
        failure: 'Não foi possível carregar a auditoria.',
        failureIcon: Icons.error_outline_rounded,
        unauthorized: 'Você não tem permissão para consultar a auditoria.',
        unauthorizedIcon: Icons.lock_outline_rounded,
      ),
      errorMessage: switch (snapshot.state) {
        AuditLoadState.notFound => 'O recurso solicitado não foi encontrado.',
        AuditLoadState.failure => 'Tente novamente sem perder a consulta atual.',
        _ => null,
      },
      onRetry: controller.retry,
      onClearFilters: _clearFilters,
      search: CoeloSearchField(
        key: const Key('audit-search'),
        controller: _searchController,
        hintText: 'Buscar na auditoria',
        semanticLabel: 'Buscar na auditoria',
        onChanged: controller.updateSearch,
      ),
      filters: [
        AuditOutcomeFilter(key: const Key('audit-outcome-filter'), controller: controller),
        AuditPeriodFilter(
          key: const Key('audit-period-filter'),
          controller: controller,
          clock: widget.clock,
        ),
      ],
      display: _display,
      onDisplayChanged: (value) => unawaited(_setDisplay(value)),
      groupedTableView: CoeloAdminDirectoryDisplay.table,
      selectedTableView: CoeloAdminDirectoryDisplay.table,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(
          value: CoeloAdminDirectoryDisplay.table,
          label: 'Tabela',
        ),
      ],
      onTableViewSelected: (_) => unawaited(_setDisplay(CoeloAdminDirectoryDisplay.table)),
      // Exportação geral adiada (ADR 0034): botão visível e honesto.
      fileActions: [
        CoeloAdminFileAction(
          label: 'Exportar CSV',
          icon: Icons.table_view_outlined,
          onPressed: () => showSuperadminNotice(context, 'Disponível depois do MVP'),
        ),
        CoeloAdminFileAction(
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: () => showSuperadminNotice(context, 'Disponível depois do MVP'),
        ),
      ],
      cards: [
        for (final event in snapshot.events)
          AuditEventCard(event: event, onPressed: () => select(event)),
      ],
      table: AuditEventRows(
        events: snapshot.events,
        selectedEventId: selectedEventId,
        onSelected: select,
      ),
      pagination: snapshot.state == AuditLoadState.content
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('audit-pagination'),
              currentPage: snapshot.pageNumber.clamp(1, snapshot.totalPages),
              totalPages: snapshot.totalPages,
              onPageSelected: (page) => unawaited(_goToPage(page)),
            )
          : null,
    );
  }
}

AuditQuery _withPageSize(AuditQuery query, int pageSize) => AuditQuery(
  search: query.search,
  actorIds: query.actorIds,
  contextKinds: query.contextKinds,
  actionCodes: query.actionCodes,
  resourceTypes: query.resourceTypes,
  outcomes: query.outcomes,
  origins: query.origins,
  institutionId: query.institutionId,
  from: query.from,
  to: query.to,
  pageSize: pageSize,
);
