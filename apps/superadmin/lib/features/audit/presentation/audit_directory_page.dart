import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/audit.dart';
import 'audit_controller.dart';
import 'audit_detail_panel.dart';
import 'widgets/audit_directory_filters.dart';
import 'widgets/audit_event_views.dart';
import 'widgets/audit_export_actions.dart';

enum AuditDirectoryDisplay { cards, table }

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
  var _display = AuditDirectoryDisplay.table;
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

  Future<void> _setDisplay(AuditDirectoryDisplay value) async {
    if (_display == value) return;
    setState(() => _display = value);
    final query = widget.controller.query;
    await widget.controller.updateFilters(
      AuditQuery(
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
        pageSize: value == AuditDirectoryDisplay.cards ? 11 : 8,
      ),
    );
  }

  void _loadInitial() {
    final query = widget.controller.query;
    if (query.pageSize == 8) {
      widget.controller.load();
      return;
    }
    widget.controller.updateFilters(
      AuditQuery(
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
        pageSize: 8,
      ),
    );
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
        builder: (context, constraints) {
          final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          return Padding(
            padding: EdgeInsets.all(padding),
            child: CoeloAdminWorkspaceLayout(
              toolbar: Padding(
                padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
                child: _toolbar(constraints.maxWidth),
              ),
              body: _body(padding),
              detailVisible: widget.controller.detail.state != AuditDetailLoadState.idle,
              detail: widget.controller.detail.state == AuditDetailLoadState.idle
                  ? null
                  : AuditDetailPanel(
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
          );
        },
      ),
    ),
  );

  Widget _toolbar(double width) {
    final controller = widget.controller;
    final compact = width < CoeloBreakpoints.medium.minWidth;
    return CoeloAdminListingToolbar(
      key: const Key('audit-toolbar'),
      search: AuditDirectoryFilters(
        controller: controller,
        searchController: _searchController,
        clock: widget.clock,
      ),
      filters: const [],
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SuperadminDirectoryViewToggle<AuditDirectoryDisplay>(
              cardsKey: const Key('audit-view-cards'),
              tableKey: const Key('audit-view-table'),
              cardsSelected: _display == AuditDirectoryDisplay.cards,
              groupedView: AuditDirectoryDisplay.table,
              selectedTableView: AuditDirectoryDisplay.table,
              tableViews: const [
                SuperadminDirectoryTableViewOption(
                  value: AuditDirectoryDisplay.table,
                  label: 'Tabela',
                ),
              ],
              onCardsSelected: () => _setDisplay(AuditDirectoryDisplay.cards),
              onTableViewSelected: _setDisplay,
            ),
            if (controller.canExport) ...[
              const SizedBox(width: CoeloSpacing.space2),
              AuditExportActions(
                controller: controller,
                compact: compact,
                openDownloadUrl: widget.openDownloadUrl,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _body(double horizontalPadding) {
    final snapshot = widget.controller.snapshot;
    final content = switch (snapshot.state) {
      AuditLoadState.loading => const _AuditState(
        state: 'loading',
        icon: Icons.hourglass_top_rounded,
        message: 'Carregando eventos...',
        loading: true,
      ),
      AuditLoadState.empty => const _AuditState(
        state: 'empty',
        icon: Icons.history_rounded,
        message: 'Ainda não há eventos de auditoria disponíveis.',
      ),
      AuditLoadState.noResults => const _AuditState(
        state: 'noResults',
        icon: Icons.search_off_rounded,
        message: 'Nenhum evento corresponde aos filtros aplicados.',
      ),
      AuditLoadState.failure => _AuditState(
        state: 'failure',
        icon: Icons.error_outline_rounded,
        message: 'Não foi possível carregar a auditoria.',
        actionLabel: 'Tentar novamente',
        onAction: widget.controller.retry,
      ),
      AuditLoadState.unauthorized => const _AuditState(
        state: 'unauthorized',
        icon: Icons.lock_outline_rounded,
        message: 'Você não tem permissão para consultar a auditoria.',
      ),
      AuditLoadState.notFound => const _AuditState(
        state: 'notFound',
        icon: Icons.manage_search_rounded,
        message: 'O recurso solicitado não foi encontrado.',
      ),
      AuditLoadState.content => AuditEventViews(
        events: snapshot.events,
        display: _display,
        selectedEventId: widget.controller.detail.state == AuditDetailLoadState.idle
            ? null
            : _selectedEventId,
        onSelected: (event) {
          setState(() => _selectedEventId = event.id);
          widget.controller.loadDetail(event.id);
        },
      ),
    };
    if (snapshot.state != AuditLoadState.content) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: SingleChildScrollView(child: content)),
        const SizedBox(height: CoeloSpacing.space3),
        SuperadminListingPaginationFooter(
          horizontalPadding: horizontalPadding,
          compactCurrentPage: snapshot.pageNumber,
          compactTotalPages: snapshot.totalPages,
          compactOnPrevious: snapshot.hasPrevious ? widget.controller.previous : null,
          compactOnNext: snapshot.hasNext ? widget.controller.next : null,
          child: CoeloAdminPagination(
            currentPage: snapshot.pageNumber,
            totalPages: snapshot.totalPages,
            onPrevious: snapshot.hasPrevious ? widget.controller.previous : null,
            onNext: snapshot.hasNext ? widget.controller.next : null,
          ),
        ),
      ],
    );
  }
}

final class _AuditState extends StatelessWidget {
  const _AuditState({
    required this.state,
    required this.icon,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final String state;
  final IconData icon;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: Key('audit-state-$state'),
    child: CoeloStatePanel(
      title: _stateTitle(state),
      message: message,
      icon: icon,
      loading: loading,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

String _stateTitle(String state) => switch (state) {
  'loading' => 'Carregando auditoria',
  'empty' => 'Auditoria vazia',
  'noResults' => 'Nenhum resultado',
  'failure' => 'Auditoria indisponível',
  'unauthorized' => 'Acesso negado',
  'notFound' => 'Recurso não encontrado',
  _ => 'Auditoria',
};
