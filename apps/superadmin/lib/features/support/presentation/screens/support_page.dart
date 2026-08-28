import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_notice.dart';
import '../../../../app/shell/superadmin_bug_report_dialog.dart';
import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../domain/support_team_member.dart';
import '../../domain/support_ticket.dart';
import '../view_models/support_prototype_controller.dart';
import '../widgets/support_filter_toolbar.dart';
import '../widgets/support_kanban.dart';
import '../widgets/support_ticket_detail.dart';
import '../widgets/support_ticket_table.dart';

final class SupportPage extends StatefulWidget {
  const SupportPage({
    required this.controller,
    required this.logout,
    required this.onInstitutionsOpen,
    required this.onCatalogOpen,
    this.onHomeOpen,
    this.onUnitsOpen,
    this.onConversationsOpen,
    super.key,
  });
  final SupportPrototypeController controller;
  final LogoutAction logout;
  final VoidCallback onInstitutionsOpen;
  final VoidCallback onCatalogOpen;
  final VoidCallback? onHomeOpen;
  final VoidCallback? onUnitsOpen;
  final VoidCallback? onConversationsOpen;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _search = TextEditingController();
  final _readFilterFocusScopeNode = FocusScopeNode(debugLabel: 'support-read-filter');
  SupportFocusRestoreCallback? _restoreDetailOriginFocus;
  SupportDisplayMode _displayMode = SupportDisplayMode.kanban;

