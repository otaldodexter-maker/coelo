import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/platform_invite.dart';
import 'invite_presentation_support.dart';

enum InviteRowAction { details, resend, revoke }

final class InviteDirectoryToolbar extends StatelessWidget {
  const InviteDirectoryToolbar({
    required this.searchController,
    required this.statuses,
    required this.channels,
    required this.onSearchChanged,
    required this.onStatusesChanged,
    required this.onChannelsChanged,
    this.onClear,
    super.key,
  });

  final TextEditingController searchController;
  final Set<InviteStatus> statuses;
  final Set<InviteChannel> channels;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Set<InviteStatus>> onStatusesChanged;
  final ValueChanged<Set<InviteChannel>> onChannelsChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final filterWidth = compact
          ? largeText
                ? constraints.maxWidth
                : (constraints.maxWidth - CoeloSpacing.space3) / 2
          : 176.0;
      return CoeloAdminListingToolbar(
        search: SizedBox(
          width: compact ? constraints.maxWidth : 280,
          height: CoeloSize.touchMin,
          child: CoeloSearchField(
            controller: searchController,
            semanticLabel: 'Buscar convites',
            hintText: 'Buscar destinatário',
            onChanged: onSearchChanged,
          ),
        ),
        filters: [
          SizedBox(
            width: filterWidth,
            child: CoeloAdminMultiSelectFilter<InviteStatus>(
              label: 'Status',
              options: InviteStatus.values,
              selectedValues: statuses,
              optionLabel: (value) => value.label,
              onChanged: onStatusesChanged,
            ),
          ),
          SizedBox(
            width: filterWidth,
            child: CoeloAdminMultiSelectFilter<InviteChannel>(
              label: 'Canal',
              options: InviteChannel.values,
              selectedValues: channels,
              optionLabel: (value) => value.label,
              onChanged: onChannelsChanged,
            ),
          ),
          if (onClear != null)
            TextButton.icon(
              key: const Key('invite-clear-filters'),
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
        ],
        actions: const [],
      );
    },
  );
}

final class InviteDirectoryTable extends StatelessWidget {
  const InviteDirectoryTable({
    required this.items,
    required this.busyInviteId,
    required this.onAction,
    this.allowCommands = false,
    this.onOpen,
    super.key,
  });

  final List<PlatformInvite> items;
  final String? busyInviteId;
  final ValueChanged<String>? onOpen;
  final bool allowCommands;
  final void Function(PlatformInvite, InviteRowAction) onAction;

  @override
  Widget build(BuildContext context) {
    final rowHeight = MediaQuery.textScalerOf(context).scale(64).clamp(64, 104).toDouble();
    return CoeloAdminResizableTable<PlatformInvite>(
      key: const Key('invite-table'),
      items: items,
      rowKey: (invite) => 'invite-row-${invite.id}',
      headerHeight: 56,
      rowHeight: rowHeight,
      showHorizontalScrollbar: true,
      onRowPressed: onOpen == null ? null : (invite) => onOpen!(invite.id),
      pinnedColumn: _column(
        id: 'recipient',
        label: 'Destinatário',
        width: 220,
        builder: (context, invite) =>
            _cell(Text(invite.recipientMasked, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ),
      columns: [
        _column(
          id: 'scope',
          label: 'Contexto',
          width: 240,
          builder: (context, invite) => _cell(
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invite.scope.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  invite.profile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        _column(
          id: 'channels',
          label: 'Canais',
          width: 160,
          builder: (context, invite) =>
              _cell(Text(invite.channels.map((value) => value.label).join(' + '))),
        ),
        _column(
          id: 'status',
          label: 'Status',
          width: 150,
          builder: (context, invite) => _cell(InviteStatusChip(status: invite.status)),
        ),
        _column(
          id: 'created',
          label: 'Criado em',
          width: 160,
          builder: (context, invite) => _cell(Text(formatInviteDate(invite.createdAt))),
        ),
        _column(
          id: 'expires',
          label: 'Expira em',
          width: 160,
          builder: (context, invite) => _cell(Text(formatInviteDate(invite.expiresAt))),
        ),
        _column(
          id: 'actions',
          label: 'Ações',
          width: 80,
          builder: (context, invite) => _cell(
            _InviteRowActions(
              invite: invite,
              busy: busyInviteId == invite.id,
              showDetails: onOpen != null,
              allowCommands: allowCommands,
              onSelected: (action) => onAction(invite, action),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _cell(Widget child) => Align(alignment: Alignment.centerLeft, child: child);

  static CoeloAdminTableColumn<PlatformInvite> _column({
    required String id,
    required String label,
    required double width,
    required Widget Function(BuildContext, PlatformInvite) builder,
  }) => CoeloAdminTableColumn<PlatformInvite>(
    id: id,
    label: label,
    initialWidth: width,
    minWidth: width * .75,
    maxWidth: width * 1.35,
    cellBuilder: builder,
  );
}

final class _InviteRowActions extends StatelessWidget {
  const _InviteRowActions({
    required this.invite,
    required this.busy,
    required this.showDetails,
    required this.allowCommands,
    required this.onSelected,
  });

  final PlatformInvite invite;
  final bool busy;
  final bool showDetails;
  final bool allowCommands;
  final ValueChanged<InviteRowAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <CoeloAdminFlyoutItem<InviteRowAction>>[
      if (showDetails)
        const CoeloAdminFlyoutItem(
          value: InviteRowAction.details,
          icon: Icons.visibility_outlined,
          label: 'Ver detalhes',
        ),
      if (allowCommands && invite.canResend)
        const CoeloAdminFlyoutItem(
          value: InviteRowAction.resend,
          icon: Icons.forward_to_inbox_outlined,
          label: 'Reenviar convite',
        ),
      if (allowCommands && invite.canRevoke)
        const CoeloAdminFlyoutItem(
          value: InviteRowAction.revoke,
          icon: Icons.block_rounded,
          label: 'Revogar convite',
          startsGroup: true,
          tone: CoeloAdminFlyoutTone.negative,
        ),
    ];
    return CoeloAdminFlyout<InviteRowAction>(
      items: items,
      onSelected: onSelected,
      builder: (context, controller) => IconButton(
        key: Key('invite-actions-${invite.id}'),
        tooltip: busy ? 'Processando convite' : 'Ações do convite',
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
        ),
        onPressed: busy ? null : () => controller.isOpen ? controller.close() : controller.open(),
        icon: busy
            ? const SizedBox.square(
                dimension: CoeloSize.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}
