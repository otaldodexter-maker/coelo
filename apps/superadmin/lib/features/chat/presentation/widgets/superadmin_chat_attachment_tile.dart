import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/chat_repository.dart';
import 'superadmin_chat_image_dialog.dart';

enum SuperadminChatAttachmentState { pending, ready, failed, deleted }

/// Renders metadata already authorised by the chat backend.
///
/// This component deliberately does not follow [ChatAttachment.downloadUrl].
/// Download authorisation remains an explicit, server-authorised action owned
/// by the calling flow.
final class SuperadminChatAttachmentTile extends StatefulWidget {
  const SuperadminChatAttachmentTile({
    required this.attachment,
    required this.state,
    this.onRetry,
    this.mediaReader,
    this.mediaSession,
    super.key,
  });

  final ChatAttachment attachment;
  final SuperadminChatAttachmentState state;
  final VoidCallback? onRetry;
  final MediaReader? mediaReader;
  final MediaSession? mediaSession;

  @override
  State<SuperadminChatAttachmentTile> createState() => _SuperadminChatAttachmentTileState();
}

final class _SuperadminChatAttachmentTileState extends State<SuperadminChatAttachmentTile> {
  final _openFocus = FocusNode(debugLabel: 'chat-open-image');
  DialogRoute<void>? _imageRoute;
  int _openingGeneration = 0;
  void Function()? _unregister;

  ChatAttachment get attachment => widget.attachment;
  SuperadminChatAttachmentState get state => widget.state;
  VoidCallback? get onRetry => widget.onRetry;

  @override
  void initState() {
    super.initState();
    _bindSession();
  }

  void _bindSession() {
    final session = widget.mediaSession;
    if (session != null && !session.isInvalidated) {
      _unregister = session.registerPurge(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant SuperadminChatAttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != attachment.id ||
        oldWidget.attachment.assetId != attachment.assetId ||
        oldWidget.state != state ||
        oldWidget.mediaReader != widget.mediaReader ||
        oldWidget.mediaSession != widget.mediaSession) {
      _dismissOwnedImage();
      _unregister?.call();
      _bindSession();
    }
  }

  void _dismissOwnedImage() {
    _openingGeneration++;
    final route = _imageRoute;
    _imageRoute = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  bool get _canOpen {
    final id = attachment.assetId;
    if (id == null ||
        widget.mediaReader == null ||
        widget.mediaSession == null ||
        widget.mediaSession!.isInvalidated ||
        state != SuperadminChatAttachmentState.ready) {
      return false;
    }
    try {
      MediaReadRequest(assetId: id, rendition: MediaReadRendition.preview);
      return true;
    } on MediaProtocolException {
      return false;
    }
  }

  Future<void> _openImage() async {
    if (!_canOpen || _imageRoute != null) return;
    final assetId = attachment.assetId!;
    final reader = widget.mediaReader!;
    final session = widget.mediaSession!;
    final generation = ++_openingGeneration;
    final navigator = Navigator.of(context);
    final route = DialogRoute<void>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context) ? AnimationStyle.noAnimation : null,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierColor:
          DialogTheme.of(context).barrierColor ??
          Theme.of(context).dialogTheme.barrierColor ??
          Colors.black54,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (_) => !mounted || generation != _openingGeneration
          ? const SizedBox.shrink()
          : SuperadminChatImageDialog(
              assetId: assetId,
              reader: reader,
              session: session,
              isContextCurrent: () => mounted && generation == _openingGeneration,
            ),
    );
    _imageRoute = route;
    await navigator.push(route);
    if (mounted && identical(_imageRoute, route)) {
      _imageRoute = null;
      if (_canOpen) _openFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _unregister?.call();
    _dismissOwnedImage();
    _openFocus.dispose();
    super.dispose();
  }

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
                    if (const {
                          'image/jpeg',
                          'image/png',
                          'image/webp',
                        }.contains(attachment.mediaType) &&
                        state == SuperadminChatAttachmentState.ready) ...[
                      TextButton(
                        focusNode: _openFocus,
                        onPressed: _canOpen ? _openImage : null,
                        child: const Text('Abrir imagem'),
                      ),
                      if (!_canOpen)
                        Text(
                          'Visualização indisponível neste contexto.',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
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
