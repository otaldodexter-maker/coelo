import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/principal_happens_feed_repository.dart';
import '../domain/principal_happens_preview_data.dart';
import '../../principal_circulars/domain/circular_repository.dart';
import '../../principal_circulars/domain/principal_happens_mixed_feed.dart';
import '../../principal_circulars/presentation/principal_circular_surfaces.dart';
import '../../principal_shared/presentation/principal_global_navigation.dart';

const _principalHappensNowCardKey = Key('principal-happens-now-card');

final class PrincipalHappensPreviewPage extends StatefulWidget {
  const PrincipalHappensPreviewPage({
    required this.feedRepository,
    required this.feedScope,
    this.onOpenMoments,
    this.onOpenProfile,
    this.onOpenAgenda,
    this.onOpenNow,
    this.onOpenForYou,
    this.onCreatePost,
    this.onPublishNow,
    this.onShareMedia,
    this.onSaveMedia,
    this.onOpenMenu,
    this.onOpenNotifications,
    this.onOpenSearch,
    this.onOpenMessages,
    this.embedded = false,
    this.data = PrincipalHappensPreviewData.demo,
    super.key,
  }) : mixedFeedRepository = null,
       mixedFeedScope = null,
       mediaRepository = feedRepository,
       onOpenCircular = null;

  const PrincipalHappensPreviewPage.mixed({
    required this.mixedFeedRepository,
    required this.mixedFeedScope,
    required this.mediaRepository,
    required this.onOpenCircular,
    this.onOpenMoments,
    this.onOpenProfile,
    this.onOpenAgenda,
    this.onOpenNow,
    this.onOpenForYou,
    this.onCreatePost,
    this.onPublishNow,
    this.onShareMedia,
    this.onSaveMedia,
    this.onOpenMenu,
    this.onOpenNotifications,
    this.onOpenSearch,
    this.onOpenMessages,
    this.embedded = false,
    this.data = PrincipalHappensPreviewData.demo,
    super.key,
  }) : feedRepository = mediaRepository,
       feedScope = null;

  const PrincipalHappensPreviewPage.demo({
    this.onOpenMoments,
    this.onOpenProfile,
    this.onOpenAgenda,
    this.onOpenNow,
    this.onOpenForYou,
    this.onCreatePost,
    this.onPublishNow,
    this.onShareMedia,
    this.onSaveMedia,
    this.onOpenMenu,
    this.onOpenNotifications,
    this.onOpenSearch,
    this.onOpenMessages,
    this.embedded = false,
    this.data = PrincipalHappensPreviewData.demo,
    super.key,
  }) : feedRepository = null,
       feedScope = null,
       mixedFeedRepository = null,
       mixedFeedScope = null,
       mediaRepository = null,
       onOpenCircular = null;

  final VoidCallback? onOpenMoments;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onOpenNow;
  final VoidCallback? onOpenForYou;
  final VoidCallback? onCreatePost;
  final VoidCallback? onPublishNow;
  final VoidCallback? onShareMedia;
  final VoidCallback? onSaveMedia;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenMessages;
  final bool embedded;
  final PrincipalHappensFeedRepository? feedRepository;
  final PrincipalHappensFeedScope? feedScope;
  final PrincipalMixedFeedRepository? mixedFeedRepository;
  final CircularScope? mixedFeedScope;
  final PrincipalHappensFeedRepository? mediaRepository;
  final ValueChanged<String>? onOpenCircular;
  final PrincipalHappensPreviewData data;

  @override
  State<PrincipalHappensPreviewPage> createState() => _PrincipalHappensPreviewPageState();
}