  @override
  void dispose() {
    _search.dispose();
    _readFilterFocusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    title: 'Suporte e implantação',
    subtitle: 'Acompanhe os chamados e solicitações da operação.',
    logout: widget.logout,
    currentDestination: 'support',
    chatLauncherBottomInset: CoeloSpacing.space20,
    onBugReportSubmitted: widget.controller.submitReport,
    onDestinationSelected: (d) {
      if (d == 'home') widget.onHomeOpen?.call();
      if (d == 'institutions') widget.onInstitutionsOpen();
      if (d == 'units') widget.onUnitsOpen?.call();
      if (d == 'catalog') widget.onCatalogOpen();
      if (d == 'conversations') widget.onConversationsOpen?.call();
    },
    child: AnimatedBuilder(animation: widget.controller, builder: (_, _) => _content(context)),
  );
  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final isMobileOrTabletSurface =
        theme.brightness == Brightness.light &&
        MediaQuery.sizeOf(context).width < CoeloBreakpoints.expanded.minWidth;
    final tickets = _displayMode == SupportDisplayMode.table
        ? widget.controller.visibleTickets
        : widget.controller.filteredTickets;
    final content = Padding(
      key: const Key('support-page-content'),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: CoeloAdminWorkspaceLayout(
        toolbar: Padding(
          padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
          child: SupportFilterToolbar(
            controller: widget.controller,
            searchController: _search,
            displayMode: _displayMode,
            onDisplayModeChanged: (displayMode) => setState(() => _displayMode = displayMode),
            readFilterFocusScopeNode: _readFilterFocusScopeNode,
            onExportCsv: _showUnavailableExport,
            onExportXlsx: _showUnavailableExport,
          ),
        ),
        body: _listing(tickets),
        detail: _details(),
        detailVisible: widget.controller.selectedTicket != null,
      ),
    );
    if (!isMobileOrTabletSurface) {
      return content;
    }
    return ColoredBox(color: theme.colorScheme.surface, child: content);
  }

  Widget _listing(List<SupportTicket> tickets) {
    if (_displayMode == SupportDisplayMode.table) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            key: const Key('support-create-table'),
            constraints: const BoxConstraints(minHeight: 128),
            child: CoeloAdminCreateAction(label: 'Criar suporte', onPressed: _createSupport),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: SingleChildScrollView(
                    child: SupportTicketTable(
                      tickets: tickets,
                      teamMembers: widget.controller.teamMembers,
                      selectedTicketId: widget.controller.selectedTicket?.id,
                      onTicketPressed: _open,
                      statusBuilder: _statusMenu,
                      sortColumn: widget.controller.sortColumn,
                      sortAscending: widget.controller.sortAscending,
                      onSort: widget.controller.setSort,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          KeyedSubtree(
            key: const Key('support-pagination'),
            child: CoeloAdminPagination(
              currentPage: widget.controller.currentPage,
              totalPages: widget.controller.totalPages,
              pageSize: widget.controller.pageSize,
              pageSizeOptions: const [9, 20, 50, 100],
              onPageSizeChanged: widget.controller.setPageSize,
              onPageSelected: widget.controller.setPage,
              onPrevious: widget.controller.currentPage > 1
                  ? () => widget.controller.setPage(widget.controller.currentPage - 1)
                  : null,
              onNext: widget.controller.currentPage < widget.controller.totalPages
                  ? () => widget.controller.setPage(widget.controller.currentPage + 1)
                  : null,
            ),
          ),
        ],
      );
    }
    return SupportKanban(
      tickets: tickets,
      teamMembers: widget.controller.teamMembers,
      selectedTicketId: widget.controller.selectedTicket?.id,
      onTicketPressed: _open,
      onTicketDoublePressed: _openFullscreen,
      onStatusChanged: _requestStatus,
      onAssigneesChanged: (ticket, memberIds) =>
          widget.controller.setAssignees(ticket.id, memberIds),
      onCreate: _createSupport,
    );
  }

  void _open(SupportTicket ticket, SupportFocusRestoreCallback restoreFocus) {
    _restoreDetailOriginFocus = restoreFocus;
    widget.controller.selectTicket(ticket.id);
  }

  Future<void> _openFullscreen(
    SupportTicket ticket,
    SupportFocusRestoreCallback restoreFocus,
  ) async {
    _restoreDetailOriginFocus = restoreFocus;
    widget.controller.selectTicket(ticket.id);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (dialogContext) => _DraggableSupportDialog(
        builder: (onDragUpdate, onMoveRequested, onResetRequested) => AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => _details(
            compact: true,
            fallbackTicket: ticket,
            onClose: () => Navigator.of(dialogContext).pop(),
            onHeaderDragUpdate: onDragUpdate,
            onHeaderMoveRequested: onMoveRequested,
            onHeaderResetRequested: onResetRequested,
          ),
        ),
      ),
    );
    if (mounted) {
      _closeDetails();
    }
  }

  Widget _details({
    bool compact = false,
    SupportTicket? fallbackTicket,
    VoidCallback? onClose,
    GestureDragUpdateCallback? onHeaderDragUpdate,
    ValueChanged<Offset>? onHeaderMoveRequested,
    VoidCallback? onHeaderResetRequested,
  }) {
    final ticket = widget.controller.selectedTicket ?? fallbackTicket;
    if (ticket == null) {
      return const CoeloStatePanel(
        title: 'Selecione um chamado',
        message: 'Abra um chamado para ver os detalhes.',
        icon: Icons.support_agent_outlined,
      );
    }
    return SupportTicketDetail(
      ticket: ticket,
      teamMembers: widget.controller.teamMembers,
      statusBuilder: _statusMenu,
      onAssigneesChanged: (memberIds) => widget.controller.setAssignees(ticket.id, memberIds),
      onExpand: compact
          ? null
          : () => _openFullscreen(ticket, _restoreDetailOriginFocus ?? () => false),
      onSend: (message) => widget.controller.sendReply(ticket.id, message),
      onClose: onClose ?? _closeDetails,
      onHeaderDragUpdate: onHeaderDragUpdate,
      onHeaderMoveRequested: onHeaderMoveRequested,
      onHeaderResetRequested: onHeaderResetRequested,
    );
  }

  void _closeDetails() {
    widget.controller.selectTicket(null);
    final restoreFocus = _restoreDetailOriginFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final restored = restoreFocus?.call() ?? false;
      if (!restored && widget.controller.filters.unreadOnly) {
        _readFilterFocusScopeNode.requestFocus();
      }
    });
  }

  Future<void> _requestStatus(SupportTicket ticket, SupportTicketStatus status) async {
    if (status == SupportTicketStatus.inProgress && ticket.assigneeIds.isEmpty) {
      final ownerId = await _chooseOwner();
      if (!mounted || ownerId == null) {
        return;
      }
      widget.controller.setAssignees(ticket.id, {ownerId});
    }
    widget.controller.changeStatus(ticket.id, status);
  }

  Future<void> _createSupport() async {
    final draft = await showSuperadminBugReportDialog(
      context,
      dialogTitle: 'Novo chamado',
      currentScreen: 'Suporte e implantação',
      sections: const {
        'Suporte e implantação': ['Chamados', 'Outro'],
        'Outros': [],
      },
    );
    if (draft == null || !mounted) {
      return;
    }
    widget.controller.submitReport(draft);
    showSuperadminNotice(
      context,
      'Chamado criado com sucesso.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  Future<String?> _chooseOwner() {
    return showDialog<String>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Escolha o responsável',
        body: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.controller.teamMembers.length,
            separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space1),
            itemBuilder: (context, index) {
              final member = widget.controller.teamMembers[index];
              return TextButton(
                onPressed: () => Navigator.of(context).pop(member.id),
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
                  alignment: Alignment.centerLeft,
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                  ),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
                child: Text(_memberLabel(member)),
              );
            },
          ),
        ),
        primaryAction: FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  void _showUnavailableExport(BuildContext noticeContext) {
    showSuperadminNotice(
      noticeContext,
      'Indisponível nesta etapa',
      icon: Icons.info_outline_rounded,
    );
  }

  Widget _chip(SupportTicketStatus status) {
    final c = Theme.of(context).extension<CoeloStatusColors>()!;
    final colors = switch (status) {
      SupportTicketStatus.newRequest => (c.infoContainer, c.onInfoContainer),
      SupportTicketStatus.inProgress => (c.warningContainer, c.onWarningContainer),
      SupportTicketStatus.waitingRequester => (c.errorContainer, c.onErrorContainer),
      SupportTicketStatus.completed => (c.successContainer, c.onSuccessContainer),
    };
    return CoeloStatusChip(
      label: _statusLabel(status),
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
    );
  }

  Widget _statusMenu(SupportTicket ticket) => CoeloAdminFlyout<SupportTicketStatus>(
    itemWidth: 220,
    alignmentOffset: const Offset(0, CoeloSpacing.space1),
    items: [
      for (final status in SupportTicketStatus.values)
        CoeloAdminFlyoutItem(
          value: status,
          label: _statusLabel(status),
          selected: ticket.status == status,
          icon: switch (status) {
            SupportTicketStatus.newRequest => Icons.info_outlined,
            SupportTicketStatus.inProgress => Icons.construction_outlined,
            SupportTicketStatus.waitingRequester => Icons.hourglass_empty_rounded,
            SupportTicketStatus.completed => Icons.check_circle_outline_rounded,
          },
        ),
    ],
    onSelected: (status) => _requestStatus(ticket, status),
    builder: (_, controller) {
      void open() => controller.isOpen ? controller.close() : controller.open();
      return Semantics(
        key: Key('support-status-${ticket.id}'),
        button: true,
        child: Focus(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(
              onPressed: open,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
                overlayColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
              ),
              child: Tooltip(
                message: 'Alterar status de ${ticket.id}',
                child: _chip(ticket.status),
              ),
            ),
          ),
        ),
      );
    },
  );
}

