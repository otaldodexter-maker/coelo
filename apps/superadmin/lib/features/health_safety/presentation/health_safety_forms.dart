import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/health_safety.dart';

final class HealthMedicationDraft {
  HealthMedicationDraft({
    required this.name,
    required this.dose,
    required this.doseUnit,
    required this.route,
    required this.startsAt,
    required this.endsAt,
    required List<HealthMedicationSchedule> schedules,
    this.documentName,
    this.documentType,
  }) : schedules = List.unmodifiable(schedules) {
    if (name.trim().isEmpty ||
        dose.trim().isEmpty ||
        doseUnit.trim().isEmpty ||
        route.trim().isEmpty) {
      throw ArgumentError('Medication prescription fields are required.');
    }
    if (endsAt.isBefore(startsAt)) {
      throw ArgumentError('Medication end cannot precede start.');
    }
    if (schedules.isEmpty) throw ArgumentError('At least one exact schedule is required.');
  }
  final String name;
  final String dose;
  final String doseUnit;
  final String route;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<HealthMedicationSchedule> schedules;
  final String? documentName;
  final String? documentType;
}

final class HealthOwnerCorrectionDraft {
  const HealthOwnerCorrectionDraft({
    required this.before,
    required this.after,
    required this.justification,
  });
  final String before;
  final String after;
  final String justification;
}

final class HealthAllergyDraft {
  const HealthAllergyDraft({required this.label, required this.type});
  final String label;
  final HealthSafetyAllergyType type;
}

