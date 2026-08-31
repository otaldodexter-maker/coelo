import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

final class HealthCareFormChoice {
  const HealthCareFormChoice({required this.id, required this.label});
  final String id;
  final String label;
}

final class CoeloMedicationChildSelector extends StatelessWidget {
  const CoeloMedicationChildSelector({
    required this.options,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });
  final List<HealthCareFormChoice> options;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const _UnavailableField(label: 'Criança');
    final value = options.any((item) => item.id == selectedId) ? selectedId! : options.first.id;
    return CoeloAdminSingleSelectField<String>(
      label: 'Criança',
      value: value,
      options: options.map((item) => item.id).toList(growable: false),
      optionLabel: (id) => options.firstWhere((item) => item.id == id).label,
      onChanged: onChanged,
      prefixIcon: Icons.child_care_rounded,
      searchable: true,
      searchHintText: 'Buscar criança',
    );
  }
}

final class CoeloMedicationDateField extends StatelessWidget {
  const CoeloMedicationDateField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: '$label: ${value == null ? 'Não informada' : _dateLabel(value!)}',
    minHeight: CoeloSize.touchMin,
    onPressed: () async {
      final now = DateUtils.dateOnly(DateTime.now());
      final selected = await showCoeloDateRangePicker(
        context: context,
        value: value == null ? null : DateTimeRange(start: value!, end: value!),
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 10, 12, 31),
        currentDate: now,
        showQuickRanges: false,
        selectionMode: CoeloDateSelectionMode.single,
      );
      if (!context.mounted || selected == null) return;
      final date = DateUtils.dateOnly(selected.start);
      if (value == null || !DateUtils.isSameDay(value, date)) onChanged(date);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      child: Text(value == null ? 'Selecionar data' : _dateLabel(value!)),
    ),
  );
}

final class CoeloMedicationTimeField extends StatelessWidget {
  const CoeloMedicationTimeField({required this.value, required this.onChanged, super.key});
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) => CoeloTimeField(
    value: value,
    onChanged: (selected) {
      if (selected != null) onChanged(selected);
    },
  );
}

final class CoeloMedicationWeekdaySelector extends StatelessWidget {
  const CoeloMedicationWeekdaySelector({
    required this.selectedValues,
    required this.onChanged,
    super.key,
  });
  final Set<int> selectedValues;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) => CoeloAdminMultiSelectField<int>(
    label: 'Dias da semana',
    options: const [1, 2, 3, 4, 5, 6, 7],
    selectedValues: selectedValues,
    optionLabel: _weekdayLabel,
    onChanged: onChanged,
    prefixIcon: Icons.calendar_view_week_rounded,
    emptyLabel: 'Selecionar dias',
  );
}

final class CoeloMedicationResponsibleSelector extends StatefulWidget {
  const CoeloMedicationResponsibleSelector({
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    super.key,
  });
  final List<HealthCareFormChoice> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<CoeloMedicationResponsibleSelector> createState() => _ResponsibleState();
}

final class _ResponsibleState extends State<CoeloMedicationResponsibleSelector> {
  String? candidate;
  @override
  Widget build(BuildContext context) {
    final available = widget.options
        .where((item) => !widget.selectedIds.contains(item.id))
        .toList();
    final value = available.any((item) => item.id == candidate)
        ? candidate
        : available.firstOrNull?.id;
    String label(String id) => widget.options.firstWhere((item) => item.id == id).label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value == null)
          const _UnavailableField(label: 'Responsável')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < CoeloBreakpoints.medium.minWidth ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final field = CoeloAdminSingleSelectField<String>(
                label: 'Responsável',
                value: value,
                options: available.map((item) => item.id).toList(),
                optionLabel: label,
                onChanged: (next) => setState(() => candidate = next),
                prefixIcon: Icons.person_outline_rounded,
              );
              final action = OutlinedButton.icon(
                onPressed: () {
                  widget.onChanged({...widget.selectedIds, value});
                  setState(() => candidate = null);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar'),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: CoeloSpacing.space2),
                    action,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: CoeloSpacing.space3),
                  action,
                ],
              );
            },
          ),
        if (widget.selectedIds.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              for (final id in widget.selectedIds)
                InputChip(
                  label: Text(label(id)),
                  onDeleted: () => widget.onChanged({...widget.selectedIds}..remove(id)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

final class _UnavailableField extends StatelessWidget {
  const _UnavailableField({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      enabled: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    child: const Text('Nenhuma opção disponível'),
  );
}

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _weekdayLabel(int value) =>
    const ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'][value - 1];
