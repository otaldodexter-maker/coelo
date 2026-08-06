import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../domain/platform_notice.dart';
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
    final requiresCheckbox = notice.behavior == NoticeBehavior.checkboxConfirmation;
    final isDismissible = notice.behavior == NoticeBehavior.dismissible;
    return CoeloAdminDialogShell(
      dialogKey: const Key('notice-preview-dialog'),
      title: notice.title,
      closeTooltip: notice.mandatory ? 'Sair da simulação' : 'Fechar aviso',
      onClose: () => Navigator.of(context).pop(),
      body: NoticePopupPreview(
        notice: notice,
        device: notice.targetDevice,
        checkboxChecked: _checked,
        onCheckboxChanged: requiresCheckbox ? (value) => setState(() => _checked = value) : null,
      ),
      primaryAction: FilledButton(
        onPressed: requiresCheckbox && !_checked
            ? null
            : () {
                if (!isDismissible) widget.onAccepted?.call();
                Navigator.of(context).pop();
              },
        child: Text(isDismissible ? 'Fechar' : notice.buttonLabel),
      ),
    );
  }
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
