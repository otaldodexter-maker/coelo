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
    title: 'Suporte',
    subtitle: 'Acompanhe os chamados enviados pelo botão de bug.',
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
    final tickets = _displayMode == SupportDisplayMode.table
        ? widget.controller.visibleTickets
        : widget.controller.filteredTickets;
    return Padding(
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
            onExportCsv: (context) => _showExportPrototype(context, 'CSV'),
            onExportXlsx: (context) => _showExportPrototype(context, 'XLSX'),
          ),
        ),
        body: _listing(tickets),
        detail: _details(),
        detailVisible: widget.controller.selectedTicket != null,
      ),
    );
  }

  Widget _listing(List<SupportTicket> tickets) {
    if (_displayMode == SupportDisplayMode.table) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const Key('support-create-table'),
            height: 128,
            child: CoeloAdminCreateAction(label: 'Criar suporte', onPressed: _createSupport),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Expanded(
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

  void _openFullscreen(SupportTicket ticket, SupportFocusRestoreCallback restoreFocus) {
    _restoreDetailOriginFocus = restoreFocus;
    widget.controller.selectTicket(ticket.id);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (_) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => Dialog.fullscreen(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: SafeArea(child: _details(compact: true)),
        ),
      ),
    );
  }

  Widget _details({bool compact = false}) {
    final ticket = widget.controller.selectedTicket;
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
      onClose: () => _closeDetails(compact: compact),
    );
  }

  void _closeDetails({required bool compact}) {
    if (compact) {
      Navigator.of(context).pop();
    }
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
      currentScreen: 'Suporte',
      sections: const {
        'Suporte': ['Chamados', 'Outro'],
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

  void _showExportPrototype(BuildContext noticeContext, String format) {
    showSuperadminNotice(
      noticeContext,
      'Exportação $format da lista filtrada preparada para a futura integração.',
      icon: Icons.download_outlined,
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

  Widget _statusMenu(SupportTicket ticket) => PopupMenuButton<SupportTicketStatus>(
    key: Key('support-status-${ticket.id}'),
    tooltip: 'Alterar status de ${ticket.id}',
    initialValue: ticket.status,
    onSelected: (status) => _requestStatus(ticket, status),
    itemBuilder: (_) => [
      for (final status in SupportTicketStatus.values)
        PopupMenuItem(value: status, child: Text(_statusLabel(status))),
    ],
    child: _chip(ticket.status),
  );
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
