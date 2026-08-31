import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/principal_moments_feed_repository.dart';
import '../domain/principal_moments_preview_data.dart';

final class PrincipalMomentsPreviewPage extends StatefulWidget {
  const PrincipalMomentsPreviewPage({
    this.embedded = false,
    this.onOpenHappens,
    this.onOpenProfile,
    this.onCreateMoment,
    this.onOpenMenu,
    this.onOpenNotifications,
    this.onReportProblem,
    this.onOpenHome,
    this.onOpenForYou,
    this.onPublishNow,
    this.onOpenMoments,
    this.onOpenSearch,
    this.onOpenMessages,
    this.feedRepository,
    this.feedScope,
    this.refreshSignal,
    this.data = PrincipalMomentsPreviewData.demo,
    super.key,
  });

  final bool embedded;
  final VoidCallback? onOpenHappens;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onCreateMoment;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onReportProblem;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenForYou;
  final VoidCallback? onPublishNow;
  final VoidCallback? onOpenMoments;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenMessages;
  final PrincipalMomentsFeedRepository? feedRepository;
  final PrincipalMomentsFeedScope? feedScope;
  final PrincipalMomentsFeedRefreshSignal? refreshSignal;
  final PrincipalMomentsPreviewData data;

  @override
  State<PrincipalMomentsPreviewPage> createState() => _PrincipalMomentsPreviewPageState();
}

final class _PrincipalMomentsPreviewPageState extends State<PrincipalMomentsPreviewPage> {
  final _pageController = PageController();
  final _focusNode = FocusNode(debugLabel: 'Momentos');
  final _liked = <int>{};
  final _saved = <int>{};
  var _currentIndex = 0;
  var _muted = true;
  List<PrincipalMomentPreviewItem>? _remoteMoments;
  PrincipalMomentsFeedFailure? _feedFailure;
  var _feedLoading = false;
  var _loadGeneration = 0;

  bool get _feedConfigurationInvalid =>
      (widget.feedRepository == null) != (widget.feedScope == null);

  bool get _usesRemoteFeed => widget.feedRepository != null && widget.feedScope != null;

