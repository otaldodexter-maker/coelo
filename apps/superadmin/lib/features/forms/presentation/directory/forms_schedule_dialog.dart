import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../data/forms_editor_context.dart';

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

Future<bool?> showFormsScheduleDialog({
  required BuildContext context,
  required FormsScheduleDraft initialValue,
  Future<void> Function(FormsScheduleDraft value)? onSave,
  String? unavailableReason,
}) => showDialog<bool>(
  context: context,
  barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
  builder: (context) => _FormsScheduleDialog(
    initialValue: initialValue,
    onSave: onSave,
    unavailableReason: unavailableReason,
  ),
);

/// Opens the production distribution flow. It only offers institution and
/// audience IDs returned by authorized RPCs; it never derives IDs from labels.
Future<void> showFormsProductionScheduleDialog({
  required BuildContext context,
  required FormsApi api,
  required FormsEditorContextApi contextApi,
  required String formId,
  required String formTitle,
  VoidCallback? onSaved,
}) => showDialog<void>(
  context: context,
  barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
  builder: (context) => _FormsProductionAudienceDialog(
    api: api,
    contextApi: contextApi,
    formId: formId,
    formTitle: formTitle,
    onSaved: onSaved,
  ),
);

final class _FormsProductionAudienceDialog extends StatefulWidget {
  const _FormsProductionAudienceDialog({
    required this.api,
    required this.contextApi,
    required this.formId,
    required this.formTitle,
    required this.onSaved,
  });

  final FormsApi api;
  final FormsEditorContextApi contextApi;
  final String formId;
  final String formTitle;
  final VoidCallback? onSaved;

  @override
  State<_FormsProductionAudienceDialog> createState() => _FormsProductionAudienceDialogState();
}

