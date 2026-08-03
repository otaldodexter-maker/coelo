import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'daily_routine.dart';
import 'daily_routine_feeling_style.dart';

enum _AdditionalFeelingDialogResult { suggest }

Future<DailyRoutineFeeling?> showDailyRoutineAdditionalFeelingsDialog(
  BuildContext context, {
  required DailyRoutineFeeling? value,
  required Future<void> Function() onSuggestFeeling,
}) async {
  final result = await showDialog<Object>(
    context: context,
    builder: (dialogContext) => CoeloAdminDialogShell(
      title: 'Mais sentimentos',
      body: Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: DailyRoutineFeeling.additional
            .map(
              (feeling) => Semantics(
                key: Key('daily-routine-feeling-${feeling.id}'),
                button: true,
                selected: value == feeling,
                label: feeling.label,
                child: ExcludeSemantics(
                  child: _AdditionalFeelingChoice(
                    feeling: feeling,
                    selected: value == feeling,
                    onSelected: () => Navigator.of(dialogContext).pop(feeling),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Fechar'),
      ),
      primaryAction: FilledButton.icon(
        onPressed: () => Navigator.of(dialogContext).pop(_AdditionalFeelingDialogResult.suggest),
        icon: const Icon(Icons.add_reaction_outlined),
        label: const Text('Sugerir sentimento'),
      ),
    ),
  );

  if (result == _AdditionalFeelingDialogResult.suggest) {
    await onSuggestFeeling();
    return null;
  }
  return result is DailyRoutineFeeling ? result : null;
}

Future<String?> showDailyRoutineFeelingSuggestionDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => const _FeelingSuggestionDialog(),
  );
}

class _FeelingSuggestionDialog extends StatefulWidget {
  const _FeelingSuggestionDialog();

  @override
  State<_FeelingSuggestionDialog> createState() => _FeelingSuggestionDialogState();
}

class _FeelingSuggestionDialogState extends State<_FeelingSuggestionDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = controller.text.trim();
    if (normalized.isNotEmpty) Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Sugerir sentimento',
    body: CoeloFormTextField(
      fieldKey: const Key('daily-routine-feeling-suggestion-field'),
      controller: controller,
      labelText: 'Sentimento sugerido',
      hintText: 'Ex.: Curioso',
      prefixIcon: Icons.add_reaction_outlined,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      onFieldSubmitted: (_) => _submit(),
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('daily-routine-feeling-suggestion-submit'),
      onPressed: controller.text.trim().isEmpty ? null : _submit,
      child: const Text('Enviar sugestão'),
    ),
  );
}

class _AdditionalFeelingChoice extends StatelessWidget {
  const _AdditionalFeelingChoice({
    required this.feeling,
    required this.selected,
    required this.onSelected,
  });

  final DailyRoutineFeeling feeling;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
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
      onSelected: (_) => onSelected(),
    );
  }
}
