import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum HealthCareSeverityLevel { veryMild, mild, moderate, severe, verySevere }

enum HealthCareAllergyKind { food, medication, restriction, other }

@immutable
final class HealthCareAllergyDraft {
  const HealthCareAllergyDraft({
    required this.id,
    this.kind = HealthCareAllergyKind.food,
    this.itemId = '',
    this.otherItem = '',
    this.severity = HealthCareSeverityLevel.moderate,
    this.reaction = '',
    this.guidance = '',
  });

  final String id;
  final HealthCareAllergyKind kind;
  final String itemId;
  final String otherItem;
  final HealthCareSeverityLevel severity;
  final String reaction;
  final String guidance;

  HealthCareAllergyDraft copyWith({
    HealthCareAllergyKind? kind,
    String? itemId,
    String? otherItem,
    HealthCareSeverityLevel? severity,
    String? reaction,
    String? guidance,
  }) => HealthCareAllergyDraft(
    id: id,
    kind: kind ?? this.kind,
    itemId: itemId ?? this.itemId,
    otherItem: otherItem ?? this.otherItem,
    severity: severity ?? this.severity,
    reaction: reaction ?? this.reaction,
    guidance: guidance ?? this.guidance,
  );
}

@immutable
final class HealthCareCareItemDraft {
  const HealthCareCareItemDraft({
    required this.id,
    required this.label,
    this.signs = '',
    this.adaptations = '',
  });

  final String id;
  final String label;
  final String signs;
  final String adaptations;

  HealthCareCareItemDraft copyWith({String? signs, String? adaptations}) => HealthCareCareItemDraft(
    id: id,
    label: label,
    signs: signs ?? this.signs,
    adaptations: adaptations ?? this.adaptations,
  );
}

final class HealthCareSeverityField extends StatelessWidget {
  const HealthCareSeverityField({required this.value, required this.onChanged, super.key});

