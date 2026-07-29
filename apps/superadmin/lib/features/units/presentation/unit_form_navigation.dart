import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'unit_form_controller.dart';

final class UnitFormNavigation extends StatelessWidget {
  const UnitFormNavigation({required this.controller, super.key});

  final UnitFormController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= CoeloBreakpoints.large.minWidth) {
          return SizedBox(
            width: 248,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final step in UnitFormStep.values)
                  _StepButton(controller: controller, step: step),
              ],
            ),
          );
        }
        if (constraints.maxWidth >= CoeloBreakpoints.medium.minWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final step in UnitFormStep.values)
                  Padding(
                    padding: const EdgeInsets.only(right: CoeloSpacing.space2),
                    child: _StepButton(controller: controller, step: step, compact: true),
                  ),
              ],
            ),
          );
        }
        final current = controller.currentStep;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Etapa ${current.index + 1} de ${UnitFormStep.values.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(current.label, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            MenuAnchor(
              menuChildren: [
                for (final step in UnitFormStep.values)
                  MenuItemButton(
                    onPressed: () => controller.selectStep(step),
                    child: Text(step.label),
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
  }
}

final class _StepButton extends StatelessWidget {
  const _StepButton({required this.controller, required this.step, this.compact = false});

  final UnitFormController controller;
  final UnitFormStep step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = controller.statusOf(step);
    final colors = Theme.of(context).colorScheme;
    final current = status == UnitFormStepStatus.current;
    final icon = switch (status) {
      UnitFormStepStatus.current => Icons.radio_button_checked_rounded,
      UnitFormStepStatus.complete => Icons.check_circle_outline_rounded,
      UnitFormStepStatus.error => Icons.error_outline_rounded,
      UnitFormStepStatus.incomplete => Icons.radio_button_unchecked_rounded,
    };
    final statusLabel = switch (status) {
      UnitFormStepStatus.current => 'selecionada',
      UnitFormStepStatus.complete => 'completa',
      UnitFormStepStatus.error => 'com erro',
      UnitFormStepStatus.incomplete => 'incompleta',
    };
    return Semantics(
      button: true,
      selected: current,
      label: '${step.label}, $statusLabel',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 0 : CoeloSpacing.spaceHalf),
        child: TextButton.icon(
          key: status == UnitFormStepStatus.error
              ? Key('unit-step-${step.name}-error')
              : Key('unit-step-${step.name}'),
          onPressed: () => controller.selectStep(step),
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
                      : status == UnitFormStepStatus.error
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