  List<PrincipalMomentPreviewItem> get _moments =>
      _usesRemoteFeed ? (_remoteMoments ?? const []) : widget.data.moments;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_reloadAfterPublication);
    if (_usesRemoteFeed) {
      _feedLoading = true;
      Future<void>.microtask(_loadFeed);
    }
  }

  @override
  void didUpdateWidget(covariant PrincipalMomentsPreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reloadAfterPublication);
      widget.refreshSignal?.addListener(_reloadAfterPublication);
    }
    if (oldWidget.feedRepository != widget.feedRepository ||
        oldWidget.feedScope != widget.feedScope) {
      _loadGeneration += 1;
      _remoteMoments = null;
      _feedFailure = null;
      _feedLoading = _usesRemoteFeed;
      if (_usesRemoteFeed) Future<void>.microtask(_loadFeed);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_reloadAfterPublication);
    _loadGeneration += 1;
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _reloadAfterPublication() => _loadFeed();

  Future<void> _loadFeed() async {
    final repository = widget.feedRepository;
    final scope = widget.feedScope;
    if (repository == null || scope == null) return;

    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _feedLoading = true;
        _feedFailure = null;
      });
    }

    try {
      final moments = await repository.listVisibleMoments(scope);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _remoteMoments = List.unmodifiable(moments);
        _feedLoading = false;
        _currentIndex = 0;
        _liked.clear();
        _saved.clear();
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    } on PrincipalMomentsFeedFailure catch (failure) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _remoteMoments = null;
        _feedLoading = false;
        _feedFailure = failure;
      });
    } on Exception {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _remoteMoments = null;
        _feedLoading = false;
        _feedFailure = const PrincipalMomentsFeedUnavailable();
      });
    }
  }

  void _prototypeMessage(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label estará disponível na experiência completa.')));
  }

  void _invoke(VoidCallback? callback, String fallback) {
    callback == null ? _prototypeMessage(fallback) : callback();
  }

  void _movePage(int delta) {
    if (_moments.isEmpty) return;
    final target = (_currentIndex + delta).clamp(0, _moments.length - 1);
    if (target == _currentIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(target);
      return;
    }
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          _invoke(widget.onOpenHappens, 'Acontece'),
    },
    child: _buildLayout(),
  );

  Widget _buildLayout() => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= CoeloBreakpoints.large.minWidth;
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            desktop ? CoeloSpacing.space4 : 0,
            desktop ? CoeloSpacing.space3 : 0,
            desktop ? CoeloSpacing.space4 : 0,
            desktop ? CoeloSpacing.space3 : 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: desktop ? 820 : double.infinity),
                  child: _buildFeedSurface(desktop: desktop),
                ),
              ),
              if (desktop) ...[
                const SizedBox(width: CoeloSpacing.space4),
                SizedBox(
                  width: 280,
                  child: _DesktopAside(
                    items: _usesRemoteFeed ? const [] : widget.data.trending,
                    onSend: () => _invoke(widget.onCreateMoment, 'Publicação de Momentos'),
                    onOpen: () => _prototypeMessage('Momento em alta'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _buildFeedSurface({required bool desktop}) {
    if (_feedConfigurationInvalid) {
      return const _MomentsStateSurface(
        title: 'Momentos indisponíveis',
        message: 'O contexto necessário para carregar os momentos não está disponível.',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (_feedLoading) {
      return const _MomentsStateSurface(
        semanticsLabel: 'Carregando momentos',
        title: 'Carregando momentos',
        message: 'Buscando publicações disponíveis para você.',
        loading: true,
      );
    }
    if (_feedFailure case final failure?) {
      final unauthorized = failure is PrincipalMomentsFeedUnauthorized;
      return _MomentsStateSurface(
        title: unauthorized ? 'Momentos indisponíveis' : 'Não foi possível carregar',
        message: unauthorized
            ? 'Seu vínculo atual não permite acessar estes momentos.'
            : 'Confira sua conexão e tente novamente.',
        icon: unauthorized ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
        actionLabel: unauthorized ? null : 'Tentar novamente',
        onAction: unauthorized ? null : _loadFeed,
      );
    }
    if (_moments.isEmpty) {
      return const _MomentsStateSurface(
        title: 'Nenhum momento por aqui',
        message: 'Novos momentos aparecerão quando forem publicados para você.',
        icon: Icons.video_library_outlined,
      );
    }
    return _MomentPager(
      controller: _pageController,
      focusNode: _focusNode,
      moments: _moments,
      currentIndex: _currentIndex,
      liked: _liked.contains(_currentIndex),
      saved: _saved.contains(_currentIndex),
      muted: _muted,
      compact: !desktop,
      onBack: () => _invoke(widget.onOpenHappens, 'Retorno ao Acontece'),
      onPageChanged: (value) => setState(() => _currentIndex = value),
      onMovePage: _movePage,
      onLike: () => setState(() {
        _liked.contains(_currentIndex) ? _liked.remove(_currentIndex) : _liked.add(_currentIndex);
      }),
      onSave: () => setState(() {
        _saved.contains(_currentIndex) ? _saved.remove(_currentIndex) : _saved.add(_currentIndex);
      }),
      onMute: () => setState(() => _muted = !_muted),
      onAction: _prototypeMessage,
    );
  }
}

final class _MomentsStateSurface extends StatelessWidget {
  const _MomentsStateSurface({
    required this.title,
    required this.message,
    this.semanticsLabel,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final String title;
  final String message;
  final String? semanticsLabel;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: semanticsLabel,
          child: CoeloStatePanel(
            title: title,
            message: message,
            icon: icon,
            actionLabel: actionLabel,
            onAction: onAction,
            loading: loading,
          ),
        ),
      ),
    ),
  );
}

final class _MomentPager extends StatelessWidget {
  const _MomentPager({
    required this.controller,
    required this.focusNode,
    required this.moments,
    required this.currentIndex,
    required this.liked,
    required this.saved,
    required this.muted,
    required this.compact,
    required this.onBack,
    required this.onPageChanged,
    required this.onMovePage,
    required this.onLike,
    required this.onSave,
    required this.onMute,
    required this.onAction,
  });

  final PageController controller;
  final FocusNode focusNode;
  final List<PrincipalMomentPreviewItem> moments;
  final int currentIndex;
  final bool liked;
  final bool saved;
  final bool muted;
  final bool compact;
  final VoidCallback onBack;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onMovePage;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onMute;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: AspectRatio(
        aspectRatio: (1672 / 5) / 941,
        child: ClipRRect(
          borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(CoeloRadius.lg),
          child: Focus(
            autofocus: true,
            focusNode: focusNode,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.pageDown) {
                onMovePage(1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.pageUp) {
                onMovePage(-1);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: PageView.builder(
              key: const Key('principal-moments-page-view'),
              controller: controller,
              scrollDirection: Axis.vertical,
              itemCount: moments.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) => _MomentFrame(
                moment: moments[index],
                liked: liked && index == currentIndex,
                saved: saved && index == currentIndex,
                muted: muted,
                onBack: onBack,
                onLike: onLike,
                onSave: onSave,
                onMute: onMute,
                onAction: onAction,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _MomentFrame extends StatelessWidget {
  const _MomentFrame({
    required this.moment,
    required this.liked,
    required this.saved,
    required this.muted,
    required this.onBack,
    required this.onLike,
    required this.onSave,
    required this.onMute,
    required this.onAction,
  });

  final PrincipalMomentPreviewItem moment;
  final bool liked;
  final bool saved;
  final bool muted;
  final VoidCallback onBack;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onMute;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Momento de ${moment.author}, ${moment.context}. ${moment.caption}',
    child: Stack(
      fit: StackFit.expand,
      children: [
        _SpriteImage(index: moment.imageIndex, count: 5),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x00000000), Color(0xCC000000)],
              stops: [0, .48, 1],
            ),
          ),
        ),
        Positioned(
          left: CoeloSpacing.space4,
          top: CoeloSpacing.space4,
          child: TextButton.icon(
            key: const Key('principal-moments-back'),
            onPressed: onBack,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
            ),
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            label: const Text('Momentos'),
          ),
        ),
        Positioned(
          right: CoeloSpacing.space3,
          top: CoeloSpacing.space3,
          child: _OverlayIcon(
            actionKey: const Key('principal-moments-mute'),
            icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            label: muted ? 'Ativar áudio' : 'Silenciar',
            onPressed: onMute,
            circularBackground: true,
          ),
        ),
        Positioned(
          right: CoeloSpacing.space3,
          bottom: 74,
          child: _ActionRail(
            moment: moment,
            liked: liked,
            saved: saved,
            onLike: onLike,
            onSave: onSave,
            onAction: onAction,
          ),
        ),
        Positioned(
          left: CoeloSpacing.space4,
          right: 76,
          bottom: CoeloSpacing.space4,
          child: _MomentContext(moment: moment),
        ),
      ],
    ),
  );
}

final class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.moment,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
    required this.onAction,
  });

  final PrincipalMomentPreviewItem moment;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _OverlayIcon(
        actionKey: const Key('principal-moments-like'),
        icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        label: liked ? 'Descurtir' : 'Curtir',
        active: liked,
        count: moment.likes + (liked ? 1 : 0),
        onPressed: onLike,
      ),
      _OverlayIcon(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Comentar',
        count: moment.comments,
        onPressed: () => onAction('Comentários'),
      ),
      _OverlayIcon(
        icon: Icons.send_outlined,
        label: 'Compartilhar',
        count: moment.shares,
        onPressed: () => onAction('Compartilhamento'),
      ),
      _OverlayIcon(
        actionKey: const Key('principal-moments-save'),
        icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        label: saved ? 'Remover dos salvos' : 'Salvar',
        active: saved,
        count: moment.saves,
        onPressed: onSave,
      ),
      _OverlayIcon(
        icon: Icons.more_horiz_rounded,
        label: 'Mais opções',
        onPressed: () => onAction('Mais opções'),
        circularBackground: true,
      ),
    ],
  );
}

