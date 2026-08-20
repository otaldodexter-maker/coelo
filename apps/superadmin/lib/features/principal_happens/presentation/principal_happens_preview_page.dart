import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../domain/principal_happens_preview_data.dart';

final class PrincipalHappensPreviewPage extends StatefulWidget {
  const PrincipalHappensPreviewPage({
    this.onOpenMoments,
    this.onOpenProfile,
    this.onOpenAgenda,
    this.onOpenNow,
    this.onOpenForYou,
    this.onCreatePost,
    this.data = PrincipalHappensPreviewData.demo,
    super.key,
  });

  final VoidCallback? onOpenMoments;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onOpenNow;
  final VoidCallback? onOpenForYou;
  final VoidCallback? onCreatePost;
  final PrincipalHappensPreviewData data;

  @override
  State<PrincipalHappensPreviewPage> createState() => _PrincipalHappensPreviewPageState();
}

final class _PrincipalHappensPreviewPageState extends State<PrincipalHappensPreviewPage> {
  final _likedPosts = <int>{};
  final _savedPosts = <int>{};

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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final expanded = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
      final large = constraints.maxWidth >= CoeloBreakpoints.large.minWidth;
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: _HappensAppBar(
          onBug: () => _prototypeMessage('Reporte de bug'),
          onNotifications: () => _prototypeMessage('Notificações'),
          onProfile: () => _invoke(widget.onOpenProfile, 'Perfil'),
        ),
        bottomNavigationBar: compact
            ? _MobileNavigation(
                onProfile: () => _invoke(widget.onOpenProfile, 'Perfil'),
                onAgenda: () => _invoke(widget.onOpenAgenda, 'Agenda'),
                onMessage: () => _prototypeMessage('Mensagens'),
                onMore: () => _prototypeMessage('Mais opções'),
                onCreate: () => _invoke(widget.onCreatePost, 'Criar publicação'),
              )
            : null,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expanded)
              _DesktopRail(
                onAgenda: () => _invoke(widget.onOpenAgenda, 'Agenda'),
                onMessage: () => _prototypeMessage('Mensagens'),
                onItem: _prototypeMessage,
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: large ? 940 : 780),
                  child: _Feed(
                    data: widget.data,
                    compact: compact,
                    onMoments: () => _invoke(widget.onOpenMoments, 'Momentos'),
                    onProfile: () => _invoke(widget.onOpenProfile, 'Perfil'),
                    onViewAllNow: () => _invoke(widget.onOpenNow, 'Todos os conteúdos de Agora'),
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
                  ),
                ),
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
      );
    },
  );
}

final class _HappensAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HappensAppBar({
    required this.onBug,
    required this.onNotifications,
    required this.onProfile,
  });

  final VoidCallback onBug;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    titleSpacing: CoeloSpacing.space4,
    shape: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    title: Image.asset(
      'assets/brand/logo-coelo-orange-complete.png',
      key: const Key('principal-happens-logo'),
      width: 116,
      height: 36,
      alignment: Alignment.centerLeft,
      fit: BoxFit.contain,
      semanticLabel: 'Coelo',
    ),
    actions: [
      IconButton(
        key: const Key('principal-happens-bug'),
        tooltip: 'Reportar bug',
        onPressed: onBug,
        icon: const Icon(Icons.bug_report_outlined),
      ),
      Stack(
        children: [
          IconButton(
            key: const Key('principal-happens-notifications'),
            tooltip: 'Notificações',
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: ExcludeSemantics(
              child: CircleAvatar(
                radius: 4,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(left: CoeloSpacing.space1, right: CoeloSpacing.space3),
        child: Tooltip(
          message: 'Abrir Perfil',
          child: IconButton(
            key: const Key('principal-happens-context-avatar'),
            onPressed: onProfile,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundImage: const AssetImage('assets/principal_profile/institution-crest.png'),
            ),
          ),
        ),
      ),
    ],
  );
}

final class _Feed extends StatelessWidget {
  const _Feed({
    required this.data,
    required this.compact,
    required this.onMoments,
    required this.onProfile,
    required this.onViewAllNow,
    required this.onForYou,
    required this.likedPosts,
    required this.savedPosts,
    required this.onLike,
    required this.onSave,
    required this.onPrototypeAction,
  });

  final PrincipalHappensPreviewData data;
  final bool compact;
  final VoidCallback onMoments;
  final VoidCallback onProfile;
  final VoidCallback onViewAllNow;
  final VoidCallback onForYou;
  final Set<int> likedPosts;
  final Set<int> savedPosts;
  final ValueChanged<int> onLike;
  final ValueChanged<int> onSave;
  final ValueChanged<String> onPrototypeAction;

  @override
  Widget build(BuildContext context) {
    final horizontal = compact ? CoeloSpacing.space3 : CoeloSpacing.space4;
    return CustomScrollView(
      key: const Key('principal-happens-feed'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, CoeloSpacing.space3, horizontal, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Acontece',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverToBoxAdapter(
            child: _TopTabs(onForYou: onForYou, onMoments: onMoments, onProfile: onProfile),
          ),
        ),
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
              onViewAll: onViewAllNow,
              onOpenItem: onViewAllNow,
            ),
          ),
        ),
        SliverList.separated(
          itemCount: data.posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space3),
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : horizontal),
            child: _PostCard(
              index: index,
              post: data.posts[index],
              compact: compact,
              liked: likedPosts.contains(index),
              saved: savedPosts.contains(index),
              onLike: () => onLike(index),
              onSave: () => onSave(index),
              onAction: onPrototypeAction,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: CoeloSpacing.space6)),
      ],
    );
  }
}

