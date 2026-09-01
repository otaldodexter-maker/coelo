import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../domain/agenda_models.dart';
import '../domain/agenda_repository.dart';
import 'agenda_reservation_conflict_dialog.dart';

final class AgendaEventFormPage extends StatefulWidget {
  const AgendaEventFormPage({
    required this.store,
    required this.onCancel,
    required this.onSaved,
    this.eventId,
    this.canPublish = true,
    this.actionsAvailable = true,
    super.key,
  });

  final AgendaRepository store;
  final String? eventId;
  final VoidCallback onCancel;
  final ValueChanged<String> onSaved;
  final bool canPublish;
  final bool actionsAvailable;

  @override
  State<AgendaEventFormPage> createState() => _AgendaEventFormPageState();
}

final class _AgendaEventFormPageState extends State<AgendaEventFormPage> {
  static const _contexts = ['Instituição', 'Unidade', 'Turma', 'Atividade', 'Pessoa'];
  static const _audiences = ['Responsáveis', 'Equipe', 'Perfis específicos', 'Pessoas'];
  static const _timeZones = ['America/Sao_Paulo', 'America/Manaus', 'UTC'];
  static const _recurrences = ['Não se repete', 'Diária', 'Semanal', 'Mensal'];
  static const _recurrenceEnds = ['Em uma data', 'Após uma quantidade'];
  static const _reminderOptions = [
    'Na publicação',
    '24 horas antes',
    '1 hora antes',
    'Personalizado',
  ];

  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _details;
  late final TextEditingController _occurrenceCount;
  late AgendaItemType _type;
  late AgendaPriority _priority;
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late String _timeZoneId;
  late String _context;
  late Set<String> _audience;
  late String _recurrence;
  String _recurrenceEnd = 'Em uma data';
  late DateTime _recurrenceUntil;
  late AgendaResponseMode _responseMode;
  late GuardianResponsePolicy _guardianPolicy;
  AgendaOccurrenceEditScope _occurrenceEditScope = AgendaOccurrenceEditScope.series;
  late Set<String> _reminders;
  late final List<_AgendaQuestionDraft> _questions;
  var _nextQuestionId = 1;
  String? _feedback;
  int _step = 0;

