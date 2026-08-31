import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_domain/profile_about.dart';
import 'package:flutter/material.dart';

import '../../principal_happens/domain/principal_happens_preview_data.dart';
import '../../principal_moments/domain/principal_moments_preview_data.dart';
import '../../principal_shared/presentation/principal_global_navigation.dart';
import '../../principal_circulars/domain/circular_repository.dart';
import '../../principal_circulars/presentation/principal_circular_surfaces.dart';
import '../domain/principal_profile_preview_data.dart';

enum _ProfileTab { happens, moments, circulars, about }

final class PrincipalProfilePreviewPage extends StatefulWidget {
  const PrincipalProfilePreviewPage({
    required this.onOpenAgenda,
    this.embedded = false,
    this.onOpenHappens,
    this.onOpenMoments,
    this.onReportBug,
    this.onOpenNotifications,
    this.onOpenContext,
    this.onMessage,
    this.onOpenBio,
    this.onOpenLinks,
    this.onOpenAboutMap,
    this.onOpenMenu,
    this.onOpenHome,
    this.onOpenForYou,
    this.onPublishNow,
    this.onOpenSearch,
    this.onOpenMessages,
    this.circularRepository,
    this.circularScope,
    this.onOpenCircular,
    this.data = PrincipalProfilePreviewData.horizon,
    this.aboutPage,
    super.key,
  });

  final VoidCallback onOpenAgenda;
  final bool embedded;
  final VoidCallback? onOpenHappens;
  final VoidCallback? onOpenMoments;
  final VoidCallback? onReportBug;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenContext;
  final VoidCallback? onMessage;
  final VoidCallback? onOpenBio;
  final VoidCallback? onOpenLinks;
  final VoidCallback? onOpenAboutMap;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenForYou;
  final VoidCallback? onPublishNow;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenMessages;
  final PrincipalProfilePreviewData data;
  final ProfileAboutPage? aboutPage;
  final CircularRepository? circularRepository;
  final CircularScope? circularScope;
  final ValueChanged<String>? onOpenCircular;

  @override
  State<PrincipalProfilePreviewPage> createState() => _PrincipalProfilePreviewPageState();
}

final class _PrincipalProfilePreviewPageState extends State<PrincipalProfilePreviewPage> {
  var _selectedTab = _ProfileTab.happens;
  var _following = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: widget.embedded
          ? null
          : PrincipalGlobalHeader(
              keyPrefix: 'principal-profile',
              onOpenMenu: () => _runOrPreview(context, widget.onOpenMenu, 'Menu'),
              onOpenNotifications: () =>
                  _runOrPreview(context, widget.onOpenNotifications, 'Notificações'),
              onReportProblem: () =>
                  _runOrPreview(context, widget.onReportBug, 'Reportar problema'),
              onOpenProfile: () =>
                  _runOrPreview(context, widget.onOpenContext, 'Troca de contexto'),
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
              final wide = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
              final inset = compact ? CoeloSpacing.space3 : CoeloSpacing.space5;
              return SingleChildScrollView(
                key: const Key('principal-profile-scroll'),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        inset,
                        0,
                        inset,
                        widget.embedded ? CoeloSpacing.space6 : 148,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileHero(data: widget.data, compact: compact, wide: wide),
                          SizedBox(height: compact ? CoeloSpacing.space3 : CoeloSpacing.space4),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildMainContent(context, compact: compact)),
                                const SizedBox(width: CoeloSpacing.space4),
                                SizedBox(
                                  width: 280,
                                  child: _ProfileContextAside(
                                    data: widget.data,
                                    onOpenAgenda: widget.onOpenAgenda,
                                  ),
                                ),
                              ],
                            )
                          else
                            _buildMainContent(context, compact: compact),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (!widget.embedded)
            PrincipalGlobalNavigation(
              selected: PrincipalDestination.home,
              onHome: () =>
                  _runOrPreview(context, widget.onOpenHome ?? widget.onOpenHappens, 'Home'),
              onForYou: () => _runOrPreview(context, widget.onOpenForYou, 'Para você'),
              onPublishNow: () => _runOrPreview(context, widget.onPublishNow, 'Publicar no Agora'),
              onMoments: () => _runOrPreview(context, widget.onOpenMoments, 'Momentos'),
              onSearch: () => _runOrPreview(context, widget.onOpenSearch, 'Pesquisar'),
              onMessages: () => _runOrPreview(context, widget.onOpenMessages, 'Mensagens'),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, {required bool compact}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _IdentitySection(
        data: widget.data,
        wide: !compact,
        following: _following,
        onFollow: () => setState(() => _following = !_following),
        onMessage: () => _runOrPreview(context, widget.onMessage, 'Mensagem'),
        onOpenBio: () => _runOrPreview(context, widget.onOpenBio, 'Biografia completa'),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _MetricsPanel(metrics: widget.data.metrics, compact: compact),
      const SizedBox(height: CoeloSpacing.space5),
      _HighlightsSection(items: widget.data.highlights, compact: compact),
      const SizedBox(height: CoeloSpacing.space5),
      _LinksSection(
        links: widget.data.links,
        onOpenAll: () => _runOrPreview(context, widget.onOpenLinks, 'Todos os vínculos'),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _AgendaSummary(event: widget.data.nextEvent, onOpenAgenda: widget.onOpenAgenda),
      const SizedBox(height: CoeloSpacing.space4),
      _ProfileTabs(
        selected: _selectedTab,
        onSelected: (tab) {
          final destination = switch (tab) {
            _ProfileTab.happens => widget.onOpenHappens,
            _ProfileTab.moments => widget.onOpenMoments,
            _ProfileTab.circulars => null,
            _ProfileTab.about => null,
          };
          if (destination != null) {
            destination();
            return;
          }
          setState(() => _selectedTab = tab);
        },
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _TabContent(
        tab: _selectedTab,
        aboutPage: widget.aboutPage,
        onOpenAboutMap: widget.onOpenAboutMap,
        circularRepository: widget.circularRepository,
        circularScope: widget.circularScope,
        onOpenCircular: widget.onOpenCircular,
      ),
    ],
  );
}

void _showPrototypeMessage(BuildContext context, String label) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label estará disponível na experiência completa.')));
}

