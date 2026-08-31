import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../principal_shared/presentation/principal_global_navigation.dart';
import '../domain/principal_for_you_preview_data.dart';
import 'widgets/coelo_principal_action_card.dart';

final class PrincipalForYouPreviewPage extends StatefulWidget {
  const PrincipalForYouPreviewPage({
    this.embedded = false,
    this.data,
    this.onOpenHappens,
    this.onOpenNow,
    this.onOpenMoments,
    this.onOpenAgenda,
    this.onOpenProfile,
    this.onOpenMenu,
    this.onOpenNotifications,
    this.onReportProblem,
    this.onOpenHome,
    this.onOpenForYou,
    this.onPublishNow,
    this.onOpenSearch,
    this.onOpenMessages,
    super.key,
  });

  final bool embedded;
  final PrincipalForYouPreviewData? data;
  final VoidCallback? onOpenHappens;
  final VoidCallback? onOpenNow;
  final VoidCallback? onOpenMoments;
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onReportProblem;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenForYou;
  final VoidCallback? onPublishNow;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenMessages;

  @override
  State<PrincipalForYouPreviewPage> createState() => _PrincipalForYouPreviewPageState();
}

final class _PrincipalForYouPreviewPageState extends State<PrincipalForYouPreviewPage> {
  late PrincipalForYouContext? _activeContext;
  final _ownedOverlays = <(NavigatorState, Route<dynamic>)>{};
  var _overlayGeneration = 0;

  PrincipalForYouPreviewData get _data => widget.data ?? PrincipalForYouPreviewData.demo;

  @override
  void initState() {
    super.initState();
    _activeContext = _data.contexts.firstOrNull;
  }

