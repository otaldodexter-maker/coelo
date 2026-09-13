import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/chat_repository.dart';

enum _InlineMediaState { loading, available, failed, expired, unavailable }

/// Inline image for a chat attachment that has already been authorized by its thread.
///
/// The URL exists only in memory and is discarded when its session or ticket expires.
final class SuperadminChatInlineMedia extends StatefulWidget {
  const SuperadminChatInlineMedia({
    required this.attachment,
    required this.attachmentRepository,
    required this.session,
    super.key,
  });

  final ChatAttachment attachment;
  final ChatAttachmentRepository attachmentRepository;
  final MediaSession session;

  @override
  State<SuperadminChatInlineMedia> createState() => _SuperadminChatInlineMediaState();
}

final class _SuperadminChatInlineMediaState extends State<SuperadminChatInlineMedia> {
  NetworkImage? _image;
  Timer? _expiry;
  void Function()? _unregister;
  var _generation = 0;
  var _state = _InlineMediaState.loading;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant SuperadminChatInlineMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.attachmentRepository != widget.attachmentRepository ||
        oldWidget.session != widget.session) {
      _unregister?.call();
      _bind();
    }
  }

  void _bind() {
    _generation++;
    unawaited(_clear());
    if (widget.session.isInvalidated) {
      _state = _InlineMediaState.unavailable;
      return;
    }
    _unregister = widget.session.registerPurge(() async {
      _generation++;
      await _clear();
      if (mounted) setState(() => _state = _InlineMediaState.unavailable);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.session.isInvalidated) unawaited(_read());
    });
  }

  Future<void> _read() async {
    if (widget.session.isInvalidated) return;
    final generation = ++_generation;
    await _clear();
    if (!mounted || generation != _generation || widget.session.isInvalidated) return;
    setState(() => _state = _InlineMediaState.loading);
    try {
      final ticket = await widget.attachmentRepository.readAttachment(widget.attachment.id);
      if (!mounted || generation != _generation || widget.session.isInvalidated) return;
      final now = DateTime.now().toUtc();
      if (!ticket.expiresAt.isAfter(now)) {
        setState(() => _state = _InlineMediaState.expired);
        return;
      }
      setState(() {
        _image = NetworkImage(ticket.url.toString());
        _state = _InlineMediaState.available;
        _expiry = Timer(ticket.expiresAt.difference(now), _expire);
      });
    } catch (_) {
      if (mounted && generation == _generation && !widget.session.isInvalidated) {
        setState(() => _state = _InlineMediaState.failed);
      }
    }
  }

  void _expire() {
    unawaited(_clear());
    if (mounted && !widget.session.isInvalidated) {
      setState(() => _state = _InlineMediaState.expired);
    }
  }

  Future<void> _clear() async {
    _expiry?.cancel();
    _expiry = null;
    final previous = _image;
    _image = null;
    if (previous != null) await previous.evict();
  }

  @override
  void dispose() {
    _generation++;
    _unregister?.call();
    unawaited(_clear());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_state) {
      _InlineMediaState.loading => const _InlineMediaMessage('Carregando imagem…'),
      _InlineMediaState.failed => _InlineMediaMessage(
        'Não foi possível carregar a imagem. Tente novamente.',
        onRetry: _read,
      ),
      _InlineMediaState.expired => _InlineMediaMessage(
        'A visualização expirou. Carregue novamente.',
        onRetry: _read,
      ),
      _InlineMediaState.unavailable => const _InlineMediaMessage(
        'Visualização indisponível neste contexto.',
      ),
      _InlineMediaState.available =>
        _image == null
            ? const _InlineMediaMessage('Carregando imagem…')
            : ClipRRect(
                borderRadius: BorderRadius.circular(CoeloRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
                  child: Image(
                    key: Key('superadmin-chat-inline-image-${widget.attachment.id}'),
                    image: _image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _InlineMediaMessage(
                      'Não foi possível carregar a imagem. Tente novamente.',
                      onRetry: _read,
                    ),
                  ),
                ),
              ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: CoeloSpacing.space2),
      child: Semantics(
        image: _state == _InlineMediaState.available,
        label: 'Imagem anexa: ${widget.attachment.fileName}',
        child: content,
      ),
    );
  }
}

final class _InlineMediaMessage extends StatelessWidget {
  const _InlineMediaMessage(this.message, {this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message, style: Theme.of(context).textTheme.labelSmall),
      if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Carregar novamente')),
    ],
  );
}
