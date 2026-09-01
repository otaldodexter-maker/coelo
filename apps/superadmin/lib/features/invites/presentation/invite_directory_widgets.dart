import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../domain/platform_invite.dart';
import 'invite_presentation_support.dart';

enum InviteRowAction { details, resend, revoke }

enum InviteDirectoryDisplay { cards, table }

enum InviteDirectoryTableView { all }

final class InviteDirectoryToolbar extends StatelessWidget {
  const InviteDirectoryToolbar({
    required this.searchController,
    required this.statuses,
    required this.channels,
    required this.onSearchChanged,
    required this.onStatusesChanged,
    required this.onChannelsChanged,
    required this.display,
    required this.onDisplayChanged,
    this.onClear,
    super.key,
  });

  final TextEditingController searchController;
  final Set<InviteStatus> statuses;
  final Set<InviteChannel> channels;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Set<InviteStatus>> onStatusesChanged;
  final ValueChanged<Set<InviteChannel>> onChannelsChanged;
  final InviteDirectoryDisplay display;
  final ValueChanged<InviteDirectoryDisplay> onDisplayChanged;
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
        actions: [
          SuperadminDirectoryViewToggle<InviteDirectoryTableView>(
            key: const Key('invite-display-toggle'),
            cardsKey: const Key('invite-view-cards'),
            tableKey: const Key('invite-view-table'),
            cardsSelected: display == InviteDirectoryDisplay.cards,
            groupedView: InviteDirectoryTableView.all,
            selectedTableView: InviteDirectoryTableView.all,
            tableViews: const [
              SuperadminDirectoryTableViewOption(
                value: InviteDirectoryTableView.all,
                label: 'Todos os convites',
              ),
            ],
            onCardsSelected: () => onDisplayChanged(InviteDirectoryDisplay.cards),
            onTableViewSelected: (_) => onDisplayChanged(InviteDirectoryDisplay.table),
          ),
          _InviteFileActions(compact: compact),
        ],
      );
    },
  );
}

final class _InviteFileActions extends StatelessWidget {
  const _InviteFileActions({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: [
      CoeloAdminFileAction(
        key: const Key('invite-files-import'),
        label: 'Importar',
        icon: Icons.upload_file_outlined,
        onPressed: () => _unavailable(context, 'Importação'),
      ),
      CoeloAdminFileAction(
        key: const Key('invite-files-export-csv'),
        label: 'Exportar CSV',
        icon: Icons.table_rows_outlined,
        onPressed: () => _unavailable(context, 'Exportação'),
      ),
      CoeloAdminFileAction(
        key: const Key('invite-files-export-xlsx'),
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: () => _unavailable(context, 'Exportação'),
      ),
    ],
  );

  void _unavailable(BuildContext context, String operation) {
    showSuperadminNotice(
      context,
      '$operation de convites ainda não está disponível.',
      icon: Icons.info_outline_rounded,
    );
  }
}

final class InviteDirectoryCards extends StatelessWidget {
  const InviteDirectoryCards({
    required this.items,
    required this.busyInviteId,
    required this.onAction,
    this.allowCommands = false,
    this.onCreate,
    this.onOpen,
    super.key,
  });

  final List<PlatformInvite> items;
  final String? busyInviteId;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  final bool allowCommands;
  final void Function(PlatformInvite, InviteRowAction) onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 340).floor().clamp(1, 99);
      final cardWidth = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
      return Wrap(
        key: const Key('invite-card-grid'),
        spacing: CoeloSpacing.space6,
        runSpacing: CoeloSpacing.space6,
        children: [
          if (onCreate != null)
            SizedBox(
              width: cardWidth,
              child: ConstrainedBox(
                key: const Key('invite-create-card'),
                constraints: const BoxConstraints(minHeight: 216),
                child: CoeloAdminCreateAction(
                  label: 'Novo convite',
                  description: 'Escolha contexto, perfil, destinatário e canais.',
                  icon: Icons.mark_email_unread_outlined,
                  onPressed: onCreate!,
                ),
              ),
            ),
          for (final invite in items)
            SizedBox(
              width: cardWidth,
              child: _InviteCard(
                invite: invite,
                busy: busyInviteId == invite.id,
                onOpen: onOpen == null ? null : () => onOpen!(invite.id),
                allowCommands: allowCommands,
                onSelected: (action) => onAction(invite, action),
              ),
            ),
        ],
      );
    },
  );
}

final class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.busy,
    required this.onOpen,
    required this.allowCommands,
    required this.onSelected,
  });

  final PlatformInvite invite;
  final bool busy;
  final VoidCallback? onOpen;
  final bool allowCommands;
  final ValueChanged<InviteRowAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CoeloAdminInteractiveCard(
      key: Key('invite-card-${invite.id}'),
      surfaceKey: Key('invite-card-surface-${invite.id}'),
      minHeight: 216,
      onPressed: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    invite.recipientMasked,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                _InviteCardStatus(inviteId: invite.id, status: invite.status),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Text(invite.scope.label, style: theme.textTheme.bodyMedium),
            Text(
              invite.profile.label,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              invite.channels.map((value) => value.label).join(' + '),
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Expira em ${formatInviteDate(invite.expiresAt)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
                _InviteRowActions(
                  invite: invite,
                  busy: busy,
                  showDetails: onOpen != null,
                  allowCommands: allowCommands,
                  onSelected: onSelected,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _InviteCardStatus extends StatelessWidget {
  const _InviteCardStatus({required this.inviteId, required this.status});

  final String inviteId;
  final InviteStatus status;

  @override
  Widget build(BuildContext context) {
    final statusColors =
        Theme.of(context).extension<CoeloStatusColors>() ??
        (Theme.brightnessOf(context) == Brightness.dark
            ? CoeloStatusColors.dark
            : CoeloStatusColors.light);
    final (background, foreground) = switch (status) {
      InviteStatus.pending => (statusColors.warningContainer, statusColors.onWarningContainer),
      InviteStatus.accepted => (statusColors.successContainer, statusColors.onSuccessContainer),
      InviteStatus.expired => (statusColors.historyContainer, statusColors.onHistoryContainer),
      InviteStatus.revoked => (statusColors.errorContainer, statusColors.onErrorContainer),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: status.label,
      backgroundColor: background,
      foregroundColor: foreground,
      semanticLabel: 'Status: ${status.label}',
      surfaceKey: Key('invite-card-status-$inviteId'),
    );
  }
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
