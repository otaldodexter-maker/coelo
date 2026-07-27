import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/support_team_member.dart';
import '../../domain/support_ticket.dart';
import 'support_assignee_view.dart';

typedef SupportFocusRestoreCallback = bool Function();
typedef SupportTicketOpenCallback =
    void Function(SupportTicket ticket, SupportFocusRestoreCallback restoreFocus);
typedef SupportStatusChangeCallback =
    Future<void> Function(SupportTicket ticket, SupportTicketStatus status);
typedef SupportOwnerChangeCallback = void Function(SupportTicket ticket, String? memberId);
typedef SupportCollaboratorsChangeCallback =
    void Function(SupportTicket ticket, Set<String> memberIds);

final class SupportKanban extends StatefulWidget {
  const SupportKanban({
    required this.tickets,
    required this.teamMembers,
    required this.selectedTicketId,
    required this.onTicketPressed,
    required this.onTicketDoublePressed,
    required this.onStatusChanged,
    required this.onOwnerChanged,
    required this.onCollaboratorsChanged,
    super.key,
  });

  final List<SupportTicket> tickets;
  final List<SupportTeamMember> teamMembers;
  final String? selectedTicketId;
  final SupportTicketOpenCallback onTicketPressed;
  final SupportTicketOpenCallback onTicketDoublePressed;
  final SupportStatusChangeCallback onStatusChanged;
  final SupportOwnerChangeCallback onOwnerChanged;
  final SupportCollaboratorsChangeCallback onCollaboratorsChanged;

  @override
  State<SupportKanban> createState() => _SupportKanbanState();
}

final class _SupportKanbanState extends State<SupportKanban> {
  final _cardFocusNodes = <String, FocusNode>{};
  SupportTicketStatus _compactStatus = SupportTicketStatus.newRequest;

  @override
  void didUpdateWidget(covariant SupportKanban oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ticketIds = widget.tickets.map((ticket) => ticket.id).toSet();
    for (final ticketId in _cardFocusNodes.keys.where((id) => !ticketIds.contains(id)).toList()) {
      _cardFocusNodes.remove(ticketId)?.dispose();
    }
  }

  @override
  void dispose() {
    for (final focusNode in _cardFocusNodes.values) {
      focusNode.dispose();
    }
    _cardFocusNodes.clear();
    super.dispose();
  }

  FocusNode _focusNodeFor(SupportTicket ticket) {
    return _cardFocusNodes.putIfAbsent(
      ticket.id,
      () => FocusNode(debugLabel: 'support-card-${ticket.id}'),
    );
  }