final class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.onForYou, required this.onMoments, required this.onProfile});
  final VoidCallback onForYou;
  final VoidCallback onMoments;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final equalWidth = constraints.maxWidth / 4;
      final tabWidth = equalWidth < 112 ? 112.0 : equalWidth;
      return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: tabWidth,
                child: const _Tab(label: 'Acontece', selected: true),
              ),
              SizedBox(
                width: tabWidth,
                child: _Tab(
                  tabKey: const Key('principal-happens-tab-for-you'),
                  label: 'Para você',
                  onPressed: onForYou,
                ),
              ),
              SizedBox(
                width: tabWidth,
                child: _Tab(
                  tabKey: const Key('principal-happens-tab-momentos'),
                  label: 'Momentos',
                  onPressed: onMoments,
                ),
              ),
              SizedBox(
                width: tabWidth,
                child: _Tab(
                  tabKey: const Key('principal-happens-tab-perfil'),
                  label: 'Perfil',
                  onPressed: onProfile,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

final class _Tab extends StatelessWidget {
  const _Tab({this.tabKey, required this.label, this.selected = false, this.onPressed});
  final Key? tabKey;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: TextButton(
      key: tabKey,
      onPressed: selected ? () {} : onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(88, CoeloSize.touchMin)),
        foregroundColor: WidgetStatePropertyAll(
          selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
        overlayColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .35),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 0,
          ),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: selected
              ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
          child: Text(
            label,
            style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w400),
          ),
        ),
      ),
    ),
  );
}

final class _NowSection extends StatelessWidget {
  const _NowSection({
    required this.items,
    required this.compact,
    required this.onViewAll,
    required this.onOpenItem,
  });
  final List<PrincipalNowPreviewItem> items;
  final bool compact;
  final VoidCallback onViewAll;
  final VoidCallback onOpenItem;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Agora',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onViewAll, child: const Text('Ver tudo')),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space2),
      SizedBox(
        height: compact ? 204 : 218,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: CoeloSpacing.space2),
          itemBuilder: (context, index) =>
              _NowCard(item: items[index], width: compact ? 106 : 120, onPressed: onOpenItem),
        ),
      ),
    ],
  );
}