void _runOrPreview(BuildContext context, VoidCallback? action, String fallbackLabel) {
  if (action != null) {
    action();
    return;
  }
  _showPrototypeMessage(context, fallbackLabel);
}

final class _ProfileContextAside extends StatelessWidget {
  const _ProfileContextAside({required this.data, required this.onOpenAgenda});

  final PrincipalProfilePreviewData data;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('principal-profile-context-aside'),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contexto atual',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(data.name, style: Theme.of(context).textTheme.labelLarge),
          Text(data.typeLabel, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: CoeloSpacing.space4),
          const _ProfileContextFact(Icons.location_on_outlined, 'São Paulo, SP'),
          const SizedBox(height: CoeloSpacing.space2),
          const _ProfileContextFact(Icons.groups_outlined, 'Comunidade escolar'),
          const SizedBox(height: CoeloSpacing.space4),
          Text('Próximo evento', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: CoeloSpacing.space1),
          Text(data.nextEvent.title, style: Theme.of(context).textTheme.bodyMedium),
          Text('${data.nextEvent.day} ${data.nextEvent.month} · ${data.nextEvent.context}'),
          const SizedBox(height: CoeloSpacing.space3),
          TextButton.icon(
            onPressed: onOpenAgenda,
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text('Abrir agenda'),
          ),
        ],
      ),
    ),
  );
}

final class _ProfileContextFact extends StatelessWidget {
  const _ProfileContextFact(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: CoeloSize.iconSm),
      const SizedBox(width: CoeloSpacing.space2),
      Expanded(child: Text(label)),
    ],
  );
}

