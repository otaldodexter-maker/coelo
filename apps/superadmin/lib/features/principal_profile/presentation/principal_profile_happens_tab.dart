import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../principal_happens/domain/principal_happens_feed_repository.dart';
import '../../principal_happens/domain/principal_happens_preview_data.dart';

/// Aba "Acontece" embutida no Perfil contextual.
///
/// Consome a projecao autorizada do feed (`listVisiblePosts`) e resolve midia
/// somente por URL assinada (`resolveMedia`). Nao ha repositorio paralelo,
/// fixture local, asset de preview nem chamada direta a Supabase.
final class PrincipalProfileHappensTab extends StatefulWidget {
  const PrincipalProfileHappensTab({
    required this.repository,
    required this.scope,
    this.onOpenPost,
    this.embedded = true,
    super.key,
  });

  final PrincipalHappensFeedRepository repository;
  final PrincipalHappensFeedScope scope;
  final ValueChanged<PrincipalPostPreviewItem>? onOpenPost;
  final bool embedded;

  @override
  State<PrincipalProfileHappensTab> createState() => _PrincipalProfileHappensTabState();
}

final class _PrincipalProfileHappensTabState extends State<PrincipalProfileHappensTab> {
  final _items = <PrincipalPostPreviewItem>[];
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
  void didUpdateWidget(covariant PrincipalProfileHappensTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.scope;
    final after = widget.scope;
    if (!identical(oldWidget.repository, widget.repository) ||
        before.institutionId != after.institutionId ||
        before.unitId != after.unitId ||
        before.groupId != after.groupId) {
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
      final posts = await repository.listVisiblePosts(scope);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items
          ..clear()
          ..addAll(posts);
        _loading = false;
      });
    } on PrincipalHappensFeedUnauthorized catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      // Fail-closed: nenhum conteudo anterior permanece e nao ha retry.
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
          label: 'Carregando Acontece',
          child: CircularProgressIndicator(key: Key('principal-profile-happens-loading')),
        ),
      );
    }
    if (_unauthorized) {
      return const _HappensTabState(
        stateKey: Key('principal-profile-happens-unauthorized'),
        icon: Icons.lock_outline_rounded,
        message: 'Você não tem acesso ao Acontece deste contexto.',
      );
    }
    if (_error != null) {
      final generation = _loadGeneration;
      return _HappensTabState(
        stateKey: const Key('principal-profile-happens-error'),
        icon: Icons.cloud_off_outlined,
        message: 'Não foi possível carregar o Acontece.',
        actionLabel: 'Tentar novamente',
        onAction: () {
          if (mounted && generation == _loadGeneration) _load();
        },
      );
    }
    if (_items.isEmpty) {
      return const _HappensTabState(
        stateKey: Key('principal-profile-happens-empty'),
        icon: Icons.photo_library_outlined,
        message: 'Nada publicado no Acontece por aqui.',
      );
    }
    final onOpenPost = widget.onOpenPost;
    return ListView.separated(
      key: const Key('principal-profile-happens-list'),
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space3),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _ProfileHappensPostCard(
          key: Key('principal-profile-happens-post-$index'),
          item: item,
          repository: widget.repository,
          onOpen: onOpenPost == null ? null : () => onOpenPost(item),
        );
      },
    );
  }
}

final class _ProfileHappensPostCard extends StatelessWidget {
  const _ProfileHappensPostCard({
    required this.item,
    required this.repository,
    this.onOpen,
    super.key,
  });