final class _NowCard extends StatelessWidget {
  const _NowCard({required this.item, required this.width, required this.onPressed});
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
    required this.compact,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
    required this.onAction,
  });
  final int index;
  final PrincipalPostPreviewItem post;
  final bool compact;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final ValueChanged<String> onAction;

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
            const SizedBox(height: CoeloSpacing.space3),
            Text(post.body, style: Theme.of(context).textTheme.bodyMedium),
            if (post.mediaIndices.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space3),
              _PostMedia(indices: post.mediaIndices, compact: compact),
            ],
            const SizedBox(height: CoeloSpacing.space2),
            Row(
              children: [
                _SocialAction(
                  actionKey: Key('principal-happens-like-post-$index'),
                  tooltip: liked ? 'Remover curtida' : 'Curtir',
                  icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: liked ? scheme.primary : null,
                  label: '${post.likes + (liked ? 1 : 0)}',
                  onPressed: onLike,
                ),
                _SocialAction(
                  tooltip: 'Comentar',
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.comments}',
                  onPressed: () => onAction('Comentários'),
                ),
                _SocialAction(
                  tooltip: 'Compartilhar',
                  icon: Icons.ios_share_rounded,
                  label: '${post.shares}',
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
            if (index == 0) ...[
              const SizedBox(height: CoeloSpacing.space1),
              Row(
                children: [
                  const _AvatarStack(),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(child: Text(post.likedBy, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _PostMedia extends StatelessWidget {
  const _PostMedia({required this.indices, required this.compact});
  final List<int> indices;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 260 : 300,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(CoeloRadius.md),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _SpriteImage(
                  asset: 'assets/principal_happens/feed-strip.png',
                  index: indices.first,
                  count: 4,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 3),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _SpriteImage(
                          asset: 'assets/principal_happens/feed-strip.png',
                          index: indices[1],
                          count: 4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Expanded(
                        child: _SpriteImage(
                          asset: 'assets/principal_happens/feed-strip.png',
                          index: indices[2],
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
                color: Colors.black87,
                borderRadius: BorderRadius.circular(CoeloRadius.full),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '1/${indices.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
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
    required this.label,
    required this.onPressed,
    this.color,
  });
  final Key? actionKey;
  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: actionKey,
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: color ?? Theme.of(context).colorScheme.onSurface,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space1),
    ),
    icon: Icon(icon, size: CoeloSize.iconSm),
    label: Text(label),
  );
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

final class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.onAgenda, required this.onMessage, required this.onItem});
  final VoidCallback onAgenda;
  final VoidCallback onMessage;
  final ValueChanged<String> onItem;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('principal-happens-desktop-rail'),
    width: 142,
    padding: const EdgeInsets.fromLTRB(
      CoeloSpacing.space2,
      CoeloSpacing.space3,
      CoeloSpacing.space2,
      CoeloSpacing.space3,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    ),
    child: Column(
      children: [
        _RailItem('Acontece', Icons.home_rounded, selected: true, onPressed: () {}),
        _RailItem('Mensagens', Icons.chat_bubble_outline_rounded, onPressed: onMessage),
        _RailItem('Agenda', Icons.calendar_today_outlined, onPressed: onAgenda),
        _RailItem('Atividades', Icons.assignment_outlined, onPressed: () => onItem('Atividades')),
        _RailItem('Desempenho', Icons.bar_chart_rounded, onPressed: () => onItem('Desempenho')),
        _RailItem(
          'Financeiro',
          Icons.monetization_on_outlined,
          onPressed: () => onItem('Financeiro'),
        ),
        _RailItem('Documentos', Icons.folder_outlined, onPressed: () => onItem('Documentos')),
        _RailItem('Comunidade', Icons.groups_outlined, onPressed: () => onItem('Comunidade')),
        _RailItem('Mais', Icons.more_horiz_rounded, onPressed: () => onItem('Mais opções')),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Colégio Coelo', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Ensino que inspira para a vida.', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.circle, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _RailItem extends StatelessWidget {
  const _RailItem(this.label, this.icon, {required this.onPressed, this.selected = false});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
    child: TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .35)
            : Colors.transparent,
        foregroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
      ),
      icon: Icon(icon, size: CoeloSize.iconSm),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CoeloSpacing.space3),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ),
        ...children,
      ],
    ),
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

final class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.onProfile,
    required this.onAgenda,
    required this.onMessage,
    required this.onMore,
    required this.onCreate,
  });
  final VoidCallback onProfile;
  final VoidCallback onAgenda;
  final VoidCallback onMessage;
  final VoidCallback onMore;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      key: const Key('principal-happens-mobile-nav'),
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const _BottomItem('Acontece', Icons.home_rounded, selected: true),
          _BottomItem('Mensagens', Icons.chat_bubble_outline_rounded, onPressed: onMessage),
          _CreateButton(onPressed: onCreate),
          _BottomItem('Agenda', Icons.calendar_today_outlined, onPressed: onAgenda),
          _BottomItem('Mais', Icons.menu_rounded, onPressed: onMore),
        ],
      ),
    ),
  );
}

final class _BottomItem extends StatelessWidget {
  const _BottomItem(this.label, this.icon, {this.selected = false, this.onPressed});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final showLabel = MediaQuery.textScalerOf(context).scale(1) <= 1.5;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: TextButton(
        onPressed: onPressed ?? () {},
        style: TextButton.styleFrom(
          minimumSize: const Size(58, 58),
          padding: EdgeInsets.zero,
          foregroundColor: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: CoeloSize.iconSm),
            if (showLabel) ...[
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 9)),
            ],
          ],
        ),
      ),
    );
  }
}

final class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: 'Criar',
    onPressed: onPressed,
    icon: const Icon(Icons.add_rounded),
  );
}
