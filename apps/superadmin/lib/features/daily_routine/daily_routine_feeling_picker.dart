import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'daily_routine.dart';
import 'daily_routine_feeling_dialogs.dart';
import 'daily_routine_feeling_style.dart';

final class DailyRoutineFeelingPicker extends StatelessWidget {
  const DailyRoutineFeelingPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onSuggestFeeling,
    this.keyPrefix = 'daily-routine-feeling',
    super.key,
  });

  final DailyRoutineFeeling? value;
  final bool enabled;
  final ValueChanged<DailyRoutineFeeling?> onChanged;
  final Future<void> Function() onSuggestFeeling;
  final String keyPrefix;

  Future<void> _showMore(BuildContext context) async {
    final selected = await showDailyRoutineAdditionalFeelingsDialog(
      context,
      value: value,
      onSuggestFeeling: onSuggestFeeling,
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final additionalSelected = value != null && !value!.isPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final feeling in DailyRoutineFeeling.primary)
              _FeelingChoice(
                keyPrefix: keyPrefix,
                feeling: feeling,
                selected: value == feeling,
                enabled: enabled,
                onSelected: () => onChanged(feeling),
              ),
            TextButton.icon(
              key: Key('$keyPrefix-more'),
              onPressed: enabled ? () => _showMore(context) : null,
              icon: const Icon(Icons.more_horiz_rounded),
              label: const Text('Ver mais'),
            ),
          ],
        ),
        if (additionalSelected) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            'Selecionado: ${value!.emoji} ${value!.label}',
            style: const TextStyle(fontFamilyFallback: dailyRoutineEmojiFontFallback),
          ),
        ],
        if (enabled && value != null) ...[
          const SizedBox(height: CoeloSpacing.space1),
          TextButton.icon(
            key: Key('$keyPrefix-clear'),
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.clear_rounded),
            label: const Text('Limpar sentimento'),
          ),
        ],
      ],
    );
  }
}

class _FeelingChoice extends StatelessWidget {
  const _FeelingChoice({
    required this.keyPrefix,
    required this.feeling,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String keyPrefix;
  final DailyRoutineFeeling feeling;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: Key('$keyPrefix-${feeling.id}'),
      button: true,
      selected: selected,
      enabled: enabled,
      label: feeling.label,
      child: ExcludeSemantics(
        child: ChoiceChip(
          label: Text(
            '${feeling.emoji} ${feeling.label}',
            style: const TextStyle(fontFamilyFallback: dailyRoutineEmojiFontFallback),
          ),
          selected: selected,
          showCheckmark: false,
          backgroundColor: colors.surface,
          selectedColor: colors.primaryContainer,
          side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
          labelStyle: TextStyle(color: selected ? colors.primary : colors.onSurface),
          onSelected: enabled ? (_) => onSelected() : null,
        ),
      ),
    );
  }
}