  final HealthCareSeverityLevel value;
  final ValueChanged<HealthCareSeverityLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Gravidade do episódio', style: theme.textTheme.labelLarge),
        const SizedBox(height: CoeloSpacing.space2),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 420 || MediaQuery.textScalerOf(context).scale(16) >= 24;
            return Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                for (final level in HealthCareSeverityLevel.values)
                  SizedBox(
                    width: stacked ? constraints.maxWidth : null,
                    child: Semantics(
                      key: Key('health-severity-${level.name}'),
                      selected: value == level,
                      button: true,
                      label: _severityLabel(level),
                      child: OutlinedButton(
                        onPressed: () => onChanged(level),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, CoeloSize.touchMin),
                          backgroundColor: value == level
                              ? status.infoContainer
                              : theme.colorScheme.surface,
                          foregroundColor: value == level
                              ? status.onInfoContainer
                              : theme.colorScheme.onSurface,
                          side: BorderSide(
                            color: value == level
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min,
                          children: [
                            Container(
                              key: Key('health-severity-dot-${level.name}'),
                              width: CoeloSpacing.space2,
                              height: CoeloSpacing.space2,
                              decoration: BoxDecoration(
                                color: _severityColor(level, status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: CoeloSpacing.space2),
                            Flexible(child: Text(_severityLabel(level))),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

final class HealthCareAllergyDraftsEditor extends StatelessWidget {
  const HealthCareAllergyDraftsEditor({
    required this.drafts,
    required this.itemOptions,
    required this.itemLabel,
    required this.otherItemId,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<HealthCareAllergyDraft> drafts;
  final Map<HealthCareAllergyKind, List<String>> itemOptions;
  final String Function(String itemId) itemLabel;
  final String otherItemId;
  final void Function(int index, HealthCareAllergyDraft value) onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < drafts.length; index++) ...[
        _AllergyEditor(
          index: index,
          draft: drafts[index],
          options: itemOptions,
          itemLabel: itemLabel,
          otherItemId: otherItemId,
          canRemove: drafts.length > 1,
          onChanged: (value) => onChanged(index, value),
          onRemove: () => onRemove(index),
        ),
        if (index < drafts.length - 1) const SizedBox(height: CoeloSpacing.space5),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('health-allergy-add'),
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar alergia ou restrição'),
        ),
      ),
    ],
  );
}

final class HealthCareCareItemDraftsEditor extends StatelessWidget {
  const HealthCareCareItemDraftsEditor({required this.drafts, required this.onChanged, super.key});

  final List<HealthCareCareItemDraft> drafts;
  final void Function(int index, HealthCareCareItemDraft value) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < drafts.length; index++) ...[
        Text(drafts[index].label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space3),
        _FieldGrid(
          children: [
            _DraftTextField(
              fieldKey: Key('health-care-signs-$index'),
              value: drafts[index].signs,
              label: 'Sinais importantes',
              icon: Icons.sign_language_outlined,
              onChanged: (value) => onChanged(index, drafts[index].copyWith(signs: value)),
            ),
            _DraftTextField(
              fieldKey: Key('health-care-adaptations-$index'),
              value: drafts[index].adaptations,
              label: 'Adaptações e orientações',
              icon: Icons.accessibility_new_rounded,
              onChanged: (value) => onChanged(index, drafts[index].copyWith(adaptations: value)),
            ),
          ],
        ),
        if (index < drafts.length - 1) const SizedBox(height: CoeloSpacing.space5),
      ],
    ],
  );
}

final class _AllergyEditor extends StatelessWidget {
  const _AllergyEditor({
    required this.index,
    required this.draft,
    required this.options,
    required this.itemLabel,
    required this.otherItemId,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final HealthCareAllergyDraft draft;
  final Map<HealthCareAllergyKind, List<String>> options;
  final String Function(String itemId) itemLabel;
  final String otherItemId;
  final bool canRemove;
  final ValueChanged<HealthCareAllergyDraft> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final kindOptions = options[draft.kind] ?? const <String>[];
    assert(kindOptions.isNotEmpty, 'Each allergy kind requires taxonomy options.');
    final selected = kindOptions.contains(draft.itemId) ? draft.itemId : kindOptions.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Alergia ou restrição ${index + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (canRemove)
              IconButton(
                key: Key('health-allergy-remove-$index'),
                tooltip: 'Remover alergia ou restrição ${index + 1}',
                color: Theme.of(context).colorScheme.error,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _FieldGrid(
          children: [
            CoeloAdminSingleSelectField<HealthCareAllergyKind>(
              label: 'Tipo',
              value: draft.kind,
              options: HealthCareAllergyKind.values,
              optionLabel: _kindLabel,
              onChanged: (kind) => onChanged(
                draft.copyWith(kind: kind, itemId: options[kind]!.first, otherItem: ''),
              ),
            ),
            CoeloAdminSingleSelectField<String>(
              label: _itemFieldLabel(draft.kind),
              value: selected,
              options: kindOptions,
              optionLabel: itemLabel,
              searchable: true,
              onChanged: (item) => onChanged(draft.copyWith(itemId: item)),
            ),
          ],
        ),
        if (draft.itemId == otherItemId) ...[
          const SizedBox(height: CoeloSpacing.space4),
          _DraftTextField(
            fieldKey: Key('health-allergy-other-$index'),
            value: draft.otherItem,
            label: 'Especifique outro',
            icon: Icons.edit_outlined,
            onChanged: (value) => onChanged(draft.copyWith(otherItem: value)),
          ),
        ],
        const SizedBox(height: CoeloSpacing.space4),
        HealthCareSeverityField(
          value: draft.severity,
          onChanged: (value) => onChanged(draft.copyWith(severity: value)),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _FieldGrid(
          children: [
            _DraftTextField(
              fieldKey: Key('health-allergy-reaction-$index'),
              value: draft.reaction,
              label: 'Reação ou sinais observados',
              icon: Icons.visibility_outlined,
              onChanged: (value) => onChanged(draft.copyWith(reaction: value)),
            ),
            _DraftTextField(
              fieldKey: Key('health-allergy-guidance-$index'),
              value: draft.guidance,
              label: 'Orientação de cuidado',
              icon: Icons.assignment_outlined,
              onChanged: (value) => onChanged(draft.copyWith(guidance: value)),
            ),
          ],
        ),
      ],
    );
  }
}

final class _DraftTextField extends StatefulWidget {
  const _DraftTextField({
    required this.fieldKey,
    required this.value,
    required this.label,
    required this.icon,
    required this.onChanged,
  });
  final Key fieldKey;
  final String value;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  State<_DraftTextField> createState() => _DraftTextFieldState();
}

final class _DraftTextFieldState extends State<_DraftTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _DraftTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloFormTextField(
    fieldKey: widget.fieldKey,
    controller: _controller,
    labelText: widget.label,
    prefixIcon: widget.icon,
    maxLines: 3,
    onChanged: widget.onChanged,
  );
}

final class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns =
          constraints.maxWidth >= 700 && MediaQuery.textScalerOf(context).scale(16) < 28;
      final width = twoColumns
          ? (constraints.maxWidth - CoeloSpacing.space3) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space4,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

String _severityLabel(HealthCareSeverityLevel value) => switch (value) {
  HealthCareSeverityLevel.veryMild => 'Muito leve',
  HealthCareSeverityLevel.mild => 'Leve',
  HealthCareSeverityLevel.moderate => 'Moderada',
  HealthCareSeverityLevel.severe => 'Grave',
  HealthCareSeverityLevel.verySevere => 'Muito grave',
};

Color _severityColor(HealthCareSeverityLevel value, CoeloStatusColors colors) => switch (value) {
  HealthCareSeverityLevel.veryMild => colors.success,
  HealthCareSeverityLevel.mild => colors.info,
  HealthCareSeverityLevel.moderate => colors.warning,
  HealthCareSeverityLevel.severe => colors.error,
  HealthCareSeverityLevel.verySevere => colors.onErrorContainer,
};

String _kindLabel(HealthCareAllergyKind value) => switch (value) {
  HealthCareAllergyKind.food => 'Alimento',
  HealthCareAllergyKind.medication => 'Medicamento',
  HealthCareAllergyKind.restriction => 'Restrição',
  HealthCareAllergyKind.other => 'Outro',
};

String _itemFieldLabel(HealthCareAllergyKind value) => switch (value) {
  HealthCareAllergyKind.food => 'Alimento',
  HealthCareAllergyKind.medication => 'Medicamento',
  HealthCareAllergyKind.restriction => 'Restrição',
  HealthCareAllergyKind.other => 'Descrição',
};
