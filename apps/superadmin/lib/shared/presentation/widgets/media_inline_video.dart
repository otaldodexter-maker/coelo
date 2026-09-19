import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Vídeo MP4 inline a partir de uma URL local (`blob:`/`data:` produzida por
/// [mediaObjectUrl]) ou assinada. A autorização já aconteceu ao obter a URL;
/// aqui só se reproduz. Toque alterna play/pause; sem controles de mídia
/// nativos, para o layout ficar o mesmo em 375/600/1440.
final class MediaInlineVideo extends StatefulWidget {
  const MediaInlineVideo({
    required this.url,
    this.fit = BoxFit.contain,
    this.autoplay = false,
    this.loop = false,
    this.muted = false,
    this.semanticLabel,
    this.placeholder,
    this.unavailable,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final bool autoplay;
  final bool loop;
  final bool muted;
  final String? semanticLabel;

  /// Mostrado enquanto o vídeo carrega.
  final Widget? placeholder;

  /// Mostrado quando o vídeo não pôde ser decodificado.
  final Widget? unavailable;

  @override
  State<MediaInlineVideo> createState() => _MediaInlineVideoState();
}

final class _MediaInlineVideoState extends State<MediaInlineVideo> {
  VideoPlayerController? _controller;
  var _generation = 0;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bind());
  }

  @override
  void didUpdateWidget(covariant MediaInlineVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) unawaited(_bind());
  }

  Future<void> _bind() async {
    final generation = ++_generation;
    await _clear();
    if (!mounted || generation != _generation) return;
    setState(() => _failed = false);
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      setState(() => _failed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    controller.addListener(() {
      if (mounted && generation == _generation) setState(() {});
    });
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(widget.loop);
      await controller.setVolume(widget.muted ? 0 : 1);
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      if (widget.autoplay) {
        await controller.play();
      } else {
        await controller.pause();
      }
      setState(() {});
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  Future<void> _clear() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.pause();
      await controller.dispose();
    }
  }

  Future<void> _toggle() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_clear());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_failed) {
      return widget.unavailable ??
          ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Center(child: Icon(Icons.videocam_off_outlined, color: scheme.onSurfaceVariant)),
          );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return widget.placeholder ??
          ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator.adaptive()),
          );
    }
    final value = controller.value;
    final aspectRatio = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
    final playing = value.isPlaying;
    return Semantics(
      label: widget.semanticLabel ?? 'Vídeo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_toggle()),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: aspectRatio * 100,
                height: 100,
                child: VideoPlayer(controller),
              ),
            ),
            if (!playing)
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.coeloOnMediaColors.scrimSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(CoeloSpacing.space2),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 40,
                      color: context.coeloOnMediaColors.foreground,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
