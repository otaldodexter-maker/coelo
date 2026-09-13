import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/chat_repository.dart';

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
  int _generation = 0;

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
    final generation = ++_generation;
    unawaited(_clear());
    if (widget.session.isInvalidated) return;
    _unregister = widget.session.registerPurge(() async {
      _generation++;
      await _clear();
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation && !widget.session.isInvalidated) {
        unawaited(_read(generation));
      }
    });
  }

  Future<void> _read(int generation) async {
    try {
      final ticket = await widget.attachmentRepository.readAttachment(widget.attachment.id);
      if (!mounted || generation != _generation || widget.session.isInvalidated) return;
      final now = DateTime.now().toUtc();
      if (!ticket.expiresAt.isAfter(now)) {
        return;
      }
      setState(() {
        _image = NetworkImage(ticket.url.toString());
        _expiry = Timer(ticket.expiresAt.difference(now), () {
          unawaited(_clear());
          if (mounted) setState(() {});
        });
      });
    } catch (_) {
      // The attachment remains available through its explicit viewer and retry path.
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
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: CoeloSpacing.space2),
      child: Semantics(
        image: true,
        label: 'Imagem anexa: ${widget.attachment.fileName}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
            child: Image(
              key: Key('superadmin-chat-inline-image-${widget.attachment.id}'),
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
