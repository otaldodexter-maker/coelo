import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/platform_invite.dart';

final class InviteStatusChip extends StatelessWidget {
  const InviteStatusChip({required this.status, super.key});

  final InviteStatus status;

  @override
  Widget build(BuildContext context) {
    final statusColors =
        Theme.of(context).extension<CoeloStatusColors>() ??
        (Theme.brightnessOf(context) == Brightness.dark
            ? CoeloStatusColors.dark
            : CoeloStatusColors.light);
    final (background, foreground, icon) = switch (status) {
      InviteStatus.pending => (
        statusColors.warningContainer,
        statusColors.onWarningContainer,
        Icons.schedule_rounded,
      ),
      InviteStatus.accepted => (
        statusColors.successContainer,
        statusColors.onSuccessContainer,
        Icons.check_circle_outline_rounded,
      ),
      InviteStatus.expired => (
        statusColors.historyContainer,
        statusColors.onHistoryContainer,
        Icons.history_rounded,
      ),
      InviteStatus.revoked => (
        statusColors.errorContainer,
        statusColors.onErrorContainer,
        Icons.block_rounded,
      ),
    };
    return CoeloStatusChip(
      label: status.label,
      icon: icon,
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}

Future<bool> showInviteRevokeConfirmation(
  BuildContext context, {
  required String recipientMasked,
}) async {
  final colors = Theme.of(context).colorScheme;
  final overlay = Theme.of(context).extension<CoeloOverlayColors>();
  return await showDialog<bool>(
        context: context,
        barrierColor: overlay?.scrim ?? Colors.black54,
        builder: (dialogContext) => CoeloAdminDialogShell(
          dialogKey: const Key('invite-revoke-dialog'),
          closeButtonKey: const Key('invite-revoke-dialog-close'),
          title: 'Revogar convite?',
          body: Text(
            'O convite para $recipientMasked deixará de poder ser aceito. Esta ação será registrada na auditoria.',
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            key: const Key('invite-revoke-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revogar convite'),
          ),
        ),
      ) ??
      false;
}

String formatInviteDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} · $hour:$minute';
}