  @override
  void didUpdateWidget(covariant PrincipalForYouPreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.data, widget.data)) return;
    _dismissOwnedOverlays();
    final activeId = _activeContext?.id;
    _activeContext = _data.contexts.where((context) => context.id == activeId).firstOrNull;
    _activeContext ??= _data.contexts.firstOrNull;
  }

  @override
  void dispose() {
    _dismissOwnedOverlays();
    super.dispose();
  }

  void _feedback(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label estará disponível na experiência completa.')));
  }

  void _invoke(VoidCallback? callback, String fallback) =>
      callback == null ? _feedback(fallback) : callback();

  Future<void> _showContextSelector() async {
    if (_data.contexts.length < 2) return;
    final generation = _overlayGeneration;
    final contexts = List<PrincipalForYouContext>.unmodifiable(_data.contexts);
    final navigator = Navigator.of(context);
    final route = ModalBottomSheetRoute<PrincipalForYouContext>(
      builder: (context) => _ContextSheet(contexts: contexts, selected: _activeContext),
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      isScrollControlled: false,
      useSafeArea: true,
    );
    final entry = (navigator, route as Route<dynamic>);
    _ownedOverlays.add(entry);
    try {
      final selected = await navigator.push(route);
      await route.completed;
      if (selected != null &&
          mounted &&
          generation == _overlayGeneration &&
          _data.contexts.any((context) => context.id == selected.id)) {
        setState(
          () => _activeContext = _data.contexts.firstWhere((context) => context.id == selected.id),
        );
      }
    } finally {
      _ownedOverlays.remove(entry);
    }
  }

  void _dismissOwnedOverlays() {
    _overlayGeneration += 1;
    for (final (navigator, route) in _ownedOverlays.toList(growable: false)) {
      if (route.isActive) navigator.removeRoute(route);
    }
    _ownedOverlays.clear();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: widget.embedded
            ? null
            : PrincipalGlobalHeader(
                keyPrefix: 'principal-for-you',
                onOpenMenu: () => _invoke(widget.onOpenMenu, 'Menu'),
                onOpenNotifications: () => _invoke(widget.onOpenNotifications, 'Notificações'),
                onReportProblem: () => _invoke(widget.onReportProblem, 'Reportar problema'),
                onOpenProfile: () => _invoke(widget.onOpenProfile, 'Perfil'),
              ),
        body: Stack(
          children: [
            _ForYouScroll(
              data: _data,
              activeContext: _activeContext,
              compact: compact,
              navigationVisible: !widget.embedded,
              onContext: _showContextSelector,
              onAction: _feedback,
            ),
            if (!widget.embedded)
              PrincipalGlobalNavigation(
                selected: PrincipalDestination.forYou,
                onHome: () => _invoke(widget.onOpenHome ?? widget.onOpenHappens, 'Home'),
                onForYou: () => _invoke(widget.onOpenForYou, 'Para você'),
                onPublishNow: () =>
                    _invoke(widget.onPublishNow ?? widget.onOpenNow, 'Publicar no Agora'),
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

final class _ForYouScroll extends StatelessWidget {
  const _ForYouScroll({
    required this.data,
    required this.activeContext,
    required this.compact,
    required this.navigationVisible,
    required this.onContext,
    required this.onAction,
  });

  final PrincipalForYouPreviewData data;
  final PrincipalForYouContext? activeContext;
  final bool compact;
  final bool navigationVisible;
  final VoidCallback onContext;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final horizontal = compact ? CoeloSpacing.space3 : CoeloSpacing.space5;
    return SingleChildScrollView(
      key: const Key('principal-for-you-scroll'),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        CoeloSpacing.space4,
        horizontal,
        navigationVisible ? 148 : CoeloSpacing.space6,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Greeting(contextData: activeContext, onContext: onContext),
              const SizedBox(height: CoeloSpacing.space4),
              _HeroCard(highlight: data.primaryHighlight, onAction: onAction),
              const SizedBox(height: CoeloSpacing.space5),
              _Shortcuts(items: data.shortcuts, compact: compact, onAction: onAction),
              const SizedBox(height: CoeloSpacing.space5),
              _EditorialGrid(items: data.editorialItems, compact: compact, onAction: onAction),
              if (data.dayItems.isNotEmpty) ...[
                const SizedBox(height: CoeloSpacing.space5),
                _DaySummary(items: data.dayItems, onAction: onAction),
              ],
              if (activeContext != null) ...[
                const SizedBox(height: CoeloSpacing.space5),
                _CurrentContext(contextData: activeContext!, onContext: onContext),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _Greeting extends StatelessWidget {
  const _Greeting({required this.contextData, required this.onContext});
  final PrincipalForYouContext? contextData;
  final VoidCallback onContext;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CoeloSpacing.space3,
    runSpacing: CoeloSpacing.space2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bom dia, Fernanda!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            contextData?.child == null
                ? 'Visão geral do responsável'
                : 'Contexto de ${contextData!.child}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      if (contextData != null)
        OutlinedButton.icon(
          key: const Key('principal-for-you-context-trigger'),
          onPressed: onContext,
          icon: const Icon(Icons.group_outlined, size: CoeloSize.iconSm),
          label: Text(contextData!.child ?? contextData!.family),
        ),
    ],
  );
}

final class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.highlight, required this.onAction});
  final PrincipalForYouHighlight? highlight;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final item = highlight;
    if (item == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
        final body = Text(
          item.body,
          maxLines: largeText ? null : (narrow ? 3 : 2),
          overflow: largeText ? null : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onPrimary),
        );
        return Container(
          key: const Key('principal-for-you-hero'),
          height: largeText ? (narrow ? 800 : 560) : (narrow ? 240 : 270),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _SpriteImage(
                  assetPath: item.assetPath,
                  index: item.assetIndex,
                  count: _spriteCount(item.assetPath),
                  semanticLabel: 'Estudante participando de atividade escolar',
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.primary, scheme.primary.withValues(alpha: 0)],
                      stops: largeText ? const [0, .78, 1] : const [0, .43, .72],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: largeText
                        ? constraints.maxWidth - CoeloSpacing.space5
                        : (narrow ? 210 : 330),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.onPrimary.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(CoeloRadius.full),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CoeloSpacing.space2,
                            vertical: CoeloSpacing.space1,
                          ),
                          child: Text(
                            item.type.label.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: CoeloSpacing.space3),
                      Text(
                        item.title,
                        maxLines: largeText ? null : 2,
                        overflow: largeText ? null : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: CoeloSpacing.space2),
                      if (largeText) body else Flexible(child: body),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        key: const Key('principal-for-you-hero-action'),
                        onPressed: () => onAction(item.cta),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.surface,
                          foregroundColor: scheme.onSurface,
                        ),
                        label: Text(item.cta),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.items, required this.compact, required this.onAction});
  final List<PrincipalForYouShortcut> items;
  final bool compact;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Atalhos essenciais',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? (largeText ? 2 : 3) : 6,
            mainAxisSpacing: CoeloSpacing.space2,
            crossAxisSpacing: CoeloSpacing.space2,
            mainAxisExtent: largeText ? 196 : 104,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return CoeloPrincipalActionCard(
              key: index == 0 ? const Key('principal-for-you-shortcut-agenda') : null,
              onPressed: () => onAction(item.label),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icon(item.iconName), color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: CoeloSpacing.space2),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

