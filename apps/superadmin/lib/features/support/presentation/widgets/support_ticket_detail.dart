import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/support_team_member.dart';
import '../../domain/support_ticket.dart';
import 'support_assignee_view.dart';

final class SupportTicketDetail extends StatefulWidget {
  const SupportTicketDetail({
    required this.ticket,
    required this.teamMembers,
    required this.statusBuilder,
    required this.onAssigneesChanged,
    required this.onExpand,
    required this.onSend,
    required this.onClose,
    super.key,
  });

  final SupportTicket ticket;
  final List<SupportTeamMember> teamMembers;
  final Widget Function(SupportTicket ticket) statusBuilder;
  final ValueChanged<Set<String>> onAssigneesChanged;
  final VoidCallback? onExpand;
  final ValueChanged<String> onSend;
  final VoidCallback onClose;

  @override
  State<SupportTicketDetail> createState() => _SupportTicketDetailState();
}

final class _SupportTicketDetailState extends State<SupportTicketDetail> {
  final _composer = TextEditingController();

  @override
  void didUpdateWidget(covariant SupportTicketDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.id != widget.ticket.id) {
      _composer.clear();
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onClose();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Card(
            key: const Key('support-detail-panel'),
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const Divider(height: 1),
                Expanded(child: _body(context)),
                const Divider(height: 1),
                KeyedSubtree(
                  key: const Key('support-composer'),
                  child: CoeloChatComposer(
                    controller: _composer,
                    hintText: 'Responder ao chamado',
                    onSend: () {
                      widget.onSend(_composer.text);
                      _composer.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ticket.id,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(widget.ticket.subject, style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              if (widget.onExpand != null)
                Tooltip(
                  message: 'Expandir detalhes',
                  child: IconButton(
                    key: const Key('support-detail-expand'),
                    onPressed: widget.onExpand,
                    constraints: const BoxConstraints.tightFor(
                      width: CoeloSize.touchMin,
                      height: CoeloSize.touchMin,
                    ),
                    icon: const Icon(Icons.open_in_full_rounded),
                  ),
                ),
              Tooltip(
                message: 'Fechar detalhes',
                child: Semantics(
                  button: true,
                  label: 'Fechar detalhes',
                  child: IconButton(
                    key: const Key('support-detail-close'),
                    onPressed: widget.onClose,
                    constraints: const BoxConstraints.tightFor(
                      width: CoeloSize.touchMin,
                      height: CoeloSize.touchMin,
                    ),
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(colors.error),
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        final highlighted =
                            states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused);
                        return highlighted ? colors.errorContainer : Colors.transparent;
                      }),
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      shape: const WidgetStatePropertyAll(CircleBorder()),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Align(alignment: Alignment.centerLeft, child: widget.statusBuilder(widget.ticket)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final ticket = widget.ticket;
    final colors = Theme.of(context).colorScheme;
    final breadcrumb = ticket.requesterContext?.breadcrumb ?? '';
    return ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      children: [
        Text('Equipe', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        SupportAssigneeView(assigneeIds: ticket.assigneeIds, teamMembers: widget.teamMembers),
        const SizedBox(height: CoeloSpacing.space2),
        CoeloAdminMultiSelectFilter<String>(
          key: const Key('support-detail-assignees'),
          label: 'Responsáveis',
          options: widget.teamMembers.map((member) => member.id).toList(growable: false),
          selectedValues: ticket.assigneeIds,
          optionLabel: (memberId) =>
              _memberLabel(widget.teamMembers.singleWhere((member) => member.id == memberId)),
          onChanged: widget.onAssigneesChanged,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Text('Relatório original', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        Text(ticket.requester, style: Theme.of(context).textTheme.titleSmall),
        if (breadcrumb.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            breadcrumb,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          '${ticket.menu} > ${ticket.screen}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text(ticket.description),
        if (ticket.attachments.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space4),
          Text('Evidências', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space2),
          for (final attachment in ticket.attachments)
            Card(
              color: colors.surfaceContainerLow,
              margin: const EdgeInsets.only(bottom: CoeloSpacing.space2),
              child: ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(attachment.fileName),
                subtitle: const Text('Preview demonstrativo'),
              ),
            ),
        ],
        const SizedBox(height: CoeloSpacing.space2),
        const Divider(),
        Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        _HistoryEntry(label: 'Chamado criado', occurredAt: ticket.createdAt),
        for (final activity in ticket.activities)
          if (activity.kind != SupportActivityKind.created)
            _HistoryEntry(label: activity.label, occurredAt: activity.occurredAt),
        for (final message in ticket.messages)
          CoeloMessageBubble(
            direction: message.author == SupportMessageAuthor.support
                ? CoeloMessageDirection.sent
                : CoeloMessageDirection.received,
            authorLabel: message.author == SupportMessageAuthor.requester ? ticket.requester : null,
            body: message.text,
            timestamp: '${message.sentAt.hour}:${message.sentAt.minute.toString().padLeft(2, '0')}',
            deliveryState: _deliveryState(message),
          ),
      ],
    );
  }
}

final class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.label, required this.occurredAt});

  final String label;
  final DateTime occurredAt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_rounded),
      title: Text(label),
      subtitle: Text(
        '${occurredAt.day.toString().padLeft(2, '0')}/'
        '${occurredAt.month.toString().padLeft(2, '0')} '
        '${occurredAt.hour.toString().padLeft(2, '0')}:'
        '${occurredAt.minute.toString().padLeft(2, '0')}',
      ),
    );
  }
}

CoeloMessageDeliveryState _deliveryState(SupportMessage message) => switch (message.deliveryState) {
  SupportMessageDeliveryState.sent => CoeloMessageDeliveryState.sent,
  SupportMessageDeliveryState.delivered => CoeloMessageDeliveryState.delivered,
  SupportMessageDeliveryState.read => CoeloMessageDeliveryState.read,
};

String _memberLabel(SupportTeamMember member) => '${member.name} · ${_roleLabel(member.role)}';

String _roleLabel(SupportTeamRole role) => switch (role) {
  SupportTeamRole.support => 'Suporte',
  SupportTeamRole.development => 'Desenvolvimento',
  SupportTeamRole.customerSuccess => 'Sucesso do cliente',
  SupportTeamRole.qualityAssurance => 'Qualidade',
};
