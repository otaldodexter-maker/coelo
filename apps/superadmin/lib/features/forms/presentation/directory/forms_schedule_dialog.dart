import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum FormsScheduleFrequency { once, daily, weekly, monthly }

final class FormsScheduleDraft {
  FormsScheduleDraft({
    required this.active,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.frequency,
    required Set<int> weekdays,
    required this.audienceLabel,
  }) : weekdays = Set.unmodifiable(weekdays);

  factory FormsScheduleDraft.empty() {
    final start = DateTime.now().add(const Duration(days: 1));
    return FormsScheduleDraft(
      active: true,
      name: '',
      startsAt: start,
      endsAt: start.add(const Duration(days: 30)),
      frequency: FormsScheduleFrequency.once,
      weekdays: const {},
      audienceLabel: 'Público da distribuição',
    );
  }

  final bool active;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final FormsScheduleFrequency frequency;
  final Set<int> weekdays;
  final String audienceLabel;
}

Future<void> showFormsScheduleDialog({
  required BuildContext context,
  required FormsScheduleDraft initialValue,
  Future<void> Function(FormsScheduleDraft value)? onSave,
  String? unavailableReason,
}) => showDialog<void>(
  context: context,
  barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
  builder: (context) => _FormsScheduleDialog(
    initialValue: initialValue,
    onSave: onSave,
    unavailableReason: unavailableReason,
  ),
);

final class _FormsScheduleDialog extends StatefulWidget {
  const _FormsScheduleDialog({
    required this.initialValue,
    required this.onSave,
    required this.unavailableReason,
  });

  final FormsScheduleDraft initialValue;
  final Future<void> Function(FormsScheduleDraft value)? onSave;
  final String? unavailableReason;

  @override
  State<_FormsScheduleDialog> createState() => _FormsScheduleDialogState();
}

final class _FormsScheduleDialogState extends State<_FormsScheduleDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initialValue.name);
  late final TextEditingController _audience = TextEditingController(
    text: widget.initialValue.audienceLabel,
  );
  late bool _active = widget.initialValue.active;
  late DateTime _startsAt = widget.initialValue.startsAt;
  late DateTime _endsAt = widget.initialValue.endsAt;
  late FormsScheduleFrequency _frequency = widget.initialValue.frequency;
  late Set<int> _weekdays = Set.of(widget.initialValue.weekdays);
  bool _saving = false;
  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _audience.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Informe o nome do agendamento.');
      return;
    }
    if (_endsAt.isBefore(_startsAt)) {
      setState(() => _formError = 'A data de término deve ser igual ou posterior ao início.');
      return;
    }
    if (_frequency == FormsScheduleFrequency.weekly && _weekdays.isEmpty) {
      setState(() => _formError = 'Selecione ao menos um dia para a recorrência semanal.');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
      _formError = null;
    });
    try {
      await widget.onSave!(
        FormsScheduleDraft(
          active: _active,
          name: name,
          startsAt: _startsAt,
          endsAt: _endsAt,
          frequency: _frequency,
          weekdays: _weekdays,
          audienceLabel: widget.initialValue.audienceLabel,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _formError = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Editar agendamento',
    closeTooltip: 'Fechar edição de agendamento',
    maxWidth: 640,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.unavailableReason case final reason?) ...[
          _ScheduleMessage(
            key: const Key('forms-schedule-unavailable'),
            message: reason,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        if (_formError case final error?) ...[
          _ScheduleMessage(
            key: const Key('forms-schedule-validation-error'),
            message: error,
            icon: Icons.error_outline_rounded,
            isError: true,
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        CoeloAdminToggleField(
          label: 'Ativo',
          description: 'O agendamento gera tarefas para os perfis selecionados.',
          value: _active,
          onChanged: _saving ? null : (value) => setState(() => _active = value),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          fieldKey: const Key('forms-schedule-name'),
          controller: _name,
          labelText: 'Nome do agendamento',
          prefixIcon: Icons.event_note_outlined,
          enabled: !_saving,
          errorText: _nameError,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ResponsivePair(
          first: CoeloDateTimeField(
            value: _startsAt,
            labelText: 'Data de início',
            firstDate: DateTime(2020),
            lastDate: DateTime(2100, 12, 31),
            enabled: !_saving,
            onChanged: (value) {
              if (value != null) setState(() => _startsAt = value);
            },
          ),
          second: CoeloDateTimeField(
            value: _endsAt,
            labelText: 'Data de término',
            firstDate: _startsAt,
            lastDate: DateTime(2100, 12, 31),
            enabled: !_saving,
            onChanged: (value) {
              if (value != null) setState(() => _endsAt = value);
            },
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ResponsivePair(
          first: CoeloAdminSingleSelectField<FormsScheduleFrequency>(
            label: 'Frequência',
            value: _frequency,
            options: FormsScheduleFrequency.values,
            optionLabel: _frequencyLabel,
            prefixIcon: Icons.repeat_rounded,
            enabled: !_saving,
            onChanged: (value) => setState(() => _frequency = value),
          ),
          second: CoeloAdminMultiSelectField<int>(
            label: 'Dias da semana',
            options: const [1, 2, 3, 4, 5, 6, 7],
            selectedValues: _weekdays,
            optionLabel: _weekdayLabel,
            enabled: !_saving && _frequency == FormsScheduleFrequency.weekly,
            onChanged: (value) => setState(() => _weekdays = value),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: _audience,
          labelText: 'Perfis e audiência',
          prefixIcon: Icons.groups_outlined,
          enabled: false,
        ),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: _saving ? null : () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      onPressed: _saving || widget.onSave == null ? null : _save,
      child: _saving
          ? const SizedBox.square(
              dimension: CoeloSize.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Salvar'),
    ),
  );
}

final class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({
    required this.message,
    required this.icon,
    this.isError = false,
    super.key,
  });

  final String message;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isError ? colors.error : colors.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

final class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 520 || MediaQuery.textScalerOf(context).scale(1) > 1.5) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            first,
            const SizedBox(height: CoeloSpacing.space4),
            second,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(child: second),
        ],
      );
    },
  );
}

String _frequencyLabel(FormsScheduleFrequency value) => switch (value) {
  FormsScheduleFrequency.once => 'Uma vez',
  FormsScheduleFrequency.daily => 'Diário',
  FormsScheduleFrequency.weekly => 'Semanal',
  FormsScheduleFrequency.monthly => 'Mensal',
};

String _weekdayLabel(int value) => const {
  DateTime.monday: 'Segunda-feira',
  DateTime.tuesday: 'Terça-feira',
  DateTime.wednesday: 'Quarta-feira',
  DateTime.thursday: 'Quinta-feira',
  DateTime.friday: 'Sexta-feira',
  DateTime.saturday: 'Sábado',
  DateTime.sunday: 'Domingo',
}[value]!;