Future<void> showHealthMedicationDialog(
  BuildContext context, {
  required FutureOr<void> Function(HealthMedicationDraft) onSave,
  List<String> institutionIds = const [],
  bool readOnly = false,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _MedicationDialog(onSave: onSave, readOnly: readOnly, institutionIds: institutionIds),
);

Future<void> showHealthAllergyDialog(
  BuildContext context, {
  required FutureOr<void> Function(HealthAllergyDraft) onSave,
  bool readOnly = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => _SimpleTextDialog(
    title: 'Alergia ou restrição',
    label: 'Nome do item',
    icon: Icons.warning_amber_rounded,
    onSave: onSave,
    readOnly: readOnly,
  ),
);

Future<void> showHealthCareProfileDialog(
  BuildContext context, {
  required ValueChanged<HealthSafetyCareProfileItem> onSave,
  bool readOnly = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => _CareProfileDialog(onSave: onSave, readOnly: readOnly),
);

Future<void> showHealthOwnerCorrectionDialog(
  BuildContext context, {
  required String before,
  required FutureOr<void> Function(HealthOwnerCorrectionDraft) onSave,
  bool owner = true,
}) => showDialog<void>(
  context: context,
  builder: (_) => _OwnerCorrectionDialog(before: before, onSave: onSave, owner: owner),
);

final class _MedicationDialog extends StatefulWidget {
  const _MedicationDialog({
    required this.onSave,
    required this.readOnly,
    required this.institutionIds,
  });
  final FutureOr<void> Function(HealthMedicationDraft) onSave;
  final bool readOnly;
  final List<String> institutionIds;
  @override
  State<_MedicationDialog> createState() => _MedicationDialogState();
}

final class _MedicationDialogState extends State<_MedicationDialog> {
  final name = TextEditingController();
  final dose = TextEditingController();
  final doseUnit = TextEditingController();
  final route = TextEditingController();
  final document = TextEditingController();
  final documentType = TextEditingController();
  var startsAt = DateTime(2026, 8, 3);
  var endsAt = DateTime(2026, 8, 10);
  final schedules = <_MedicationScheduleDraft>[
    _MedicationScheduleDraft(time: const TimeOfDay(hour: 7, minute: 30)),
  ];
  var validate = false;
  var dateOrderError = false;
  var saving = false;
  String? saveError;

  @override
  void dispose() {
    for (final controller in [name, dose, doseUnit, route, document, documentType]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => validate = true);
    if ([name, dose, doseUnit, route].any((controller) => controller.text.trim().isEmpty)) {
      return;
    }
    if (endsAt.isBefore(startsAt)) {
      setState(() => dateOrderError = true);
      return;
    }
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await widget.onSave(
        HealthMedicationDraft(
          name: name.text.trim(),
          dose: dose.text.trim(),
          doseUnit: doseUnit.text.trim(),
          route: route.text.trim(),
          startsAt: startsAt,
          endsAt: endsAt,
          schedules: [
            for (var index = 0; index < schedules.length; index++)
              HealthMedicationSchedule(
                id: 'schedule-local-$index',
                time: HealthSafetyTimeOfDay(
                  schedules[index].time.hour,
                  schedules[index].time.minute,
                ),
                atHome: schedules[index].responsible == 'Casa',
                institutionId: schedules[index].responsible == 'Casa'
                    ? null
                    : schedules[index].responsible,
              ),
          ],
          documentName: document.text.trim().isEmpty ? null : document.text.trim(),
          documentType: documentType.text.trim().isEmpty ? null : documentType.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() {
          saving = false;
          saveError = 'Não foi possível salvar. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Medicamento',
    maxWidth: CoeloBreakpoints.medium.maxWidth,
    closeTooltip: 'Fechar formulário de medicamento',
    body: LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
        final fields = <Widget>[
          _field(
            name,
            'Nome',
            Icons.medication_outlined,
            key: const Key('health-medication-name'),
            error: validate && name.text.trim().isEmpty ? 'Informe o nome.' : null,
          ),
          _field(
            dose,
            'Dose',
            Icons.straighten_rounded,
            key: const Key('health-medication-dose'),
            error: validate && dose.text.trim().isEmpty ? 'Informe a dose.' : null,
          ),
          _field(
            doseUnit,
            'Unidade',
            Icons.straighten_rounded,
            key: const Key('health-medication-dose-unit'),
            error: validate && doseUnit.text.trim().isEmpty ? 'Informe a unidade.' : null,
          ),
          _field(
            route,
            'Via',
            Icons.route_outlined,
            key: const Key('health-medication-route'),
            error: validate && route.text.trim().isEmpty ? 'Informe a via.' : null,
          ),
          _field(document, 'Documento demonstrativo (opcional)', Icons.description_outlined),
          _field(documentType, 'Tipo do documento (opcional)', Icons.article_outlined),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _responsiveFields(fields, twoColumns: twoColumns),
            const SizedBox(height: CoeloSpacing.space5),
            _responsiveFields([
              _dateControl(
                label: 'Data inicial',
                value: startsAt,
                onChanged: (value) => setState(() {
                  startsAt = value;
                  dateOrderError = endsAt.isBefore(startsAt);
                }),
              ),
              _dateControl(
                label: 'Data final',
                value: endsAt,
                error: dateOrderError ? 'A data final não pode anteceder a inicial.' : null,
                onChanged: (value) => setState(() {
                  endsAt = value;
                  dateOrderError = endsAt.isBefore(startsAt);
                }),
              ),
            ], twoColumns: twoColumns),
            const SizedBox(height: CoeloSpacing.space5),
            Text('Horários exatos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: CoeloSpacing.space3),
            for (var index = 0; index < schedules.length; index++) ...[
              _scheduleControl(index),
              if (index + 1 < schedules.length) const SizedBox(height: CoeloSpacing.space3),
            ],
            const SizedBox(height: CoeloSpacing.space3),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.readOnly
                    ? null
                    : () => setState(
                        () => schedules.add(
                          _MedicationScheduleDraft(time: const TimeOfDay(hour: 12, minute: 0)),
                        ),
                      ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar horário'),
              ),
            ),
            if (saveError != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Text(saveError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        );
      },
    ),
    secondaryAction: OutlinedButton(
      onPressed: saving ? null : () => Navigator.pop(context),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      onPressed: widget.readOnly || saving ? null : save,
      child: saving
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(dimension: CoeloSpacing.space4, child: CircularProgressIndicator()),
                SizedBox(width: CoeloSpacing.space2),
                Text('Salvando…'),
              ],
            )
          : const Text('Salvar'),
    ),
  );

  Widget _responsiveFields(List<Widget> fields, {required bool twoColumns}) {
    if (!twoColumns) return Column(children: _spaced(fields));
    return Column(
      children: [
        for (var index = 0; index < fields.length; index += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[index]),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: index + 1 < fields.length ? fields[index + 1] : const SizedBox.shrink(),
              ),
            ],
          ),
          if (index + 2 < fields.length) const SizedBox(height: CoeloSpacing.space4),
        ],
      ],
    );
  }

  Widget _dateControl({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
    String? error,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: CoeloSpacing.space1),
      OutlinedButton.icon(
        onPressed: widget.readOnly
            ? null
            : () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected != null) onChanged(selected);
              },
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(_formatDate(value)),
      ),
      if (error != null) ...[
        const SizedBox(height: CoeloSpacing.space1),
        Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    ],
  );

  Widget _scheduleControl(int index) {
    final schedule = schedules[index];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
            final time = OutlinedButton.icon(
              onPressed: widget.readOnly
                  ? null
                  : () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime: schedule.time,
                      );
                      if (selected != null) setState(() => schedule.time = selected);
                    },
              icon: const Icon(Icons.schedule_rounded),
              label: Text(schedule.time.format(context)),
            );
            final responsible = CoeloAdminSingleSelectField<String>(
              label: 'Responsável',
              value: schedule.responsible,
              options: ['Casa', ...widget.institutionIds],
              optionLabel: _responsibleLabel,
              enabled: !widget.readOnly,
              onChanged: (value) => setState(() => schedule.responsible = value),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  time,
                  const SizedBox(height: CoeloSpacing.space3),
                  responsible,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: time),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(child: responsible),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    Key? key,
    String? error,
  }) => CoeloFormTextField(
    controller: controller,
    fieldKey: key,
    labelText: label,
    prefixIcon: icon,
    errorText: error,
    enabled: !widget.readOnly,
    onChanged: (_) {
      if (validate) setState(() {});
    },
  );
}

