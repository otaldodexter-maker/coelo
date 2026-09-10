import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../principal_moments/domain/principal_moments_feed_repository.dart';
import '../../principal_moments/domain/principal_moments_preview_data.dart';

/// The Momentos tab embedded in the contextual Perfil.
///
/// It consumes the authorized projection (`listVisibleMoments`) with the scope
/// the server resolved for the actor. Media arrives already resolved as short
/// lived signed URLs; nothing here reads a bucket, an object key or a local
/// sprite, and the preview fixture the `/dev` Perfil uses never reaches this
/// widget.
///
/// The tab offers neither publishing nor withdrawal: those belong to the
/// Momentos surface itself, and duplicating them here would create a second
/// place to reason about the same commands.
final class PrincipalProfileMomentsTab extends StatefulWidget {
  const PrincipalProfileMomentsTab({
    required this.repository,
    required this.scope,
    this.embedded = true,
    super.key,
  });

  final PrincipalMomentsFeedRepository repository;
  final PrincipalMomentsFeedScope scope;
  final bool embedded;

  @override
  State<PrincipalProfileMomentsTab> createState() => _PrincipalProfileMomentsTabState();
}

final class _PrincipalProfileMomentsTabState extends State<PrincipalProfileMomentsTab> {
  final _items = <PrincipalMomentPreviewItem>[];
  var _loading = true;
  var _unauthorized = false;
  Object? _error;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrincipalProfileMomentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // By value, not by identity: the route rebuilds the scope every frame.
    if (!identical(oldWidget.repository, widget.repository) || oldWidget.scope != widget.scope) {
      _load();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final scope = widget.scope;
    setState(() {
      _items.clear();
      _loading = true;
      _unauthorized = false;
      _error = null;
    });
    try {
      final moments = await repository.listVisibleMoments(scope);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items
          ..clear()
          ..addAll(moments);
        _loading = false;
      });
    } on PrincipalMomentsFeedUnauthorized catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      // Fail-closed: no previous content survives and no retry is offered,
      // because retrying a denial only re-probes the server.
      setState(() {
        _items.clear();
        _loading = false;
        _unauthorized = true;
        _error = error;
      });
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items.clear();
        _loading = false;
        _unauthorized = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Carregando Momentos',
          child: const CircularProgressIndicator(key: Key('principal-profile-moments-loading')),
        ),
      );
    }
    if (_unauthorized) {
      return const _MomentsTabState(
        stateKey: Key('principal-profile-moments-unauthorized'),
        icon: Icons.lock_outline_rounded,
        message: 'Você não tem acesso aos Momentos deste contexto.',
      );
    }
    if (_error != null) {
      final generation = _loadGeneration;
      return _MomentsTabState(
        stateKey: const Key('principal-profile-moments-error'),
        icon: Icons.cloud_off_outlined,
        message: 'Não foi possível carregar os Momentos.',
        actionLabel: 'Tentar novamente',
        onAction: () {
          if (mounted && generation == _loadGeneration) _load();
        },
      );
    }
    if (_items.isEmpty) {
      return const _MomentsTabState(
        stateKey: Key('principal-profile-moments-empty'),
        icon: Icons.photo_library_outlined,
        message: 'Nada publicado em Momentos por aqui.',
      );
    }
    return ListView.separated(
      key: const Key('principal-profile-moments-list'),
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space3),
      itemBuilder: (context, index) =>
          _ProfileMomentCard(key: Key('principal-profile-moment-$index'), item: _items[index]),
    );
  }
}

final class _ProfileMomentCard extends StatelessWidget {
  const _ProfileMomentCard({required this.item, super.key});

  final PrincipalMomentPreviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = [...item.media]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.author,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text('${item.context} · ${item.time}', style: theme.textTheme.bodySmall),
            if (item.caption.trim().isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Text(item.caption, style: theme.textTheme.bodyMedium),
            ],
            if (media.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space3),
              ClipRRect(
                borderRadius: BorderRadius.circular(CoeloRadius.md),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: _MomentMedia(key: ValueKey(media.first.signedUrl), media: media.first),
                ),
              ),
            ],
            const SizedBox(height: CoeloSpacing.space3),
            Wrap(
              spacing: CoeloSpacing.space4,
              runSpacing: CoeloSpacing.space2,
              children: [
                _Metric(icon: Icons.favorite_border_rounded, label: '${item.likes}'),
                _Metric(icon: Icons.chat_bubble_outline_rounded, label: '${item.comments}'),
                _Metric(icon: Icons.share_outlined, label: '${item.shares}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders one already-signed media, degrading to a neutral slot.
///
/// The URL is short lived and comes from the authorized projection, so a
/// failure never falls back to a local asset or to a public URL.
final class _MomentMedia extends StatelessWidget {
  const _MomentMedia({required this.media, super.key});

  final PrincipalMomentMedia media;

  @override
  Widget build(BuildContext context) {
    if (media.signedUrl.isEmpty) {
      return const _MediaPlaceholder(
        placeholderKey: Key('principal-profile-moment-media-placeholder'),
        icon: Icons.image_not_supported_outlined,
      );
    }
    if (media.mimeType.startsWith('video/')) {
      return const _MediaPlaceholder(
        placeholderKey: Key('principal-profile-moment-media-video'),
        icon: Icons.videocam_outlined,
      );
    }
    return Image.network(
      media.signedUrl,
      key: const Key('principal-profile-moment-media-image'),
      fit: BoxFit.cover,
      semanticLabel: 'Momento da comunidade escolar',
      errorBuilder: (_, _, _) => const _MediaPlaceholder(
        placeholderKey: Key('principal-profile-moment-media-placeholder'),
        icon: Icons.image_not_supported_outlined,
      ),
    );
  }
}

final class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.placeholderKey, required this.icon});

  final Key placeholderKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: placeholderKey,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Center(child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: CoeloSpacing.space1),
      Text(label),
    ],
  );
}

final class _MomentsTabState extends StatelessWidget {
  const _MomentsTabState({
    required this.stateKey,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final Key stateKey;
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    key: stateKey,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: CoeloSize.iconLg, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: CoeloSpacing.space3),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel case final label? when onAction != null) ...[
            const SizedBox(height: CoeloSpacing.space3),
            FilledButton.tonal(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
    ),
  );
}
