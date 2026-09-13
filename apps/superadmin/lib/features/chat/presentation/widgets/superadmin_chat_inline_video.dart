import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/chat_repository.dart';

enum _InlineVideoState { loading, available, failed, expired, unavailable }

/// Private MP4 playback. Every ticket is reauthorized by attachment binding.
final class SuperadminChatInlineVideo extends StatefulWidget {
  const SuperadminChatInlineVideo({
    required this.attachment,
    required this.attachmentRepository,
    required this.session,
    super.key,
  });

  final ChatAttachment attachment;
  final ChatAttachmentRepository attachmentRepository;
  final MediaSession session;

  @override
  State<SuperadminChatInlineVideo> createState() => _SuperadminChatInlineVideoState();
}

final class _SuperadminChatInlineVideoState extends State<SuperadminChatInlineVideo> {
  VideoPlayerController? _controller;
  Timer? _expiry;
  void Function()? _unregister;
  var _generation = 0;
  var _state = _InlineVideoState.loading;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant SuperadminChatInlineVideo oldWidget) {
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
      _state = _InlineVideoState.unavailable;
      return;
    }
    _unregister = widget.session.registerPurge(() async {
      _generation++;
      await _clear();
      if (mounted) setState(() => _state = _InlineVideoState.unavailable);
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
    setState(() => _state = _InlineVideoState.loading);
    try {
      final ticket = await widget.attachmentRepository.readAttachment(widget.attachment.id);
      if (!mounted || generation != _generation || widget.session.isInvalidated) return;
      final now = DateTime.now().toUtc();
      if (!ticket.expiresAt.isAfter(now)) {
        setState(() => _state = _InlineVideoState.expired);
        return;
      }
      final controller = VideoPlayerController.networkUrl(ticket.url);
      controller.addListener(() {
        if (mounted && generation == _generation) setState(() {});
      });
      _controller = controller;
      await controller.initialize();
      await controller.pause();
      if (!mounted || generation != _generation || widget.session.isInvalidated) {
        await controller.dispose();
        return;
      }
      setState(() {
        _state = _InlineVideoState.available;
        _expiry = Timer(ticket.expiresAt.difference(now), _expire);
      });
    } catch (_) {
      if (mounted && generation == _generation && !widget.session.isInvalidated) {
        setState(() => _state = _InlineVideoState.failed);
      }
    }
  }

  void _expire() {
    unawaited(_clear());
    if (mounted && !widget.session.isInvalidated) {
      setState(() => _state = _InlineVideoState.expired);
    }
  }

  Future<void> _clear() async {
    _expiry?.cancel();
    _expiry = null;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.pause();
      await controller.dispose();
    }
  }

  Future<void> _toggle() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || widget.session.isInvalidated) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
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
      _InlineVideoState.loading => const _InlineVideoMessage('Carregando vídeo…'),
      _InlineVideoState.failed => _InlineVideoMessage(
        'Não foi possível carregar o vídeo. Tente novamente.',
        onRetry: _read,
      ),
      _InlineVideoState.expired => _InlineVideoMessage(
        'A visualização expirou. Carregue novamente.',
        onRetry: _read,
      ),
      _InlineVideoState.unavailable => const _InlineVideoMessage(
        'Visualização indisponível neste contexto.',
      ),
      _InlineVideoState.available => _InlineVideoPlayer(
        controller: _controller!,
        onToggle: _toggle,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: CoeloSpacing.space2),
      child: Semantics(label: 'Vídeo anexo: ${widget.attachment.fileName}', child: content),
    );
  }
}

final class _InlineVideoPlayer extends StatelessWidget {
  const _InlineVideoPlayer({required this.controller, required this.onToggle});

  final VideoPlayerController controller;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final playing = value.isPlaying;
    final aspectRatio = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
    return ClipRRect(
      borderRadius: BorderRadius.circular(CoeloRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(aspectRatio: aspectRatio, child: VideoPlayer(controller)),
            IconButton.filled(
              tooltip: playing ? 'Pausar vídeo' : 'Reproduzir vídeo',
              onPressed: () => unawaited(onToggle()),
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

final class _InlineVideoMessage extends StatelessWidget {
  const _InlineVideoMessage(this.message, {this.onRetry});

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
