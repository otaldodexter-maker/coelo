import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

enum SuperadminFormStepStatus { current, complete, error, incomplete }

final class SuperadminFormStep {
  const SuperadminFormStep({required this.label, required this.status, this.enabled = true});

  final String label;
  final SuperadminFormStepStatus status;
  final bool enabled;
}

/// Shared navigation for sequential Superadmin flows.
///
/// This is distinct from record pagination. It preserves the approved
/// completed/current/pending anatomy from Create/Edit Institution.
final class SuperadminFormStepNavigation extends StatelessWidget {
  const SuperadminFormStepNavigation({
    required this.steps,
    required this.currentIndex,
    required this.onStepSelected,
    super.key,
  }) : assert(steps.length > 1),
       assert(currentIndex >= 0 && currentIndex < steps.length);

  final List<SuperadminFormStep> steps;
  final int currentIndex;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= CoeloBreakpoints.large.minWidth) {
        return SizedBox(
          width: 248,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var index = 0; index < steps.length; index++) _button(context, index)],
          ),
        );
      }
      if (constraints.maxWidth >= CoeloBreakpoints.medium.minWidth) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < steps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(right: CoeloSpacing.space2),
                  child: _button(context, index, compact: true),
                ),
            ],
          ),
        );
      }
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Etapa ${currentIndex + 1} de ${steps.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(steps[currentIndex].label, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          MenuAnchor(
            menuChildren: [
              for (var index = 0; index < steps.length; index++)
                MenuItemButton(
                  onPressed: steps[index].enabled ? () => onStepSelected(index) : null,
                  child: Text(steps[index].label),
                ),
            ],
            builder: (context, menu, child) => IconButton(
              tooltip: 'Selecionar etapa',
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(Icons.format_list_bulleted_rounded),
            ),
          ),
        ],
      );
    },
  );

  Widget _button(BuildContext context, int index, {bool compact = false}) {
    final step = steps[index];
    final colors = Theme.of(context).colorScheme;
    final current = step.status == SuperadminFormStepStatus.current;
    final icon = switch (step.status) {
      SuperadminFormStepStatus.current => Icons.radio_button_checked_rounded,
      SuperadminFormStepStatus.complete => Icons.check_circle_outline_rounded,
      SuperadminFormStepStatus.error => Icons.error_outline_rounded,
      SuperadminFormStepStatus.incomplete => Icons.radio_button_unchecked_rounded,
    };
    final statusLabel = switch (step.status) {
      SuperadminFormStepStatus.current => 'selecionada',
      SuperadminFormStepStatus.complete => 'completa',
      SuperadminFormStepStatus.error => 'com erro',
      SuperadminFormStepStatus.incomplete => 'incompleta',
    };
    final keyLabel = step.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return Semantics(
      button: true,
      selected: current,
      enabled: step.enabled,
      label: '${step.label}, $statusLabel',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 0 : CoeloSpacing.spaceHalf),
        child: TextButton.icon(
          key: Key('step-$keyLabel'),
          onPressed: step.enabled ? () => onStepSelected(index) : null,
          style:
              TextButton.styleFrom(
                minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
              ).copyWith(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      current ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primary
                      : step.status == SuperadminFormStepStatus.error
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      current ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primaryContainer
                      : Colors.transparent,
                ),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          icon: Icon(icon),
          label: Text(step.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