final class _PrincipalHappensPreviewPageState extends State<PrincipalHappensPreviewPage> {
  final _likedPosts = <int>{};
  final _savedPosts = <int>{};
  List<PrincipalPostPreviewItem>? _remotePosts;
  List<PrincipalHappensFeedItem>? _mixedItems;
  Object? _feedError;
  var _feedLoading = false;
  var _feedRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void didUpdateWidget(covariant PrincipalHappensPreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feedRepository, widget.feedRepository) ||
        oldWidget.feedScope != widget.feedScope ||
        !identical(oldWidget.mixedFeedRepository, widget.mixedFeedRepository) ||
        oldWidget.mixedFeedScope != widget.mixedFeedScope ||
        !identical(oldWidget.mediaRepository, widget.mediaRepository)) {
      _loadFeed();
    }
  }

  Future<void> _loadFeed() async {
    final mixedRepository = widget.mixedFeedRepository;
    final mixedScope = widget.mixedFeedScope;
    final repository = widget.feedRepository;
    final scope = widget.feedScope;
    final request = ++_feedRequest;
    setState(() {
      _remotePosts = null;
      _mixedItems = null;
      _likedPosts.clear();
      _savedPosts.clear();
      _feedError = null;
      _feedLoading =
          mixedRepository != null && mixedScope != null || repository != null && scope != null;
    });
    if (mixedRepository != null && mixedScope != null) {
      try {
        final page = await mixedRepository.list(mixedScope);
        if (!mounted || request != _feedRequest) return;
        setState(() {
          _mixedItems = page.items;
          _remotePosts = null;
          _feedLoading = false;
        });
      } on Object catch (error) {
        if (!mounted || request != _feedRequest) return;
        setState(() {
          _feedError = error;
          _feedLoading = false;
        });
      }
      return;
    }
    if (repository == null || scope == null) {
      return;
    }
    try {
      final posts = await repository.listVisiblePosts(scope);
      if (!mounted || request != _feedRequest) return;
      setState(() {
        _remotePosts = posts;
        _mixedItems = null;
        _feedLoading = false;
      });
    } on Object catch (error) {
      if (!mounted || request != _feedRequest) return;
      setState(() {
        _feedError = error;
        _feedLoading = false;
      });
    }
  }

  void _prototypeMessage(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label estará disponível na experiência completa.')));
  }

  void _invoke(VoidCallback? callback, String fallback) {
    if (callback == null) {
      _prototypeMessage(fallback);
    } else {
      callback();
    }
  }

  Future<void> _openGallery(PrincipalPostPreviewItem post) async {
    final originFocus = FocusManager.instance.primaryFocus;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (context) => _HappensGallery(
        post: post,
        repository: widget.mediaRepository ?? widget.feedRepository,
        onReload: _loadFeed,
        onShare: widget.onShareMedia,
        onSave: widget.onSaveMedia,
      ),
    );
    if (originFocus?.canRequestFocus ?? false) originFocus!.requestFocus();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final large = constraints.maxWidth >= CoeloBreakpoints.large.minWidth;
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: PrincipalGlobalHeader(
          onOpenMenu: () => _invoke(widget.onOpenMenu, 'Menu'),
          onOpenNotifications: () => _invoke(widget.onOpenNotifications, 'Notificações'),
          onOpenProfile: () => _invoke(widget.onOpenProfile, 'Perfil'),
        ),
        body: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Feed(
                    data: widget.data,
                    mediaRepository: widget.mediaRepository ?? widget.feedRepository,
                    posts: widget.feedRepository == null
                        ? widget.data.posts
                        : (_remotePosts ?? const []),
                    mixedItems: _mixedItems,
                    onOpenCircular: widget.onOpenCircular,
                    loading: _feedLoading,
                    error: _feedError,
                    onRetry: _loadFeed,
                    compact: compact,
                    onCreatePost: () =>
                        _invoke(widget.onPublishNow ?? widget.onCreatePost, 'Publicar no Agora'),
                    onMoments: () => _invoke(widget.onOpenMoments, 'Momentos'),
                    onProfile: () => _invoke(widget.onOpenProfile, 'Perfil'),
                    onOpenNow: () => _invoke(widget.onOpenNow, 'Agora'),
                    onForYou: () => _invoke(widget.onOpenForYou, 'Para você'),
                    likedPosts: _likedPosts,
                    savedPosts: _savedPosts,
                    onLike: (index) => setState(() {
                      _likedPosts.contains(index)
                          ? _likedPosts.remove(index)
                          : _likedPosts.add(index);
                    }),
                    onSave: (index) => setState(() {
                      _savedPosts.contains(index)
                          ? _savedPosts.remove(index)
                          : _savedPosts.add(index);
                    }),
                    onPrototypeAction: _prototypeMessage,
                    onOpenGallery: _openGallery,
                    embedded: widget.embedded,
                  ),
                ),
                if (large)
                  _ContextColumn(
                    data: widget.data,
                    onOpenAgenda: () => _invoke(widget.onOpenAgenda, 'Agenda'),
                    onAction: _prototypeMessage,
                  ),
              ],
            ),
            PrincipalGlobalNavigation(
              selected: PrincipalDestination.home,
              onHome: () {},
              onForYou: () => _invoke(widget.onOpenForYou, 'Para você'),
              onPublishNow: () =>
                  _invoke(widget.onPublishNow ?? widget.onCreatePost, 'Publicar no Agora'),
              onMoments: () => _invoke(widget.onOpenMoments, 'Momentos'),
              onSearch: () => _invoke(widget.onOpenSearch, 'Pesquisar'),
              onMessages: () => _invoke(widget.onOpenMessages, 'Mensagens'),
            ),
          ],
        ),
      );
    },
  );
}

