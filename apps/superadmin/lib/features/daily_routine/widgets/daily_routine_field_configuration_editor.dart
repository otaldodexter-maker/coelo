import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/routine_contract.dart';
import 'daily_routine_option_list_editor.dart';

enum _BooleanInitial { none, yes, no }

final class DailyRoutineFieldConfigurationEditor extends StatefulWidget {
  const DailyRoutineFieldConfigurationEditor({
    required this.field,
    required this.availableParents,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final RoutineField field;
  final List<RoutineField> availableParents;
  final bool enabled;
  final ValueChanged<RoutineField> onChanged;

  @override
  State<DailyRoutineFieldConfigurationEditor> createState() =>
      _DailyRoutineFieldConfigurationEditorState();
}

final class _DailyRoutineFieldConfigurationEditorState
    extends State<DailyRoutineFieldConfigurationEditor> {
  late final TextEditingController label;
  late final TextEditingController initial;
  late final TextEditingController minimum;
  late final TextEditingController maximum;
  late RoutineFieldKind kind;
  late bool required;
  late List<RoutineFieldOption> options;
  String? selectedOptionId;
  Set<String> selectedOptionIds = {};
  _BooleanInitial booleanInitial = _BooleanInitial.none;
  RoutineField? parent;
  String? triggerOptionId;
  bool triggerBoolean = true;

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    label = TextEditingController(text: field.label);
    initial = TextEditingController(
      text:
          field.kind == RoutineFieldKind.shortText ||
              field.kind == RoutineFieldKind.longText ||
              field.kind == RoutineFieldKind.number
          ? field.initialValue?.toString() ?? ''
          : '',
    );
    minimum = TextEditingController(text: field.minimumValue?.toString() ?? '');
    maximum = TextEditingController(text: field.maximumValue?.toString() ?? '');
    kind = field.kind;
    required = field.isRequired;
    options = [...field.options]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (field.kind == RoutineFieldKind.singleChoice) {
      selectedOptionId = field.initialValue as String?;
    } else if (field.kind == RoutineFieldKind.multipleChoice) {
      selectedOptionIds = (field.initialValue as Iterable? ?? const [])
          .map((value) => value.toString())
          .toSet();
    } else if (field.kind == RoutineFieldKind.boolean) {
      booleanInitial = field.initialValue == null
          ? _BooleanInitial.none
          : field.initialValue == true
          ? _BooleanInitial.yes
          : _BooleanInitial.no;
    }
    if (field.conditions.isNotEmpty) {
      final condition = field.conditions.first;
      for (final candidate in widget.availableParents) {
        if (candidate.id == condition.parentFieldId) parent = candidate;
      }
      triggerOptionId = condition.optionId;
      triggerBoolean = condition.booleanValue ?? true;
    }
  }

  @override
  void dispose() {
    label.dispose();
    initial.dispose();
    minimum.dispose();
    maximum.dispose();
    super.dispose();
  }

  bool get isChoice =>
      kind == RoutineFieldKind.singleChoice || kind == RoutineFieldKind.multipleChoice;

  void emit() {
    Object? initialValue;
    if (kind == RoutineFieldKind.shortText || kind == RoutineFieldKind.longText) {
      initialValue = initial.text.trim().isEmpty ? null : initial.text;
    } else if (kind == RoutineFieldKind.number) {
      initialValue = num.tryParse(initial.text.replaceAll(',', '.'));
    } else if (kind == RoutineFieldKind.boolean) {
      initialValue = switch (booleanInitial) {
        _BooleanInitial.none => null,
        _BooleanInitial.yes => true,
        _BooleanInitial.no => false,
      };
    } else if (kind == RoutineFieldKind.singleChoice) {
      initialValue = selectedOptionId;
    } else {
      initialValue = selectedOptionIds.isEmpty ? null : selectedOptionIds.toList();
    }

    final conditions = <RoutineCondition>[];
    final selectedParent = parent;
    if (selectedParent != null) {
      final depth = _fieldDepth(selectedParent) + 1;
      if (depth <= 4 &&
          (selectedParent.kind == RoutineFieldKind.boolean || triggerOptionId != null)) {
        conditions.add(
          RoutineCondition(
            id: widget.field.conditions.isEmpty
                ? 'condition-${widget.field.id}'
                : widget.field.conditions.first.id,
            parentFieldId: selectedParent.id,
            targetFieldId: widget.field.id,
            optionId: selectedParent.kind == RoutineFieldKind.boolean ? null : triggerOptionId,
            booleanValue: selectedParent.kind == RoutineFieldKind.boolean ? triggerBoolean : null,
            depth: depth,
          ),
        );
      }
    }

    widget.onChanged(
      RoutineField(
        id: widget.field.id,
        label: label.text,
        kind: kind,
        sortOrder: widget.field.sortOrder,
        isRequired: required,
        initialValue: initialValue,
        minimumValue: kind == RoutineFieldKind.number
            ? num.tryParse(minimum.text.replaceAll(',', '.'))
            : null,
        maximumValue: kind == RoutineFieldKind.number
            ? num.tryParse(maximum.text.replaceAll(',', '.'))
            : null,
        options: isChoice ? List.unmodifiable(options) : const [],
        conditions: conditions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloFormTextField(
        fieldKey: const Key('daily-routine-field-label'),
        controller: label,
        labelText: 'Nome do campo',
        prefixIcon: Icons.label_outline_rounded,
        enabled: widget.enabled,
        onChanged: (_) => emit(),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloAdminSingleSelectField<RoutineFieldKind>(
        key: const Key('daily-routine-field-type'),
        label: 'Tipo',
        value: kind,
        options: RoutineFieldKind.values,
        optionLabel: _kindLabel,
        enabled: widget.enabled,
        onChanged: (value) => setState(() {
          kind = value;
          selectedOptionId = null;
          selectedOptionIds = {};
          emit();
        }),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      if (isChoice) ...[
        DailyRoutineOptionListEditor(
          options: options,
          enabled: widget.enabled,
          onAdd: () => setState(() {
            options = [
              ...options,
              RoutineFieldOption(
                id: 'option-${widget.field.id}-${options.length + 1}',
                label: '',
                sortOrder: options.length,
              ),
            ];
            emit();
          }),
          onLabelChanged: (option, value) {
            final index = options.indexWhere((item) => item.id == option.id);
            if (index < 0) return;
            options = [...options]
              ..[index] = RoutineFieldOption(
                id: option.id,
                label: value,
                sortOrder: option.sortOrder,
              );
            emit();
          },
          onRemove: (option) => setState(() {
            options = options.where((item) => item.id != option.id).toList();
            selectedOptionIds.remove(option.id);
            if (selectedOptionId == option.id) selectedOptionId = null;
            emit();
          }),
          onReorder: (oldIndex, newIndex) => setState(() {
            if (newIndex > oldIndex) newIndex--;
            final reordered = [...options];
            final moved = reordered.removeAt(oldIndex);
            reordered.insert(newIndex, moved);
            options = [
              for (var i = 0; i < reordered.length; i++)
                RoutineFieldOption(id: reordered[i].id, label: reordered[i].label, sortOrder: i),
            ];
            emit();
          }),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (options.isNotEmpty)
          if (kind == RoutineFieldKind.singleChoice)
            CoeloAdminSingleSelectField<String>(
              key: const Key('daily-routine-field-initial-choice'),
              label: 'Valor inicial',
              value: selectedOptionId ?? '',
              options: ['', ...options.map((option) => option.id)],
              optionLabel: (id) => id.isEmpty
                  ? 'Sem valor inicial'
                  : options.firstWhere((option) => option.id == id).label,
              enabled: widget.enabled,
              searchable: false,
              onChanged: (value) => setState(() {
                selectedOptionId = value.isEmpty ? null : value;
                emit();
              }),
            )
          else
            CoeloAdminMultiSelectField<String>(
              key: const Key('daily-routine-field-initial-choices'),
              label: 'Valores iniciais',
              options: options.map((option) => option.id).toList(),
              selectedValues: selectedOptionIds,
              optionLabel: (id) => options.firstWhere((option) => option.id == id).label,
              enabled: widget.enabled,
              searchable: false,
              onChanged: (values) => setState(() {
                selectedOptionIds = values;
                emit();
              }),
            ),
      ] else if (kind == RoutineFieldKind.boolean)
        CoeloAdminSingleSelectField<_BooleanInitial>(
          key: const Key('daily-routine-field-initial-boolean'),
          label: 'Valor inicial',
          value: booleanInitial,
          options: _BooleanInitial.values,
          optionLabel: (value) => switch (value) {
            _BooleanInitial.none => 'Sem valor inicial',
            _BooleanInitial.yes => 'Sim',
            _BooleanInitial.no => 'Nao',
          },
          enabled: widget.enabled,
          searchable: false,
          onChanged: (value) => setState(() {
            booleanInitial = value;
            emit();
          }),
        )
      else if (kind == RoutineFieldKind.number)
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 3 : 1;
            final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space3) / columns;
            return Wrap(
              spacing: CoeloSpacing.space3,
              runSpacing: CoeloSpacing.space3,
              children: [
                SizedBox(
                  width: width,
                  child: _NumberField(
                    fieldKey: const Key('daily-routine-field-initial-value'),
                    controller: initial,
                    label: 'Valor inicial (opcional)',
                    enabled: widget.enabled,
                    onChanged: emit,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _NumberField(
                    fieldKey: const Key('daily-routine-number-min'),
                    controller: minimum,
                    label: 'Valor minimo',
                    enabled: widget.enabled,
                    onChanged: emit,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _NumberField(
                    fieldKey: const Key('daily-routine-number-max'),
                    controller: maximum,
                    label: 'Valor maximo',
                    enabled: widget.enabled,
                    onChanged: emit,
                  ),
                ),
              ],
            );
          },
        )
      else
        CoeloFormTextField(
          fieldKey: const Key('daily-routine-field-initial-value'),
          controller: initial,
          labelText: 'Valor inicial (opcional)',
          prefixIcon: Icons.auto_awesome_outlined,
          enabled: widget.enabled,
          maxLines: kind == RoutineFieldKind.longText ? 3 : 1,
          onChanged: (_) => emit(),
        ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloAdminToggleField(
        key: const Key('daily-routine-field-required'),
        label: 'Resposta obrigatoria',
        description: 'Quem preenche precisa responder para avancar.',
        value: required,
        onChanged: widget.enabled
            ? (value) => setState(() {
                required = value;
                emit();
              })
            : null,
      ),
      if (widget.availableParents.isNotEmpty) ...[
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminSingleSelectField<String>(
          key: const Key('daily-routine-condition-parent'),
          label: 'Exibir dependendo de',
          value: parent?.id ?? '',
          options: [
            '',
            ...widget.availableParents
                .where(
                  (field) =>
                      _fieldDepth(field) < 4 &&
                      (field.kind == RoutineFieldKind.boolean ||
                          (field.kind == RoutineFieldKind.singleChoice &&
                              field.options.isNotEmpty)),
                )
                .map((field) => field.id),
          ],
          optionLabel: (id) => id.isEmpty
              ? 'Sempre visivel'
              : widget.availableParents.firstWhere((field) => field.id == id).label,
          enabled: widget.enabled,
          onChanged: (value) => setState(() {
            parent = value.isEmpty
                ? null
                : widget.availableParents.firstWhere((field) => field.id == value);
            triggerOptionId = null;
            emit();
          }),
        ),
        if (parent case final selectedParent?) ...[
          const SizedBox(height: CoeloSpacing.space3),
          if (selectedParent.kind == RoutineFieldKind.boolean)
            CoeloAdminToggleField(
              key: const Key('daily-routine-condition-boolean'),
              label: 'Exibir quando a resposta for Sim',
              value: triggerBoolean,
              onChanged: widget.enabled
                  ? (value) => setState(() {
                      triggerBoolean = value;
                      emit();
                    })
                  : null,
            )
          else
            CoeloAdminSingleSelectField<String>(
              key: const Key('daily-routine-condition-option'),
              label: 'Exibir quando a opcao for',
              value: triggerOptionId ?? selectedParent.options.first.id,
              options: selectedParent.options.map((option) => option.id).toList(),
              optionLabel: (id) =>
                  selectedParent.options.firstWhere((option) => option.id == id).label,
              enabled: widget.enabled,
              searchable: false,
              onChanged: (value) => setState(() {
                triggerOptionId = value;
                emit();
              }),
            ),
        ],
      ],
    ],
  );
}

final class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => CoeloFormTextField(
    fieldKey: fieldKey,
    controller: controller,
    labelText: label,
    prefixIcon: Icons.numbers_rounded,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9,.]'))],
    onChanged: (_) => onChanged(),
  );
}

int _fieldDepth(RoutineField field) {
  var depth = 0;
  for (final condition in field.conditions) {
    if (condition.depth > depth) depth = condition.depth;
  }
  return depth;
}

String _kindLabel(RoutineFieldKind kind) => switch (kind) {
  RoutineFieldKind.shortText => 'Texto curto',
  RoutineFieldKind.longText => 'Texto longo',
  RoutineFieldKind.number => 'Numero',
  RoutineFieldKind.boolean => 'Sim/Nao',
  RoutineFieldKind.singleChoice => 'Escolha unica',
  RoutineFieldKind.multipleChoice => 'Escolha multipla',
};