  AgendaItem? get _existing =>
      widget.eventId == null ? null : widget.store.itemById(widget.eventId!);

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _existing?.title ?? 'Novo evento');
    _location = TextEditingController(text: _existing?.location ?? '');
    _details = TextEditingController(text: _existing?.description ?? '');
    _occurrenceCount = TextEditingController(
      text: '${_existing?.recurrence?.occurrenceCount ?? 8}',
    );
    _type = _existing?.type ?? AgendaItemType.event;
    _priority = _existing?.priority ?? AgendaPriority.normal;
    _start = _existing?.startsAt ?? widget.store.referenceDate.add(const Duration(days: 2));
    _end = _existing?.endsAt ?? _start.add(const Duration(hours: 1));
    _allDay = _existing?.allDay ?? false;
    _timeZoneId = _existing?.timeZoneId ?? 'America/Sao_Paulo';
    _context = _contextFor(_existing?.audience);
    _audience = _existing?.audienceLabels.isNotEmpty == true
        ? {..._existing!.audienceLabels}
        : {'Responsáveis'};
    _recurrence = _recurrenceLabel(_existing?.recurrence);
    if (_existing?.recurrence?.occurrenceCount != null) {
      _recurrenceEnd = 'Após uma quantidade';
    }
    _recurrenceUntil = _existing?.recurrence?.until ?? _start.add(const Duration(days: 30));
    _responseMode = _existing?.responseMode ?? AgendaResponseMode.none;
    _guardianPolicy = _existing?.guardianResponsePolicy ?? GuardianResponsePolicy.oneIsEnough;
    _reminders = _existing?.reminders.isNotEmpty == true
        ? {..._existing!.reminders}
        : {'Na publicação', '24 horas antes'};
    _questions = [
      for (final question in _existing?.questions ?? const <AgendaQuestion>[])
        _AgendaQuestionDraft.fromQuestion(question),
    ];
    for (final question in _questions) {
      final suffix = int.tryParse(question.id.split('-').last) ?? 0;
      if (suffix >= _nextQuestionId) _nextQuestionId = suffix + 1;
    }
    if (widget.eventId != null && _existing == null) unawaited(_loadExisting());
  }

  Future<void> _loadExisting() async {
    await widget.store.loadItem(widget.eventId!);
    if (!mounted) return;
    final item = _existing;
    if (item == null) {
      setState(() => _feedback = widget.store.errorMessage ?? 'O evento não foi encontrado.');
      return;
    }
    _title.text = item.title;
    _location.text = item.location;
    _details.text = item.description;
    _occurrenceCount.text = '${item.recurrence?.occurrenceCount ?? 8}';
    for (final question in _questions) {
      question.dispose();
    }
    _questions
      ..clear()
      ..addAll(item.questions.map(_AgendaQuestionDraft.fromQuestion));
    setState(() {
      _type = item.type;
      _priority = item.priority;
      _start = item.startsAt;
      _end = item.endsAt;
      _allDay = item.allDay;
      _timeZoneId = item.timeZoneId;
      _context = _contextFor(item.audience);
      _audience = item.audienceLabels.isEmpty ? {'Responsáveis'} : {...item.audienceLabels};
      _recurrence = _recurrenceLabel(item.recurrence);
      _recurrenceEnd = item.recurrence?.occurrenceCount == null
          ? 'Em uma data'
          : 'Após uma quantidade';
      _recurrenceUntil = item.recurrence?.until ?? item.startsAt.add(const Duration(days: 30));
      _responseMode = item.responseMode;
      _guardianPolicy = item.guardianResponsePolicy;
      _reminders = item.reminders.isEmpty
          ? {'Na publicação', '24 horas antes'}
          : {...item.reminders};
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _details.dispose();
    _occurrenceCount.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AgendaItemStatus requestedStatus) async {
    if (!widget.actionsAvailable) return;
    if (_title.text.trim().isEmpty || _audience.isEmpty) {
      setState(() {
        _feedback = _title.text.trim().isEmpty
            ? 'Informe o título do evento antes de continuar.'
            : 'Selecione pelo menos uma audiência.';
      });
      return;
    }
    if (_recurrence != 'Não se repete' &&
        _recurrenceEnd == 'Após uma quantidade' &&
        ((int.tryParse(_occurrenceCount.text.trim()) ?? 0) <= 0)) {
      setState(() {
        _feedback = 'Informe uma quantidade de ocorrências maior que zero.';
      });
      return;
    }
    if (_questions.any((question) => question.title.text.trim().isEmpty)) {
      setState(() {
        _feedback = 'Preencha o título de todas as perguntas ou remova as perguntas vazias.';
      });
      return;
    }
    final existing = _existing;
    if (existing?.recurrence != null &&
        _occurrenceEditScope != AgendaOccurrenceEditScope.series &&
        !widget.store.supportsOccurrenceScopedEdits) {
      setState(() {
        _feedback =
            'A edição de uma ocorrência isolada ainda não está disponível. Selecione toda a série para salvar.';
      });
      return;
    }
    final selectedContext = _selectedContext();
    if (existing == null && selectedContext == null) {
      setState(() {
        _feedback = 'Nenhum contexto institucional autorizado está disponível para este item.';
      });
      return;
    }
    final institutionId = existing?.audience.institutionId ?? selectedContext!.institutionId;
    final id = widget.eventId ?? 'local-agenda-${widget.store.items.length + 1}';
    final start = _allDay ? DateTime(_start.year, _start.month, _start.day) : _start;
    var end = _allDay ? DateTime(_end.year, _end.month, _end.day) : _end;
    if (!end.isAfter(start)) {
      end = start.add(_allDay ? const Duration(days: 1) : const Duration(hours: 1));
    }
    final status = requestedStatus == AgendaItemStatus.published && !widget.canPublish
        ? AgendaItemStatus.draft
        : requestedStatus;
    final item = AgendaItem(
      id: id,
      title: _title.text.trim(),
      type: _type,
      audience: _resolvedAudience(institutionId),
      priority: _priority,
      status: status,
      origin: existing?.origin ?? AgendaItemOrigin.institution,
      startsAt: start,
      endsAt: end,
      location: _location.text.trim(),
      description: _details.text.trim(),
      recurrence: _buildRecurrence(),
      allDay: _allDay,
      requiresRsvp: _responseMode == AgendaResponseMode.rsvp,
      authorizationReference: existing?.authorizationReference,
      timeZoneId: _timeZoneId,
      responseMode: _responseMode,
      guardianResponsePolicy: _guardianPolicy,
      audienceLabels: Set.unmodifiable(_audience),
      reminders: Set.unmodifiable(_reminders),
      questions: [for (final question in _questions) question.toQuestion()],
      history: existing?.history ?? const [],
    );
    final actorContextId = selectedContext?.id ?? institutionId;
    var result = await widget.store.saveItem(item, actorContextId: actorContextId);
    if (!mounted) return;
    if (result == AgendaMutationResult.reservationConflict &&
        widget.store
            .resolveCapability(institutionId, AgendaCapability.overrideReservationConflict)
            .isAllowed) {
      final reason = await showAgendaReservationConflictOverrideDialog(context);
      if (!mounted || reason == null) return;
      result = await widget.store.saveItem(
        item,
        actorContextId: actorContextId,
        actorName: 'Owner Coelo',
        overrideConflict: true,
        reason: reason,
      );
    }
    if (result == AgendaMutationResult.success) {
      final savedItemId = widget.store.lastSavedItemId ?? id;
      if (existing?.recurrence != null) {
        await widget.store.recordOccurrenceEdit(
          itemId: savedItemId,
          occurrenceStartsAt: existing!.startsAt,
          scope: _occurrenceEditScope,
          actorName: 'Owner Coelo',
        );
      }
      if (requestedStatus == AgendaItemStatus.published && !widget.canPublish) {
        await widget.store.requestPublication(
          savedItemId,
          requestedBy: 'Usuário local sem permissão de publicação',
        );
      }
      widget.onSaved(savedItemId);
      return;
    }
    setState(() {
      _feedback = switch (result) {
        AgendaMutationResult.reservationConflict =>
          'Existe uma reserva conflitante neste local e horário. Ajuste o período ou solicite a substituição autorizada.',
        AgendaMutationResult.notAuthorized => 'Seu perfil não permite substituir este conflito.',
        AgendaMutationResult.reasonRequired => 'Informe o motivo para substituir o conflito.',
        AgendaMutationResult.invalidLifecycle => 'Este evento não pode ser alterado neste estado.',
        AgendaMutationResult.notFound => 'O evento não está mais disponível.',
        AgendaMutationResult.conflict =>
          'Este evento foi alterado em outra sessão. Recarregue antes de salvar novamente.',
        AgendaMutationResult.unavailable =>
          'Não foi possível salvar o evento agora. Nenhuma alteração foi confirmada.',
        AgendaMutationResult.success => null,
      };
    });
  }

  AgendaContext? _selectedContext() {
    final level = switch (_context) {
      'Instituição' => AgendaContextLevel.institution,
      'Unidade' => AgendaContextLevel.unit,
      'Turma' => AgendaContextLevel.group,
      'Atividade' => AgendaContextLevel.activity,
      _ => null,
    };
    if (level == null) return null;
    for (final context in widget.store.contexts) {
      if (context.level == level) return context;
    }
    return null;
  }

  AgendaAudience _resolvedAudience(String institutionId) {
    final context = _selectedContext();
    return switch (context?.level) {
      AgendaContextLevel.unit => AgendaAudience(
        institutionId: institutionId,
        unitIds: {context!.id},
      ),
      AgendaContextLevel.group => AgendaAudience(
        institutionId: institutionId,
        groupIds: {context!.id},
      ),
      AgendaContextLevel.activity => AgendaAudience(
        institutionId: institutionId,
        activityIds: {context!.id},
      ),
      AgendaContextLevel.institution || null => AgendaAudience(institutionId: institutionId),
    };
  }

  AgendaRecurrence? _buildRecurrence() {
    if (_recurrence == 'Não se repete') return null;
    final count = int.tryParse(_occurrenceCount.text.trim());
    final byCount = _recurrenceEnd == 'Após uma quantidade';
    return switch (_recurrence) {
      'Diária' => AgendaRecurrence.daily(
        until: byCount ? null : _recurrenceUntil,
        occurrenceCount: byCount ? (count ?? 1) : null,
      ),
      'Mensal' => AgendaRecurrence.monthly(
        until: byCount ? null : _recurrenceUntil,
        occurrenceCount: byCount ? (count ?? 1) : null,
      ),
      _ => AgendaRecurrence.weekly(
        until: byCount ? null : _recurrenceUntil,
        occurrenceCount: byCount ? (count ?? 1) : null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SuperadminFormFrame(
      viewportWidth: constraints.maxWidth,
      navigation: SuperadminFormStepNavigation(
        steps: [
          for (var index = 0; index < 4; index++)
            SuperadminFormStep(
              key: Key('agenda-form-step-$index'),
              label: const ['Dados básicos', 'Período', 'Respostas', 'Revisão'][index],
              status: index == _step
                  ? SuperadminFormStepStatus.current
                  : index < _step
                  ? SuperadminFormStepStatus.complete
                  : SuperadminFormStepStatus.incomplete,
              enabled: index <= _step,
            ),
        ],
        currentIndex: _step,
        onStepSelected: (value) {
          if (value <= _step) setState(() => _step = value);
        },
      ),
      scrollKey: const Key('agenda-event-form-scroll'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.eventId == null ? 'Criar evento' : 'Editar evento',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (_feedback != null) ...[
            const SizedBox(height: CoeloSpacing.space2),
            Semantics(
              liveRegion: true,
              child: Text(
                _feedback!,
                key: const Key('agenda-event-form-feedback'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: CoeloSpacing.space4),
          _content(),
        ],
      ),
      footer: SuperadminFormActionFooter(
        tertiaryAction: TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
        continuationActions: [
          if (_step > 0)
            OutlinedButton(
              key: const Key('agenda-wizard-previous'),
              onPressed: () => setState(() => _step--),
              child: const Text('Anterior'),
            ),
          if (_step < 3)
            OutlinedButton(
              key: const Key('agenda-wizard-continue'),
              onPressed: () => setState(() => _step++),
              child: const Text('Continuar'),
            )
          else ...[
            OutlinedButton(
              key: const Key('agenda-wizard-save-draft'),
              onPressed: widget.actionsAvailable ? () => _save(AgendaItemStatus.draft) : null,
              child: const Text('Salvar rascunho'),
            ),
            FilledButton(
              key: const Key('agenda-wizard-publish'),
              onPressed: widget.actionsAvailable ? () => _save(AgendaItemStatus.published) : null,
              child: Text(widget.canPublish ? 'Publicar' : 'Solicitar publicação'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _content() => _Group(
    title: const ['1. Dados básicos', '2. Período', '3. Respostas', '4. Revisão'][_step],
    children: switch (_step) {
      0 => _basicFields(),
      1 => _periodFields(),
      2 => _responseFields(),
      _ => _reviewFields(),
    },
  );

  List<Widget> _basicFields() => [
    CoeloFormTextField(controller: _title, labelText: 'Título', prefixIcon: Icons.title_rounded),
    CoeloAdminSingleSelectField<AgendaItemType>(
      key: const Key('agenda-event-type'),
      label: 'Tipo',
      value: _type,
      options: AgendaItemType.values,
      optionLabel: (value) => value.label,
      onChanged: (value) => setState(() => _type = value),
    ),
    CoeloAdminSingleSelectField<String>(
      key: const Key('agenda-event-context'),
      label: 'Contexto principal',
      value: _context,
      options: _contexts,
      optionLabel: (value) => value,
      onChanged: (value) => setState(() => _context = value),
      prefixIcon: Icons.account_tree_outlined,
    ),
    CoeloAdminMultiSelectField<String>(
      key: const Key('agenda-event-audience'),
      label: 'Audiência',
      options: _audiences,
      selectedValues: _audience,
      optionLabel: (value) => value,
      onChanged: (value) => setState(() => _audience = value),
      prefixIcon: Icons.groups_outlined,
    ),
    CoeloFormTextField(
      controller: _details,
      labelText: 'Descrição (opcional)',
      prefixIcon: Icons.notes_rounded,
      maxLines: 4,
    ),
    _questionBuilder(),
  ];

  List<Widget> _periodFields() => [
    CoeloAdminToggleField(
      key: const Key('agenda-event-all-day'),
      value: _allDay,
      onChanged: (value) => setState(() => _allDay = value),
      label: 'Dia inteiro',
      description: 'Eventos de dia inteiro não exibem horário.',
    ),
    if (_allDay)
      CoeloDateRangeField(
        key: const Key('agenda-event-all-day-range'),
        value: DateTimeRange(start: _start, end: _end),
        firstDate: DateTime(2025),
        lastDate: DateTime(2030, 12, 31),
        labelText: 'Período',
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _start = value.start;
              _end = value.end;
            });
          }
        },
      )
    else ...[
      CoeloDateTimeField(
        key: const Key('agenda-event-start'),
        value: _start,
        firstDate: DateTime(2025),
        lastDate: DateTime(2030, 12, 31),
        labelText: 'Início',
        onChanged: (value) {
          if (value != null) setState(() => _start = value);
        },
      ),
      CoeloDateTimeField(
        key: const Key('agenda-event-end'),
        value: _end,
        firstDate: DateTime(2025),
        lastDate: DateTime(2030, 12, 31),
        labelText: 'Fim',
        onChanged: (value) {
          if (value != null) setState(() => _end = value);
        },
      ),
    ],
    CoeloAdminSingleSelectField<String>(
      key: const Key('agenda-event-timezone'),
      label: 'Fuso horário IANA',
      value: _timeZoneId,
      options: _timeZones,
      optionLabel: (value) => value,
      onChanged: (value) => setState(() => _timeZoneId = value),
      prefixIcon: Icons.public_outlined,
    ),
    CoeloFormTextField(
      controller: _location,
      labelText: 'Local (opcional)',
      prefixIcon: Icons.place_outlined,
      onChanged: (_) => setState(() {}),
    ),
    _LocationPreview(location: _location.text.trim()),
    CoeloAdminSingleSelectField<String>(
      key: const Key('agenda-event-recurrence'),
      label: 'Recorrência',
      value: _recurrence,
      options: _recurrences,
      optionLabel: (value) => value,
      onChanged: (value) => setState(() => _recurrence = value),
      prefixIcon: Icons.repeat_rounded,
    ),
    if (_recurrence != 'Não se repete') ...[
      CoeloAdminSingleSelectField<String>(
        key: const Key('agenda-event-recurrence-end'),
        label: 'Término da recorrência',
        value: _recurrenceEnd,
        options: _recurrenceEnds,
        optionLabel: (value) => value,
        onChanged: (value) => setState(() => _recurrenceEnd = value),
      ),
      if (_recurrenceEnd == 'Em uma data')
        CoeloDateRangeField(
          value: DateTimeRange(start: _recurrenceUntil, end: _recurrenceUntil),
          firstDate: _start,
          lastDate: DateTime(2035, 12, 31),
          selectionMode: CoeloDateSelectionMode.single,
          labelText: 'Repetir até',
          onChanged: (value) {
            if (value != null) setState(() => _recurrenceUntil = value.start);
          },
        )
      else
        CoeloFormTextField(
          key: const Key('agenda-event-occurrence-count'),
          controller: _occurrenceCount,
          labelText: 'Quantidade de ocorrências',
          prefixIcon: Icons.numbers_rounded,
          keyboardType: TextInputType.number,
        ),
      if (_existing?.recurrence != null)
        CoeloAdminSingleSelectField<AgendaOccurrenceEditScope>(
          key: const Key('agenda-event-occurrence-edit-scope'),
          label: 'Aplicar alteração em',
          value: _occurrenceEditScope,
          options: AgendaOccurrenceEditScope.values,
          optionLabel: _occurrenceEditScopeLabel,
          onChanged: (value) => setState(() => _occurrenceEditScope = value),
          prefixIcon: Icons.edit_calendar_outlined,
        )
      else
        const _Fact(
          label: 'Edição da série',
          value: 'Editar uma ocorrência, esta e próximas ou toda a série',
        ),
    ],
  ];

  List<Widget> _responseFields() => [
    CoeloAdminSingleSelectField<AgendaPriority>(
      label: 'Prioridade',
      value: _priority,
      options: AgendaPriority.values,
      optionLabel: (value) => _label(value.name),
      onChanged: (value) => setState(() => _priority = value),
    ),
    CoeloAdminSingleSelectField<AgendaResponseMode>(
      key: const Key('agenda-event-response-mode'),
      label: 'Modo de resposta',
      value: _responseMode,
      options: AgendaResponseMode.values,
      optionLabel: _responseLabel,
      onChanged: (value) => setState(() => _responseMode = value),
      prefixIcon: Icons.how_to_reg_outlined,
    ),
    if (_responseMode != AgendaResponseMode.none)
      CoeloAdminSingleSelectField<GuardianResponsePolicy>(
        key: const Key('agenda-event-guardian-policy'),
        label: 'Política de responsáveis',
        value: _guardianPolicy,
        options: GuardianResponsePolicy.values,
        optionLabel: (value) => value == GuardianResponsePolicy.oneIsEnough
            ? 'Um responsável basta'
            : 'Todos devem responder',
        onChanged: (value) => setState(() => _guardianPolicy = value),
        prefixIcon: Icons.family_restroom_outlined,
      ),
    CoeloAdminMultiSelectField<String>(
      key: const Key('agenda-event-reminders'),
      label: 'Lembretes',
      options: _reminderOptions,
      selectedValues: _reminders,
      optionLabel: (value) => value,
      onChanged: (value) => setState(() => _reminders = value),
      prefixIcon: Icons.notifications_active_outlined,
    ),
    const _Fact(
      label: 'Entrega',
      value: 'Defina apenas quando lembrar; os canais serão configurados pela plataforma.',
    ),
  ];

  List<Widget> _reviewFields() => [
    _Fact(label: 'Evento', value: '${_title.text} · ${_type.label}'),
    _Fact(label: 'Contexto e audiência', value: '$_context · ${_audience.join(', ')}'),
    _Fact(
      label: 'Período',
      value: _allDay
          ? '${_shortDate(_start)} — ${_shortDate(_end)} · dia inteiro'
          : '${_date(_start)} — ${_date(_end)} · $_timeZoneId',
    ),
    _Fact(label: 'Recorrência', value: _recurrence),
    _Fact(label: 'Resposta', value: _responseLabel(_responseMode)),
    _Fact(
      label: 'Perguntas',
      value: _questions.isEmpty
          ? 'Nenhuma pergunta adicional'
          : '${_questions.length} adicionada(s)',
    ),
    _Fact(label: 'Lembretes', value: _reminders.join(', ')),
    if (!widget.canPublish)
      const _Fact(
        label: 'Publicação',
        value: 'Sem capability de publicação: será salvo como rascunho e enviado para aprovação.',
      ),
    if (!widget.actionsAvailable)
      const CoeloStatePanel(
        key: Key('agenda-event-actions-unavailable'),
        icon: Icons.cloud_off_outlined,
        title: 'Integração indisponível',
        message:
            'A composição está disponível, mas salvar e publicar permanecem bloqueados nesta rota.',
      ),
  ];

  Widget _questionBuilder() => _AgendaQuestionsEditor(
    questions: _questions,
    onAdd: () => setState(() {
      _questions.add(_AgendaQuestionDraft(id: 'question-${_nextQuestionId++}'));
    }),
    onRemove: (index) => setState(() {
      _questions.removeAt(index).dispose();
    }),
    onChanged: () => setState(() {}),
  );
}

final class _AgendaQuestionDraft {
  _AgendaQuestionDraft({required this.id, String title = ''})
    : title = TextEditingController(text: title);

  factory _AgendaQuestionDraft.fromQuestion(AgendaQuestion question) =>
      _AgendaQuestionDraft(id: question.id, title: question.title)..type = question.type;

  final String id;
  final TextEditingController title;
  AgendaQuestionType type = AgendaQuestionType.shortText;

  AgendaQuestion toQuestion() => AgendaQuestion(id: id, title: title.text.trim(), type: type);

  void dispose() => title.dispose();
}

final class _AgendaQuestionsEditor extends StatelessWidget {
  const _AgendaQuestionsEditor({
    required this.questions,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<_AgendaQuestionDraft> questions;
  final VoidCallback onAdd, onChanged;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Perguntas do evento', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            'Inclua confirmações ou informações necessárias para participar. Não solicite dados sensíveis.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (var index = 0; index < questions.length; index++) ...[
            const SizedBox(height: CoeloSpacing.space4),
            CoeloFormTextField(
              key: Key('agenda-event-question-$index'),
              controller: questions[index].title,
              labelText: 'Pergunta ${index + 1}',
              prefixIcon: Icons.help_outline_rounded,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Row(
              children: [
                Expanded(
                  child: CoeloAdminSingleSelectField<AgendaQuestionType>(
                    key: Key('agenda-event-question-type-$index'),
                    label: 'Tipo de resposta',
                    value: questions[index].type,
                    options: AgendaQuestionType.values,
                    optionLabel: _questionTypeLabel,
                    onChanged: (value) {
                      questions[index].type = value;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                IconButton(
                  tooltip: 'Remover pergunta ${index + 1}',
                  onPressed: () => onRemove(index),
                  color: Theme.of(context).colorScheme.error,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
          const SizedBox(height: CoeloSpacing.space3),
          OutlinedButton.icon(
            key: const Key('agenda-event-add-question'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar pergunta'),
          ),
        ],
      ),
    ),
  );
}

final class _LocationPreview extends StatelessWidget {
  const _LocationPreview({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: location.isEmpty
        ? 'Prévia de localização aguardando endereço'
        : 'Prévia de localização para $location',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: SizedBox(
        key: const Key('agenda-event-location-map'),
        height: 148,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              location.isEmpty ? Icons.map_outlined : Icons.location_pin,
              size: CoeloSize.iconLg,
              color: Theme.of(context).colorScheme.primary,
            ),
            Positioned(
              left: CoeloSpacing.space3,
              right: CoeloSpacing.space3,
              bottom: CoeloSpacing.space2,
              child: Text(
                location.isEmpty
                    ? 'Informe o local para preparar a visualização.'
                    : 'Local informado: $location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space5),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) const SizedBox(height: CoeloSpacing.space4),
          ],
          const SizedBox(height: CoeloSpacing.space6),
        ],
      ),
    ),
  );
}

final class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      child: Text(value),
    ),
  );
}

String _contextFor(AgendaAudience? audience) {
  if (audience == null) return 'Instituição';
  if (audience.personIds.isNotEmpty) return 'Pessoa';
  if (audience.activityIds.isNotEmpty) return 'Atividade';
  if (audience.groupIds.isNotEmpty) return 'Turma';
  if (audience.unitIds.isNotEmpty) return 'Unidade';
  return 'Instituição';
}

String _recurrenceLabel(AgendaRecurrence? recurrence) => switch (recurrence?.frequency) {
  AgendaRecurrenceFrequency.daily => 'Diária',
  AgendaRecurrenceFrequency.weekly => 'Semanal',
  AgendaRecurrenceFrequency.monthly => 'Mensal',
  null => 'Não se repete',
};

String _responseLabel(AgendaResponseMode value) => switch (value) {
  AgendaResponseMode.none => 'Nenhuma resposta',
  AgendaResponseMode.rsvp => 'RSVP · Sim, Não ou Talvez',
  AgendaResponseMode.acknowledgement => 'Ciência',
  AgendaResponseMode.authorization => 'Autorização · Autorizo ou Não autorizo',
};

String _questionTypeLabel(AgendaQuestionType value) => switch (value) {
  AgendaQuestionType.shortText => 'Resposta curta',
  AgendaQuestionType.yesNo => 'Sim ou não',
};

String _occurrenceEditScopeLabel(AgendaOccurrenceEditScope value) => switch (value) {
  AgendaOccurrenceEditScope.occurrence => 'Somente esta ocorrência',
  AgendaOccurrenceEditScope.thisAndFollowing => 'Esta e as próximas',
  AgendaOccurrenceEditScope.series => 'Toda a série',
};

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _date(DateTime value) =>
    '${_shortDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _label(String value) =>
    '${value[0].toUpperCase()}${value.substring(1).replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)!.toLowerCase()}')}';
