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

Future<void> showNoticePreview(
  BuildContext context,
  PlatformNotice notice, {
  VoidCallback? onAccepted,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black54,
  builder: (_) => NoticePreviewDialog(notice: notice, onAccepted: onAccepted),
);
