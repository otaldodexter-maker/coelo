import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

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
    this.onConversationsOpen,
    super.key,
  });
  final SupportPrototypeController controller;
  final LogoutAction logout;
  final VoidCallback onInstitutionsOpen;
  final VoidCallback onCatalogOpen;
  final VoidCallback? onHomeOpen;
  final VoidCallback? onConversationsOpen;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _search = TextEditingController();
  final _tableFocusNode = FocusNode(debugLabel: 'support-ticket-table');
  FocusNode? _detailOriginFocusNode;
  SupportDisplayMode _displayMode = SupportDisplayMode.kanban;

  @override
  void dispose() {
    _search.dispose();
    _tableFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    title: 'Suporte',
    subtitle: 'Acompanhe os chamados enviados pelo botão de bug.',
    logout: widget.logout,
    currentDestination: 'support',
    onBugReportSubmitted: widget.controller.submitReport,
    onDestinationSelected: (d) {
      if (d == 'home') widget.onHomeOpen?.call();
      if (d == 'institutions') widget.onInstitutionsOpen();
      if (d == 'catalog') widget.onCatalogOpen();
      if (d == 'conversations') widget.onConversationsOpen?.call();
    },
    child: AnimatedBuilder(animation: widget.controller, builder: (_, _) => _content(context)),
  );
  Widget _content(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= CoeloBreakpoints.expanded.minWidth;
    final tickets = widget.controller.filteredTickets;
    return Padding(
      key: const Key('support-page-content'),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        children: [
          SupportFilterToolbar(
            controller: widget.controller,
            searchController: _search,
            displayMode: _displayMode,
            onDisplayModeChanged: (displayMode) => setState(() => _displayMode = displayMode),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Expanded(child: _listing(tickets)),
                      if (widget.controller.selectedTicket != null) ...[
                        const SizedBox(width: CoeloSpacing.space3),
                        SizedBox(width: 400, child: _details()),
                      ],
                    ],
                  )
                : _listing(tickets),
          ),
        ],
      ),
    );
  }

  Widget _listing(List<SupportTicket> tickets) {
    if (_displayMode == SupportDisplayMode.table) {
      return Focus(
        focusNode: _tableFocusNode,
        child: SupportTicketTable(
          tickets: tickets,
          teamMembers: widget.controller.teamMembers,
          selectedTicketId: widget.controller.selectedTicket?.id,
          onTicketPressed: (ticket) => _open(
            ticket,
            _tableFocusNode.hasFocus
                ? FocusManager.instance.primaryFocus ?? _tableFocusNode
                : _tableFocusNode,
          ),
          statusBuilder: _statusMenu,
        ),
      );
    }
    return SupportKanban(
      tickets: tickets,
      teamMembers: widget.controller.teamMembers,
      selectedTicketId: widget.controller.selectedTicket?.id,
      onTicketPressed: _open,
      onStatusChanged: _requestStatus,
      onOwnerChanged: (ticket, memberId) => widget.controller.assignOwner(ticket.id, memberId),
      onCollaboratorsChanged: (ticket, memberIds) =>
          widget.controller.setCollaborators(ticket.id, memberIds),
    );
  }

  void _open(SupportTicket ticket, FocusNode originFocusNode) {
    _detailOriginFocusNode = originFocusNode;
    widget.controller.selectTicket(ticket.id);
    if (MediaQuery.sizeOf(context).width < CoeloBreakpoints.expanded.minWidth) {
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
      onOwnerChanged: (memberId) => widget.controller.assignOwner(ticket.id, memberId),
      onCollaboratorsChanged: (memberIds) =>
          widget.controller.setCollaborators(ticket.id, memberIds),
      onSend: (message) => widget.controller.sendReply(ticket.id, message),
      onClose: () => _closeDetails(compact: compact),
    );
  }

  void _closeDetails({required bool compact}) {
    if (compact) {
      Navigator.of(context).pop();
    }
    widget.controller.selectTicket(null);
    final originFocusNode = _detailOriginFocusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && originFocusNode?.canRequestFocus == true) {
        originFocusNode!.requestFocus();
      }
    });
  }

  Future<void> _requestStatus(SupportTicket ticket, SupportTicketStatus status) async {
    if (status == SupportTicketStatus.inProgress && ticket.ownerId == null) {
      final ownerId = await _chooseOwner();
      if (!mounted || ownerId == null) {
        return;
      }
      widget.controller.assignOwner(ticket.id, ownerId);
    }
    widget.controller.changeStatus(ticket.id, status);
  }

  Future<String?> _chooseOwner() {
    return showDialog<String>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => SimpleDialog(
        title: const Text('Escolha o responsável'),
        children: [
          for (final member in widget.controller.teamMembers)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(member.id),
              child: SizedBox(
                height: CoeloSize.touchMin,
                child: Align(alignment: Alignment.centerLeft, child: Text(_memberLabel(member))),
              ),
            ),
        ],
      ),
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