final class _MedicationScheduleDraft {
  _MedicationScheduleDraft({required this.time});
  TimeOfDay time;
  String responsible = 'Casa';
}

final class _SimpleTextDialog extends StatefulWidget {
  const _SimpleTextDialog({
    required this.title,
    required this.label,
    required this.icon,
    required this.onSave,
    required this.readOnly,
  });
  final String title;
  final String label;
  final IconData icon;
  final FutureOr<void> Function(HealthAllergyDraft) onSave;
  final bool readOnly;
  @override
  State<_SimpleTextDialog> createState() => _SimpleTextDialogState();
}

final class _SimpleTextDialogState extends State<_SimpleTextDialog> {
  final controller = TextEditingController();
  var error = false;
  var saving = false;
  String? saveError;
  var type = HealthSafetyAllergyType.other;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: widget.title,
    body: Column(
      children: [
        CoeloFormTextField(
          controller: controller,
          labelText: widget.label,
          prefixIcon: widget.icon,
          enabled: !widget.readOnly && !saving,
          errorText: error ? 'Informe o nome.' : null,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminSingleSelectField<HealthSafetyAllergyType>(
          label: 'Tipo',
          value: type,
          options: HealthSafetyAllergyType.values,
          optionLabel: _allergyTypeLabel,
          enabled: !widget.readOnly && !saving,
          onChanged: (value) => setState(() => type = value),
        ),
        if (saveError != null)
          Text(saveError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: saving ? null : () => Navigator.pop(context),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      onPressed: widget.readOnly || saving
          ? null
          : () async {
              if (controller.text.trim().isEmpty) {
                setState(() => error = true);
                return;
              }
              setState(() {
                saving = true;
                saveError = null;
              });
              try {
                await widget.onSave(HealthAllergyDraft(label: controller.text.trim(), type: type));
                if (mounted) Navigator.pop(this.context);
              } on Object {
                if (mounted) {
                  setState(() {
                    saving = false;
                    saveError = 'Não foi possível salvar. Tente novamente.';
                  });
                }
              }
            },
      child: Text(saving ? 'Salvando…' : 'Salvar'),
    ),
  );
}

final class _CareProfileDialog extends StatefulWidget {
  const _CareProfileDialog({required this.onSave, required this.readOnly});
  final ValueChanged<HealthSafetyCareProfileItem> onSave;
  final bool readOnly;
  @override
  State<_CareProfileDialog> createState() => _CareProfileDialogState();
}

final class _CareProfileDialogState extends State<_CareProfileDialog> {
  var selected = healthSafetyCareProfileCatalog.first.items.first.id;
  final other = TextEditingController();
  var error = false;
  @override
  void dispose() {
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Perfil de Cuidado',
    body: RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (!widget.readOnly && value != null) setState(() => selected = value);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in healthSafetyCareProfileCatalog) ...[
            Text(group.label, style: Theme.of(context).textTheme.titleSmall),
            for (final item in group.items)
              RadioListTile<String>(
                value: item.id,
                title: Text(item.label),
                enabled: !widget.readOnly,
              ),
            const SizedBox(height: CoeloSpacing.space3),
          ],
          if (selected == 'other')
            CoeloFormTextField(
              controller: other,
              labelText: 'Outro',
              prefixIcon: Icons.edit_outlined,
              errorText: error ? 'Descreva o apoio.' : null,
              enabled: !widget.readOnly,
            ),
          const Text('Use linguagem de apoio; este catálogo não realiza diagnóstico.'),
        ],
      ),
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      onPressed: widget.readOnly
          ? null
          : () {
              if (selected == 'other' && other.text.trim().isEmpty) {
                setState(() => error = true);
                return;
              }
              widget.onSave(
                HealthSafetyCareProfileItem(
                  catalogItemId: selected,
                  otherText: selected == 'other' ? other.text.trim() : null,
                ),
              );
              Navigator.pop(context);
            },
      child: const Text('Salvar'),
    ),
  );
}

