import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
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
    required this.onStatusChanged,
    required this.onOwnerChanged,
    required this.onCollaboratorsChanged,
    super.key,
  });

  final List<SupportTicket> tickets;
  final List<SupportTeamMember> teamMembers;
  final String? selectedTicketId;
  final SupportTicketOpenCallback onTicketPressed;
  final SupportStatusChangeCallback onStatusChanged;
  final SupportOwnerChangeCallback onOwnerChanged;
  final SupportCollaboratorsChangeCallback onCollaboratorsChanged;

  @override
  State<SupportKanban> createState() => _SupportKanbanState();
}

final class _SupportKanbanState extends State<SupportKanban> {
  final _cardFocusNodes = <String, FocusNode>{};
  SupportTicketStatus _compactStatus = SupportTicketStatus.newRequest;
  String? _highlightedTicketId;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
          return Column(
            children: [
              DropdownButton<SupportTicketStatus>(
                key: const Key('support-compact-status'),
                value: _compactStatus,
                isExpanded: true,
                items: [
                  for (final status in SupportTicketStatus.values)
                    DropdownMenuItem(value: status, child: Text(_statusLabel(status))),
                ],
                onChanged: (status) {
                  if (status != null) {
                    setState(() => _compactStatus = status);
                  }
                },
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Expanded(child: _lane(_compactStatus)),
            ],
          );
        }

        const laneWidth = 280.0;
        final boardWidth =
            SupportTicketStatus.values.length * laneWidth +
            (SupportTicketStatus.values.length - 1) * CoeloSpacing.space2;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(boardWidth, constraints.maxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < SupportTicketStatus.values.length; index++) ...[
                  SizedBox(width: laneWidth, child: _lane(SupportTicketStatus.values[index])),
                  if (index != SupportTicketStatus.values.length - 1)
                    const SizedBox(width: CoeloSpacing.space2),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _lane(SupportTicketStatus status) {
    final items = widget.tickets.where((ticket) => ticket.status == status).toList(growable: false);
    final statusColors = _statusColors(context, status);
    return DragTarget<SupportTicket>(
      key: Key('support-kanban-${status.name}'),
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) => widget.onStatusChanged(details.data, status),
      builder: (context, candidates, rejected) {
        final colors = Theme.of(context).colorScheme;
        final highlighted = candidates.isNotEmpty;
        return Semantics(
          container: true,
          label: '${_statusLabel(status)}, ${items.length} chamados',
          child: AnimatedContainer(
            duration: CoeloMotion.fast,
            decoration: BoxDecoration(
              color: highlighted ? colors.primaryContainer : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              border: Border.all(
                color: highlighted ? colors.primary : colors.outlineVariant,
                width: highlighted ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: CoeloSpacing.space1,
                  decoration: BoxDecoration(
                    color: statusColors.$2,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(CoeloRadius.lg)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _statusLabel(status),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: CoeloSpacing.space6),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: CoeloSpacing.space2,
                          vertical: CoeloSpacing.space1,
                        ),
                        decoration: BoxDecoration(
                          color: statusColors.$1,
                          borderRadius: BorderRadius.circular(CoeloRadius.full),
                        ),
                        child: Text(
                          '${items.length}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: statusColors.$2),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(CoeloSpacing.space4),
                            child: Text(
                              'Nenhum chamado',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            CoeloSpacing.space2,
                            0,
                            CoeloSpacing.space2,
                            CoeloSpacing.space2,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space2),
                          itemBuilder: (context, index) => _draggableCard(items[index]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _draggableCard(SupportTicket ticket) {
    return LongPressDraggable<SupportTicket>(
      data: ticket,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 264, child: _ticketCard(ticket, feedback: true)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _ticketCard(ticket)),
      child: _ticketCard(ticket),
    );
  }

  Widget _ticketCard(SupportTicket ticket, {bool feedback = false}) {
    final colors = Theme.of(context).colorScheme;
    final selected = widget.selectedTicketId == ticket.id;
    final highlighted = _highlightedTicketId == ticket.id;
    final breadcrumb = ticket.requesterContext?.breadcrumb ?? '';
    final unreadCount = ticket.messages
        .where(
          (message) => message.author == SupportMessageAuthor.requester && !message.isReadBySupport,
        )
        .length;
    final focusNode = feedback ? null : _focusNodeFor(ticket);

    return Material(
      color: selected || highlighted ? colors.primaryContainer : colors.surface,
      elevation: feedback ? 6 : 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
      ),
      child: InkWell(
        key: feedback ? null : Key('support-card-${ticket.id}'),
        focusNode: focusNode,
        onTap: feedback
            ? null
            : () => widget.onTicketPressed(ticket, () => _restoreCardFocus(ticket.id, focusNode!)),
        onHover: feedback
            ? null
            : (value) => setState(() => _highlightedTicketId = value ? ticket.id : null),
        onFocusChange: feedback
            ? null
            : (value) => setState(() => _highlightedTicketId = value ? ticket.id : null),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.id,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: highlighted ? colors.primary : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!feedback) _CardMenu(ticket: ticket, widget: widget),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                ticket.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: highlighted ? colors.primary : colors.onSurface,
                ),
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                ticket.description,
                key: feedback ? null : Key('support-card-description-${ticket.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(ticket.requester, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (breadcrumb.isNotEmpty) ...[
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  breadcrumb,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                '${ticket.menu} > ${ticket.screen}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                'Atualizado em ${_dateTime(ticket.updatedAt)}',
                key: feedback ? null : Key('support-card-updated-${ticket.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SupportAssigneeView(
                        ownerId: ticket.ownerId,
                        collaboratorIds: ticket.collaboratorIds,
                        teamMembers: widget.teamMembers,
                      ),
                    ),
                  ),
                  if (ticket.attachments.isNotEmpty) ...[
                    Icon(
                      Icons.attach_file_rounded,
                      size: CoeloSpacing.space4,
                      color: colors.onSurfaceVariant,
                    ),
                    Text('${ticket.attachments.length}'),
                  ],
                  if (unreadCount > 0) ...[
                    const SizedBox(width: CoeloSpacing.space2),
                    Icon(
                      Icons.mark_chat_unread_outlined,
                      size: CoeloSpacing.space4,
                      color: colors.primary,
                    ),
                    Text('$unreadCount'),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
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
        SubmenuButton(
          focusNode: _ownerMenuFocusNode,
          style: _menuItemStyle(colors),
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

(Color, Color) _statusColors(BuildContext context, SupportTicketStatus status) {
  final colors = Theme.of(context).extension<CoeloStatusColors>()!;
  return switch (status) {
    SupportTicketStatus.newRequest => (colors.infoContainer, colors.onInfoContainer),
    SupportTicketStatus.inProgress => (colors.warningContainer, colors.onWarningContainer),
    SupportTicketStatus.waitingRequester => (colors.errorContainer, colors.onErrorContainer),
    SupportTicketStatus.completed => (colors.successContainer, colors.onSuccessContainer),
  };
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