final class _FormsProductionAudienceDialogState extends State<_FormsProductionAudienceDialog> {
  FormsEditorContext? _context;
  FormApplication? _application;
  List<FormAudienceCandidate> _candidates = const [];
  String? _institutionId;
  FormAudienceRuleKind _audienceKind = FormAudienceRuleKind.institution;
  String? _audienceId;
  bool _loading = true;
  bool _loadingAudience = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object>([
        widget.contextApi.getEditorContext(),
        widget.api.getEditor(widget.formId),
      ]);
      final context = values[0] as FormsEditorContext;
      final application = (values[1] as FormEditorProjection).application;
      final allowedInstitutions = context.institutions
          .where((institution) => institution.canManageForms)
          .toList(growable: false);
      if (!context.canManageApplications || allowedInstitutions.isEmpty) {
        throw const _ScheduleAccessException(
          'Você não tem permissão para distribuir este formulário.',
        );
      }
      final institutionId = application?.institutionId ?? allowedInstitutions.first.id;
      if (!allowedInstitutions.any((institution) => institution.id == institutionId)) {
        throw const _ScheduleAccessException(
          'A instituição desta distribuição não está autorizada para sua sessão.',
        );
      }
      if (!mounted) return;
      setState(() {
        _context = context;
        _application = application;
        _institutionId = institutionId;
        _audienceKind =
            application?.audienceRules.firstOrNull?.kind ?? FormAudienceRuleKind.institution;
        _audienceId = application?.audienceRules.firstOrNull?.targetId ?? institutionId;
        _loading = false;
      });
      await _loadAudienceCandidates();
    } on FormApiException catch (error) {
      if (mounted) setState(() => _fail(error.message));
    } on _ScheduleAccessException catch (error) {
      if (mounted) setState(() => _fail(error.message));
    } on Object {
      if (mounted) setState(() => _fail('Não foi possível carregar a distribuição autorizada.'));
    }
  }

  void _fail(String message) {
    _loading = false;
    _error = message;
  }

  Future<void> _loadAudienceCandidates() async {
    final institutionId = _institutionId;
    if (institutionId == null) return;
    if (_audienceKind == FormAudienceRuleKind.institution) {
      setState(() {
        _candidates = [
          FormAudienceCandidate(
            id: institutionId,
            label: _institutionName(institutionId),
            kind: FormAudienceRuleKind.institution,
          ),
        ];
        _audienceId = institutionId;
      });
      return;
    }
    setState(() {
      _loadingAudience = true;
      _error = null;
      _audienceId = null;
    });
    try {
      final page = await widget.api.listAudienceCandidates(
        FormAudienceCandidatesQuery(institutionId: institutionId, kind: _audienceKind, limit: 100),
      );
      if (mounted) {
        setState(() {
          _candidates = page.items;
          _loadingAudience = false;
        });
      }
    } on FormApiException catch (error) {
      if (mounted) {
        setState(() {
          _loadingAudience = false;
          _error = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loadingAudience = false;
          _error = 'Não foi possível carregar o público autorizado.';
        });
      }
    }
  }

  String _institutionName(String id) =>
      _context!.institutions.where((institution) => institution.id == id).firstOrNull?.name ?? id;

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Público e agendamento',
    closeTooltip: 'Fechar distribuição do formulário',
    maxWidth: 640,
    body: _loading
        ? const Padding(
            padding: EdgeInsets.all(CoeloSpacing.space6),
            child: Center(child: CircularProgressIndicator()),
          )
        : _error != null && _context == null
        ? CoeloStatePanel(
            icon: Icons.lock_outline_rounded,
            title: 'Distribuição indisponível',
            message: _error!,
          )
        : _content(context),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      onPressed: _canContinue ? _openSchedule : null,
      child: const Text('Continuar'),
    ),
  );

  bool get _canContinue =>
      !_loading &&
      !_loadingAudience &&
      _error == null &&
      _institutionId != null &&
      _audienceId != null;

  Widget _content(BuildContext context) {
    final application = _application;
    final institutionOptions = application == null
        ? _context!.institutions
              .where((institution) => institution.canManageForms)
              .map((item) => item.id)
        : [application.institutionId];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escolha somente uma instituição e um público devolvidos pelas fontes autorizadas.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<String>(
          key: const Key('forms-schedule-institution'),
          label: 'Instituição',
          value: _institutionId ?? '',
          options: institutionOptions.toList(growable: false),
          optionLabel: _institutionName,
          prefixIcon: Icons.account_balance_outlined,
          enabled: application == null && !_loadingAudience,
          onChanged: (value) {
            setState(() => _institutionId = value);
            _loadAudienceCandidates();
          },
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<FormAudienceRuleKind>(
          key: const Key('forms-schedule-audience-kind'),
          label: 'Tipo de público',
          value: _audienceKind,
          options: const [
            FormAudienceRuleKind.institution,
            FormAudienceRuleKind.group,
            FormAudienceRuleKind.activity,
            FormAudienceRuleKind.profile,
          ],
          optionLabel: _audienceKindLabel,
          prefixIcon: Icons.groups_outlined,
          enabled: !_loadingAudience,
          onChanged: (value) {
            setState(() => _audienceKind = value);
            _loadAudienceCandidates();
          },
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (_loadingAudience)
          const Center(child: CircularProgressIndicator())
        else if (_candidates.isEmpty)
          const CoeloStatePanel(
            icon: Icons.groups_outlined,
            title: 'Nenhum público disponível',
            message: 'Altere a instituição ou o tipo de público para continuar.',
          )
        else
          CoeloAdminSingleSelectField<String>(
            key: const Key('forms-schedule-audience'),
            label: 'Público',
            value: _audienceId ?? '',
            options: _candidates.map((candidate) => candidate.id).toList(growable: false),
            optionLabel: (id) =>
                _candidates.where((candidate) => candidate.id == id).firstOrNull?.label ?? id,
            prefixIcon: Icons.group_outlined,
            enabled: true,
            onChanged: (value) => setState(() => _audienceId = value),
          ),
        if (_error case final error?) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }

  Future<void> _openSchedule() async {
    final application = _application;
    final existingSchedule = application?.schedules.firstOrNull;
    final now = DateTime.now();
    final saved = await showFormsScheduleDialog(
      context: context,
      initialValue: FormsScheduleDraft(
        active: application?.status != FormApplicationStatus.paused,
        name: application?.name ?? 'Distribuição de ${widget.formTitle}',
        startsAt: existingSchedule?.schedule.startsAtLocal ?? now,
        endsAt: _endDate(existingSchedule?.schedule.end) ?? now.add(const Duration(days: 30)),
        frequency: _frequency(existingSchedule?.schedule.recurrence),
        weekdays: _weekdays(existingSchedule?.schedule.recurrence),
        audienceLabel:
            _candidates.where((candidate) => candidate.id == _audienceId).firstOrNull?.label ?? '',
      ),
      onSave: (draft) => _persist(draft, existingSchedule),
    );
    if (saved == true && mounted) {
      widget.onSaved?.call();
      Navigator.of(context).pop();
    }
  }

  Future<void> _persist(FormsScheduleDraft draft, FormApplicationSchedule? existingSchedule) async {
    final institutionId = _institutionId!;
    final audienceId = _audienceId!;
    final previous = _application;
    final application = FormApplication(
      id: previous?.id ?? _newScheduleRequestId(),
      formId: widget.formId,
      institutionId: previous?.institutionId ?? institutionId,
      name: draft.name,
      status: draft.active ? FormApplicationStatus.active : FormApplicationStatus.paused,
      opensForDays: previous?.opensForDays ?? 7,
      audienceRules: [
        FormAudienceRule(
          id: previous?.audienceRules.firstOrNull?.id ?? _newScheduleRequestId(),
          kind: _audienceKind,
          mode: FormAudienceRuleMode.include,
          targetId: audienceId,
        ),
      ],
      schedules: previous?.schedules ?? const [],
      managementVersion: previous?.managementVersion ?? 0,
    );
    final savedApplication = await widget.api.saveApplication(
      FormCommand(
        requestId: _newScheduleRequestId(),
        expectedVersion: previous?.managementVersion ?? 0,
        payload: FormSaveApplicationPayload(application),
      ),
    );
    final schedule = FormSchedule(
      startsAtLocal: draft.startsAt,
      timeZone: 'America/Sao_Paulo',
      recurrence: _recurrence(draft),
      end: FormScheduleEnd.onDate(draft.endsAt),
    );
    await widget.api.saveSchedule(
      FormCommand(
        requestId: _newScheduleRequestId(),
        expectedVersion: existingSchedule?.managementVersion ?? 0,
        payload: FormSaveSchedulePayload(
          applicationId: savedApplication.id,
          scheduleId: existingSchedule?.id,
          schedule: schedule,
        ),
      ),
    );
  }
}

final class _ScheduleAccessException implements Exception {
  const _ScheduleAccessException(this.message);
  final String message;
}

FormRecurrence _recurrence(FormsScheduleDraft draft) => switch (draft.frequency) {
  FormsScheduleFrequency.once => const FormRecurrence.once(),
  FormsScheduleFrequency.daily => const FormRecurrence.daily(interval: 1),
  FormsScheduleFrequency.weekly => FormRecurrence.weekly(interval: 1, weekdays: draft.weekdays),
  FormsScheduleFrequency.monthly => FormRecurrence.monthly(interval: 1, day: draft.startsAt.day),
};

FormsScheduleFrequency _frequency(FormRecurrence? recurrence) => switch (recurrence) {
  FormDailyRecurrence() => FormsScheduleFrequency.daily,
  FormWeeklyRecurrence() => FormsScheduleFrequency.weekly,
  FormMonthlyRecurrence() => FormsScheduleFrequency.monthly,
  _ => FormsScheduleFrequency.once,
};

Set<int> _weekdays(FormRecurrence? recurrence) => switch (recurrence) {
  FormWeeklyRecurrence(:final weekdays) => weekdays,
  _ => const {},
};

DateTime? _endDate(FormScheduleEnd? end) => switch (end) {
  FormScheduleEndsOnDate(:final date) => date,
  _ => null,
};

String _audienceKindLabel(FormAudienceRuleKind value) => switch (value) {
  FormAudienceRuleKind.institution => 'Toda a instituição',
  FormAudienceRuleKind.group => 'Turma',
  FormAudienceRuleKind.activity => 'Atividade',
  FormAudienceRuleKind.profile => 'Perfil',
  _ => value.name,
};

String _newScheduleRequestId() {
  final values = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

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
      if (mounted) Navigator.of(context).pop(true);
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
