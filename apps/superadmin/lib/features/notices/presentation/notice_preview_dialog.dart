import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../domain/platform_notice.dart';

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
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice.message),
          if (notice.linkLabel != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(notice.linkLabel!),
            ),
          ],
          if (requiresCheckbox)
            CheckboxListTile(
              value: _checked,
              onChanged: (value) => setState(() => _checked = value ?? false),
              contentPadding: EdgeInsets.zero,
              title: const Text('Li e estou ciente deste aviso.'),
            ),
        ],
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