final class _OverlayIcon extends StatelessWidget {
  const _OverlayIcon({
    this.actionKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.count,
    this.circularBackground = false,
    this.active = false,
  });

  final Key? actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int? count;
  final bool circularBackground;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Column(
      children: [
        IconButton(
          key: actionKey,
          tooltip: label,
          onPressed: onPressed,
          style:
              IconButton.styleFrom(
                minimumSize: const Size.square(CoeloSize.touchMin),
                foregroundColor: Colors.white,
              ).copyWith(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  final highlighted =
                      states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                  return highlighted || active
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  final highlighted =
                      states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                  if (highlighted) return Theme.of(context).colorScheme.primaryContainer;
                  return circularBackground ? Colors.black38 : Colors.transparent;
                }),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          icon: Icon(icon, size: 24),
        ),
        if (count case final value?)
          Text(
            '$value',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
          ),
      ],
    ),
  );
}

final class _MomentContext extends StatelessWidget {
  const _MomentContext({required this.moment});
  final PrincipalMomentPreviewItem moment;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.white),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Text(
                'CO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: CoeloSpacing.space2),
            Flexible(
              child: Text(moment.author, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: CoeloSpacing.space1),
            Icon(Icons.verified_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space1),
        Text('${moment.time}  •  ${moment.context}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: CoeloSpacing.space2),
        Text(moment.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: CoeloSpacing.space2),
        const Text('Curtido por Maria e outras 531 pessoas', style: TextStyle(fontSize: 10)),
      ],
    ),
  );
}

