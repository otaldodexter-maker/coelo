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
    final textColor = _toneToColor(notice.textTone, forText: true);
    final backgroundColor = _toneToColor(notice.backgroundTone);
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
          if (requiresCheckbox) ...[
            const SizedBox(height: 12),
            CoeloAdminToggleField(
              key: const Key('notice-acknowledgement'),
              label: 'Li e estou ciente deste aviso.',
              value: _checked,
              onChanged: (value) => setState(() => _checked = value),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 6),
                Text(notice.message, style: TextStyle(color: textColor)),
              ],
            ),
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

Color _toneToColor(NoticeVisualTone tone, {bool forText = false}) => switch (tone) {
  NoticeVisualTone.brand => forText ? const Color(0xFFFFF8F3) : const Color(0xFFD63C00),
  NoticeVisualTone.dark => forText ? const Color(0xFFF5F5F5) : const Color(0xFF3F4549),
  NoticeVisualTone.light => forText ? const Color(0xFF3F4549) : const Color(0xFFF9F9F9),
  NoticeVisualTone.neutral => forText ? const Color(0xFF202427) : const Color(0xFFECEDED),
  NoticeVisualTone.success => forText ? const Color(0xFFF6FFF6) : const Color(0xFF2E7D32),
  NoticeVisualTone.warning => forText ? const Color(0xFF3D2800) : const Color(0xFFFFB300),
  NoticeVisualTone.danger => forText ? const Color(0xFFFFF2F2) : const Color(0xFFD32F2F),
};