  bool _restoreCardFocus(String ticketId, FocusNode focusNode) {
    if (!mounted || !identical(_cardFocusNodes[ticketId], focusNode)) {
      return false;
    }
    if (!focusNode.canRequestFocus) {
      return false;
    }
    focusNode.requestFocus();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return CoeloAdminKanbanBoard<SupportTicket, SupportTicketStatus>(
      key: const Key('support-kanban'),
      statuses: SupportTicketStatus.values,
      statusLabel: _statusLabel,
      selectedStatus: _compactStatus,
      compact: MediaQuery.sizeOf(context).width < 600,
      onSelectedStatusChanged: (status) => setState(() => _compactStatus = status),
      itemsForStatus: (status) =>
          widget.tickets.where((ticket) => ticket.status == status).toList(growable: false),
      itemBuilder: (context, ticket) => _ticketCard(ticket),
      onItemAccepted: (ticket, status) => widget.onStatusChanged(ticket, status),
      emptyLaneBuilder: (context, status) => Center(
        child: Text(
          'Nenhum chamado',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _ticketCard(SupportTicket ticket) {
    final breadcrumb = ticket.requesterContext?.breadcrumb ?? '';
    final unreadCount = ticket.messages
        .where(
          (message) => message.author == SupportMessageAuthor.requester && !message.isReadBySupport,
        )
        .length;
    final focusNode = _focusNodeFor(ticket);
    final indicators = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ticket.attachments.isNotEmpty) ...[
          const Icon(Icons.attach_file_rounded, size: CoeloSpacing.space4),
          Text('${ticket.attachments.length}'),
        ],
        if (unreadCount > 0) ...[
          const SizedBox(width: CoeloSpacing.space2),
          Icon(
            Icons.mark_chat_unread_outlined,
            size: CoeloSpacing.space4,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text('$unreadCount'),
        ],
      ],
    );

    return CoeloAdminWorkItemCard<SupportTicket>(
      key: Key('support-card-${ticket.id}'),
      focusNode: focusNode,
      eyebrow: '${ticket.id} · ${ticket.menu} > ${ticket.screen}',
      title: ticket.subject,
      summary: ticket.description,
      metadata: [
        ticket.requester,
        if (breadcrumb.isNotEmpty) breadcrumb,
        'Atualizado em ${_dateTime(ticket.updatedAt)}',
      ],
      assignees: SupportAssigneeView(
        ownerId: ticket.ownerId,
        collaboratorIds: ticket.collaboratorIds,
        teamMembers: widget.teamMembers,
      ),
      indicators: indicators,
      trailingMenu: _CardMenu(ticket: ticket, widget: widget),
      selected: widget.selectedTicketId == ticket.id,
      dragData: ticket,
      onTap: () => widget.onTicketPressed(ticket, () => _restoreCardFocus(ticket.id, focusNode)),
      onDoubleTap: () =>
          widget.onTicketDoublePressed(ticket, () => _restoreCardFocus(ticket.id, focusNode)),
    );
  }
}

final class _CardMenu extends StatefulWidget {
  const _CardMenu({required this.ticket, required this.widget});

  final SupportTicket ticket;
  final SupportKanban widget;

  @override
  State<_CardMenu> createState() => _CardMenuState();
}

final class _CardMenuState extends State<_CardMenu> {
  final _menuFocusNode = FocusNode(debugLabel: 'support-card-menu');
  final _ownerMenuFocusNode = FocusNode(debugLabel: 'support-owner-menu');
  var _focusOwnerWhenOpened = false;

  @override
  void dispose() {
    _menuFocusNode.dispose();
    _ownerMenuFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ticket = widget.ticket;
    final supportKanban = widget.widget;
    final menuStyle = _menuSurfaceStyle(colors);
    return MenuAnchor(
      childFocusNode: _menuFocusNode,
      onOpen: () {
        if (!_focusOwnerWhenOpened) {
          return;
        }
        _focusOwnerWhenOpened = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _ownerMenuFocusNode.canRequestFocus) {
            _ownerMenuFocusNode.requestFocus();
          }
        });
      },
      alignmentOffset: const Offset(0, CoeloSpacing.spaceHalf),
      style: menuStyle,
      menuChildren: [
        SubmenuButton(
          focusNode: _ownerMenuFocusNode,
          style: _menuItemStyle(colors),
          menuStyle: menuStyle,
          leadingIcon: const Icon(Icons.person_add_alt_1_outlined),
          menuChildren: [
            for (final member in supportKanban.teamMembers)
              Semantics(
                key: Key('support-owner-option-${ticket.id}-${member.id}'),
                selected: ticket.ownerId == member.id,
                child: MenuItemButton(
                  style: _menuItemStyle(colors, selected: ticket.ownerId == member.id),
                  leadingIcon: ExcludeSemantics(
                    child: ticket.ownerId == member.id
                        ? const Icon(Icons.check_rounded)
                        : const SizedBox(width: CoeloSpacing.space6),
                  ),
                  onPressed: () => supportKanban.onOwnerChanged(ticket, member.id),
                  child: Text(_memberLabel(member)),
                ),
              ),
          ],
          child: const Text('Atribuir responsável'),
        ),
        SubmenuButton(
          style: _menuItemStyle(colors),
          menuStyle: menuStyle,
          leadingIcon: const Icon(Icons.group_outlined),
          menuChildren: [
            for (final member in supportKanban.teamMembers)
              Semantics(
                key: Key('support-collaborator-option-${ticket.id}-${member.id}'),
                checked: ticket.collaboratorIds.contains(member.id),
                child: MenuItemButton(
                  closeOnActivate: false,
                  style: _menuItemStyle(
                    colors,
                    checked: ticket.collaboratorIds.contains(member.id),
                  ),
                  leadingIcon: ExcludeSemantics(
                    child: Icon(
                      ticket.collaboratorIds.contains(member.id)
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                    ),
                  ),
                  onPressed: () {
                    final collaborators = Set<String>.of(ticket.collaboratorIds);
                    if (!collaborators.add(member.id)) {
                      collaborators.remove(member.id);
                    }
                    supportKanban.onCollaboratorsChanged(ticket, collaborators);
                  },
                  child: Text(_memberLabel(member)),
                ),
              ),
          ],
          child: const Text('Colaboradores'),
        ),
        const Divider(height: 1),
        SubmenuButton(
          style: _menuItemStyle(colors),
          menuStyle: menuStyle,
          leadingIcon: const Icon(Icons.swap_horiz_rounded),
          menuChildren: [
            for (final status in SupportTicketStatus.values)
              Semantics(
                key: Key('support-status-option-${ticket.id}-${status.name}'),
                selected: ticket.status == status,
                child: MenuItemButton(
                  style: _menuItemStyle(colors, selected: ticket.status == status),
                  leadingIcon: ExcludeSemantics(
                    child: ticket.status == status
                        ? const Icon(Icons.check_rounded)
                        : const SizedBox(width: CoeloSpacing.space6),
                  ),
                  onPressed: () => supportKanban.onStatusChanged(ticket, status),
                  child: Text(_statusLabel(status)),
                ),
              ),
          ],
          child: const Text('Mover para'),
        ),
      ],
      builder: (context, controller, child) => IconButton(
        key: Key('support-card-menu-${ticket.id}'),
        focusNode: _menuFocusNode,
        tooltip: 'Ações de ${ticket.id}',
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
            return;
          }
          _focusOwnerWhenOpened = _menuFocusNode.hasFocus;
          controller.open();
        },
        icon: const Icon(Icons.more_horiz_rounded),
        constraints: const BoxConstraints.tightFor(
          width: CoeloSize.touchMin,
          height: CoeloSize.touchMin,
        ),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            final highlighted =
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed);
            return highlighted ? colors.primary : colors.onSurfaceVariant;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final highlighted =
                states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
            return highlighted ? colors.primaryContainer : Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
          ),
        ),
      ),
    );
  }
}

MenuStyle _menuSurfaceStyle(ColorScheme colors) {
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(colors.surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(CoeloElevation.level2),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
  );
}

ButtonStyle _menuItemStyle(ColorScheme colors, {bool selected = false, bool checked = false}) {
  return MenuItemButton.styleFrom(minimumSize: const Size.fromHeight(CoeloSize.touchMin)).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return selected || checked || highlighted ? colors.primary : colors.onSurface;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return selected || checked || highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      if (highlighted || selected) {
        return colors.primaryContainer;
      }
      return Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
    ),
  );
}

String _statusLabel(SupportTicketStatus status) => switch (status) {
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

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