final class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.data, required this.compact, required this.wide});

  final PrincipalProfilePreviewData data;
  final bool compact;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final coverHeight = compact
        ? 168.0
        : wide
        ? 268.0
        : 208.0;
    final avatarSize = compact
        ? 88.0
        : wide
        ? 132.0
        : 108.0;
    return SizedBox(
      height: coverHeight + avatarSize * .42,
      child: Stack(
        children: [
          Semantics(
            image: true,
            label: 'Campus do ${data.name}',
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(CoeloRadius.lg)),
              child: Image.asset(
                'assets/principal_profile/institution-cover.png',
                width: double.infinity,
                height: coverHeight,
                fit: BoxFit.cover,
                alignment: compact ? const Alignment(.5, 0) : Alignment.center,
              ),
            ),
          ),
          Positioned(
            left: compact ? CoeloSpacing.space3 : CoeloSpacing.space5,
            top: coverHeight - avatarSize * .45,
            child: Semantics(
              image: true,
              label: 'Brasão do ${data.name}',
              child: Container(
                width: avatarSize,
                height: avatarSize,
                padding: const EdgeInsets.all(CoeloSpacing.space1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: .16),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/principal_profile/institution-crest.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.data,
    required this.wide,
    required this.following,
    required this.onFollow,
    required this.onMessage,
    required this.onOpenBio,
  });

  final PrincipalProfilePreviewData data;
  final bool wide;
  final bool following;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onOpenBio;

  @override
  Widget build(BuildContext context) {
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                data.name,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: CoeloSpacing.space1),
            Semantics(
              label: 'Perfil verificado',
              child: Icon(
                Icons.verified_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: CoeloSize.iconSm,
              ),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space1),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.primary),
            borderRadius: BorderRadius.circular(CoeloRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space2,
              vertical: CoeloSpacing.spaceHalf,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: CoeloSize.iconSm,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: CoeloSpacing.space1),
                Flexible(
                  child: Text(
                    data.typeLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        FilledButton.icon(
          key: const Key('principal-profile-follow'),
          onPressed: onFollow,
          icon: Icon(following ? Icons.check_rounded : Icons.person_add_alt_1_outlined),
          label: Text(following ? 'Acompanhando' : 'Acompanhar'),
        ),
        OutlinedButton.icon(
          key: const Key('principal-profile-message'),
          onPressed: onMessage,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Mensagem'),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: identity),
              const SizedBox(width: CoeloSpacing.space4),
              actions,
            ],
          )
        else ...[
          identity,
          const SizedBox(height: CoeloSpacing.space3),
          actions,
        ],
        const SizedBox(height: CoeloSpacing.space3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(data.bio, style: Theme.of(context).textTheme.bodyMedium),
        ),
        TextButton(onPressed: onOpenBio, child: const Text('Ver mais')),
      ],
    );
  }
}

final class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.metrics, required this.compact});

  final List<PrincipalProfileMetric> metrics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          final columns = largeText
              ? compact
                    ? 1
                    : 3
              : compact
              ? 3
              : metrics.length;
          final itemWidth = constraints.maxWidth / columns;
          return Wrap(
            children: [
              for (final metric in metrics)
                SizedBox(
                  width: itemWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoeloSpacing.space2,
                      vertical: CoeloSpacing.space3,
                    ),
                    child: MergeSemantics(
                      child: Row(
                        children: [
                          Icon(metric.icon, size: CoeloSize.iconSm),
                          const SizedBox(width: CoeloSpacing.space2),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metric.value,
                                  maxLines: largeText ? null : 1,
                                  overflow: largeText ? null : TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  key: Key('principal-profile-metric-${metric.label}'),
                                  metric.label,
                                  maxLines: largeText ? null : 1,
                                  overflow: largeText ? null : TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

final class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.items, required this.compact});

  final List<PrincipalProfileHighlight> items;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Destaques',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      SizedBox(
        height: compact ? 126 : 142,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: CoeloSpacing.space2),
          itemBuilder: (context, index) =>
              _HighlightCard(item: items[index], width: compact ? 112 : 152),
        ),
      ),
    ],
  );
}

final class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.item, required this.width});

  final PrincipalProfileHighlight item;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => ClipRect(
              child: OverflowBox(
                alignment: Alignment(item.alignmentX, 0),
                minWidth: constraints.maxWidth * 5,
                maxWidth: constraints.maxWidth * 5,
                minHeight: constraints.maxHeight,
                maxHeight: constraints.maxHeight,
                child: Image.asset(
                  'assets/principal_profile/highlights-strip.png',
                  width: constraints.maxWidth * 5,
                  height: constraints.maxHeight,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space2),
          child: Row(
            children: [
              Icon(item.icon, size: CoeloSize.iconSm, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: CoeloSpacing.space1),
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _LinksSection extends StatelessWidget {
  const _LinksSection({required this.links, required this.onOpenAll});

  final List<String> links;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Vínculos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onOpenAll, child: const Text('Ver todos')),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Row(
        children: [
          for (var index = 0; index < links.length; index++)
            Align(
              widthFactor: index == 0 ? 1 : .72,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Color.lerp(
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                  index / links.length,
                ),
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                child: Text(links[index]),
              ),
            ),
          const SizedBox(width: CoeloSpacing.space2),
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            child: const Text('+42'),
          ),
        ],
      ),
    ],
  );
}

final class _AgendaSummary extends StatelessWidget {
  const _AgendaSummary({required this.event, required this.onOpenAgenda});