final class _Feed extends StatelessWidget {
  const _Feed({
    required this.data,
    required this.posts,
    required this.mixedItems,
    required this.onOpenCircular,
    required this.mediaRepository,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.compact,
    required this.onCreatePost,
    required this.onMoments,
    required this.onProfile,
    required this.onOpenNow,
    required this.onForYou,
    required this.likedPosts,
    required this.savedPosts,
    required this.onLike,
    required this.onSave,
    required this.onPrototypeAction,
    required this.onOpenGallery,
    required this.embedded,
  });

  final PrincipalHappensPreviewData data;
  final List<PrincipalPostPreviewItem> posts;
  final List<PrincipalHappensFeedItem>? mixedItems;
  final ValueChanged<String>? onOpenCircular;
  final PrincipalHappensFeedRepository? mediaRepository;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final bool compact;
  final VoidCallback onCreatePost;
  final VoidCallback onMoments;
  final VoidCallback onProfile;
  final VoidCallback onOpenNow;
  final VoidCallback onForYou;
  final Set<int> likedPosts;
  final Set<int> savedPosts;
  final ValueChanged<int> onLike;
  final ValueChanged<int> onSave;
  final ValueChanged<String> onPrototypeAction;
  final ValueChanged<PrincipalPostPreviewItem> onOpenGallery;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final horizontal = compact ? CoeloSpacing.space3 : CoeloSpacing.space4;
    return CustomScrollView(
      key: const Key('principal-happens-feed'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            CoeloSpacing.space3,
            horizontal,
            CoeloSpacing.space3,
          ),
          sliver: SliverToBoxAdapter(
            child: _NowSection(
              items: data.nowItems,
              compact: compact,
              onPublish: onCreatePost,
              onOpenItem: onOpenNow,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, CoeloSpacing.space3),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Acontece',
              key: const Key('principal-happens-local-title'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (loading)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            sliver: const SliverToBoxAdapter(child: _FeedStatePanel.loading()),
          )
        else if (error != null)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            sliver: SliverToBoxAdapter(
              child: _FeedStatePanel.error(
                unauthorized: error is PrincipalHappensFeedUnauthorized,
                onRetry: onRetry,
              ),
            ),
          )
        else if ((mixedItems ?? posts).isEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            sliver: const SliverToBoxAdapter(child: _FeedStatePanel.empty()),
          )
        else
          SliverList.separated(
            itemCount: mixedItems?.length ?? posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space3),
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : horizontal),
              child: _feedItem(index),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 150)),
      ],
    );
  }

  Widget _feedItem(int index) {
    final mixed = mixedItems;
    if (mixed == null) return _post(index, posts[index]);
    return switch (mixed[index]) {
      PrincipalHappensPostItem item => _post(index, _postPreview(item)),
      PrincipalHappensCircularItem item => PrincipalCircularFeedCard(
        key: Key('principal-happens-circular-${item.id}'),
        item: item.summary,
        onOpen: () => onOpenCircular?.call(item.id),
      ),
    };
  }

  Widget _post(int index, PrincipalPostPreviewItem post) => _PostCard(
    key: Key('principal-happens-post-$index'),
    index: index,
    post: post,
    mediaRepository: mediaRepository,
    onReloadMedia: onRetry,
    compact: compact,
    liked: likedPosts.contains(index),
    saved: savedPosts.contains(index),
    onLike: () => onLike(index),
    onSave: () => onSave(index),
    onAction: onPrototypeAction,
    onOpenGallery: () => onOpenGallery(post),
  );
}

