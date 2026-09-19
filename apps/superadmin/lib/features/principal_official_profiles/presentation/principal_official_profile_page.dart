import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/data/entity_image_repository.dart';
import '../../../shared/presentation/widgets/entity_image_view.dart';
import '../../notices/domain/notice_repository.dart';
import '../../notices/domain/platform_notice.dart';
import '../domain/principal_official_profile.dart';

/// Tela do perfil oficial no Principal (spec 068): cabeçalho com @, descrição
/// e seguir/seguindo, atalhos para os outros perfis Coelo e as publicações
/// que o ator pode ver (mesma audiência do Para você).
final class PrincipalOfficialProfilePage extends StatefulWidget {
  const PrincipalOfficialProfilePage({
    required this.handle,
    required this.reader,
    this.embedded = false,
    this.onReturn,
    this.onOpenProfile,
    this.onOpenCtaTarget,
    super.key,
  });

  final String handle;
  final PrincipalOfficialProfilesReader reader;
  final bool embedded;
  final VoidCallback? onReturn;

  /// Abre outro perfil oficial pelo handle.
  final ValueChanged<String>? onOpenProfile;

  /// Abre o destino do CTA (spec 069 H13); devolve `false` quando não há rota.
  final bool Function(NoticeCtaTarget target)? onOpenCtaTarget;

  @override
  State<PrincipalOfficialProfilePage> createState() => _PrincipalOfficialProfilePageState();
}

final class _PrincipalOfficialProfilePageState extends State<PrincipalOfficialProfilePage> {
  PrincipalOfficialProfileDetail? _detail;
  NoticeRepositoryException? _error;
  var _loading = true;
  var _togglingFollow = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrincipalOfficialProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.reader.loadOfficialProfile(widget.handle);
      if (!mounted || generation != _generation) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on NoticeRepositoryException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = const NoticeUnexpectedException();
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final detail = _detail;
    if (detail == null || _togglingFollow) return;
    final profile = detail.profile;
    setState(() => _togglingFollow = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final following = await widget.reader.setOfficialFollowing(
        profile.personId,
        follow: !profile.following,
      );
      if (!mounted) return;
      setState(() {
        _detail = PrincipalOfficialProfileDetail(
          profile: profile.copyWith(
            following: following,
            followers:
                profile.followers + (following == profile.following ? 0 : (following ? 1 : -1)),
          ),
          profiles: detail.profiles,
          items: detail.items,
          posts: detail.posts,
        );
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              following
                  ? 'Você segue ${profile.displayName}.'
                  : 'Você deixou de seguir ${profile.displayName}.',
            ),
          ),
        );
    } on NoticeRepositoryException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.safeMessage)));
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Não foi possível concluir a operação.')));
    } finally {
      if (mounted) setState(() => _togglingFollow = false);
    }
  }

  void _return() {
    final callback = widget.onReturn;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _return},
    child: Focus(
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          final title = _detail?.profile.displayName ?? 'Perfil Coelo';
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: compact
                ? null
                : AppBar(
                    leading: IconButton(
                      tooltip: 'Voltar',
                      onPressed: _return,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    title: Text(title),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                  ),
            body: compact
                ? SafeArea(
                    top: !widget.embedded,
                    bottom: !widget.embedded,
                    left: !widget.embedded,
                    right: !widget.embedded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('principal-official-profile-return'),
                            onPressed: _return,
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: Text(title),
                          ),
                        ),
                        Expanded(child: _body(context)),
                      ],
                    ),
                  )
                : _body(context),
          );
        },
      ),
    ),
  );

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(
        key: Key('principal-official-profile-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error case final error?) {
      final notFound = error is NoticeNotFoundException;
      final unauthorized = error is NoticeUnauthorizedException;
      return Center(
        key: const Key('principal-official-profile-error'),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                unauthorized
                    ? Icons.lock_outline_rounded
                    : notFound
                    ? Icons.person_off_outlined
                    : Icons.cloud_off_outlined,
                size: CoeloSize.iconLg,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              Text(
                unauthorized
                    ? 'Acesso não disponível.'
                    : notFound
                    ? 'Este perfil não existe ou não está ativo.'
                    : 'Não foi possível carregar o perfil.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!unauthorized && !notFound) ...[
                const SizedBox(height: CoeloSpacing.space3),
                FilledButton.tonal(onPressed: _load, child: const Text('Tentar novamente')),
              ],
            ],
          ),
        ),
      );
    }
    final detail = _detail!;
    final others = detail.profiles.where((p) => p.id != detail.profile.id).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('principal-official-profile-list'),
        padding: const EdgeInsets.fromLTRB(
          CoeloSpacing.space4,
          CoeloSpacing.space2,
          CoeloSpacing.space4,
          CoeloSpacing.space8,
        ),
        children: [
          _Header(profile: detail.profile, busy: _togglingFollow, onToggleFollow: _toggleFollow),
          if (others.isNotEmpty) ...[
            const SizedBox(height: CoeloSpacing.space5),
            Text('Outros perfis Coelo', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: CoeloSpacing.space2),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: others.length,
                separatorBuilder: (_, _) => const SizedBox(width: CoeloSpacing.space2),
                itemBuilder: (context, index) {
                  final other = others[index];
                  return ActionChip(
                    key: Key('principal-official-profile-chip-${other.handle}'),
                    avatar: Icon(
                      other.following ? Icons.check_rounded : Icons.add_rounded,
                      size: CoeloSize.iconSm,
                    ),
                    label: Text(other.displayName),
                    onPressed: widget.onOpenProfile == null
                        ? null
                        : () => widget.onOpenProfile!(other.handle),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: CoeloSpacing.space5),
          Text('Publicações', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: CoeloSpacing.space2),
          if (detail.items.isEmpty && detail.posts.isEmpty)
            Padding(
              key: const Key('principal-official-profile-empty'),
              padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space6),
              child: Text(
                'Nenhuma publicação por enquanto.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            for (final item in detail.items) ...[
              _PublicationCard(item: item, onOpenCtaTarget: widget.onOpenCtaTarget),
              const SizedBox(height: CoeloSpacing.space3),
            ],
            for (final post in detail.posts) ...[
              _PostCard(post: post),
              const SizedBox(height: CoeloSpacing.space3),
            ],
          ],
        ],
      ),
    );
  }
}

