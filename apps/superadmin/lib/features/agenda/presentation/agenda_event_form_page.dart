import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/presentation/widgets/publication_surface.dart';
import '../domain/agenda_models.dart';
import '../domain/agenda_repository.dart';
import 'agenda_reservation_conflict_dialog.dart';

final class AgendaEventFormPage extends StatelessWidget {
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
  Widget build(BuildContext context) => _AgendaEventFormBody(
    key: ValueKey((ObjectKey(store), eventId, canPublish, actionsAvailable)),
    store: store,
    eventId: eventId,
    canPublish: canPublish,
    actionsAvailable: actionsAvailable,
    onCancel: onCancel,
    onSaved: onSaved,
  );
}

final class _AgendaEventFormBody extends StatefulWidget {
  const _AgendaEventFormBody({
    required this.store,
    required this.eventId,
    required this.canPublish,
    required this.actionsAvailable,
    required this.onCancel,
    required this.onSaved,
    super.key,
  });

  final AgendaRepository store;
  final String? eventId;
  final bool canPublish;
  final bool actionsAvailable;
  final VoidCallback onCancel;
  final ValueChanged<String> onSaved;

  @override
  State<_AgendaEventFormBody> createState() => _AgendaEventFormPageState();
}

final class _AgendaEventFormPageState extends State<_AgendaEventFormBody> {
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
  String? _contextId;
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
  bool _saving = false;
  bool _completionFailed = false;
  String? _completionOperation;
  DialogRoute<String>? _conflictRoute;

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
    _contextId = _contextIdFor(_existing?.audience);
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
    if (widget.store.contexts.isEmpty) unawaited(_loadContexts());
    if (widget.eventId != null && _existing == null) unawaited(_loadExisting());
  }

  Future<void> _loadContexts() async {
    await widget.store.loadContexts();
    if (!mounted) return;
    setState(() {
      if (widget.store.contexts.isEmpty) {
        _feedback =
            widget.store.errorMessage ??
            'Nenhum contexto institucional autorizado está disponível.';
      }
    });
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
      _contextId = _contextIdFor(item.audience);
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
    final route = _conflictRoute;
    _conflictRoute = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
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
    if (_saving || _completionFailed || !widget.actionsAvailable) return;
    _completionOperation = null;
    setState(() => _saving = true);
    try {
      await _saveCurrent(requestedStatus);
    } on Exception {
      if (mounted) {
        if (_completionOperation case final operation?) {
          _showPartialFailure(operation);
        } else {
          setState(() => _feedback = 'Não foi possível concluir o evento agora. Tente novamente.');
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveCurrent(AgendaItemStatus requestedStatus) async {
    final store = widget.store;
    final canPublish = widget.canPublish;
    final occurrenceEditScope = _occurrenceEditScope;
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
    if (widget.eventId != null && existing == null) {
      setState(() {
        _feedback = widget.store.isLoading
            ? 'Aguarde o carregamento do evento antes de salvar.'
            : widget.store.errorMessage ?? 'O evento não foi encontrado.';
      });
      return;
    }
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
    var result = await store.saveItem(item, actorContextId: actorContextId);
    if (!mounted) return;
    if (result == AgendaMutationResult.reservationConflict &&
        store
            .resolveCapability(institutionId, AgendaCapability.overrideReservationConflict)
            .isAllowed) {
      final route = createAgendaReservationConflictOverrideRoute(context);
      _conflictRoute = route;
      final reason = await Navigator.of(context, rootNavigator: true).push<String>(route);
      if (identical(_conflictRoute, route)) _conflictRoute = null;
      if (!mounted || reason == null) return;
      result = await store.saveItem(
        item,
        actorContextId: actorContextId,
        actorName: 'Owner Coelo',
        overrideConflict: true,
        reason: reason,
      );
      if (!mounted) return;
    }
    if (result == AgendaMutationResult.success) {
      final savedItemId = store.lastSavedItemId ?? id;
      if (existing?.recurrence != null) {
        _completionOperation = 'o registro da edição da recorrência';
        final occurrenceResult = await store.recordOccurrenceEdit(
          itemId: savedItemId,
          occurrenceStartsAt: existing!.startsAt,
          scope: occurrenceEditScope,
          actorName: 'Owner Coelo',
        );
        if (!mounted) return;
        if (occurrenceResult != AgendaMutationResult.success) {
          _showPartialFailure('o registro da edição da recorrência');
          return;
        }
      }
      if (requestedStatus == AgendaItemStatus.published && !canPublish) {
        _completionOperation = 'a solicitação de publicação';
        final publicationResult = await store.requestPublication(
          savedItemId,
          requestedBy: 'Usuário local sem permissão de publicação',
        );
        if (!mounted) return;
        if (publicationResult != AgendaMutationResult.success) {
          _showPartialFailure('a solicitação de publicação');
          return;
        }
      }
      _completionOperation = null;
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

  void _showPartialFailure(String operation) {
    setState(() {
      _completionFailed = true;
      _feedback =
          'O evento foi salvo, mas não foi possível confirmar $operation. '
          'Reabra o evento para verificar seu estado antes de tentar novamente.';
    });
  }

  AgendaContextLevel? _selectedLevel() => switch (_context) {
    'Instituição' => AgendaContextLevel.institution,
    'Unidade' => AgendaContextLevel.unit,
    'Turma' => AgendaContextLevel.group,
    'Atividade' => AgendaContextLevel.activity,
    _ => null,
  };

  List<AgendaContext> _contextsOfLevel() {
    final level = _selectedLevel();
    if (level == null) return const [];
    return widget.store.contexts.where((context) => context.level == level).toList(growable: false);
  }

  AgendaContext? _selectedContext() {
    final candidates = _contextsOfLevel();
    if (candidates.isEmpty) return null;
    for (final context in candidates) {
      if (context.id == _contextId) return context;
    }
    return candidates.first;
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

  // Familia Publicacao (Owner, 11/09/2026 17:19): o evento e uma publicacao
  // em superficie unica (titulo, data e horario, local, descricao, categoria,
  // publico e contexto, lembrete), sem wizard de etapas; o restante do
  // contrato (dia inteiro, fuso, recorrencia, prioridade, resposta, perguntas)
  // fica em "Mais opcoes" na mesma superficie. Referencia:
  // evidence/etapa-2/referencias/publicacao/aprovadas-20260911/evento-*.png.
  @override
  Widget build(BuildContext context) {
    final enabled = widget.actionsAvailable && !_saving && !_completionFailed;
    return PublicationSurface(
      subtitle: widget.eventId == null ? 'Publicar Evento' : 'Editar Evento',
      scrollKey: const Key('agenda-event-form-scroll'),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_feedback != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _feedback!,
                key: const Key('agenda-event-form-feedback'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ..._publicationFields(),
          const PublicationLabel('Mais opções'),
          ..._spaced([..._periodFields(), ..._responseFields()]),
          const SizedBox(height: CoeloSpacing.space4),
          _questionBuilder(),
          if (!widget.canPublish)
            const Padding(
              padding: EdgeInsets.only(top: CoeloSpacing.space3),
              child: PublicationNote(
                'Sem permissão de publicação: o evento será salvo como rascunho e enviado para aprovação.',
              ),
            ),
          if (!widget.actionsAvailable)
            const CoeloStatePanel(
              key: Key('agenda-event-actions-unavailable'),
              icon: Icons.cloud_off_outlined,
              title: 'Integração indisponível',
              message:
                  'A composição está disponível, mas salvar e publicar permanecem bloqueados nesta rota.',
            ),
        ],
      ),
      preview: _AgendaEventPreview(
        key: const Key('agenda-event-preview'),
        title: _title.text,
        start: _start,
        end: _end,
        allDay: _allDay,
        location: _location.text,
        context: _selectedContext()?.name ?? _context,
        audience: _audience,
      ),
      tertiaryAction: TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
      continuationActions: [
        OutlinedButton(
          key: const Key('agenda-wizard-save-draft'),
          onPressed: enabled ? () => _save(AgendaItemStatus.draft) : null,
          child: const Text('Salvar rascunho'),
        ),
        FilledButton(
          key: const Key('agenda-wizard-publish'),
          onPressed: enabled ? () => _save(AgendaItemStatus.published) : null,
          child: Text(widget.canPublish ? 'Publicar evento' : 'Solicitar publicação'),
        ),
      ],
    );
  }

  List<Widget> _publicationFields() => [
    const PublicationLabel('Título do evento'),
    PublicationTextField(
      fieldKey: const Key('agenda-event-title'),
      controller: _title,
      hintText: 'Festa junina do 3º ano',
      // O banco recusa titulo acima de 240 caracteres em superadmin_agenda_save.
      maxLength: 240,
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: CoeloSpacing.space3),
    LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
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
              labelText: 'Data e início',
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
        ];
        if (constraints.maxWidth < 600 || fields.length == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                if (index > 0) const SizedBox(height: CoeloSpacing.space3),
                fields[index],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(child: fields[1]),
          ],
        );
      },
    ),
    const SizedBox(height: CoeloSpacing.space3),
    PublicationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloFormTextField(
            controller: _location,
            labelText: 'Local (opcional)',
            prefixIcon: Icons.place_outlined,
            onChanged: (_) => setState(() {}),
            // Limite da coluna location de agenda_events.
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
          ),
          _LocationPreview(location: _location.text.trim()),
        ],
      ),
    ),
    const PublicationLabel('Descrição'),
    PublicationTextField(
      fieldKey: const Key('agenda-event-description'),
      controller: _details,
      hintText: 'Conte o que vai acontecer…',
      maxLines: 4,
      // Limite da coluna description de agenda_events.
      maxLength: 10000,
    ),
    const PublicationLabel('Categoria'),
    Wrap(
      key: const Key('agenda-event-type'),
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        for (final type in AgendaItemType.values)
          PublicationChip(
            key: Key('agenda-event-type-${type.name}'),
            label: type.label,
            icon: Icons.event_outlined,
            selected: _type == type,
            onTap: () => setState(() => _type = type),
          ),
      ],
    ),
    const PublicationLabel('Público e contexto'),
    PublicationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloAdminSingleSelectField<String>(
            key: const Key('agenda-event-context'),
            label: 'Contexto principal',
            value: _context,
            options: _contexts,
            optionLabel: (value) => value,
            onChanged: (value) => setState(() {
              _context = value;
              _contextId = null;
            }),
            prefixIcon: Icons.account_tree_outlined,
          ),
          // Achado R05 (agenda.location): o nível sozinho escolhia o primeiro
          // contexto daquele nível; com mais de um, o operador escolhe qual.
          if (_contextsOfLevel().length > 1)
            CoeloAdminSingleSelectField<AgendaContext>(
              key: const Key('agenda-event-context-target'),
              label: 'Qual $_context',
              value: _selectedContext()!,
              options: _contextsOfLevel(),
              optionLabel: (value) => value.name,
              onChanged: (value) => setState(() => _contextId = value.id),
              prefixIcon: Icons.place_outlined,
            ),
        ],
      ),
    ),
    const SizedBox(height: CoeloSpacing.space3),
    Wrap(
      key: const Key('agenda-event-audience'),
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        for (final audience in _audiences)
          PublicationChip(
            key: Key('agenda-event-audience-$audience'),
            label: audience,
            selected: _audience.contains(audience),
            onTap: () => setState(() {
              final next = {..._audience};
              if (!next.add(audience)) next.remove(audience);
              _audience = next;
            }),
          ),
      ],
    ),
    const SizedBox(height: CoeloSpacing.space2),
    PublicationToggleRow(
      icon: Icons.notifications_none_rounded,
      label: 'Lembrar 1 dia antes',
      value: _reminders.contains('24 horas antes'),
      onChanged: (value) => setState(() {
        final next = {..._reminders};
        if (value) {
          next.add('24 horas antes');
        } else {
          next.remove('24 horas antes');
        }
        _reminders = next;
      }),
    ),
  ];

  List<Widget> _periodFields() => [
    CoeloAdminToggleField(
      key: const Key('agenda-event-all-day'),
      value: _allDay,
      onChanged: (value) => setState(() => _allDay = value),
      label: 'Dia inteiro',
      description: 'Eventos de dia inteiro não exibem horário.',
    ),
    CoeloAdminSingleSelectField<String>(
      key: const Key('agenda-event-timezone'),
      label: 'Fuso horário IANA',
      value: _timeZoneId,
      options: _timeZones,
      optionLabel: (value) => value,
      onChanged: (value) => setState(() => _timeZoneId = value),
      prefixIcon: Icons.public_outlined,
    ),
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
  ];

  static List<Widget> _spaced(List<Widget> fields) => [
    for (var index = 0; index < fields.length; index++) ...[
      if (index > 0) const SizedBox(height: CoeloSpacing.space4),
      fields[index],
    ],
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

/// "Prévia na Agenda": o evento como card do calendário (mês, dia, título,
/// horário · local) e a nota de onde ele aparece.
final class _AgendaEventPreview extends StatelessWidget {
  const _AgendaEventPreview({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.location,
    required this.context,
    required this.audience,
    super.key,
  });
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String location;
  final String context;
  final Set<String> audience;

  static const _months = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];

  @override
  Widget build(BuildContext buildContext) {
    final colors = Theme.of(buildContext).colorScheme;
    final textTheme = Theme.of(buildContext).textTheme;
    String hm(DateTime v) =>
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
    final when = allDay ? 'Dia inteiro' : '${hm(start)} – ${hm(end)}';
    final detail = location.trim().isEmpty ? when : '$when · ${location.trim()}';
    return PublicationPreviewPanel(
      title: 'Prévia na Agenda',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colors.primary, width: 4)),
              borderRadius: BorderRadius.circular(CoeloRadius.sm),
              color: colors.surface,
              boxShadow: [
                BoxShadow(color: colors.shadow.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      _months[start.month - 1],
                      style: textTheme.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${start.day}',
                      style: textTheme.titleLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.trim().isEmpty ? 'Título do evento' : title,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        detail,
                        style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            'Aparece no calendário de ${audience.isEmpty ? 'ninguém ainda' : audience.join(', ').toLowerCase()} em $context e no sino no dia anterior.',
            style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
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

String? _contextIdFor(AgendaAudience? audience) {
  if (audience == null) return null;
  if (audience.unitIds.isNotEmpty) return audience.unitIds.first;
  if (audience.groupIds.isNotEmpty) return audience.groupIds.first;
  if (audience.activityIds.isNotEmpty) return audience.activityIds.first;
  return null;
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

String _label(String value) =>
    '${value[0].toUpperCase()}${value.substring(1).replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)!.toLowerCase()}')}';
