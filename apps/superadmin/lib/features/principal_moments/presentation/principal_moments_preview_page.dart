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
    this.withdrawalRepository,
    this.refreshSignal,
    this.data = PrincipalMomentsPreviewData.demo,
    super.key,
  });

  /// Marks the viewer as hosted inside the Superadmin shell content area.
  ///
  /// The host keeps its own shell/menu visible (Owner decision of 2026-09-09),
  /// so the viewer must not re-apply the system insets the host already
  /// consumed. The immersive Momentos composition itself is unchanged.
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

  /// Optional author-only withdrawal seam. The affordance is rendered only for
  /// moments the backend already marked as withdrawable.
  final PrincipalMomentsWithdrawalRepository? withdrawalRepository;
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
  String? _withdrawingPublicationId;

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

  bool _canWithdraw(PrincipalMomentPreviewItem moment) =>
      widget.withdrawalRepository != null &&
      moment.canWithdraw &&
      (moment.publicationId?.isNotEmpty ?? false);

  Future<void> _confirmWithdrawal(PrincipalMomentPreviewItem moment) async {
    final repository = widget.withdrawalRepository;
    final publicationId = moment.publicationId;
    if (repository == null || publicationId == null || publicationId.isEmpty) return;
    if (_withdrawingPublicationId != null) return;

    // A confirmacao e assincrona: enquanto ela esta aberta o contexto de runtime
    // pode trocar, e `didUpdateWidget` substitui repositorio e escopo sem
    // destruir este State, entao `mounted` sozinho nao percebe. O momento
    // confirmado pertence ao feed que estava em tela; se esse feed deixou de
    // ser o atual, a confirmacao perdeu o sentido e nao pode ser aplicada.
    // Mesma guarda que a retirada do Acontece ja fazia.
    final generationAtOpen = _loadGeneration;
    final scopeAtOpen = widget.feedScope;
    bool stillTheSameFeed() =>
        mounted &&
        _loadGeneration == generationAtOpen &&
        identical(widget.withdrawalRepository, repository) &&
        widget.feedScope == scopeAtOpen;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('principal-moments-withdraw-dialog'),
        title: const Text('Retirar este momento?'),
        content: const Text(
          'Ele deixa de aparecer para quem podia ver. A mídia não é apagada e a '
          'retirada fica registrada.',
        ),
        actions: [
          TextButton(
            key: const Key('principal-moments-withdraw-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Manter publicado'),
          ),
          FilledButton(
            key: const Key('principal-moments-withdraw-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !stillTheSameFeed()) return;

    setState(() => _withdrawingPublicationId = publicationId);
    try {
      await repository.withdrawMoment(publicationId);
      if (!stillTheSameFeed()) return;
      setState(() => _withdrawingPublicationId = null);
      _announce('Momento retirado.');
      await _loadFeed();
    } on PrincipalMomentsWithdrawalFailure catch (failure) {
      if (!stillTheSameFeed()) return;
      setState(() => _withdrawingPublicationId = null);
      _announce(
        failure is PrincipalMomentsWithdrawalDenied
            ? 'Você não tem permissão para retirar este momento.'
            : 'Não foi possível retirar agora. Tente novamente.',
      );
    } on Exception {
      if (!stillTheSameFeed()) return;
      setState(() => _withdrawingPublicationId = null);
      _announce('Não foi possível retirar agora. Tente novamente.');
    }
  }

  void _announce(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _prototypeMessage(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label ainda não está disponível.')));
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

  // IMG (decisao do Owner de 10/09/2026, goldens 1024/1440 = referencia):
  // ate 768 o Momentos e tela cheia; a partir de 840 (expanded) a midia vive numa
  // moldura vertical centrada e o preto preenche toda a largura disponivel; a
  // partir de 1200 entra o aside "Em alta na escola" com Enviar momento.
  Widget _buildLayout() => LayoutBuilder(
    builder: (context, constraints) {
      final framed = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
      final desktop = constraints.maxWidth >= CoeloBreakpoints.large.minWidth;
      final surface = _buildFeedSurface(framed: framed);
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: !framed
            ? surface
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space4,
                  vertical: CoeloSpacing.space3,
                ),
                child: Row(
                  children: [
                    Expanded(child: surface),
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

  Widget _buildFeedSurface({required bool framed}) {
    if (_feedConfigurationInvalid) {
      return _buildExitState(
        _MomentsStateSurface(
          title: 'Momentos indisponíveis',
          message: 'O contexto necessário para carregar os momentos não está disponível.',
          icon: Icons.lock_outline_rounded,
          onBack: _returnToHappens,
        ),
      );
    }
    if (_feedLoading) {
      return _buildExitState(
        _MomentsStateSurface(
          semanticsLabel: 'Carregando momentos',
          title: 'Carregando momentos',
          message: 'Buscando publicações disponíveis para você.',
          loading: true,
          onBack: _returnToHappens,
        ),
      );
    }
    if (_feedFailure case final failure?) {
      final unauthorized = failure is PrincipalMomentsFeedUnauthorized;
      return _buildExitState(
        _MomentsStateSurface(
          title: unauthorized ? 'Momentos indisponíveis' : 'Não foi possível carregar',
          message: unauthorized
              ? 'Seu vínculo atual não permite acessar estes momentos.'
              : 'Confira sua conexão e tente novamente.',
          icon: unauthorized ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
          actionLabel: unauthorized ? null : 'Tentar novamente',
          onAction: unauthorized ? null : _loadFeed,
          onBack: _returnToHappens,
        ),
      );
    }
    if (_moments.isEmpty) {
      return _buildExitState(
        _MomentsStateSurface(
          title: 'Nenhum momento por aqui',
          message: 'Novos momentos aparecerão quando forem publicados para você.',
          icon: Icons.video_library_outlined,
          onBack: _returnToHappens,
        ),
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
      canWithdraw: _canWithdraw,
      withdrawingPublicationId: _withdrawingPublicationId,
      onWithdraw: _confirmWithdrawal,
      embedded: widget.embedded,
      framed: framed,
    );
  }

  Widget _buildExitState(Widget child) =>
      Focus(autofocus: true, focusNode: _focusNode, child: child);

  void _returnToHappens() => _invoke(widget.onOpenHappens, 'Retorno ao Acontece');
}

final class _MomentsStateSurface extends StatelessWidget {
  const _MomentsStateSurface({
    required this.title,
    required this.message,
    this.semanticsLabel,
    this.icon,
    this.actionLabel,
    this.onAction,
    required this.onBack,
    this.loading = false,
  });

  final String title;
  final String message;
  final String? semanticsLabel;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onBack;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoeloStatePanel(
                title: title,
                message: message,
                icon: icon,
                actionLabel: actionLabel,
                onAction: onAction,
                loading: loading,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              TextButton.icon(
                key: const Key('principal-moments-back'),
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Voltar para Acontece'),
              ),
            ],
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
    required this.onBack,
    required this.onPageChanged,
    required this.onMovePage,
    required this.onLike,
    required this.onSave,
    required this.onMute,
    required this.onAction,
    required this.canWithdraw,
    required this.withdrawingPublicationId,
    required this.onWithdraw,
    required this.embedded,
    this.framed = false,
  });

  final PageController controller;
  final FocusNode focusNode;
  final List<PrincipalMomentPreviewItem> moments;
  final int currentIndex;
  final bool liked;
  final bool saved;
  final bool muted;
  final VoidCallback onBack;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onMovePage;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onMute;
  final ValueChanged<String> onAction;
  final bool Function(PrincipalMomentPreviewItem moment) canWithdraw;
  final String? withdrawingPublicationId;
  final ValueChanged<PrincipalMomentPreviewItem> onWithdraw;
  final bool embedded;

  /// Moldura vertical centrada sobre o preto (a partir de 1024); abaixo disso
  /// a midia ocupa a tela inteira.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final pager = Focus(
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
          canWithdraw: canWithdraw(moments[index]),
          withdrawing:
              withdrawingPublicationId != null &&
              withdrawingPublicationId == moments[index].publicationId,
          onWithdraw: () => onWithdraw(moments[index]),
          embedded: embedded,
        ),
      ),
    );
    return ColoredBox(
      color: Colors.black,
      child: framed
          ? Center(
              child: AspectRatio(
                aspectRatio: (1672 / 5) / 941,
                child: ClipRRect(borderRadius: BorderRadius.circular(CoeloRadius.lg), child: pager),
              ),
            )
          : pager,
    );
  }
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
    required this.canWithdraw,
    required this.withdrawing,
    required this.onWithdraw,
    required this.embedded,
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
  final bool canWithdraw;
  final bool withdrawing;
  final VoidCallback onWithdraw;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Hosted in the Superadmin shell the system insets already belong to the
    // host chrome; only the standalone viewer offsets its overlay controls.
    final viewPadding = embedded ? EdgeInsets.zero : MediaQuery.viewPaddingOf(context);
    return Semantics(
      image: true,
      label: 'Momento de ${moment.author}, ${moment.context}. ${moment.caption}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          _MomentSurface(moment: moment),
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
            left: viewPadding.left + CoeloSpacing.space4,
            top: viewPadding.top + CoeloSpacing.space4,
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
            right: viewPadding.right + CoeloSpacing.space3,
            top: viewPadding.top + CoeloSpacing.space3,
            child: _OverlayIcon(
              actionKey: const Key('principal-moments-mute'),
              icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              label: muted ? 'Ativar áudio' : 'Silenciar',
              onPressed: onMute,
              circularBackground: true,
            ),
          ),
          Positioned(
            right: viewPadding.right + CoeloSpacing.space3,
            bottom: viewPadding.bottom + 74,
            child: _ActionRail(
              moment: moment,
              liked: liked,
              saved: saved,
              onLike: onLike,
              onSave: onSave,
              onAction: onAction,
              canWithdraw: canWithdraw,
              withdrawing: withdrawing,
              onWithdraw: onWithdraw,
            ),
          ),
          Positioned(
            left: viewPadding.left + CoeloSpacing.space4,
            right: viewPadding.right + 76,
            bottom: viewPadding.bottom + CoeloSpacing.space4,
            child: _MomentContext(moment: moment),
          ),
        ],
      ),
    );
  }
}