final class _EditorialGrid extends StatelessWidget {
  const _EditorialGrid({required this.items, required this.compact, required this.onAction});
  final List<PrincipalForYouEditorialItem> items;
  final bool compact;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Para você',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => onAction('Todos os conteúdos'),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space2),
        if (compact)
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: CoeloSpacing.space2),
              itemBuilder: (context, index) => SizedBox(
                width: 230,
                child: _EditorialCard(item: items[index], onAction: onAction),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: items.length,
              mainAxisSpacing: CoeloSpacing.space2,
              crossAxisSpacing: CoeloSpacing.space2,
              mainAxisExtent: 236,
            ),
            itemBuilder: (context, index) => _EditorialCard(item: items[index], onAction: onAction),
          ),
      ],
    );
  }
}

final class _EditorialCard extends StatelessWidget {
  const _EditorialCard({required this.item, required this.onAction});
  final PrincipalForYouEditorialItem item;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return CoeloPrincipalActionCard(
      onPressed: () => onAction(item.title),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CoeloSpacing.space3,
              CoeloSpacing.space3,
              CoeloSpacing.space3,
              CoeloSpacing.space2,
            ),
            child: Text(item.eyebrow, style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SpriteImage(
                  assetPath: item.assetPath,
                  index: item.assetIndex,
                  count: _spriteCount(item.assetPath),
                  semanticLabel: item.title,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.surface.withValues(alpha: .96),
                        Theme.of(context).colorScheme.surface.withValues(alpha: .72),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: CoeloSpacing.space1),
                      if (!largeText)
                        Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.items, required this.onAction});
  final List<PrincipalForYouDayItem> items;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Resumo do dia',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => onAction('Resumo completo'),
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            for (final item in items) _DayRow(item: item),
          ],
        ),
      ),
    );
  }
}

