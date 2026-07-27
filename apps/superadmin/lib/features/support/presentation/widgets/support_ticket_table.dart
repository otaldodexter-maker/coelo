import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/support_team_member.dart';
import '../../domain/support_ticket.dart';
import 'support_assignee_view.dart';

typedef SupportTableTicketOpenCallback =
    void Function(SupportTicket ticket, bool Function() restoreFocus);

final class SupportTicketTable extends StatefulWidget {
  const SupportTicketTable({
    required this.tickets,
    required this.teamMembers,
    required this.selectedTicketId,
    required this.onTicketPressed,
    required this.statusBuilder,
    super.key,
  });

  final List<SupportTicket> tickets;
  final List<SupportTeamMember> teamMembers;
  final String? selectedTicketId;
  final SupportTableTicketOpenCallback onTicketPressed;
  final Widget Function(SupportTicket ticket) statusBuilder;

  @override
  State<SupportTicketTable> createState() => _SupportTicketTableState();
}

final class _SupportTicketTableState extends State<SupportTicketTable> {
  final _rowFocusNodes = <String, FocusNode>{};

  @override
  void didUpdateWidget(covariant SupportTicketTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ticketIds = widget.tickets.map((ticket) => ticket.id).toSet();
    for (final ticketId in _rowFocusNodes.keys.where((id) => !ticketIds.contains(id)).toList()) {
      _rowFocusNodes.remove(ticketId)?.dispose();
    }
  }

  @override
  void dispose() {
    for (final focusNode in _rowFocusNodes.values) {
      focusNode.dispose();
    }
    _rowFocusNodes.clear();
    super.dispose();
  }

  FocusNode _focusNodeFor(SupportTicket ticket) {
    return _rowFocusNodes.putIfAbsent(
      ticket.id,
      () => FocusNode(debugLabel: 'support-table-row-${ticket.id}'),
    );
  }

  bool _restoreRowFocus(String ticketId, FocusNode focusNode) {
    if (!mounted || !identical(_rowFocusNodes[ticketId], focusNode)) {
      return false;
    }
    if (!focusNode.canRequestFocus) {
      return false;
    }
    focusNode.requestFocus();
    return true;
  }

  void _openTicket(SupportTicket ticket) {
    final focusNode = _focusNodeFor(ticket);
    focusNode.requestFocus();
    widget.onTicketPressed(ticket, () => _restoreRowFocus(ticket.id, focusNode));
  }

  @override
  Widget build(BuildContext context) {
    final ticketColumn = CoeloAdminTableColumn<SupportTicket>(
      id: 'ticket',
      label: 'Chamado',
      initialWidth: 240,
      minWidth: 200,
      maxWidth: 420,
      cellBuilder: (context, ticket) => _ticketCell(context, ticket),
    );
    final columns = [
      CoeloAdminTableColumn<SupportTicket>(
        id: 'origin',
        label: 'Origem',
        initialWidth: 200,
        minWidth: 160,
        maxWidth: 320,
        cellBuilder: (_, ticket) => _text('${ticket.menu} > ${ticket.screen}'),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'requester-context',
        label: 'Solicitante / contexto',
        initialWidth: 240,
        minWidth: 200,
        maxWidth: 420,
        cellBuilder: (context, ticket) => _requesterCell(context, ticket),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'assignee',
        label: 'Responsável',
        initialWidth: 140,
        minWidth: 120,
        maxWidth: 260,
        cellBuilder: (_, ticket) => SupportAssigneeView(
          ownerId: ticket.ownerId,
          collaboratorIds: ticket.collaboratorIds,
          teamMembers: widget.teamMembers,
        ),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'status',
        label: 'Status',
        initialWidth: 190,
        minWidth: 160,
        maxWidth: 220,
        cellBuilder: (_, ticket) => widget.statusBuilder(ticket),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'attachments',
        label: 'Anexos',
        initialWidth: 90,
        minWidth: 80,
        maxWidth: 120,
        cellBuilder: (_, ticket) => _text('${ticket.attachments.length}'),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'unread',
        label: 'Não lidas',
        initialWidth: 100,
        minWidth: 90,
        maxWidth: 130,
        cellBuilder: (_, ticket) => _text('${_unreadCount(ticket)}'),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'updated',
        label: 'Atualizado em',
        initialWidth: 150,
        minWidth: 130,
        maxWidth: 210,
        cellBuilder: (_, ticket) => _text(_dateTime(ticket.updatedAt)),
      ),
    ];
    return CoeloAdminResizableTable<SupportTicket>(
      key: const Key('support-ticket-table'),
      items: widget.tickets,
      rowKey: (ticket) => ticket.id,
      headerHeight: 56,
      rowHeight: 64,
      pinnedColumn: ticketColumn,
      columns: columns,
      onRowPressed: _openTicket,
      isSelected: (ticket) => ticket.id == widget.selectedTicketId,
    );
  }

  Widget _ticketCell(BuildContext context, SupportTicket ticket) {
    return Focus(
      key: Key('support-table-row-focus-${ticket.id}'),
      focusNode: _focusNodeFor(ticket),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ticket.id, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            ticket.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _requesterCell(BuildContext context, SupportTicket ticket) {
    final breadcrumb = ticket.requesterContext?.breadcrumb ?? '';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ticket.requester, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (breadcrumb.isNotEmpty)
          Text(
            breadcrumb,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

Widget _text(String value) => Align(
  alignment: Alignment.centerLeft,
  child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
);

int _unreadCount(SupportTicket ticket) => ticket.messages
    .where(
      (message) => message.author == SupportMessageAuthor.requester && !message.isReadBySupport,
    )
    .length;

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