final class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.moment,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
    required this.onAction,
    required this.canWithdraw,
    required this.withdrawing,
    required this.onWithdraw,
  });

  final PrincipalMomentPreviewItem moment;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final ValueChanged<String> onAction;
  final bool canWithdraw;
  final bool withdrawing;
  final VoidCallback onWithdraw;

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
      if (canWithdraw)
        withdrawing
            ? const Padding(
                key: Key('principal-moments-withdraw-progress'),
                padding: EdgeInsets.only(bottom: CoeloSpacing.space2),
                child: SizedBox.square(
                  dimension: CoeloSize.touchMin,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              )
            : _OverlayIcon(
                actionKey: const Key('principal-moments-withdraw'),
                icon: Icons.remove_circle_outline_rounded,
                label: 'Retirar momento',
                onPressed: onWithdraw,
                circularBackground: true,
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
              child: Text(
                moment.resolvedInitials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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

/// Renders the authorized media rendition when the backend provided one, and
/// falls back to the local preview sprite for fixture data only.
final class _MomentSurface extends StatelessWidget {
  const _MomentSurface({required this.moment});

  final PrincipalMomentPreviewItem moment;

  @override
  Widget build(BuildContext context) {
    if (moment.media.isEmpty) {
      return _SpriteImage(index: moment.imageIndex, count: 5);
    }
    // IMG (decisao do Owner de 10/09/2026): a midia nao pode ser perdida nem
    // cortada; ela cabe inteira sobre o preto em vez de preencher cortando.
    return ColoredBox(
      color: Colors.black,
      child: Image.network(
        moment.media.first.signedUrl,
        key: const Key('principal-moments-media'),
        fit: BoxFit.contain,
        alignment: Alignment.center,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Colors.black),
      ),
    );
  }
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
