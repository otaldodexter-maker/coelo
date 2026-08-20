import 'dart:async';
import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../application/form_autosave_controller.dart';
import '../../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';

typedef FormEditorRequestIdFactory = String Function();

final class FormsEditorPage extends StatefulWidget {
  const FormsEditorPage({
    required this.api,
    required this.initialDefinition,
    this.initialApplication,
    this.autosaveDebounce = const Duration(milliseconds: 600),
    this.requestIdFactory,
    super.key,
  });

  final FormsApi? api;
  final FormDefinition initialDefinition;
  final FormApplication? initialApplication;
  final Duration autosaveDebounce;
  final FormEditorRequestIdFactory? requestIdFactory;

  @override
  State<FormsEditorPage> createState() => _FormsEditorPageState();
}

final class _FormsEditorPageState extends State<FormsEditorPage> {
  static const _steps = [
    'Identificação',
    'Estrutura',
    'Aplicações/Distribuições',
    'Regras de resposta',
    'Agendamentos',
    'Revisão',
  ];

  late FormDefinition _definition;
  FormApplication? _application;
  late FormAutosaveController<FormDefinition> _autosave;
  StreamSubscription<FormAutosaveState<FormDefinition>>? _subscription;
  var _step = 0;
  var _publishing = false;
  var _savingDistribution = false;
  String? _expandedItemId;
  String? _editingScheduleId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _definition = widget.initialDefinition;
    _application = widget.initialApplication;
    _editingScheduleId = _application?.schedules.firstOrNull?.id;
    _expandedItemId = _definition.sections.expand((section) => section.items).firstOrNull?.id;
    _autosave = FormAutosaveController<FormDefinition>(
      initialValue: _definition,
      debounce: widget.autosaveDebounce,
      save: _save,
    );
    _subscription = _autosave.changes.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state.savedValue case final saved?) _definition = saved;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_autosave.dispose());
    super.dispose();
  }

  Future<FormDefinition> _save(FormDefinition value) async {
    final api = widget.api;
    if (api == null) {
      throw const FormApiException(FormApiFailureKind.unavailable, 'Serviço indisponível.');
    }
    return api.saveDraft(
      FormCommand(
        requestId: _requestId(),
        expectedVersion: value.managementVersion,
        payload: value,
      ),
    );
  }

  void _update(FormDefinition value) {
    setState(() {
      _definition = value;
      _message = null;
    });
    _autosave.update(value);
  }

  FormDefinition _copy({
    String? title,
    String? description,
    FormKind? kind,
    FormIdentityMode? identityMode,
    FormResponseUnit? responseUnit,
    List<FormSection>? sections,
  }) => FormDefinition(
    id: _definition.id,
    institutionId: _definition.institutionId,
    kind: kind ?? _definition.kind,
    identityMode: identityMode ?? _definition.identityMode,
    responseUnit: responseUnit ?? _definition.responseUnit,
    title: title ?? _definition.title,
    description: description ?? _definition.description,
    sections: sections ?? _definition.sections,
    status: _definition.status,
    managementVersion: _definition.managementVersion,
  );

  Future<void> _publish() async {
    final api = widget.api;
    if (api == null) return;
    final validation = const FormDefinitionValidator().validate(_definition);
    if (_definition.kind == FormKind.quickPoll &&
        validation.any(
          (issue) =>
              issue.code == FormValidationCode.quickPollIntentRequired ||
              issue.code == FormValidationCode.quickPollIntentTooLong ||
              issue.code == FormValidationCode.quickPollRequiresOneQuestion,
        )) {
      setState(
        () => _message = 'A enquete rápida precisa de uma intenção curta e uma pergunta principal.',
      );
      return;
    }
    setState(() {
      _publishing = true;
      _message = null;
    });
    try {
      await _autosave.flush();
      if (_autosave.state.status == FormAutosaveStatus.failure) {
        throw const FormApiException(
          FormApiFailureKind.unavailable,
          'Salve o rascunho antes de publicar.',
        );
      }
      final published = await api.publish(
        FormCommand(
          requestId: _requestId(),
          expectedVersion: _definition.managementVersion,
          payload: FormIdPayload(_definition.id),
        ),
      );
      if (mounted) {
        setState(() {
          _definition = published;
          _message = 'Formulário publicado.';
        });
      }
    } on FormApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  String _requestId() => widget.requestIdFactory?.call() ?? _uuid();

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stepNavigation = SuperadminFormStepNavigation(
            steps: [
              for (var index = 0; index < _steps.length; index++)
                SuperadminFormStep(
                  label: _steps[index],
                  status: index < _step
                      ? SuperadminFormStepStatus.complete
                      : index == _step
                      ? SuperadminFormStepStatus.current
                      : SuperadminFormStepStatus.incomplete,
                ),
            ],
            currentIndex: _step,
            onStepSelected: (index) => setState(() => _step = index),
          );
          final content = Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showPreview = constraints.maxWidth >= 1100 && _step <= 1;
                    return Row(
                      children: [
                        Expanded(child: _content(context)),
                        if (showPreview) SizedBox(width: 360, child: _preview(context)),
                      ],
                    );
                  },
                ),
              ),
              _footer(context),
            ],
          );
          if (constraints.maxWidth >= CoeloBreakpoints.medium.minWidth) {
            return Row(
              children: [
                stepNavigation,
                Expanded(child: content),
              ],
            );
          }
          return Column(
            children: [
              stepNavigation,
              Expanded(child: content),
            ],
          );
        },
      ),
    ),
  );

  Widget _content(BuildContext context) => ListView(
    padding: const EdgeInsets.all(CoeloSpacing.space5),
    children: [
      Text(_steps[_step], style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: CoeloSpacing.space4),
      switch (_step) {
        0 => _identity(context),
        1 => _structure(context),
        2 => _distribution(context),
        3 => _responseRules(context),
        4 => _schedule(context),
        _ => _review(context),
      },
      if (_message != null) ...[
        const SizedBox(height: CoeloSpacing.space4),
        Semantics(liveRegion: true, child: Text(_message!)),
      ],
    ],
  );

  Widget _identity(BuildContext context) => Column(
    children: [
      TextFormField(
        key: const ValueKey('form-title'),
        initialValue: _definition.title,
        decoration: const InputDecoration(labelText: 'Título *'),
        onChanged: (value) => _update(_copy(title: value)),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      TextFormField(
        key: _definition.kind == FormKind.quickPoll
            ? const ValueKey('quick-poll-intent')
            : const ValueKey('form-description'),
        initialValue: _definition.description,
        decoration: InputDecoration(
          labelText: _definition.kind == FormKind.quickPoll ? 'Intenção curta *' : 'Descrição',
          helperText: _definition.kind == FormKind.quickPoll
              ? 'Explique o objetivo em até 280 caracteres.'
              : null,
        ),
        minLines: 3,
        maxLines: 5,
        maxLength: _definition.kind == FormKind.quickPoll
            ? FormDefinitionLimits.quickPollIntentMaxLength
            : null,
        onChanged: (value) => _update(_copy(description: value)),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<FormKind>(
        label: 'Tipo',
        value: _definition.kind,
        options: FormKind.values,
        optionLabel: (value) => value == FormKind.form ? 'Formulário' : 'Enquete rápida',
        onChanged: (value) => _update(_copy(kind: value)),
      ),
    ],
  );

  Widget _structure(BuildContext context) => Column(
    children: [
      for (final section in _definition.sections)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(section.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: CoeloSpacing.space3),
                for (final item in section.items)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(item.label),
                          subtitle: Text(_itemKind(item.kind)),
                          onTap: () => setState(() {
                            _expandedItemId = _expandedItemId == item.id ? null : item.id;
                          }),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Mover item para cima',
                                onPressed: item.position == 0
                                    ? null
                                    : () => _moveItem(section, item, -1),
                                icon: const Icon(Icons.arrow_upward_rounded),
                              ),
                              IconButton(
                                tooltip: 'Mover item para baixo',
                                onPressed: item.position == section.items.length - 1
                                    ? null
                                    : () => _moveItem(section, item, 1),
                                icon: const Icon(Icons.arrow_downward_rounded),
                              ),
                            ],
                          ),
                        ),
                        if (_expandedItemId == item.id)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              CoeloSpacing.space4,
                              0,
                              CoeloSpacing.space4,
                              CoeloSpacing.space4,
                            ),
                            child: TextFormField(
                              initialValue: item.helpText,
                              decoration: const InputDecoration(labelText: 'Texto de ajuda'),
                              onChanged: (helpText) => _updateItemHelpText(
                                sectionId: section.id,
                                itemId: item.id,
                                helpText: helpText.trim().isEmpty ? null : helpText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );

  void _moveItem(FormSection section, FormItem item, int delta) {
    final items = [...section.items];
    final from = items.indexWhere((candidate) => candidate.id == item.id);
    final to = from + delta;
    final moved = items.removeAt(from);
    items.insert(to, moved);
    final normalized = [
      for (var index = 0; index < items.length; index++) _copyItem(items[index], position: index),
    ];
    final sections = [
      for (final candidate in _definition.sections)
        if (candidate.id == section.id)
          FormSection(
            id: candidate.id,
            title: candidate.title,
            description: candidate.description,
            position: candidate.position,
            items: normalized,
          )
        else
          candidate,
    ];
    _update(_copy(sections: sections));
  }

  void _updateItemHelpText({
    required String sectionId,
    required String itemId,
    required String? helpText,
  }) {
    _update(
      _copy(
        sections: [
          for (final section in _definition.sections)
            if (section.id == sectionId)
              FormSection(
                id: section.id,
                title: section.title,
                description: section.description,
                position: section.position,
                items: [
                  for (final item in section.items)
                    item.id == itemId
                        ? _copyItem(item, helpText: helpText, replaceHelpText: true)
                        : item,
                ],
              )
            else
              section,
        ],
      ),
    );
  }

  FormItem _copyItem(
    FormItem item, {
    int? position,
    String? helpText,
    bool replaceHelpText = false,
  }) => FormItem(
    id: item.id,
    kind: item.kind,
    label: item.label,
    helpText: replaceHelpText ? helpText : item.helpText,
    position: position ?? item.position,
    isRequired: item.isRequired,
    config: item.config,
    options: item.options,
    conditions: item.conditions,
  );

  Widget _responseRules(BuildContext context) => Column(
    children: [
      CoeloAdminSingleSelectField<FormIdentityMode>(
        label: 'Identificação',
        value: _definition.identityMode,
        options: FormIdentityMode.values,
        optionLabel: (value) => value == FormIdentityMode.identified ? 'Identificada' : 'Anônima',
        enabled: _definition.status != FormStatus.published,
        onChanged: (value) => _update(_copy(identityMode: value)),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<FormResponseUnit>(
        label: 'Unidade de resposta',
        value: _definition.responseUnit,
        options: FormResponseUnit.values,
        optionLabel: (value) =>
            value == FormResponseUnit.person ? 'Pessoa' : 'Contexto criança/família',
        onChanged: (value) => _update(_copy(responseUnit: value)),
      ),
    ],
  );

  Widget _distribution(BuildContext context) {
    final application = _application;
    if (application == null) {
      return _placeholder('Crie uma aplicação no backend para configurar sua audiência.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: application.name,
          decoration: const InputDecoration(labelText: 'Nome da aplicação *'),
          onChanged: (name) => _application = _copyApplication(application, name: name),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Text('Audiência normalizada', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            for (final rule in application.audienceRules)
              Chip(
                label: Text(
                  '${_audienceKind(rule.kind)} · '
                  '${rule.mode == FormAudienceRuleMode.include ? 'incluir' : 'excluir'} · '
                  '${rule.targetId}',
                ),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _savingDistribution ? null : _saveApplication,
            child: Text(_savingDistribution ? 'Salvando…' : 'Salvar aplicação'),
          ),
        ),
      ],
    );
  }

  Widget _schedule(BuildContext context) {
    final application = _application;
    if (application == null) {
      return _placeholder('Salve uma aplicação antes de configurar o agendamento.');
    }
    final scheduleEntry = _editingSchedule(application);
    final schedule = scheduleEntry?.schedule ?? _defaultSchedule();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Agendamentos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        if (application.schedules.isNotEmpty)
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              for (var index = 0; index < application.schedules.length; index++)
                OutlinedButton(
                  onPressed: _savingDistribution
                      ? null
                      : () => setState(() => _editingScheduleId = application.schedules[index].id),
                  child: Text('Agendamento ${index + 1}'),
                ),
            ],
          ),
        if (application.schedules.isNotEmpty) const SizedBox(height: CoeloSpacing.space3),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _savingDistribution ? null : _addSchedule,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar agendamento'),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Text(
          scheduleEntry?.managementVersion == 0 || scheduleEntry == null
              ? 'Novo agendamento'
              : 'Editar agendamento',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        TextFormField(
          key: ValueKey('schedule-time-zone-${scheduleEntry?.id ?? 'new'}'),
          initialValue: schedule.timeZone,
          decoration: const InputDecoration(labelText: 'Fuso horário IANA'),
          onChanged: (timeZone) => _updateSchedule(
            FormSchedule(
              startsAtLocal: schedule.startsAtLocal,
              timeZone: timeZone,
              recurrence: schedule.recurrence,
              end: schedule.end,
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<FormRecurrenceKind>(
          label: 'Recorrência',
          value: schedule.recurrence.kind,
          options: FormRecurrenceKind.values,
          optionLabel: (kind) => switch (kind) {
            FormRecurrenceKind.once => 'Uma vez',
            FormRecurrenceKind.daily => 'Diária',
            FormRecurrenceKind.weekly => 'Semanal',
            FormRecurrenceKind.monthly => 'Mensal',
          },
          onChanged: (kind) {
            final recurrence = switch (kind) {
              FormRecurrenceKind.once => const FormRecurrence.once(),
              FormRecurrenceKind.daily => const FormRecurrence.daily(interval: 1),
              FormRecurrenceKind.weekly => FormRecurrence.weekly(
                interval: 1,
                weekdays: {schedule.startsAtLocal.weekday},
              ),
              FormRecurrenceKind.monthly => FormRecurrence.monthly(
                interval: 1,
                day: schedule.startsAtLocal.day,
              ),
            };
            setState(
              () => _updateSchedule(
                FormSchedule(
                  startsAtLocal: schedule.startsAtLocal,
                  timeZone: schedule.timeZone,
                  recurrence: recurrence,
                  end: schedule.end,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _savingDistribution ? null : _saveSchedule,
            child: Text(_savingDistribution ? 'Salvando…' : 'Salvar agendamento'),
          ),
        ),
        if (scheduleEntry != null) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _savingDistribution ? null : () => _confirmRemoveSchedule(scheduleEntry),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remover agendamento'),
            ),
          ),
        ],
      ],
    );
  }

  FormSchedule _defaultSchedule() => FormSchedule(
    startsAtLocal: DateTime.now().add(const Duration(days: 1)),
    timeZone: 'America/Sao_Paulo',
    recurrence: const FormRecurrence.once(),
    end: const FormScheduleEnd.never(),
  );

  FormApplication _copyApplication(
    FormApplication value, {
    String? name,
    List<FormApplicationSchedule>? schedules,
  }) => FormApplication(
    id: value.id,
    formId: value.formId,
    institutionId: value.institutionId,
    name: name ?? value.name,
    status: value.status,
    opensForDays: value.opensForDays,
    audienceRules: value.audienceRules,
    schedules: schedules ?? value.schedules,
    managementVersion: value.managementVersion,
  );

  FormApplicationSchedule? _editingSchedule(FormApplication application) {
    final selectedId = _editingScheduleId;
    if (selectedId != null) {
      return application.schedules.where((schedule) => schedule.id == selectedId).firstOrNull;
    }
    return application.schedules.firstOrNull;
  }

  void _addSchedule() {
    final application = _application;
    if (application == null) return;
    final schedule = FormApplicationSchedule(
      id: _uuid(),
      schedule: _defaultSchedule(),
      managementVersion: 0,
    );
    setState(() {
      _application = _copyApplication(application, schedules: [...application.schedules, schedule]);
      _editingScheduleId = schedule.id;
    });
  }

  void _updateSchedule(FormSchedule schedule) {
    final application = _application;
    if (application == null) return;
    final current = _editingSchedule(application);
    final updated = current == null
        ? FormApplicationSchedule(id: _uuid(), schedule: schedule, managementVersion: 0)
        : FormApplicationSchedule(
            id: current.id,
            status: current.status,
            schedule: schedule,
            reminders: current.reminders,
            managementVersion: current.managementVersion,
          );
    _application = _copyApplication(
      application,
      schedules: [
        for (final entry in application.schedules)
          if (entry.id == updated.id) updated else entry,
        if (current == null) updated,
      ],
    );
    _editingScheduleId = updated.id;
  }

  Future<void> _saveApplication() async {
    final application = _application;
    final api = widget.api;
    if (application == null || api == null) return;
    await _runDistributionSave(() async {
      _application = await api.saveApplication(
        FormCommand(
          requestId: _requestId(),
          expectedVersion: application.managementVersion,
          payload: FormSaveApplicationPayload(application),
        ),
      );
    });
  }

  Future<void> _saveSchedule() async {
    final application = _application;
    final api = widget.api;
    if (application == null || api == null) return;
    final scheduleEntry = _editingSchedule(application);
    final scheduleId = scheduleEntry?.id ?? _uuid();
    await _runDistributionSave(() async {
      _application = await api.saveSchedule(
        FormCommand(
          requestId: _requestId(),
          expectedVersion: scheduleEntry?.managementVersion ?? 0,
          payload: FormSaveSchedulePayload(
            applicationId: application.id,
            scheduleId: scheduleId,
            schedule: scheduleEntry?.schedule ?? _defaultSchedule(),
            reminders: scheduleEntry?.reminders ?? const [],
          ),
        ),
      );
      _editingScheduleId = scheduleId;
    });
  }

  Future<void> _confirmRemoveSchedule(FormApplicationSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('form-schedule-remove-dialog'),
        title: 'Remover agendamento?',
        body: const Text('As ocorrências futuras deste agendamento serão canceladas.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: const Text('Remover'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final application = _application;
    if (application == null) return;
    if (schedule.managementVersion == 0) {
      setState(() {
        final schedules = application.schedules.where((entry) => entry.id != schedule.id).toList();
        _application = _copyApplication(application, schedules: schedules);
        _editingScheduleId = schedules.firstOrNull?.id;
      });
      return;
    }
    final api = widget.api;
    if (api == null) return;
    await _runDistributionSave(() async {
      _application = await api.removeSchedule(
        FormCommand(
          requestId: _requestId(),
          expectedVersion: schedule.managementVersion,
          payload: FormRemoveSchedulePayload(scheduleId: schedule.id),
        ),
      );
      _editingScheduleId = _application?.schedules.firstOrNull?.id;
    });
  }

  Future<void> _runDistributionSave(Future<void> Function() save) async {
    setState(() => _savingDistribution = true);
    try {
      await save();
    } on FormApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _savingDistribution = false);
    }
  }

  String _audienceKind(FormAudienceRuleKind kind) => switch (kind) {
    FormAudienceRuleKind.institution => 'Instituição',
    FormAudienceRuleKind.unit => 'Unidade',
    FormAudienceRuleKind.group => 'Grupo',
    FormAudienceRuleKind.activity => 'Atividade',
    FormAudienceRuleKind.guardian => 'Responsável',
    FormAudienceRuleKind.teacher => 'Professor',
    FormAudienceRuleKind.employee => 'Funcionário',
    FormAudienceRuleKind.profile => 'Perfil',
    FormAudienceRuleKind.person => 'Pessoa',
  };

  Widget _placeholder(String message) => CoeloStatePanel(
    title: 'Configuração conectada ao backend',
    message: message,
    icon: Icons.tune_rounded,
  );

  Widget _review(BuildContext context) {
    final issues = const FormDefinitionValidator().validate(_definition);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_definition.title, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${_definition.sections.length} seção(ões) · '
          '${_definition.sections.expand((section) => section.items).length} item(ns)',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (issues.isEmpty)
          const CoeloStatePanel(
            title: 'Pronto para publicar',
            message: 'A definição local respeita os limites e as condições do domínio.',
            icon: Icons.check_circle_outline_rounded,
          )
        else
          CoeloStatePanel(
            title: 'Revise o formulário',
            message: '${issues.length} pendência(s) impedem a publicação.',
            icon: Icons.warning_amber_rounded,
          ),
      ],
    );
  }

  Widget _preview(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        Text('Prévia', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space4),
        Text(_definition.title, style: Theme.of(context).textTheme.headlineSmall),
        if (_definition.description case final description?) Text(description),
        const SizedBox(height: CoeloSpacing.space4),
        for (final section in _definition.sections) ...[
          Text(section.title, style: Theme.of(context).textTheme.titleMedium),
          for (final item in section.items)
            ListTile(contentPadding: EdgeInsets.zero, title: Text(item.label)),
        ],
      ],
    ),
  );

  Widget _footer(BuildContext context) => Material(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space2,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(switch (_autosave.state.status) {
              FormAutosaveStatus.idle => 'Alterações locais',
              FormAutosaveStatus.saving => 'Salvando…',
              FormAutosaveStatus.saved => 'Salvo',
              FormAutosaveStatus.failure => 'Falha ao salvar',
            }),
          ),
          Wrap(
            spacing: CoeloSpacing.space2,
            children: [
              if (_step > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Voltar'),
                ),
              if (_step < _steps.length - 1)
                FilledButton(
                  onPressed: () => setState(() => _step++),
                  child: const Text('Continuar'),
                )
              else
                FilledButton.icon(
                  onPressed: _publishing ? null : _publish,
                  icon: const Icon(Icons.publish_rounded),
                  label: Text(_publishing ? 'Publicando…' : 'Publicar'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  String _itemKind(FormItemKind kind) => switch (kind) {
    FormItemKind.shortText => 'Texto curto',
    FormItemKind.integer => 'Inteiro',
    FormItemKind.decimal => 'Decimal',
    FormItemKind.money => 'Dinheiro',
    FormItemKind.date => 'Data',
    FormItemKind.yesNo => 'Sim ou não',
    FormItemKind.singleChoice => 'Escolha única',
    FormItemKind.multipleChoice => 'Múltipla escolha',
    FormItemKind.scale => 'Escala',
    FormItemKind.photo => 'Foto',
    FormItemKind.gallery => 'Galeria',
    FormItemKind.information => 'Informação',
  };
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

@Preview(name: 'Formulários · construtor · desktop', size: Size(1440, 900))
Widget formsEditorDesktopPreview() => MaterialApp(
  theme: ThemeData(useMaterial3: true),
  home: FormsEditorPage(api: null, initialDefinition: _previewDefinition()),
);

@Preview(name: 'Formulários · construtor · compacto dark', size: Size(375, 800))
Widget formsEditorCompactDarkPreview() => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: FormsEditorPage(api: null, initialDefinition: _previewDefinition()),
);

FormDefinition _previewDefinition() => FormDefinition(
  id: 'preview-form',
  institutionId: 'preview-institution',
  kind: FormKind.form,
  identityMode: FormIdentityMode.identified,
  responseUnit: FormResponseUnit.person,
  title: 'Pesquisa com as famílias',
  description: 'Conte como foi a experiência desta semana.',
  sections: [
    FormSection(
      id: 'preview-section',
      title: 'Sua experiência',
      position: 0,
      items: [
        FormItem(
          id: 'preview-item',
          kind: FormItemKind.shortText,
          label: 'O que podemos melhorar?',
          position: 0,
          isRequired: true,
        ),
      ],
    ),
  ],
);
