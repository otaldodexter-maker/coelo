import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../core/platform/open_download.dart';
import '../../chat/domain/chat_repository.dart';
import '../../chat/presentation/widgets/chat_image_preview.dart';

/// Principal presentation for a binding already authorised by the thread.
final class PrincipalChatAttachmentTile extends StatefulWidget {
  const PrincipalChatAttachmentTile({required this.attachment, this.repository, super.key});
  final ChatAttachment attachment;
  final ChatAttachmentRepository? repository;

  @override
  State<PrincipalChatAttachmentTile> createState() => _PrincipalChatAttachmentTileState();
}

final class _PrincipalChatAttachmentTileState extends State<PrincipalChatAttachmentTile> {
  MediaSession _session = MediaSession();
  DialogRoute<void>? _route;
  final _focus = FocusNode(debugLabel: 'principal-chat-attachment');
  int _generation = 0;
  bool _opening = false;
  String? _error;

  bool get _isImage =>
      const {'image/png', 'image/jpeg', 'image/webp'}.contains(widget.attachment.mediaType);
  bool get _supported => _isImage || widget.attachment.mediaType == 'application/pdf';

  void _reset() {
    _generation++;
    _opening = false;
    _error = null;
    unawaited(_session.invalidate());
    final route = _route;
    _route = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PrincipalChatAttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.attachment.mediaType != widget.attachment.mediaType ||
        !identical(oldWidget.repository, widget.repository)) {
      _reset();
      _session = MediaSession();
    }
  }

  Future<void> _open() async {
    final repository = widget.repository;
    if (repository == null || !_supported || _opening || _session.isInvalidated) return;
    final generation = _generation;
    final session = _session;
    bool isCurrent() => mounted && generation == _generation && !session.isInvalidated;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      if (_isImage) {
        final navigator = Navigator.of(context);
        final bindingId = widget.attachment.id;
        final route = DialogRoute<void>(
          context: context,
          themes: InheritedTheme.capture(from: context, to: navigator.context),
          animationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
          builder: (_) => !isCurrent()
              ? const SizedBox.shrink()
              : ChatImagePreview.attachment(
                  attachmentId: bindingId,
                  attachmentRepository: repository,
                  session: session,
                  isContextCurrent: isCurrent,
                  frameBuilder: _imageFrame,
                ),
        );
        _route = route;
        await navigator.push(route);
        if (isCurrent()) _route = null;
      } else {
        final ticket = await repository.readAttachment(widget.attachment.id);
        if (!isCurrent()) return;
        if (!ticket.expiresAt.isAfter(DateTime.now().toUtc()) ||
            !await openDownloadUrl(ticket.url.toString())) {
          throw const ChatFailureException();
        }
      }
    } catch (_) {
      if (isCurrent()) {
        setState(() => _error = 'Não foi possível abrir o arquivo. Tente novamente.');
      }
    } finally {
      if (isCurrent()) {
        setState(() => _opening = false);
        _focus.requestFocus();
      }
    }
  }

  Widget _imageFrame(
    BuildContext context,
    Widget body,
    VoidCallback close,
    VoidCallback? retry,
  ) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 720, maxHeight: MediaQuery.sizeOf(context).height * .8),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Imagem da conversa', style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: close,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Flexible(child: body),
            const SizedBox(height: CoeloSpacing.space3),
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                TextButton(onPressed: close, child: const Text('Fechar')),
                if (retry != null)
                  FilledButton(onPressed: retry, child: const Text('Tentar novamente')),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _reset();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('principal-chat-attachment-${widget.attachment.id}'),
    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.attachment.fileName, style: Theme.of(context).textTheme.labelLarge),
        Text(
          '${_isImage
              ? 'Imagem'
              : widget.attachment.mediaType == 'application/pdf'
              ? 'PDF'
              : 'Arquivo'} · ${(widget.attachment.byteSize / 1024).ceil()} KB',
        ),
        if (_supported)
          TextButton(
            focusNode: _focus,
            onPressed: widget.repository == null || _opening ? null : _open,
            child: Text(
              _opening
                  ? 'Abrindo…'
                  : _isImage
                  ? 'Abrir imagem'
                  : 'Abrir PDF',
            ),
          ),
        if (widget.repository == null) const Text('Visualização indisponível neste contexto.'),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
      ],
    ),
  );
}