  final PrincipalProfileEvent event;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Próximo evento: ${event.title}, ${event.day} de maio',
    child: OutlinedButton(
      key: const Key('principal-profile-open-agenda'),
      onPressed: onOpenAgenda,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space3,
          vertical: CoeloSpacing.space2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.day,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(event.month, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  event.context,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: CoeloSpacing.space2),
          if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
            Text(
              'Ver agenda',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

final class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selected, required this.onSelected});

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _ProfileTabButton(
        tabKey: const Key('principal-profile-tab-acontece'),
        label: 'Acontece',
        icon: Icons.dynamic_feed_outlined,
        selected: selected == _ProfileTab.happens,
        onPressed: () => onSelected(_ProfileTab.happens),
      ),
      _ProfileTabButton(
        tabKey: const Key('principal-profile-tab-momentos'),
        label: 'Momentos',
        icon: Icons.play_circle_outline_rounded,
        selected: selected == _ProfileTab.moments,
        onPressed: () => onSelected(_ProfileTab.moments),
      ),
      _ProfileTabButton(
        tabKey: const Key('principal-profile-tab-circulares'),
        label: 'Circulares',
        icon: Icons.description_outlined,
        selected: selected == _ProfileTab.circulars,
        onPressed: () => onSelected(_ProfileTab.circulars),
      ),
      _ProfileTabButton(
        tabKey: const Key('principal-profile-tab-sobre'),
        label: 'Sobre',
        icon: Icons.info_outline_rounded,
        selected: selected == _ProfileTab.about,
        onPressed: () => onSelected(_ProfileTab.about),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expanded =
              constraints.maxWidth >= 680 && MediaQuery.textScalerOf(context).scale(1) <= 1.5;
          if (expanded) {
            return Row(children: [for (final tab in tabs) Expanded(child: tab)]);
          }
          return SingleChildScrollView(
            key: const Key('principal-profile-tabs-scroll'),
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final tab in tabs) SizedBox(width: 176, child: tab)]),
          );
        },
      ),
    );
  }
}

final class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.tabKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final Key tabKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: TextButton.icon(
        key: tabKey,
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
          foregroundColor: WidgetStatePropertyAll(
            selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStatePropertyAll(scheme.primaryContainer.withValues(alpha: .48)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        icon: Icon(icon, size: CoeloSize.iconSm),
        label: Text(
          label,
          style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w400),
        ),
      ),
    );
  }
}

final class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tab,
    required this.aboutPage,
    required this.onOpenAboutMap,
    required this.circularRepository,
    required this.circularScope,
    required this.onOpenCircular,
  });

  final _ProfileTab tab;
  final ProfileAboutPage? aboutPage;
  final VoidCallback? onOpenAboutMap;
  final CircularRepository? circularRepository;
  final CircularScope? circularScope;
  final ValueChanged<String>? onOpenCircular;

  @override
  Widget build(BuildContext context) => switch (tab) {
    _ProfileTab.happens => const _ProfileHappensFeed(),
    _ProfileTab.moments => const _ProfileMomentsFeed(),
    _ProfileTab.circulars =>
      circularRepository == null || circularScope == null
          ? const _PlaceholderContent(
              icon: Icons.lock_outline_rounded,
              title: 'Contexto não autorizado',
              message: 'Selecione um contexto autorizado para consultar Circulares.',
            )
          : PrincipalProfileCircularsTab(
              repository: circularRepository!,
              scope: circularScope!,
              onOpen: onOpenCircular ?? (_) {},
              embedded: true,
            ),
    _ProfileTab.about => _AboutContent(page: aboutPage, onOpenMap: onOpenAboutMap),
  };
}

final class _ProfileHappensFeed extends StatelessWidget {
  const _ProfileHappensFeed();

  @override
  Widget build(BuildContext context) {
    final posts = PrincipalHappensPreviewData.demo.posts;
    return _ProfileEditorialGrid(
      children: [for (final post in posts) _ProfileHappensCard(post: post)],
    );
  }
}

final class _ProfileHappensCard extends StatelessWidget {
  const _ProfileHappensCard({required this.post});
  final PrincipalPostPreviewItem post;