final class _DayRow extends StatelessWidget {
  const _DayRow({required this.item});
  final PrincipalForYouDayItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _icon(item.iconName),
          color: Theme.of(context).colorScheme.primary,
          size: CoeloSize.iconSm,
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.labelMedium),
              Text(item.body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Text(item.time, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

final class _CurrentContext extends StatelessWidget {
  const _CurrentContext({required this.contextData, required this.onContext});
  final PrincipalForYouContext contextData;
  final VoidCallback onContext;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Seu contexto atual', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: CoeloSpacing.space3),
          Wrap(
            spacing: CoeloSpacing.space5,
            runSpacing: CoeloSpacing.space3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ContextFact(
                Icons.group_outlined,
                contextData.family,
                '${contextData.childCount} crianças',
              ),
              if (contextData.child != null)
                _ContextFact(Icons.child_care_outlined, 'Criança', contextData.child!),
              if (contextData.institution != null)
                _ContextFact(
                  Icons.account_balance_outlined,
                  'Instituição',
                  contextData.institution!,
                ),
              if (contextData.unit != null)
                _ContextFact(Icons.location_on_outlined, 'Unidade', contextData.unit!),
              if (contextData.group != null)
                _ContextFact(Icons.groups_outlined, 'Turma', contextData.group!),
              TextButton.icon(
                key: const Key('principal-for-you-context-trigger'),
                onPressed: onContext,
                label: const Text('Trocar contexto'),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _ContextFact extends StatelessWidget {
  const _ContextFact(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: CoeloSize.iconSm),
        const SizedBox(width: CoeloSpacing.space2),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _ContextSheet extends StatelessWidget {
  const _ContextSheet({required this.contexts, required this.selected});
  final List<PrincipalForYouContext> contexts;
  final PrincipalForYouContext? selected;

  @override
  Widget build(BuildContext context) => Semantics(
    namesRoute: true,
    label: 'Trocar contexto',
    child: Padding(
      key: const Key('principal-for-you-context-sheet'),
      padding: const EdgeInsets.fromLTRB(
        CoeloSpacing.space4,
        CoeloSpacing.space2,
        CoeloSpacing.space4,
        CoeloSpacing.space5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trocar contexto',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            'Escolha a visão geral ou aprofunde por criança e vínculo escolar.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          for (final item in contexts)
            _ContextOption(
              item: item,
              selected: selected?.id == item.id,
              onPressed: () => Navigator.of(context).pop(item),
            ),
        ],
      ),
    ),
  );
}

final class _ContextOption extends StatelessWidget {
  const _ContextOption({required this.item, required this.selected, required this.onPressed});
  final PrincipalForYouContext item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Semantics(
      selected: selected,
      button: true,
      child: CoeloPrincipalActionCard(
        onPressed: onPressed,
        selected: selected,
        child: Row(
          children: [
            Icon(
              item.child == null ? Icons.person_outline_rounded : Icons.child_care_outlined,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: CoeloSpacing.space1),
                  Text(item.summary, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    ),
  );
}

final class _SpriteImage extends StatelessWidget {
  const _SpriteImage({
    required this.assetPath,
    required this.index,
    required this.count,
    required this.semanticLabel,
  });
  final String assetPath;
  final int index;
  final int count;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final panelAspect = _spritePanelAspect(assetPath, count);
      final tileWidth = constraints.maxWidth > constraints.maxHeight * panelAspect
          ? constraints.maxWidth
          : constraints.maxHeight * panelAspect;
      final imageHeight = tileWidth / panelAspect;
      final horizontalCrop = (tileWidth - constraints.maxWidth) / 2;
      final verticalCrop = (imageHeight - constraints.maxHeight) * .18;
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
                assetPath,
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.image_not_supported_outlined)),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

int _spriteCount(String assetPath) => assetPath.endsWith('feed-strip.png') ? 4 : 5;

double _spritePanelAspect(String assetPath, int count) {
  final fullAspect = assetPath.endsWith('highlights-strip.png') ? 1774 / 887 : 1983 / 793;
  return fullAspect / count;
}

IconData _icon(String name) => switch (name) {
  'calendar' => Icons.calendar_today_outlined,
  'activities' => Icons.assignment_outlined,
  'messages' => Icons.chat_bubble_outline_rounded,
  'meals' => Icons.restaurant_outlined,
  'performance' => Icons.bar_chart_rounded,
  'health' => Icons.favorite_border_rounded,
  'gift' => Icons.card_giftcard_outlined,
  'bell' => Icons.notifications_none_rounded,
  'folder' => Icons.folder_outlined,
  _ => Icons.circle_outlined,
};
