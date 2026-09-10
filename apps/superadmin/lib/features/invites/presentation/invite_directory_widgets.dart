import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';
import '../domain/platform_invite.dart';
import 'invite_presentation_support.dart';

enum InviteRowAction { details, resend, revoke }

enum InviteDirectoryTableView { all }

/// Ações de arquivo de Convites para o `CoeloAdminDirectory` (adiadas no MVP).
List<CoeloAdminFileAction> inviteFileActions(BuildContext context) {
  void unavailable(String operation) {
    showSuperadminNotice(
      context,
      '$operation de convites ainda não está disponível.',
      icon: Icons.info_outline_rounded,
    );
  }

  return [
    CoeloAdminFileAction(
      key: const Key('invite-files-import'),
      label: 'Importar',
      icon: Icons.upload_file_outlined,
      onPressed: () => unavailable('Importação'),
    ),
    CoeloAdminFileAction(
      key: const Key('invite-files-export-csv'),
      label: 'Exportar CSV',
      icon: Icons.table_rows_outlined,
      onPressed: () => unavailable('Exportação'),
    ),
    CoeloAdminFileAction(
      key: const Key('invite-files-export-xlsx'),
      label: 'Exportar XLSX',
      icon: Icons.grid_on_outlined,
      onPressed: () => unavailable('Exportação'),
    ),
  ];
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
      final cards = <Widget>[
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
            child: InviteCard(
              invite: invite,
              busy: busyInviteId == invite.id,
              onOpen: onOpen == null ? null : () => onOpen!(invite.id),
              allowCommands: allowCommands,
              onSelected: (action) => onAction(invite, action),
            ),
          ),
      ];
      // Match each row's content height, including enlarged text, while keeping
      // the approved directory widths, gaps and canonical card surfaces.
      return Column(
        key: const Key('invite-card-grid'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var start = 0; start < cards.length; start += columns) ...[
            if (start > 0) const SizedBox(height: CoeloSpacing.space6),
            Table(
              // ponytail: fixed columns avoid intrinsic width measurement of
              // the LayoutBuilder used by the canonical status indicator.
              defaultColumnWidth: FixedColumnWidth(cardWidth),
              defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
              columnWidths: {
                for (var gap = 1; gap < columns * 2 - 1; gap += 2)
                  gap: const FixedColumnWidth(CoeloSpacing.space6),
              },
              children: [
                TableRow(
                  children: [
                    for (
                      var index = start;
                      index < cards.length && index < start + columns;
                      index++
                    ) ...[
                      if (index > start) const SizedBox(width: CoeloSpacing.space6),
                      cards[index],
                    ],
                  ],
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

/// Card de domínio de um convite; largura, grade e o Criar vêm do composto.
final class InviteCard extends StatelessWidget {
  const InviteCard({
    required this.invite,
    required this.busy,
    required this.onOpen,
    required this.allowCommands,
    required this.onSelected,
    super.key,
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
            Text(invite.channelLabel, style: theme.textTheme.labelMedium),
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

/// Linhas e colunas de domínio de Convites sobre a tabela compartilhada.
final class InviteTableRows extends StatelessWidget {
  const InviteTableRows({
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
          builder: (context, invite) => _cell(Text(invite.channelLabel)),
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