PrincipalPostPreviewItem _postPreview(PrincipalHappensPostItem item) => PrincipalPostPreviewItem(
  author: item.authorName,
  context: item.contextLabel,
  time: _relativeTime(item.publishedAt),
  initials: _initials(item.authorName),
  body: item.caption,
  media: item.media,
);

String _initials(String value) => value
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();

String _relativeTime(DateTime value) {
  final difference = DateTime.now().toUtc().difference(value.toUtc());
  if (difference.inMinutes < 1) return 'Agora';
  if (difference.inHours < 1) return '${difference.inMinutes} min';
  if (difference.inDays < 1) return '${difference.inHours} h';
  return '${difference.inDays} d';
}

final class _FeedStatePanel extends StatelessWidget {
  const _FeedStatePanel._({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  const _FeedStatePanel.loading()
    : this._(
        icon: Icons.dynamic_feed_outlined,
        title: 'Carregando publicações',
        message: 'Buscando as novidades deste contexto.',
        loading: true,
      );

  const _FeedStatePanel.empty()
    : this._(
        icon: Icons.auto_awesome_outlined,
        title: 'Tudo em dia por aqui',
        message: 'As próximas publicações aparecerão neste espaço.',
      );

  factory _FeedStatePanel.error({required bool unauthorized, required VoidCallback onRetry}) =>
      _FeedStatePanel._(
        icon: unauthorized ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
        title: unauthorized ? 'Acesso não disponível' : 'Não foi possível carregar o Acontece',
        message: unauthorized
            ? 'Este contexto não está disponível para o seu vínculo atual.'
            : 'Confira sua conexão e tente novamente.',
        onRetry: unauthorized ? null : onRetry,
      );

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: Key(
        'principal-happens-feed-state-${loading
            ? 'loading'
            : onRetry == null
            ? 'terminal'
            : 'error'}',
      ),
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Column(
        children: [
          if (loading)
            const SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: 3))
          else
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: CoeloSpacing.space3),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ],
      ),
    ),
  );
}

final class _NowSection extends StatelessWidget {
  const _NowSection({
    required this.items,
    required this.compact,
    required this.onPublish,
    required this.onOpenItem,
  });
  final List<PrincipalNowPreviewItem> items;
  final bool compact;
  final VoidCallback onPublish;
  final VoidCallback onOpenItem;

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Agora',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        SizedBox(
          height: enlargedText
              ? 240
              : compact
              ? 142
              : 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: CoeloSpacing.space2),
            itemBuilder: (context, index) => index == 0
                ? _PublishNowCard(
                    width: enlargedText
                        ? 132
                        : compact
                        ? 88
                        : 104,
                    onPressed: onPublish,
                  )
                : _NowCard(
                    key: index == 1 ? _principalHappensNowCardKey : null,
                    item: items[index - 1],
                    width: enlargedText
                        ? 132
                        : compact
                        ? 88
                        : 104,
                    onPressed: onOpenItem,
                  ),
          ),
        ),
      ],
    );
  }
}