  final PrincipalPostPreviewItem item;
  final PrincipalHappensFeedRepository repository;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = [...item.media]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final card = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.primary,
                child: Text(item.initials),
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.author,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text('${item.context} · ${item.time}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(item.body, style: theme.textTheme.bodyMedium),
          if (media.isNotEmpty) ...[
            const SizedBox(height: CoeloSpacing.space3),
            ClipRRect(
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _ProfileHappensMedia(
                  key: ValueKey(media.first.readTicket),
                  media: media.first,
                  repository: repository,
                ),
              ),
            ),
          ],
          if (item.likedBy case final likedBy? when likedBy.isNotEmpty) ...[
            const SizedBox(height: CoeloSpacing.space2),
            Text(likedBy, style: theme.textTheme.bodySmall),
          ],
          if (item.likes != null || item.comments != null || item.shares != null) ...[
            const SizedBox(height: CoeloSpacing.space2),
            Wrap(
              spacing: CoeloSpacing.space4,
              children: [
                if (item.likes case final likes?)
                  _Metric(icon: Icons.favorite_border_rounded, label: '$likes'),
                if (item.comments case final comments?)
                  _Metric(icon: Icons.mode_comment_outlined, label: '$comments'),
                if (item.shares case final shares?)
                  _Metric(icon: Icons.share_outlined, label: '$shares'),
              ],
            ),
          ],
        ],
      ),
    );
    if (onOpen == null) {
      return Semantics(container: true, label: 'Publicação de ${item.author}', child: card);
    }
    return Semantics(
      button: true,
      label: 'Abrir publicação de ${item.author}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: card,
      ),
    );
  }
}

/// Resolve a midia por URL assinada. Falha degrada para um espaco neutro,
/// sem quebrar a lista e sem cair para asset local ou URL publica.
final class _ProfileHappensMedia extends StatefulWidget {
  const _ProfileHappensMedia({required this.media, required this.repository, super.key});

  final PrincipalHappensMediaDescriptor media;
  final PrincipalHappensFeedRepository repository;

  @override
  State<_ProfileHappensMedia> createState() => _ProfileHappensMediaState();
}

final class _ProfileHappensMediaState extends State<_ProfileHappensMedia> {
  late Future<PrincipalHappensMediaRead?> _read = _resolve();
  var _resolveGeneration = 0;

  @override
  void didUpdateWidget(covariant _ProfileHappensMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.media.readTicket != widget.media.readTicket) {
      setState(() => _read = _resolve());
    }
  }

  @override
  void dispose() {
    _resolveGeneration++;
    super.dispose();
  }

  Future<PrincipalHappensMediaRead?> _resolve() {
    final generation = ++_resolveGeneration;
    return widget.repository
        .resolveMedia(widget.media)
        .then<PrincipalHappensMediaRead?>((read) {
          if (!mounted || generation != _resolveGeneration) return null;
          if (read.signedUrl.isEmpty || read.expiresIn <= Duration.zero) return null;
          return read;
        })
        .onError<Object>((_, _) => null);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PrincipalHappensMediaRead?>(
    future: _read,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _MediaPlaceholder(
          placeholderKey: Key('principal-profile-happens-media-loading'),
          icon: Icons.hourglass_empty_rounded,
        );
      }
      final read = snapshot.data;
      if (read == null) {
        return const _MediaPlaceholder(
          placeholderKey: Key('principal-profile-happens-media-placeholder'),
          icon: Icons.image_not_supported_outlined,
        );
      }
      if (read.mimeType.startsWith('video/')) {
        return const _MediaPlaceholder(
          placeholderKey: Key('principal-profile-happens-media-video'),
          icon: Icons.videocam_outlined,
        );
      }
      return Image.network(
        read.signedUrl,
        key: const Key('principal-profile-happens-media-image'),
        fit: BoxFit.cover,
        semanticLabel: 'Registro da comunidade escolar',
        errorBuilder: (_, _, _) => const _MediaPlaceholder(
          placeholderKey: Key('principal-profile-happens-media-placeholder'),
          icon: Icons.image_not_supported_outlined,
        ),
      );
    },
  );
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

final class _HappensTabState extends StatelessWidget {
  const _HappensTabState({
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
          if (actionLabel case final label?) ...[
            const SizedBox(height: CoeloSpacing.space3),
            OutlinedButton(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
    ),
  );
}
