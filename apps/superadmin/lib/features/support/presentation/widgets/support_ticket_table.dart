import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/support_team_member.dart';
import '../../domain/support_ticket.dart';
import '../view_models/support_prototype_controller.dart';
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
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    super.key,
  });

  final List<SupportTicket> tickets;
  final List<SupportTeamMember> teamMembers;
  final String? selectedTicketId;
  final SupportTableTicketOpenCallback onTicketPressed;
  final Widget Function(SupportTicket ticket) statusBuilder;
  final SupportSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<SupportSortColumn> onSort;

  @override
  State<SupportTicketTable> createState() => _SupportTicketTableState();
}

final class _SupportTicketTableState extends State<SupportTicketTable> {
  final _tableController = CoeloAdminTableController();

  void _openTicket(SupportTicket ticket) {
    _tableController.focusRow(ticket.id);
    widget.onTicketPressed(ticket, () => _tableController.focusRow(ticket.id));
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = (MediaQuery.textScalerOf(context).scale(32) + CoeloSpacing.space4)
        .clamp(64, double.infinity)
        .toDouble();
    final ticketColumn = CoeloAdminTableColumn<SupportTicket>(
      id: 'ticket',
      label: 'Chamado',
      initialWidth: 240,
      minWidth: 200,
      maxWidth: 420,
      sortable: true,
      cellBuilder: (context, ticket) => _ticketCell(context, ticket),
    );
    final columns = [
      CoeloAdminTableColumn<SupportTicket>(
        id: 'origin',
        label: 'Origem',
        initialWidth: 200,
        minWidth: 160,
        maxWidth: 320,
        sortable: true,
        cellBuilder: (context, ticket) => _originCell(context, ticket),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'requester-context',
        label: 'Solicitante / contexto',
        initialWidth: 240,
        minWidth: 200,
        maxWidth: 420,
        sortable: true,
        cellBuilder: (context, ticket) => _requesterCell(context, ticket),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'assignee',
        label: 'Responsável',
        initialWidth: 140,
        minWidth: 120,
        maxWidth: 260,
        sortable: true,
        cellBuilder: (_, ticket) =>
            SupportAssigneeView(assigneeIds: ticket.assigneeIds, teamMembers: widget.teamMembers),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'status',
        label: 'Status',
        initialWidth: 190,
        minWidth: 160,
        maxWidth: 220,
        sortable: true,
        cellBuilder: (_, ticket) => widget.statusBuilder(ticket),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'attachments',
        label: 'Anexos',
        initialWidth: 90,
        minWidth: 80,
        maxWidth: 120,
        sortable: true,
        cellBuilder: (_, ticket) => _text('${ticket.attachments.length}'),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'unread',
        label: 'Não lidas',
        initialWidth: 100,
        minWidth: 90,
        maxWidth: 130,
        sortable: true,
        cellBuilder: (_, ticket) => _text('${_unreadCount(ticket)}'),
      ),
      CoeloAdminTableColumn<SupportTicket>(
        id: 'updated',
        label: 'Atualizado em',
        initialWidth: 150,
        minWidth: 130,
        maxWidth: 210,
        sortable: true,
        cellBuilder: (_, ticket) => _text(_dateTime(ticket.updatedAt)),
      ),
    ];
    return CoeloAdminResizableTable<SupportTicket>(
      key: const Key('support-ticket-table'),
      items: widget.tickets,
      rowKey: (ticket) => ticket.id,
      headerHeight: 56,
      rowHeight: rowHeight,
      pinnedColumn: ticketColumn,
      columns: columns,
      controller: _tableController,
      onRowPressed: _openTicket,
      isSelected: (ticket) => ticket.id == widget.selectedTicketId,
      sortColumnId: _columnId(widget.sortColumn),
      sortAscending: widget.sortAscending,
      onSort: (id) => widget.onSort(_sortColumn(id)),
      showHorizontalScrollbar: true,
    );
  }

  Widget _ticketCell(BuildContext context, SupportTicket ticket) {
    return Column(
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
    );
  }

  Widget _originCell(BuildContext context, SupportTicket ticket) {
    return Text('${ticket.menu} > ${ticket.screen}', maxLines: 1, overflow: TextOverflow.ellipsis);
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

String _columnId(SupportSortColumn column) => switch (column) {
  SupportSortColumn.id || SupportSortColumn.subject => 'ticket',
  SupportSortColumn.menu => 'origin',
  SupportSortColumn.requester => 'requester-context',
  SupportSortColumn.assignees => 'assignee',
  SupportSortColumn.status => 'status',
  SupportSortColumn.attachments => 'attachments',
  SupportSortColumn.unread => 'unread',
  SupportSortColumn.updatedAt => 'updated',
};

SupportSortColumn _sortColumn(String id) => switch (id) {
  'ticket' => SupportSortColumn.subject,
  'origin' => SupportSortColumn.menu,
  'requester-context' => SupportSortColumn.requester,
  'assignee' => SupportSortColumn.assignees,
  'status' => SupportSortColumn.status,
  'attachments' => SupportSortColumn.attachments,
  'unread' => SupportSortColumn.unread,
  _ => SupportSortColumn.updatedAt,
};

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