  @override
  Widget build(BuildContext context) => _ProfileEditorialCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
          leading: CircleAvatar(child: Text(post.initials)),
          title: Text(post.author, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${post.context} · ${post.time}'),
        ),
        if (post.mediaIndices.isNotEmpty)
          SizedBox(
            height: 220,
            child: _ProfileSpriteMedia(
              assetPath: 'assets/principal_happens/feed-strip.png',
              index: post.mediaIndices.first,
              count: 4,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.body, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: CoeloSpacing.space2),
              Wrap(
                spacing: CoeloSpacing.space3,
                children: [
                  if (post.likes case final value?)
                    _ProfileMetric(icon: Icons.favorite_border_rounded, value: value),
                  if (post.comments case final value?)
                    _ProfileMetric(icon: Icons.chat_bubble_outline_rounded, value: value),
                  if (post.shares case final value?)
                    _ProfileMetric(icon: Icons.share_outlined, value: value),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _ProfileMomentsFeed extends StatelessWidget {
  const _ProfileMomentsFeed();

  @override
  Widget build(BuildContext context) {
    final moments = PrincipalMomentsPreviewData.demo.moments.take(4);
    return _ProfileEditorialGrid(
      children: [for (final moment in moments) _ProfileMomentCard(moment: moment)],
    );
  }
}

final class _ProfileMomentCard extends StatelessWidget {
  const _ProfileMomentCard({required this.moment});
  final PrincipalMomentPreviewItem moment;

  @override
  Widget build(BuildContext context) => _ProfileEditorialCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 260,
          child: _ProfileSpriteMedia(
            assetPath: 'assets/principal_moments/moments-strip.png',
            index: moment.imageIndex,
            count: 5,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(moment.caption, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: CoeloSpacing.space2),
              Text('${moment.author} · ${moment.context} · ${moment.time}'),
              const SizedBox(height: CoeloSpacing.space2),
              Wrap(
                spacing: CoeloSpacing.space3,
                children: [
                  _ProfileMetric(icon: Icons.favorite_border_rounded, value: moment.likes),
                  _ProfileMetric(icon: Icons.chat_bubble_outline_rounded, value: moment.comments),
                  _ProfileMetric(icon: Icons.share_outlined, value: moment.shares),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _ProfileEditorialGrid extends StatelessWidget {
  const _ProfileEditorialGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space4),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space3) / columns;
        return Wrap(
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space3,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    ),
  );
}

final class _ProfileEditorialCard extends StatelessWidget {
  const _ProfileEditorialCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(CoeloRadius.lg), child: child),
  );
}

final class _ProfileSpriteMedia extends StatelessWidget {
  const _ProfileSpriteMedia({required this.assetPath, required this.index, required this.count});

  final String assetPath;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fullAspect = assetPath.endsWith('moments-strip.png') ? 1672 / 941 : 1983 / 793;
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
              child: Image.asset(assetPath, fit: BoxFit.cover, excludeFromSemantics: true),
            ),
          ),
        ),
      );
    },
  );
}

final class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: CoeloSize.iconSm),
        const SizedBox(width: CoeloSpacing.space1),
        Text('$value'),
      ],
    ),
  );
}

final class _PlaceholderContent extends StatelessWidget {
  const _PlaceholderContent({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space5),
    child: Column(
      children: [
        Icon(icon, size: CoeloSize.iconLg, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: CoeloSpacing.space2),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space1),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

final class _AboutContent extends StatelessWidget {
  const _AboutContent({required this.page, required this.onOpenMap});
  final ProfileAboutPage? page;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final visible = page?.project(ProfileAboutAudience.profileAccess);
    if (visible == null || (visible.fields.isEmpty && visible.sections.isEmpty)) {
      return const _PlaceholderContent(
        icon: Icons.info_outline,
        title: 'Sobre ainda não publicado',
        message: 'Quando houver conteúdo autorizado, ele aparecerá aqui.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in visible.sections) ...[
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (section.body.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Text(section.body),
            ],
            for (final item in section.items.where((item) => item.trim().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: CoeloSize.iconSm),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            const SizedBox(height: CoeloSpacing.space5),
          ],
          for (final field in visible.fields) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    field.key == ProfileAboutFieldKey.preciseLocation
                        ? Icons.location_on_outlined
                        : Icons.info_outline,
                    size: CoeloSize.iconSm,
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(child: Text(field.value)),
                ],
              ),
            ),
            if (field.key == ProfileAboutFieldKey.preciseLocation && onOpenMap != null)
              Padding(
                padding: const EdgeInsets.only(bottom: CoeloSpacing.space5),
                child: Semantics(
                  container: true,
                  label: 'Mapa compacto da localização autorizada',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(CoeloRadius.md),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 148,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.location_pin, size: CoeloSize.iconLg),
                          Positioned(
                            right: CoeloSpacing.space3,
                            bottom: CoeloSpacing.space2,
                            child: TextButton.icon(
                              onPressed: onOpenMap,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Ver no mapa'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
