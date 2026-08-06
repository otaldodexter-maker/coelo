import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/plan_catalog.dart';

final class PlanCapabilityMatrix extends StatelessWidget {
  const PlanCapabilityMatrix({
    required this.searchController,
    required this.selected,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final TextEditingController searchController;
  final Set<PlanFeature> selected;
  final ValueChanged<Set<PlanFeature>> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final visible = PlanFeature.values
        .where((feature) => query.isEmpty || feature.label.toLowerCase().contains(query))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoeloSearchField(
          key: const Key('plan-capability-search'),
          controller: searchController,
          semanticLabel: 'Buscar capacidades do plano',
          hintText: 'Buscar capacidade',
          onChanged: (_) => onChanged({...selected}),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Text(
          '${selected.length} de ${PlanFeature.values.length} incluídas',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (errorText case final message?) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              key: const Key('plan-capability-error'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: CoeloSpacing.space4),
        if (visible.isEmpty)
          const CoeloStatePanel(
            title: 'Nenhuma capacidade encontrada',
            message: 'Revise o termo pesquisado.',
            icon: Icons.search_off_rounded,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MatrixHeader(compact: compact),
                  const SizedBox(height: CoeloSpacing.space2),
                  for (final surface in PlanSurface.values) ...[
                    if (visible.any((feature) => feature.surface == surface))
                      _CapabilityGroup(
                        surface: surface,
                        visibleFeatures: visible
                            .where((feature) => feature.surface == surface)
                            .toList(growable: false),
                        selected: selected,
                        compact: compact,
                        onChanged: onChanged,
                      ),
                    if (surface != PlanSurface.values.last &&
                        visible.any((feature) => feature.surface == surface))
                      const SizedBox(height: CoeloSpacing.space4),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

final class _MatrixHeader extends StatelessWidget {
  const _MatrixHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Capacidade', style: style),
          const SizedBox(height: CoeloSpacing.space1),
          Text('Incluído no plano', style: style),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            key: const Key('plan-capability-column-capability'),
            child: Text('Capacidade', style: style),
          ),
        ),
        Expanded(
          flex: 2,
          child: SizedBox(
            key: const Key('plan-capability-column-inclusion'),
            child: Text('Incluído no plano', textAlign: TextAlign.center, style: style),
          ),
        ),
      ],
    );
  }
}

final class _CapabilityGroup extends StatelessWidget {
  const _CapabilityGroup({
    required this.surface,
    required this.visibleFeatures,
    required this.selected,
    required this.compact,
    required this.onChanged,
  });

  final PlanSurface surface;
  final List<PlanFeature> visibleFeatures;
  final Set<PlanFeature> selected;
  final bool compact;
  final ValueChanged<Set<PlanFeature>> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allFeatures = PlanFeature.values
        .where((feature) => feature.surface == surface)
        .toList(growable: false);
    final selectedCount = allFeatures.where(selected.contains).length;
    final groupValue = selectedCount == 0
        ? false
        : selectedCount == allFeatures.length
        ? true
        : null;
    final surfaceName = surface == PlanSurface.admin ? 'Admin' : 'Principal';
    final surfaceKey = surface.name;
    final selectionLabel = switch (groupValue) {
      true => 'todas incluídas',
      false => 'nenhuma incluída',
      null => 'seleção parcial',
    };
    final actionLabel = groupValue == true ? 'Limpar grupo' : 'Selecionar todas';
    void toggleGroup() {
      final next = {...selected};
      if (groupValue == true) {
        next.removeAll(allFeatures);
      } else {
        next.addAll(allFeatures);
      }
      onChanged(next);
    }

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(surfaceName, style: Theme.of(context).textTheme.titleMedium),
        Text(
          '$selectedCount de ${allFeatures.length} incluídas',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
    final groupToggle = Semantics(
      key: Key('plan-capability-group-$surfaceKey-semantics'),
      label: '$surfaceName, $selectionLabel. $actionLabel',
      checked: groupValue ?? false,
      mixed: groupValue == null,
      onTap: toggleGroup,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(actionLabel, textAlign: TextAlign.end),
                  Checkbox(
                    key: Key('plan-capability-group-$surfaceKey-toggle'),
                    tristate: true,
                    value: groupValue,
                    onChanged: (_) => toggleGroup(),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel),
                  const SizedBox(width: CoeloSpacing.space1),
                  Checkbox(
                    key: Key('plan-capability-group-$surfaceKey-toggle'),
                    tristate: true,
                    value: groupValue,
                    onChanged: (_) => toggleGroup(),
                  ),
                ],
              ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space3,
              vertical: CoeloSpacing.space2,
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      Align(alignment: Alignment.centerRight, child: groupToggle),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: identity),
                      groupToggle,
                    ],
                  ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          for (var index = 0; index < visibleFeatures.length; index++) ...[
            _CapabilityRow(
              feature: visibleFeatures[index],
              selected: selected.contains(visibleFeatures[index]),
              compact: compact,
              onChanged: (value) {
                final next = {...selected};
                value ? next.add(visibleFeatures[index]) : next.remove(visibleFeatures[index]);
                onChanged(next);
              },
            ),
            if (index < visibleFeatures.length - 1)
              Divider(height: 1, indent: CoeloSpacing.space3, color: colors.outlineVariant),
          ],
        ],
      ),
    );
  }
}

final class _CapabilityRow extends StatefulWidget {
  const _CapabilityRow({
    required this.feature,
    required this.selected,
    required this.compact,
    required this.onChanged,
  });

  final PlanFeature feature;
  final bool selected;
  final bool compact;
  final ValueChanged<bool> onChanged;

  @override
  State<_CapabilityRow> createState() => _CapabilityRowState();
}

final class _CapabilityRowState extends State<_CapabilityRow> {
  late final FocusNode _focusNode;
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'Capacidade ${widget.feature.label}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    void toggle() => widget.onChanged(!widget.selected);
    final checkbox = ExcludeSemantics(
      child: Checkbox(
        value: widget.selected,
        onChanged: (value) => widget.onChanged(value ?? false),
      ),
    );
    final content = widget.compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.feature.label),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Incluído no plano',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  checkbox,
                ],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(flex: 3, child: Text(widget.feature.label)),
              Expanded(flex: 2, child: Center(child: checkbox)),
            ],
          );
    return Semantics(
      key: Key('plan-capability-row-${widget.feature.name}'),
      container: true,
      button: true,
      checked: widget.selected,
      label: '${widget.feature.label}, disponibilidade no plano',
      excludeSemantics: true,
      onTap: toggle,
      child: FocusableActionDetector(
        key: Key('plan-capability-row-${widget.feature.name}-focus'),
        focusNode: _focusNode,
        shortcuts: {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => toggle())},
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: toggle,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.fast,
              constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
              padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
              color: _hovered || _focused
                  ? colors.primaryContainer.withValues(alpha: .48)
                  : Colors.transparent,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