final class _OwnerCorrectionDialog extends StatefulWidget {
  const _OwnerCorrectionDialog({required this.before, required this.onSave, required this.owner});
  final String before;
  final FutureOr<void> Function(HealthOwnerCorrectionDraft) onSave;
  final bool owner;
  @override
  State<_OwnerCorrectionDialog> createState() => _OwnerCorrectionDialogState();
}

final class _OwnerCorrectionDialogState extends State<_OwnerCorrectionDialog> {
  late final TextEditingController before;
  final after = TextEditingController();
  final justification = TextEditingController();
  var afterError = false;
  var justificationError = false;
  var saving = false;
  String? saveError;

  @override
  void initState() {
    super.initState();
    before = TextEditingController(text: widget.before);
  }

  @override
  void didUpdateWidget(covariant _OwnerCorrectionDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.before != widget.before) before.text = widget.before;
  }

  @override
  void dispose() {
    before.dispose();
    after.dispose();
    justification.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Correção excepcional do Owner',
    body: Column(
      children: [
        CoeloFormTextField(
          controller: before,
          labelText: 'Antes',
          prefixIcon: Icons.history_rounded,
          enabled: false,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: after,
          fieldKey: const Key('health-owner-after'),
          labelText: 'Depois',
          prefixIcon: Icons.edit_outlined,
          enabled: widget.owner && !saving,
          errorText: afterError ? 'Informe o valor depois.' : null,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: justification,
          fieldKey: const Key('health-owner-justification'),
          labelText: 'Justificativa obrigatória',
          prefixIcon: Icons.fact_check_outlined,
          maxLines: 3,
          enabled: widget.owner && !saving,
          errorText: justificationError ? 'Informe a justificativa.' : null,
        ),
        if (saveError != null) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Text(saveError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: saving ? null : () => Navigator.pop(context),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      onPressed: !widget.owner || saving
          ? null
          : () async {
              final missingAfter = after.text.trim().isEmpty;
              final missingJustification = justification.text.trim().isEmpty;
              if (missingAfter || missingJustification) {
                setState(() {
                  afterError = missingAfter;
                  justificationError = missingJustification;
                });
                return;
              }
              setState(() {
                saving = true;
                saveError = null;
                afterError = false;
                justificationError = false;
              });
              try {
                await widget.onSave(
                  HealthOwnerCorrectionDraft(
                    before: widget.before,
                    after: after.text.trim(),
                    justification: justification.text.trim(),
                  ),
                );
                if (mounted) Navigator.pop(this.context);
              } on Object {
                if (mounted) {
                  setState(() {
                    saving = false;
                    saveError = 'Não foi possível salvar. Tente novamente.';
                  });
                }
              }
            },
      child: saving
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(dimension: CoeloSpacing.space4, child: CircularProgressIndicator()),
                SizedBox(width: CoeloSpacing.space2),
                Text('Salvando…'),
              ],
            )
          : const Text('Salvar correção'),
    ),
  );
}

List<Widget> _spaced(List<Widget> children) => [
  for (var index = 0; index < children.length; index++) ...[
    children[index],
    if (index + 1 < children.length) const SizedBox(height: CoeloSpacing.space4),
  ],
];

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _responsibleLabel(String value) => switch (value) {
  'Casa' => 'Casa',
  'institution-demo-a' => 'Instituição Demo A',
  'institution-demo-b' => 'Instituição Demo B',
  _ => value,
};

String _allergyTypeLabel(HealthSafetyAllergyType value) => switch (value) {
  HealthSafetyAllergyType.medication => 'Medicamentosa',
  HealthSafetyAllergyType.food => 'Alimentar',
  HealthSafetyAllergyType.restriction => 'Restrição',
  HealthSafetyAllergyType.other => 'Outra',
};