typedef _DraggableSupportDialogBuilder =
    Widget Function(
      GestureDragUpdateCallback onDragUpdate,
      ValueChanged<Offset> onMoveRequested,
      VoidCallback onResetRequested,
    );

final class _DraggableSupportDialog extends StatefulWidget {
  const _DraggableSupportDialog({required this.builder});

  final _DraggableSupportDialogBuilder builder;

  @override
  State<_DraggableSupportDialog> createState() => _DraggableSupportDialogState();
}

final class _DraggableSupportDialogState extends State<_DraggableSupportDialog> {
  Offset _offset = Offset.zero;
  Rect _movementBounds = Rect.zero;

  Offset _clamp(Offset value) => Offset(
    value.dx.clamp(_movementBounds.left, _movementBounds.right).toDouble(),
    value.dy.clamp(_movementBounds.top, _movementBounds.bottom).toDouble(),
  );

  void _moveBy(Offset delta) {
    setState(() => _offset = _clamp(_offset + delta));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth
            ? CoeloSpacing.space20
            : CoeloSpacing.space4;
        final safeWidth = constraints.maxWidth - media.padding.left - media.padding.right;
        final safeHeight = constraints.maxHeight - media.padding.top - media.padding.bottom;
        final availableWidth = (safeWidth - (margin * 2)).clamp(0, double.infinity);
        final availableHeight = (safeHeight - (margin * 2)).clamp(0, double.infinity);
        final panelWidth = availableWidth.clamp(0, CoeloBreakpoints.expanded.maxWidth).toDouble();
        final panelHeight = availableHeight.toDouble();
        final maxDx = ((safeWidth - panelWidth) / 2).clamp(0, double.infinity).toDouble();
        final maxDy = ((safeHeight - panelHeight) / 2).clamp(0, double.infinity).toDouble();
        _movementBounds = Rect.fromLTRB(-maxDx, -maxDy, maxDx, maxDy);
        _offset = _clamp(_offset);

        final initialLeft = media.padding.left + ((safeWidth - panelWidth) / 2);
        final initialTop = media.padding.top + ((safeHeight - panelHeight) / 2);
        return Stack(
          children: [
            Positioned(
              left: initialLeft + _offset.dx,
              top: initialTop + _offset.dy,
              width: panelWidth,
              height: panelHeight,
              child: Material(
                key: const Key('support-expanded-detail'),
                color: colors.surface,
                surfaceTintColor: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: widget.builder(
                  (details) => _moveBy(details.delta),
                  _moveBy,
                  () => setState(() => _offset = Offset.zero),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _statusLabel(SupportTicketStatus s) => switch (s) {
  SupportTicketStatus.newRequest => 'Novo',
  SupportTicketStatus.inProgress => 'Em andamento',
  SupportTicketStatus.waitingRequester => 'Aguardando solicitante',
  SupportTicketStatus.completed => 'Concluído',
};

String _memberLabel(SupportTeamMember member) => '${member.name} · ${_roleLabel(member.role)}';

String _roleLabel(SupportTeamRole role) => switch (role) {
  SupportTeamRole.support => 'Suporte',
  SupportTeamRole.development => 'Desenvolvimento',
  SupportTeamRole.customerSuccess => 'Sucesso do cliente',
  SupportTeamRole.qualityAssurance => 'Qualidade',
};
