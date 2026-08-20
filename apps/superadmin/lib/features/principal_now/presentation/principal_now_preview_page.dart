import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/principal_now_preview_data.dart';

final class PrincipalNowPreviewPage extends StatefulWidget {
  const PrincipalNowPreviewPage({
    this.onClose,
    this.onOpenHappens,
    this.onCreate,
    this.data = PrincipalNowPreviewData.demo,
    super.key,
  });

  final VoidCallback? onClose;
  final VoidCallback? onOpenHappens;
  final VoidCallback? onCreate;
  final PrincipalNowPreviewData data;

  @override
  State<PrincipalNowPreviewPage> createState() => _PrincipalNowPreviewPageState();
}

final class _PrincipalNowPreviewPageState extends State<PrincipalNowPreviewPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final FocusNode _replyFocusNode;
  late final TextEditingController _replyController;
  var _index = 0;
  var _muted = false;
  var _liked = false;
  var _manuallyPaused = false;
  var _holding = false;
  var _focusPaused = false;
  var _overlayPaused = false;

  PrincipalNowPreviewStory get _story => widget.data.stories[_index];
  bool get _paused => _manuallyPaused || _holding || _focusPaused || _overlayPaused;

  @override
  void initState() {
    super.initState();
    _replyFocusNode = FocusNode()..addListener(_handleReplyFocus);
    _replyController = TextEditingController();
    _progressController = AnimationController(vsync: this)
      ..addStatusListener(_handleProgressStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _progressController.stop();
      return;
    }
    if (!_progressController.isAnimating && !_paused) {
      _startCurrentStory(from: _progressController.value);
    }
  }

  @override
  void dispose() {
    _progressController
      ..removeStatusListener(_handleProgressStatus)
      ..dispose();
    _replyFocusNode
      ..removeListener(_handleReplyFocus)
      ..dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _handleReplyFocus() {
    _focusPaused = _replyFocusNode.hasFocus;
    _syncProgress();
  }

  void _handleProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _next();
    }
  }

  void _startCurrentStory({double from = 0}) {
    _progressController.duration = _story.duration;
    unawaited(_progressController.forward(from: from));
  }

  void _syncProgress() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    if (_paused) {
      _progressController.stop();
    } else {
      _startCurrentStory(from: _progressController.value);
    }
    setState(() {});
  }

  void _goTo(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= widget.data.stories.length) {
      return;
    }
    setState(() {
      _index = nextIndex;
      _liked = false;
    });
    _progressController.reset();
    if (!_paused && !MediaQuery.disableAnimationsOf(context)) {
      _startCurrentStory();
    }
  }

  void _previous() => _goTo(_index - 1);

  void _next() {
    if (_index == widget.data.stories.length - 1) {
      _close();
    } else {
      _goTo(_index + 1);
    }
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (widget.onOpenHappens != null) {
      widget.onOpenHappens!();
    } else {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  void _togglePause() {
    _manuallyPaused = !_manuallyPaused;
    _syncProgress();
  }

  Future<void> _showOptions() async {
    _overlayPaused = true;
    _syncProgress();
    final createRequested = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space5,
            0,
            CoeloSpacing.space5,
            CoeloSpacing.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Opções deste Agora', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: CoeloSpacing.space3),
              const Text('Conteúdo institucional privado e temporário.'),
              if (widget.onCreate != null) ...[
                const SizedBox(height: CoeloSpacing.space5),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Publicar no Agora'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    _overlayPaused = false;
    _syncProgress();
    if (createRequested ?? false) {
      widget.onCreate?.call();
    }
  }

  void _sendReply() {
    if (_replyController.text.trim().isEmpty) {
      return;
    }
    _replyController.clear();
    _replyFocusNode.unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Resposta privada preparada.')));
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
      const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
      const SingleActivator(LogicalKeyboardKey.space): _togglePause,
      const SingleActivator(LogicalKeyboardKey.escape): _close,
    },
    child: Focus(
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
          final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          return Scaffold(
            backgroundColor: CoeloPalette.neutral950,
            body: SafeArea(
              child: desktop ? _buildDesktop(context) : _buildCompact(context, compact: compact),
            ),
          );
        },
      ),
    ),
  );

  Widget _buildCompact(BuildContext context, {required bool compact}) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 430),
      child: _StoryCard(
        key: const Key('principal-now-story'),
        story: _story,
        stories: widget.data.stories,
        activeIndex: _index,
        progress: _progressController,
        showReply: true,
        showClose: true,
        liked: _liked,
        muted: _muted,
        replyController: _replyController,
        replyFocusNode: _replyFocusNode,
        onPrevious: _previous,
        onNext: _next,
        onClose: _close,
        onOptions: _showOptions,
        onAudio: () => setState(() => _muted = !_muted),
        onLike: () => setState(() => _liked = !_liked),
        onSendReply: _sendReply,
        onHoldChanged: (holding) {
          _holding = holding;
          _syncProgress();
        },
      ),
    ),
  );

  Widget _buildDesktop(BuildContext context) => Stack(
    key: const Key('principal-now-desktop-shell'),
    children: [
      Positioned(
        left: CoeloSpacing.space5,
        top: CoeloSpacing.space4,
        child: Semantics(
          label: 'Coelo',
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/brand/logo-coelo-orange.svg',
                key: const Key('principal-now-brand-logo'),
                width: CoeloSize.iconSm,
                height: CoeloSize.iconSm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Text(
                'COELO',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        right: CoeloSpacing.space4,
        top: CoeloSpacing.space2,
        child: Row(
          children: [
            _ViewerIconButton(
              key: const Key('principal-now-audio'),
              tooltip: _muted ? 'Ativar áudio' : 'Desativar áudio',
              icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              onPressed: () => setState(() => _muted = !_muted),
            ),
            _ViewerIconButton(
              key: const Key('principal-now-close'),
              tooltip: 'Fechar Agora',
              icon: Icons.close_rounded,
              onPressed: _close,
            ),
          ],
        ),
      ),
      Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NeighborPreview(
              key: const Key('principal-now-previous-preview'),
              story: widget.data.stories[(_index - 1).clamp(0, widget.data.stories.length - 1)],
              enabled: _index > 0,
              icon: Icons.chevron_left_rounded,
              label: 'Agora anterior',
              onTap: _previous,
            ),
            const SizedBox(width: CoeloSpacing.space3),
            SizedBox(
              width: 330,
              height: 640,
              child: _StoryCard(
                key: const Key('principal-now-story'),
                story: _story,
                stories: widget.data.stories,
                activeIndex: _index,
                progress: _progressController,
                showReply: false,
                showClose: false,
                liked: _liked,
                muted: _muted,
                replyController: _replyController,
                replyFocusNode: _replyFocusNode,
                onPrevious: _previous,
                onNext: _next,
                onClose: _close,
                onOptions: _showOptions,
                onAudio: () => setState(() => _muted = !_muted),
                onLike: () => setState(() => _liked = !_liked),
                onSendReply: _sendReply,
                onHoldChanged: (holding) {
                  _holding = holding;
                  _syncProgress();
                },
              ),
            ),
            const SizedBox(width: CoeloSpacing.space3),
            _NeighborPreview(
              key: const Key('principal-now-next-preview'),
              story: widget.data.stories[(_index + 1).clamp(0, widget.data.stories.length - 1)],
              enabled: _index < widget.data.stories.length - 1,
              icon: Icons.chevron_right_rounded,
              label: 'Próximo Agora',
              onTap: _next,
            ),
          ],
        ),
      ),
    ],
  );
}

