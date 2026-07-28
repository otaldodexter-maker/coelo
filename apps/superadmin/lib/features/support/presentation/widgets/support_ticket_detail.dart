import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/support_team_member.dart';
import '../../domain/support_ticket.dart';
import 'support_assignee_view.dart';
import 'support_message_bubble.dart';
import 'support_reply_composer.dart';

final class SupportTicketDetail extends StatefulWidget {
  const SupportTicketDetail({
    required this.ticket,
    required this.teamMembers,
    required this.statusBuilder,
    required this.onOwnerChanged,
    required this.onCollaboratorsChanged,
    required this.onSend,
    required this.onClose,
    super.key,
  });

  final SupportTicket ticket;
  final List<SupportTeamMember> teamMembers;
  final Widget Function(SupportTicket ticket) statusBuilder;
  final ValueChanged<String?> onOwnerChanged;
  final ValueChanged<Set<String>> onCollaboratorsChanged;
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
                  child: SupportReplyComposer(
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
        SupportAssigneeView(
          ownerId: ticket.ownerId,
          collaboratorIds: ticket.collaboratorIds,
          teamMembers: widget.teamMembers,
        ),
        const SizedBox(height: CoeloSpacing.space2),
        _OwnerSelector(
          key: const Key('support-detail-owner'),
          ownerId: ticket.ownerId,
          teamMembers: widget.teamMembers,
          onChanged: widget.onOwnerChanged,
        ),
        const SizedBox(height: CoeloSpacing.space2),
        CoeloAdminMultiSelectFilter<String>(
          key: const Key('support-detail-collaborators'),
          label: 'Colaboradores',
          options: widget.teamMembers.map((member) => member.id).toList(growable: false),
          selectedValues: ticket.collaboratorIds,
          optionLabel: (memberId) =>
              _memberLabel(widget.teamMembers.singleWhere((member) => member.id == memberId)),
          onChanged: widget.onCollaboratorsChanged,
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
        for (final message in ticket.messages)
          SupportMessageBubble(message: message, requesterName: ticket.requester),
      ],
    );
  }
}

final class _OwnerSelector extends StatelessWidget {
  const _OwnerSelector({
    required this.ownerId,
    required this.teamMembers,
    required this.onChanged,
    super.key,
  });

  final String? ownerId;
  final List<SupportTeamMember> teamMembers;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final owner = teamMembers.where((member) => member.id == ownerId).firstOrNull;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: ownerId == null
              ? const Icon(Icons.check_rounded)
              : const SizedBox(width: CoeloSpacing.space6),
          onPressed: () => onChanged(null),
          child: const Text('Sem responsável'),
        ),
        for (final member in teamMembers)
          MenuItemButton(
            leadingIcon: ownerId == member.id
                ? const Icon(Icons.check_rounded)
                : const SizedBox(width: CoeloSpacing.space6),
            onPressed: () => onChanged(member.id),
            child: Text(_memberLabel(member)),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(CoeloSize.touchMin),
          alignment: Alignment.centerLeft,
          shape: const StadiumBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                owner == null ? 'Atribuir responsável' : _memberLabel(owner),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

String _memberLabel(SupportTeamMember member) => '${member.name} · ${_roleLabel(member.role)}';

String _roleLabel(SupportTeamRole role) => switch (role) {
  SupportTeamRole.support => 'Suporte',
  SupportTeamRole.development => 'Desenvolvimento',
  SupportTeamRole.customerSuccess => 'Sucesso do cliente',
  SupportTeamRole.qualityAssurance => 'Qualidade',
};