final class _DesktopAside extends StatelessWidget {
  const _DesktopAside({required this.items, required this.onSend, required this.onOpen});

  final List<PrincipalMomentTrendingItem> items;
  final VoidCallback onSend;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('principal-moments-desktop-aside'),
    children: [
      if (items.isNotEmpty) ...[
        _AsideCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Em alta na escola', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: CoeloSpacing.space3),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                  child: TextButton(
                    onPressed: onOpen,
                    style: _discreteTextButtonStyle(context).copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size(double.infinity, CoeloSize.touchMin),
                      ),
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      alignment: Alignment.centerLeft,
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 86,
                          height: 62,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(CoeloRadius.md),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _SpriteImage(index: item.imageIndex, count: 5),
                                Positioned(
                                  right: 4,
                                  bottom: 3,
                                  child: Text(
                                    item.duration,
                                    style: const TextStyle(color: Colors.white, fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: CoeloSpacing.space2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text(item.context, style: Theme.of(context).textTheme.bodySmall),
                              Text('Há 4h', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
      ],
      _AsideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compartilhe momentos que inspiram',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              'Registre conquistas, aprendizados e experiências que merecem ser lembradas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            FilledButton.icon(
              key: const Key('principal-moments-create'),
              onPressed: onSend,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Enviar momento'),
            ),
          ],
        ),
      ),
    ],
  );
}

ButtonStyle _discreteTextButtonStyle(BuildContext context, {Color? restingForeground}) {
  final colors = Theme.of(context).colorScheme;
  return TextButton.styleFrom(
    foregroundColor: restingForeground ?? colors.onSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return highlighted ? colors.primary : (restingForeground ?? colors.onSurface);
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return highlighted ? colors.primaryContainer : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

final class _AsideCard extends StatelessWidget {
  const _AsideCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(padding: const EdgeInsets.all(CoeloSpacing.space4), child: child),
  );
}

final class _SpriteImage extends StatelessWidget {
  const _SpriteImage({required this.index, required this.count});
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const fullAspect = 1672 / 941;
      final panelAspect = fullAspect / count;
      final tileWidth = constraints.maxWidth > constraints.maxHeight * panelAspect
          ? constraints.maxWidth
          : constraints.maxHeight * panelAspect;
      final imageHeight = tileWidth / panelAspect;
      final horizontalCrop = (tileWidth - constraints.maxWidth) / 2;
      final verticalCrop = (imageHeight - constraints.maxHeight) * .12;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: tileWidth * count,
          maxWidth: tileWidth * count,
          minHeight: imageHeight,
          maxHeight: imageHeight,
          child: Transform.translate(
            offset: Offset(-tileWidth * index - horizontalCrop, -verticalCrop),
            child: SizedBox(
              width: tileWidth * count,
              height: imageHeight,
              child: Image.asset(
                'assets/principal_moments/moments-strip.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      );
    },
  );
}