final class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.stories,
    required this.activeIndex,
    required this.progress,
    required this.showReply,
    required this.showClose,
    required this.liked,
    required this.muted,
    required this.replyController,
    required this.replyFocusNode,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    required this.onOptions,
    required this.onAudio,
    required this.onLike,
    required this.onSendReply,
    required this.onHoldChanged,
    super.key,
  });

  final PrincipalNowPreviewStory story;
  final List<PrincipalNowPreviewStory> stories;
  final int activeIndex;
  final Animation<double> progress;
  final bool showReply;
  final bool showClose;
  final bool liked;
  final bool muted;
  final TextEditingController replyController;
  final FocusNode replyFocusNode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback onOptions;
  final VoidCallback onAudio;
  final VoidCallback onLike;
  final VoidCallback onSendReply;
  final ValueChanged<bool> onHoldChanged;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(showReply ? 0 : CoeloRadius.lg),
    child: DecoratedBox(
      decoration: BoxDecoration(border: showReply ? null : Border.all(color: Colors.white38)),
      child: Listener(
        onPointerDown: (_) => onHoldChanged(true),
        onPointerUp: (_) => onHoldChanged(false),
        onPointerCancel: (_) => onHoldChanged(false),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _StoryImage(story: story),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
                  stops: [0, .22, .58, 1],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Agora anterior',
                    child: GestureDetector(
                      key: const Key('principal-now-previous-zone'),
                      behavior: HitTestBehavior.translucent,
                      onTap: onPrevious,
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Próximo Agora',
                    child: GestureDetector(
                      key: const Key('principal-now-next-zone'),
                      behavior: HitTestBehavior.translucent,
                      onTap: onNext,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: CoeloSpacing.space3,
              right: CoeloSpacing.space3,
              top: CoeloSpacing.space3,
              child: Column(
                children: [
                  AnimatedBuilder(
                    key: const Key('principal-now-progress'),
                    animation: progress,
                    builder: (context, _) => Row(
                      children: List.generate(stories.length, (index) {
                        final value = index < activeIndex
                            ? 1.0
                            : index == activeIndex
                            ? progress.value
                            : 0.0;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == stories.length - 1 ? 0 : 4),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(CoeloRadius.full),
                              backgroundColor: Colors.white30,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: CoeloStatusColors.light.warningContainer,
                        child: Text(
                          'COELO',
                          style: TextStyle(
                            fontSize: 7,
                            color: CoeloStatusColors.light.onWarningContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: CoeloSpacing.space2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              story.timeLabel,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      _ViewerIconButton(
                        key: const Key('principal-now-options'),
                        tooltip: 'Opções do Agora',
                        icon: Icons.more_horiz_rounded,
                        onPressed: onOptions,
                      ),
                      if (showClose)
                        _ViewerIconButton(
                          key: const Key('principal-now-close'),
                          tooltip: 'Fechar Agora',
                          icon: Icons.close_rounded,
                          onPressed: onClose,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: CoeloSpacing.space6,
              right: CoeloSpacing.space6,
              bottom: showReply ? 116 : 74,
              child: Text(
                story.caption,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
                ),
              ),
            ),
            if (showReply)
              Positioned(
                left: CoeloSpacing.space3,
                right: CoeloSpacing.space3,
                bottom: CoeloSpacing.space4,
                child: Row(
                  children: [
                    Expanded(
                      child: _PrivateReplyField(
                        controller: replyController,
                        focusNode: replyFocusNode,
                        onSubmitted: onSendReply,
                      ),
                    ),
                    _ViewerIconButton(
                      key: const Key('principal-now-like'),
                      tooltip: liked ? 'Remover reação' : 'Reagir a este Agora',
                      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      onPressed: onLike,
                    ),
                    _ViewerIconButton(
                      key: const Key('principal-now-send-reply'),
                      tooltip: 'Enviar resposta privada',
                      icon: Icons.send_rounded,
                      onPressed: onSendReply,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

final class _PrivateReplyField extends StatefulWidget {
  const _PrivateReplyField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  State<_PrivateReplyField> createState() => _PrivateReplyFieldState();
}

final class _PrivateReplyFieldState extends State<_PrivateReplyField> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Semantics(
      textField: true,
      label: 'Resposta privada ao Agora',
      child: TextField(
        key: const Key('principal-now-reply-field'),
        controller: widget.controller,
        focusNode: widget.focusNode,
        cursorColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => widget.onSubmitted(),
        decoration: InputDecoration(
          hintText: 'Responder em particular…',
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.black26,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space4,
            vertical: CoeloSpacing.space3,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.full),
            borderSide: BorderSide(color: _hovered ? Colors.white70 : Colors.white38),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.full),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
    ),
  );
}

final class _NeighborPreview extends StatefulWidget {
  const _NeighborPreview({
    required this.story,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final PrincipalNowPreviewStory story;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_NeighborPreview> createState() => _NeighborPreviewState();
}

final class _NeighborPreviewState extends State<_NeighborPreview> {
  var _highlighted = false;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: widget.enabled ? (_highlighted ? .72 : .58) : .18,
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.fast,
    child: SizedBox(
      width: 164,
      height: 480,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        child: FocusableActionDetector(
          enabled: widget.enabled,
          mouseCursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => _highlighted = value),
          onShowHoverHighlight: (value) => setState(() => _highlighted = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: Semantics(
            button: true,
            enabled: widget.enabled,
            label: widget.label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? widget.onTap : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _StoryImage(story: widget.story),
                  const ColoredBox(color: Colors.black54),
                  Center(
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.black45,
                      child: Icon(widget.icon, color: Colors.white, size: 34),
                    ),
                  ),
                  Positioned(
                    left: CoeloSpacing.space3,
                    right: CoeloSpacing.space3,
                    bottom: CoeloSpacing.space6,
                    child: Text(
                      widget.story.caption,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _StoryImage extends StatelessWidget {
  const _StoryImage({required this.story});

  final PrincipalNowPreviewStory story;

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(-1 + story.imageIndex * .5, 0);
    return Image.asset(
      story.assetPath,
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      semanticLabel: story.caption,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white70)),
      ),
    );
  }
}

final class _ViewerIconButton extends StatelessWidget {
  const _ViewerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    color: Colors.white,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      minimumSize: const Size.square(CoeloSize.touchMin),
      backgroundColor: Colors.transparent,
      hoverColor: Colors.white12,
      focusColor: Colors.white12,
      highlightColor: Colors.transparent,
    ),
  );
}