final class _PublishNowCard extends StatelessWidget {
  const _PublishNowCard({required this.width, required this.onPressed});

  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: OutlinedButton(
      key: const Key('principal-happens-publish-now-card'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(CoeloSpacing.space2),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.add_rounded),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            'Publicar\nagora',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

final class _NowCard extends StatelessWidget {
  const _NowCard({required this.item, required this.width, required this.onPressed, super.key});
  final PrincipalNowPreviewItem item;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Semantics(
      label: '${item.title}, publicado há ${item.time}',
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            final active =
                states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
            return BorderSide(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: active ? 2 : 1,
            );
          }),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _SpriteImage(
                asset: 'assets/principal_happens/now-strip.png',
                index: item.imageIndex,
                count: 5,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB8000000)],
                    stops: [.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: CoeloSpacing.space2,
                right: CoeloSpacing.space2,
                bottom: CoeloSpacing.space2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.school_outlined, size: 13),
                    ),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(item.time, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    const SizedBox(height: CoeloSpacing.space1),
                    LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(CoeloRadius.full),
                      backgroundColor: Colors.white38,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.index,
    required this.post,
    required this.mediaRepository,
    required this.onReloadMedia,
    required this.compact,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
    required this.onAction,
    required this.onOpenGallery,
    super.key,
  });
  final int index;
  final PrincipalPostPreviewItem post;
  final PrincipalHappensFeedRepository? mediaRepository;
  final VoidCallback onReloadMedia;
  final bool compact;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final ValueChanged<String> onAction;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(compact ? 0 : CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(post.initials, style: Theme.of(context).textTheme.labelSmall),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        post.context,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(post.time, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Mais opções da publicação',
                  onPressed: () => onAction('Opções da publicação'),
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
            if (post.media.isNotEmpty || post.mediaIndices.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space3),
              _PostMedia(
                mediaKey: Key('principal-happens-media-post-$index'),
                media: post.media,
                demoIndices: post.mediaIndices,
                repository: mediaRepository,
                onReload: onReloadMedia,
                compact: compact,
                onOpen: onOpenGallery,
              ),
            ],
            const SizedBox(height: CoeloSpacing.space2),
            Row(
              children: [
                _SocialAction(
                  actionKey: Key('principal-happens-like-post-$index'),
                  tooltip: liked ? 'Remover curtida' : 'Curtir',
                  icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: liked ? scheme.primary : null,
                  label: post.likes == null ? null : '${post.likes! + (liked ? 1 : 0)}',
                  onPressed: onLike,
                ),
                _SocialAction(
                  tooltip: 'Comentar',
                  icon: Icons.chat_bubble_outline_rounded,
                  label: post.comments?.toString(),
                  onPressed: () => onAction('Comentários'),
                ),
                _SocialAction(
                  tooltip: 'Compartilhar',
                  icon: Icons.ios_share_rounded,
                  label: post.shares?.toString(),
                  onPressed: () => onAction('Compartilhamento'),
                ),
                const Spacer(),
                IconButton(
                  key: Key('principal-happens-save-post-$index'),
                  tooltip: saved ? 'Remover dos salvos' : 'Salvar',
                  onPressed: onSave,
                  icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                ),
              ],
            ),
            if (index == 0 && post.likedBy != null) ...[
              const SizedBox(height: CoeloSpacing.space1),
              Row(
                children: [
                  const _AvatarStack(),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(
                    child: Text(post.likedBy!, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ],
            const SizedBox(height: CoeloSpacing.space2),
            Wrap(
              spacing: CoeloSpacing.space1,
              children: [
                Text(
                  post.author,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(post.body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _PostMedia extends StatelessWidget {
  const _PostMedia({
    required this.mediaKey,
    required this.media,
    required this.demoIndices,
    required this.repository,
    required this.onReload,
    required this.compact,
    required this.onOpen,
  });

  final Key mediaKey;
  final List<PrincipalHappensMediaDescriptor> media;
  final List<int> demoIndices;
  final PrincipalHappensFeedRepository? repository;
  final VoidCallback onReload;
  final bool compact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Abrir galeria da publicação',
    child: FocusableActionDetector(
      key: mediaKey,
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onOpen();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: SizedBox(
          height: compact ? 320 : 460,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: media.isNotEmpty
                          ? _AuthorizedMedia(
                              media: media.first,
                              repository: repository,
                              onReload: onReload,
                            )
                          : _SpriteImage(
                              asset: 'assets/principal_happens/feed-strip.png',
                              index: demoIndices.first,
                              count: 4,
                            ),
                    ),
                    if (media.isEmpty && !compact) ...[
                      const SizedBox(width: 3),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _SpriteImage(
                                asset: 'assets/principal_happens/feed-strip.png',
                                index: demoIndices[1],
                                count: 4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Expanded(
                              child: _SpriteImage(
                                asset: 'assets/principal_happens/feed-strip.png',
                                index: demoIndices[2],
                                count: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Positioned(
                  right: CoeloSpacing.space2,
                  top: CoeloSpacing.space2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inverseSurface.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(CoeloRadius.full),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '1/${media.isNotEmpty ? media.length : demoIndices.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _HappensGallery extends StatefulWidget {
  const _HappensGallery({
    required this.post,
    required this.repository,
    required this.onReload,
    required this.onShare,
    required this.onSave,
  });

  final PrincipalPostPreviewItem post;
  final PrincipalHappensFeedRepository? repository;
  final VoidCallback onReload;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  @override
  State<_HappensGallery> createState() => _HappensGalleryState();
}

final class _HappensGalleryState extends State<_HappensGallery> {
  final _focusNode = FocusNode();
  var _index = 0;

  int get _count =>
      widget.post.media.isNotEmpty ? widget.post.media.length : widget.post.mediaIndices.length;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _move(int delta) => setState(() => _index = (_index + delta + _count) % _count);

  void _invokeOrExplain(VoidCallback? callback, String action) {
    if (callback != null) {
      callback();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$action indisponível nesta prévia.')));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final content = KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.escape) Navigator.of(context).pop();
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _move(-1);
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) _move(1);
        },
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: .86,
                    heightFactor: .82,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(CoeloRadius.lg),
                        child: widget.post.media.isNotEmpty
                            ? _AuthorizedMedia(
                                media: widget.post.media[_index],
                                repository: widget.repository,
                                onReload: widget.onReload,
                                onVideoUnavailable: () => Navigator.of(context).pop(),
                                fit: BoxFit.contain,
                              )
                            : Center(
                                child: AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: _SpriteImage(
                                    asset: 'assets/principal_happens/feed-strip.png',
                                    index: widget.post.mediaIndices[_index],
                                    count: 4,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              if (compact)
                Positioned(
                  left: CoeloSpacing.space2,
                  top: CoeloSpacing.space2,
                  child: TextButton.icon(
                    key: const Key('principal-happens-gallery-compact-return'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Acontece'),
                  ),
                )
              else
                Positioned(
                  left: CoeloSpacing.space4,
                  top: CoeloSpacing.space3,
                  child: Text(
                    'coelo',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              if (!compact)
                Positioned(
                  right: CoeloSpacing.space3,
                  top: CoeloSpacing.space2,
                  child: IconButton(
                    key: const Key('principal-happens-gallery-wide-close'),
                    tooltip: 'Fechar galeria',
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              if (_count > 1) ...[
                Positioned(
                  left: CoeloSpacing.space3,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: 'Mídia anterior',
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                  ),
                ),
                Positioned(
                  right: CoeloSpacing.space3,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: 'Próxima mídia',
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
              ],
              Positioned(
                left: 0,
                right: 0,
                bottom: CoeloSpacing.space4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .64),
                        borderRadius: BorderRadius.circular(CoeloRadius.full),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CoeloSpacing.space3,
                          vertical: CoeloSpacing.space2,
                        ),
                        child: Text(
                          '${_index + 1} de $_count',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    IconButton(
                      tooltip: 'Compartilhar mídia',
                      onPressed: () => _invokeOrExplain(widget.onShare, 'Compartilhamento'),
                      color: Colors.white,
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                    IconButton(
                      tooltip: 'Salvar mídia',
                      onPressed: () => _invokeOrExplain(widget.onSave, 'Salvar mídia'),
                      color: Colors.white,
                      icon: const Icon(Icons.bookmark_border_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (compact) {
        return Dialog.fullscreen(
          key: const Key('principal-happens-gallery'),
          backgroundColor: Colors.black,
          child: content,
        );
      }
      return Dialog(
        key: const Key('principal-happens-gallery'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(CoeloSpacing.space6),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
          child: ColoredBox(color: Colors.black, child: content),
        ),
      );
    },
  );
}

final class _AuthorizedMedia extends StatefulWidget {
  const _AuthorizedMedia({
    required this.media,
    required this.repository,
    required this.onReload,
    this.onVideoUnavailable,
    this.fit = BoxFit.cover,
  });

  final PrincipalHappensMediaDescriptor media;
  final PrincipalHappensFeedRepository? repository;
  final VoidCallback onReload;
  final VoidCallback? onVideoUnavailable;
  final BoxFit fit;

  @override
  State<_AuthorizedMedia> createState() => _AuthorizedMediaState();
}

final class _AuthorizedMediaState extends State<_AuthorizedMedia> {
  late Future<PrincipalHappensMediaRead> _read = _resolve();

  Future<PrincipalHappensMediaRead> _resolve() {
    final repository = widget.repository;
    if (repository == null) {
      return Future.error(const PrincipalHappensFeedUnavailable());
    }
    return repository.resolveMedia(widget.media);
  }

  @override
  void didUpdateWidget(covariant _AuthorizedMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.media.readTicket != widget.media.readTicket) {
      _read = _resolve();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PrincipalHappensMediaRead>(
    future: _read,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      final read = snapshot.data;
      if (read == null) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Center(
            child: IconButton(
              tooltip: 'Tentar carregar a mídia novamente',
              onPressed: widget.onReload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        );
      }
      if (read.mimeType.startsWith('video/')) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  const Text(
                    'Reprodução de vídeo indisponível nesta prévia.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  OutlinedButton.icon(
                    key: const Key('principal-happens-video-unavailable-action'),
                    onPressed: widget.onVideoUnavailable ?? widget.onReload,
                    icon: Icon(
                      widget.onVideoUnavailable == null
                          ? Icons.refresh_rounded
                          : Icons.chevron_left_rounded,
                    ),
                    label: Text(
                      widget.onVideoUnavailable == null
                          ? 'Atualizar publicação'
                          : 'Voltar ao Acontece',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Image.network(
        read.signedUrl,
        key: ValueKey(widget.media.readTicket),
        fit: widget.fit,
        semanticLabel: 'Registro da comunidade escolar',
        errorBuilder: (_, _, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Center(
            child: IconButton(
              tooltip: 'Tentar carregar a mídia novamente',
              onPressed: widget.onReload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ),
      );
    },
  );
}

final class _SpriteImage extends StatelessWidget {
  const _SpriteImage({required this.asset, required this.index, required this.count});
  final String asset;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ClipRect(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: constraints.maxWidth * count,
        maxWidth: constraints.maxWidth * count,
        minHeight: constraints.maxHeight,
        maxHeight: constraints.maxHeight,
        child: Transform.translate(
          offset: Offset(-constraints.maxWidth * index, 0),
          child: SizedBox(
            width: constraints.maxWidth * count,
            height: constraints.maxHeight,
            child: Image.asset(
              asset,
              fit: BoxFit.fill,
              semanticLabel: 'Registro da comunidade escolar',
              errorBuilder: (_, _, _) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.image_not_supported_outlined)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _SocialAction extends StatelessWidget {
  const _SocialAction({
    this.actionKey,
    required this.tooltip,
    required this.icon,
    this.label,
    required this.onPressed,
    this.color,
  });
  final Key? actionKey;
  final String tooltip;
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return IconButton(
        key: actionKey,
        tooltip: tooltip,
        onPressed: onPressed,
        color: color ?? Theme.of(context).colorScheme.onSurface,
        icon: Icon(icon, size: CoeloSize.iconSm),
      );
    }
    return TextButton.icon(
      key: actionKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? Theme.of(context).colorScheme.onSurface,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space1),
      ),
      icon: Icon(icon, size: CoeloSize.iconSm),
      label: Text(label!),
    );
  }
}

final class _AvatarStack extends StatelessWidget {
  const _AvatarStack();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    height: 24,
    child: Stack(
      children: [
        for (var index = 0; index < 3; index++)
          Positioned(
            left: index * 15,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Color.lerp(
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                  index / 3,
                ),
                child: Text('${index + 1}', style: const TextStyle(fontSize: 8)),
              ),
            ),
          ),
      ],
    ),
  );
}

final class _ContextColumn extends StatelessWidget {
  const _ContextColumn({required this.data, required this.onOpenAgenda, required this.onAction});
  final PrincipalHappensPreviewData data;
  final VoidCallback onOpenAgenda;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('principal-happens-context-column'),
    width: 286,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        CoeloSpacing.space2,
        CoeloSpacing.space3,
        CoeloSpacing.space3,
        CoeloSpacing.space5,
      ),
      child: Column(
        children: [
          _ContextPanel(
            title: 'Próximos eventos',
            action: 'Ver agenda',
            onAction: onOpenAgenda,
            children: [
              for (final event in data.events) _EventRow(event: event),
              const SizedBox(height: CoeloSpacing.space2),
              OutlinedButton(
                key: const Key('principal-happens-open-agenda'),
                onPressed: onOpenAgenda,
                child: const Text('Ver todos os eventos'),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          _ContextPanel(
            title: 'Avisos importantes',
            action: 'Ver todos',
            onAction: () => onAction('Todos os avisos'),
            children: [for (final notice in data.notices) _NoticeCard(notice: notice)],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          _ContextPanel(
            title: 'Aniversariantes',
            action: 'Ver todos',
            onAction: () => onAction('Aniversariantes'),
            children: [for (final birthday in data.birthdays) _BirthdayRow(item: birthday)],
          ),
        ],
      ),
    ),
  );
}

final class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.title,
    required this.action,
    required this.onAction,
    required this.children,
  });
  final String title;
  final String action;
  final VoidCallback onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actionButton = TextButton(onPressed: onAction, child: Text(action));
      final titleText = Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      );
      final stackedHeader = constraints.maxWidth < 300;

      return Container(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stackedHeader) ...[
              titleText,
              Align(alignment: Alignment.centerLeft, child: actionButton),
            ] else
              Row(
                children: [
                  Expanded(child: titleText),
                  actionButton,
                ],
              ),
            ...children,
          ],
        ),
      );
    },
  );
}

final class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final PrincipalEventPreviewItem event;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Row(
      children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(CoeloRadius.md),
          ),
          child: Column(
            children: [
              Text(event.month, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
              Text(event.day, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: Theme.of(context).textTheme.labelSmall),
              Text(event.time, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});
  final PrincipalNoticePreviewItem notice;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    padding: const EdgeInsets.all(CoeloSpacing.space2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .3),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(notice.title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(notice.body, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(notice.time, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

final class _BirthdayRow extends StatelessWidget {
  const _BirthdayRow({required this.item});
  final PrincipalBirthdayPreviewItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Row(
      children: [
        CircleAvatar(radius: 17, child: Text(item.initials, style: const TextStyle(fontSize: 9))),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.labelSmall),
              Text(item.context, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Text(item.date, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
