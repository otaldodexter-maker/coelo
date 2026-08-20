import 'package:flutter/material.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';

import '../domain/platform_notice.dart';
import 'communication_type_badge.dart';
import 'notice_popup_preview.dart';

final class NoticePreviewDialog extends StatefulWidget {
  const NoticePreviewDialog({required this.notice, this.onAccepted, super.key});

  final PlatformNotice notice;
  final VoidCallback? onAccepted;

  @override
  State<NoticePreviewDialog> createState() => _NoticePreviewDialogState();
}

final class _NoticePreviewDialogState extends State<NoticePreviewDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    if (!notice.isPopup) {
      return CoeloAdminDialogShell(
        key: const Key('communication-card-preview'),
        title: 'Prévia administrativa',
        body: CommunicationPreviewCard(notice: notice),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      );
    }
    final fullscreen = notice.popupSize == NoticePopupSize.fullscreen;
    final preview = NoticePopupPreview(
      notice: notice,
      device: notice.targetDevice,
      checkboxChecked: _checked,
      onCheckboxChanged: notice.behavior == NoticeBehavior.checkboxConfirmation
          ? (value) => setState(() => _checked = value)
          : null,
      onClose: () => Navigator.of(context).pop(),
      onPrimaryPressed: () {
        if (notice.behavior != NoticeBehavior.dismissible) widget.onAccepted?.call();
        Navigator.of(context).pop();
      },
    );

    if (fullscreen) {
      return Dialog.fullscreen(
        key: const Key('notice-preview-dialog-fullscreen'),
        backgroundColor: Colors.transparent,
        child: preview,
      );
    }
    return Dialog(
      key: const Key('notice-preview-dialog'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: notice.hasOuterInset ? null : EdgeInsets.zero,
      child: preview,
    );
  }
}

final class CommunicationPreviewCard extends StatelessWidget {
  const CommunicationPreviewCard({required this.notice, super.key});

  final PlatformNotice notice;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Prévia administrativa de ${notice.type.label}.',
    child: CoeloAdminInteractiveCard(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommunicationTypeBadge(type: notice.type),
            const SizedBox(height: CoeloSpacing.space4),
            Text(notice.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CoeloSpacing.space2),
            Text(notice.message),
            const SizedBox(height: CoeloSpacing.space4),
            Text(
              '${notice.audienceLabel} · ${notice.priority.label} · ${notice.recurrenceLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              'Prévia administrativa para conferência de conteúdo e distribuição.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showNoticePreview(
  BuildContext context,
  PlatformNotice notice, {
  VoidCallback? onAccepted,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black54,
  builder: (_) => NoticePreviewDialog(notice: notice, onAccepted: onAccepted),
);
