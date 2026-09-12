import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/chat_repository.dart';
import 'chat_image_preview.dart';

final class SuperadminChatImageDialog extends StatelessWidget {
  const SuperadminChatImageDialog({
    required this.assetId,
    required this.reader,
    required this.session,
    this.isContextCurrent,
    super.key,
  }) : attachmentId = null,
       attachmentRepository = null;

  const SuperadminChatImageDialog.attachment({
    required this.attachmentId,
    required this.attachmentRepository,
    required this.session,
    this.isContextCurrent,
    super.key,
  }) : assetId = null,
       reader = null;

  final String? assetId;
  final MediaReader? reader;
  final String? attachmentId;
  final ChatAttachmentRepository? attachmentRepository;
  final MediaSession session;
  final bool Function()? isContextCurrent;

  @override
  Widget build(BuildContext context) => attachmentRepository != null
      ? ChatImagePreview.attachment(
          attachmentId: attachmentId,
          attachmentRepository: attachmentRepository,
          session: session,
          isContextCurrent: isContextCurrent,
          frameBuilder: _frame,
        )
      : ChatImagePreview(
          assetId: assetId,
          reader: reader,
          session: session,
          isContextCurrent: isContextCurrent,
          frameBuilder: _frame,
        );

  Widget _frame(BuildContext context, Widget body, VoidCallback close, VoidCallback? retry) {
    final closeButton = OutlinedButton(
      onPressed: close,
      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      child: const Text('Fechar'),
    );
    return CoeloAdminDialogShell(
      title: 'Imagem da conversa',
      onClose: close,
      primaryAction: retry == null
          ? closeButton
          : FilledButton(onPressed: retry, child: const Text('Tentar novamente')),
      secondaryAction: retry == null ? null : closeButton,
      body: body,
    );
  }
}
