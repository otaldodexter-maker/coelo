import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/chat_repository.dart';

enum SuperadminChatAttachmentState { pending, ready, failed, deleted }

/// Renders metadata already authorised by the chat backend.
///
/// This component deliberately does not follow [ChatAttachment.downloadUrl].
/// Download authorisation remains an explicit, server-authorised action owned
/// by the calling flow.
final class SuperadminChatAttachmentTile extends StatelessWidget {
  const SuperadminChatAttachmentTile({
    required this.attachment,
    required this.state,
    this.onRetry,
    super.key,
  });

  final ChatAttachment attachment;
  final SuperadminChatAttachmentState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = _AttachmentStatus.from(state, colors);
    final canRetry = state == SuperadminChatAttachmentState.failed && onRetry != null;
    return Semantics(
      container: true,
      label:
          '${attachment.fileName}. ${attachment.mediaType}. '
          '${_formatByteSize(attachment.byteSize)}. ${status.semanticsLabel}',
      child: Container(
        key: Key('superadmin-chat-attachment-${attachment.id}'),
        constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
        padding: const EdgeInsetsDirectional.fromSTEB(
          CoeloSpacing.space2,
          CoeloSpacing.space1,
          CoeloSpacing.space1,
          CoeloSpacing.space1,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.md),
        ),
        child: Row(
          children: [
            Icon(_iconFor(attachment.mediaType), color: colors.onSurfaceVariant),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(
              child: Tooltip(
                message: attachment.fileName,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: CoeloSpacing.spaceHalf),
                    Text(
                      '${attachment.mediaType} \u00b7 ${_formatByteSize(attachment.byteSize)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: CoeloSpacing.spaceHalf),
                    Text(
                      status.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: status.color),
                    ),
                  ],
                ),
              ),
            ),
            if (canRetry)
              IconButton(
                tooltip: 'Tentar novamente',
                onPressed: onRetry,
                color: colors.error,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? colors.errorContainer
                        : Colors.transparent,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String mediaType) {
  if (mediaType.startsWith('image/')) return Icons.image_outlined;
  if (mediaType.startsWith('video/')) return Icons.video_file_outlined;
  if (mediaType.startsWith('audio/')) return Icons.audio_file_outlined;
  return Icons.description_outlined;
}

String _formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  for (var index = 0; index < units.length; index += 1) {
    if (value < 1024 || index == units.length - 1) {
      final digits = value >= 10 || value == value.roundToDouble() ? 0 : 1;
      return '${value.toStringAsFixed(digits).replaceAll('.', ',')} ${units[index]}';
    }
    value /= 1024;
  }
  return '$bytes B';
}

final class _AttachmentStatus {
  const _AttachmentStatus({required this.label, required this.semanticsLabel, required this.color});

  factory _AttachmentStatus.from(SuperadminChatAttachmentState state, ColorScheme colors) {
    return switch (state) {
      SuperadminChatAttachmentState.pending => _AttachmentStatus(
        label: 'Envio pendente',
        semanticsLabel: 'Envio pendente',
        color: colors.primary,
      ),
      SuperadminChatAttachmentState.ready => _AttachmentStatus(
        label: 'Pronto para enviar',
        semanticsLabel: 'Pronto para enviar',
        color: colors.primary,
      ),
      SuperadminChatAttachmentState.failed => _AttachmentStatus(
        label: 'Falha no envio',
        semanticsLabel: 'Falha no envio',
        color: colors.error,
      ),
      SuperadminChatAttachmentState.deleted => _AttachmentStatus(
        label: 'Anexo removido',
        semanticsLabel: 'Anexo removido',
        color: colors.onSurfaceVariant,
      ),
    };
  }

  final String label;
  final String semanticsLabel;
  final Color color;
}