final class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.busy, required this.onToggleFollow});

  final PrincipalOfficialProfile profile;
  final bool busy;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final followers = profile.followers == 1 ? '1 seguidor' : '${profile.followers} seguidores';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 72,
              child: EntityImageView(
                entity: EntityKind.person,
                entityId: profile.personId,
                principal: true,
                semanticLabel: 'Avatar de ${profile.displayName}',
                fallback: FittedBox(
                  child: CoeloAvatar(
                    initials: profile.initials,
                    semanticLabel: 'Avatar de ${profile.displayName}',
                    size: CoeloAvatarSize.large,
                  ),
                ),
              ),
            ),
            const SizedBox(width: CoeloSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          key: const Key('principal-official-profile-name'),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: CoeloSpacing.space1),
                      Tooltip(
                        message: 'Perfil oficial do Coelo',
                        child: Icon(
                          Icons.verified_rounded,
                          color: colors.primary,
                          size: CoeloSize.iconSm,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '@${profile.handle}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: CoeloSpacing.space1),
                  Text(
                    followers,
                    key: const Key('principal-official-profile-followers'),
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (profile.description.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Text(profile.description, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: CoeloSpacing.space3),
        if (profile.mandatory)
          Tooltip(
            message:
                'Todo mundo segue o ${profile.displayName}: é por aqui que chegam as novidades do app.',
            child: FilledButton.tonalIcon(
              key: const Key('principal-official-profile-follow'),
              onPressed: null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Seguindo · perfil obrigatório'),
            ),
          )
        else if (profile.following)
          OutlinedButton.icon(
            key: const Key('principal-official-profile-follow'),
            onPressed: busy ? null : onToggleFollow,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Seguindo'),
          )
        else
          FilledButton.icon(
            key: const Key('principal-official-profile-follow'),
            onPressed: busy ? null : onToggleFollow,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Seguir'),
          ),
      ],
    );
  }
}

final class _PublicationCard extends StatelessWidget {
  const _PublicationCard({required this.item, required this.onOpenCtaTarget});

  final PlatformNotice item;
  final bool Function(NoticeCtaTarget target)? onOpenCtaTarget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = item.startsAt;
    final cta = item.linkLabel ?? item.buttonLabel;
    final hasTarget = item.ctaTarget.hasTarget && onOpenCtaTarget != null;
    return Card(
      key: Key('principal-official-profile-item-${item.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item.type.label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  CoeloDateField.format(date.toLocal()),
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              item.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (item.message.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space1),
              Text(item.message, style: theme.textTheme.bodyMedium),
            ],
            if (hasTarget) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => onOpenCtaTarget!(item.ctaTarget),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(cta),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final PrincipalOfficialPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      key: Key('principal-official-profile-post-${post.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ACONTECE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  CoeloDateField.format(post.publishedAt.toLocal()),
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(post.caption, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
