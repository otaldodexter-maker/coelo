import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../domain/routine_contract.dart';

final class DailyRoutineInheritanceSummary extends StatelessWidget {
  const DailyRoutineInheritanceSummary({
    required this.application,
    required this.originLabel,
    required this.inheritedLabel,
    required this.effectiveLabel,
    required this.enabled,
    required this.onModeChanged,
    required this.onRevert,
    super.key,
  });

  final RoutineApplication application;
  final String originLabel;
  final String inheritedLabel;
  final String effectiveLabel;
  final bool enabled;
  final ValueChanged<RoutineInheritanceMode> onModeChanged;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final customized = application.inheritanceMode == RoutineInheritanceMode.customized;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('daily-routine-inheritance-summary'),
      container: true,
      label: 'Heranca da rotina',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Heranca', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: CoeloSpacing.space3),
              _SummaryLine(label: 'Origem', value: originLabel),
              _SummaryLine(label: 'Herdado', value: inheritedLabel),
              _SummaryLine(label: 'Efetivo', value: effectiveLabel),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloAdminToggleField(
                key: const Key('daily-routine-inheritance-toggle'),
                label: 'Personalizar nesta hierarquia',
                description: customized
                    ? 'Os valores efetivos incluem personalizacoes locais.'
                    : 'Mudancas da origem continuam refletidas automaticamente.',
                value: customized,
                onChanged: enabled
                    ? (value) => onModeChanged(
                        value
                            ? RoutineInheritanceMode.customized
                            : RoutineInheritanceMode.inherited,
                      )
                    : null,
              ),
              if (customized) ...[
                const SizedBox(height: CoeloSpacing.space2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('daily-routine-inheritance-reset'),
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    onPressed: enabled ? onRevert : null,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Reverter para o herdado'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
