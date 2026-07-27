import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../domain/support_ticket.dart';
import '../view_models/support_prototype_controller.dart';
import '../widgets/support_filter_toolbar.dart';
import '../widgets/support_ticket_table.dart';

final class SupportPage extends StatefulWidget {
  const SupportPage({
    required this.controller,
    required this.logout,
    required this.onInstitutionsOpen,
    required this.onCatalogOpen,
    this.onHomeOpen,
    super.key,
  });
  final SupportPrototypeController controller;
  final LogoutAction logout;
  final VoidCallback onInstitutionsOpen;
  final VoidCallback onCatalogOpen;
  final VoidCallback? onHomeOpen;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _search = TextEditingController();
  final _composer = TextEditingController();
  SupportTicketStatus _compactStatus = SupportTicketStatus.newRequest;
  String? _highlightedTicketId;
  SupportDisplayMode _displayMode = SupportDisplayMode.kanban;
  @override
  void dispose() {
    _search.dispose();
    _composer.dispose();
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
    },
    child: AnimatedBuilder(animation: widget.controller, builder: (_, _) => _content(context)),
  );
  Widget _content(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
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
            child: wide && widget.controller.selectedTicket != null
                ? Row(
                    children: [
                      Expanded(child: _listing(tickets, wide)),
                      const SizedBox(width: CoeloSpacing.space3),
                      SizedBox(width: 360, child: _details()),
                    ],
                  )
                : _listing(tickets, wide),
          ),
        ],
      ),
    );
  }

  Widget _listing(List<SupportTicket> tickets, bool wide) {
    if (_displayMode == SupportDisplayMode.table) {
      return SupportTicketTable(
        tickets: tickets,
        teamMembers: widget.controller.teamMembers,
        selectedTicketId: widget.controller.selectedTicket?.id,
        onTicketPressed: _open,
        statusBuilder: _statusMenu,
      );
    }
    if (!wide) {
      return Column(
        children: [
          DropdownButton<SupportTicketStatus>(
            key: const Key('support-compact-status'),
            value: _compactStatus,
            items: SupportTicketStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))))
                .toList(),
            onChanged: (s) => setState(() => _compactStatus = s!),
          ),
          Expanded(child: _lane(_compactStatus, tickets)),
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1120,
        child: Row(
          children: [
            for (final s in SupportTicketStatus.values)
              Expanded(
                child: Padding(padding: const EdgeInsets.all(4), child: _lane(s, tickets)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _lane(SupportTicketStatus status, List<SupportTicket> tickets) {
    final items = tickets.where((t) => t.status == status).toList();
    return DragTarget<SupportTicket>(
      key: Key('support-kanban-${status.name}'),
      onAcceptWithDetails: (d) => widget.controller.changeStatus(d.data.id, status),
      builder: (_, _, _) => Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(child: Text('${_statusLabel(status)} (${items.length})')),
                  _chip(status),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final t in items)
                    LongPressDraggable(
                      data: t,
                      feedback: Material(child: _ticket(t)),
                      child: _ticket(t),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticket(SupportTicket t) => Card(
    key: Key('support-ticket-${t.id}'),
    margin: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(t),
        onHover: (value) => setState(() => _highlightedTicketId = value ? t.id : null),
        onFocusChange: (value) => setState(() => _highlightedTicketId = value ? t.id : null),
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
            return Theme.of(context).colorScheme.primaryContainer;
          }
          return Colors.transparent;
        }),
        splashColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
          child: ListTile(
            textColor: _highlightedTicketId == t.id
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
            iconColor: _highlightedTicketId == t.id
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            title: Text('${t.id} · ${t.subject}', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${t.menu} · ${t.screen}', maxLines: 1),
            trailing: _statusMenu(t),
          ),
        ),
      ),
    ),
  );
  void _open(SupportTicket t) {
    widget.controller.selectTicket(t.id);
    if (MediaQuery.sizeOf(context).width < 840) {
      showDialog<void>(
        context: context,
        barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
        builder: (_) => Dialog.fullscreen(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: SafeArea(child: _details(compact: true)),
        ),
      );
    }
  }

  Widget _details({bool compact = false}) {
    final t = widget.controller.selectedTicket;
    if (t == null) {
      return const CoeloStatePanel(
        title: 'Selecione um chamado',
        message: 'Abra um chamado para ver os detalhes.',
        icon: Icons.support_agent_outlined,
      );
    }
    return Card(
      key: const Key('support-detail-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.id, style: Theme.of(context).textTheme.labelLarge),
                      Text(t.subject, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
                _statusMenu(t),
                IconButton(
                  tooltip: 'Fechar detalhes',
                  onPressed: compact
                      ? () {
                          Navigator.of(context).pop();
                          widget.controller.selectTicket(null);
                        }
                      : () => widget.controller.selectTicket(null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Relatório original', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.space2),
                Text('${t.menu} > ${t.screen} · ${t.requester}'),
                const SizedBox(height: CoeloSpacing.space2),
                Text(t.description),
                if (t.attachments.isNotEmpty) ...[
                  const SizedBox(height: CoeloSpacing.space4),
                  Text('Evidências', style: Theme.of(context).textTheme.titleMedium),
                  for (final attachment in t.attachments)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: Text(attachment.fileName),
                        subtitle: const Text('Preview demonstrativo'),
                      ),
                    ),
                ],
                const Divider(),
                Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
                for (final m in t.messages)
                  CoeloMessageBubble(
                    direction: m.author == SupportMessageAuthor.support
                        ? CoeloMessageDirection.sent
                        : CoeloMessageDirection.received,
                    authorLabel: m.author == SupportMessageAuthor.requester ? t.requester : null,
                    body: m.text,
                    timestamp: '${m.sentAt.hour}:${m.sentAt.minute.toString().padLeft(2, '0')}',
                    deliveryState: _deliveryState(m),
                  ),
              ],
            ),
          ),
          KeyedSubtree(
            key: const Key('support-composer'),
            child: CoeloChatComposer(
              controller: _composer,
              hintText: 'Responder ao chamado',
              onSend: () {
                widget.controller.sendReply(t.id, _composer.text);
                _composer.clear();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(SupportTicketStatus s) {
    final c = Theme.of(context).extension<CoeloStatusColors>()!;
    final colors = switch (s) {
      SupportTicketStatus.newRequest => (c.infoContainer, c.onInfoContainer),
      SupportTicketStatus.inProgress => (c.warningContainer, c.onWarningContainer),
      SupportTicketStatus.waitingRequester => (c.errorContainer, c.onErrorContainer),
      SupportTicketStatus.completed => (c.successContainer, c.onSuccessContainer),
    };
    return CoeloStatusChip(
      label: _statusLabel(s),
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
    );
  }

  Widget _statusMenu(SupportTicket ticket) => PopupMenuButton<SupportTicketStatus>(
    key: Key('support-status-${ticket.id}'),
    tooltip: 'Alterar status de ${ticket.id}',
    initialValue: ticket.status,
    onSelected: (status) => widget.controller.changeStatus(ticket.id, status),
    itemBuilder: (_) => [
      for (final status in SupportTicketStatus.values)
        PopupMenuItem(value: status, child: Text(_statusLabel(status))),
    ],
    child: _chip(ticket.status),
  );
}

CoeloMessageDeliveryState _deliveryState(SupportMessage message) => switch (message.deliveryState) {
  SupportMessageDeliveryState.sent => CoeloMessageDeliveryState.sent,
  SupportMessageDeliveryState.delivered => CoeloMessageDeliveryState.delivered,
  SupportMessageDeliveryState.read => CoeloMessageDeliveryState.read,
};

String _statusLabel(SupportTicketStatus s) => switch (s) {
  SupportTicketStatus.newRequest => 'Novo',
  SupportTicketStatus.inProgress => 'Em andamento',
  SupportTicketStatus.waitingRequester => 'Aguardando',
  SupportTicketStatus.completed => 'Concluído',
};
