import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../data/agenda_prototype_store.dart';
import '../domain/agenda_models.dart';

final class AgendaRequestsPage extends StatefulWidget {
  const AgendaRequestsPage({required this.store, super.key});
  final AgendaPrototypeStore store;

  @override
  State<AgendaRequestsPage> createState() => _AgendaRequestsPageState();
}

final class _AgendaRequestsPageState extends State<AgendaRequestsPage> {
  final _reason = TextEditingController();
  final _requestTitle = TextEditingController(text: 'Festa de aniversário');
  final _requestDetails = TextEditingController(text: 'Bolo simples na sala.');
  final _requestDate = TextEditingController(text: '03/09/2026');
  final _requestStart = TextEditingController(text: '15:00');
  final _requestEnd = TextEditingController(text: '16:00');
  String? _rejectingId;
  String? _notice;
  bool _creating = false;
  int _requestStep = 0;
  String _child = 'Lia';

  DateTime? get _requestStartsAt => _parseTime(_parseDate(_requestDate.text), _requestStart.text);
  DateTime? get _requestEndsAt => _parseTime(_parseDate(_requestDate.text), _requestEnd.text);

  void _setRequestDateTime(DateTime? value, {required bool start}) {
    if (value == null) return;
    setState(() {
      _requestDate.text =
          '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
      final time =
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      (start ? _requestStart : _requestEnd).text = time;
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    _requestTitle.dispose();
    _requestDetails.dispose();
    _requestDate.dispose();
    _requestStart.dispose();
    _requestEnd.dispose();
    super.dispose();
  }

  void _submitRequest() {
    final date = _parseDate(_requestDate.text);
    final start = _parseTime(date, _requestStart.text);
    final end = _parseTime(date, _requestEnd.text);
    if (date == null || start == null || end == null || !end.isAfter(start)) {
      setState(() => _notice = 'Confira a data e o período informado.');
      return;
    }
    final lia = _child == 'Lia';
    widget.store.upsertRequest(
      GuardianBirthdayRequest(
        id: 'request-local-${DateTime.now().microsecondsSinceEpoch}',
        childId: lia ? 'child-lia' : 'child-noah',
        childName: _child,
        guardianName: 'Responsável',
        contextId: lia ? 'group-girassol' : 'group-estrelas',
        institutionId: lia ? 'inst-horizonte' : 'inst-aurora',
        title: _requestTitle.text.trim(),
        startsAt: start,
        endsAt: end,
        status: GuardianRequestStatus.sent,
        details: _requestDetails.text.trim(),
      ),
    );
    setState(() {
      _creating = false;
      _requestStep = 0;
      _notice = 'Solicitação de festa de aniversário enviada.';
    });
  }

  void _decide(GuardianBirthdayRequest request, bool approve) {
    final actor = widget.store.contexts.firstWhere(
      (context) => widget.store
          .resolveCapability(context.id, AgendaCapability.approveGuardianBirthdayRequest)
          .isAllowed,
    );
    final result = widget.store.decideRequest(
      requestId: request.id,
      actorContextId: actor.id,
      actorName: 'Marina Oliveira · ${actor.name}',
      approve: approve,
      reason: approve ? null : _reason.text.trim(),
    );
    setState(() {
      _notice = switch (result) {
        RequestDecisionResult.approvedAndConvertedToDraft => 'Aprovada e convertida em rascunho.',
        RequestDecisionResult.rejected => 'Solicitação reprovada; o motivo ficou visível.',
        RequestDecisionResult.alreadyDecided => 'Solicitação já decidida.',
        RequestDecisionResult.reasonRequired => 'Informe o motivo da reprovação.',
        RequestDecisionResult.notAuthorized => 'Este perfil não pode decidir.',
        RequestDecisionResult.notFound => 'Solicitação não encontrada.',
      };
      if (result != RequestDecisionResult.reasonRequired) {
        _rejectingId = null;
        _reason.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return ListView(
          key: const Key('agenda-requests-scroll'),
          padding: EdgeInsets.all(padding),
          children: [
            Text('Solicitações', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: CoeloSpacing.space1),
            const Text('Pedidos de festa de aniversário enviados por responsáveis.'),
            const SizedBox(height: CoeloSpacing.space3),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('agenda-request-create'),
                onPressed: () => setState(() => _creating = !_creating),
                icon: const Icon(Icons.cake_outlined),
                label: const Text('Nova solicitação'),
              ),
            ),
            if (_creating) ...[
              const SizedBox(height: CoeloSpacing.space4),
              _RequestForm(
                step: _requestStep,
                child: _child,
                title: _requestTitle,
                details: _requestDetails,
                date: _requestDate,
                start: _requestStart,
                end: _requestEnd,
                startAt: _requestStartsAt,
                endAt: _requestEndsAt,
                onStartChanged: (value) => _setRequestDateTime(value, start: true),
                onEndChanged: (value) => _setRequestDateTime(value, start: false),
                onChildChanged: (value) => setState(() => _child = value),
                onPrevious: () => setState(() => _requestStep--),
                onContinue: () => setState(() => _requestStep++),
                onCancel: () => setState(() {
                  _creating = false;
                  _requestStep = 0;
                }),
                onSubmit: _submitRequest,
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Semantics(
                liveRegion: true,
                child: Text(_notice!, key: const Key('agenda-request-notice')),
              ),
            ],
            const SizedBox(height: CoeloSpacing.space6),
            for (final request in widget.store.requests) ...[
              CoeloAdminInteractiveCard(
                semanticLabel: '${request.title}, ${_label(request.status.name)}',
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: CoeloSpacing.space2,
                        runSpacing: CoeloSpacing.space2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(request.title, style: Theme.of(context).textTheme.titleMedium),
                          _StatusLabel(text: _label(request.status.name)),
                        ],
                      ),
                      const SizedBox(height: CoeloSpacing.space2),
                      Text('${request.childName} · Responsável: ${request.guardianName}'),
                      Text('${_date(request.startsAt)} — ${_date(request.endsAt)}'),
                      const SizedBox(height: CoeloSpacing.space2),
                      Text(request.details),
                      const SizedBox(height: CoeloSpacing.space3),
                      if (request.decision case final decision?) ...[
                        Text(
                          'Decidida por ${decision.actorName} em ${_date(decision.decidedAt)}.',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        if (decision.reason != null) Text('Motivo: ${decision.reason}'),
                        if (request.linkedAgendaItemId != null)
                          Text('Rascunho criado: ${request.linkedAgendaItemId}'),
                      ] else if (_rejectingId == request.id) ...[
                        CoeloFormTextField(
                          controller: _reason,
                          labelText: 'Motivo da reprovação',
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                        const SizedBox(height: CoeloSpacing.space3),
                        Wrap(
                          spacing: CoeloSpacing.space2,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _rejectingId = null),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              key: const Key('agenda-request-confirm-reject'),
                              onPressed: () => _decide(request, false),
                              child: const Text('Confirmar reprovação'),
                            ),
                          ],
                        ),
                      ] else ...[
                        Wrap(
                          spacing: CoeloSpacing.space2,
                          runSpacing: CoeloSpacing.space2,
                          children: [
                            OutlinedButton(
                              key: Key('agenda-request-reject-${request.id}'),
                              onPressed: () => setState(() => _rejectingId = request.id),
                              child: const Text('Reprovar com motivo'),
                            ),
                            FilledButton(
                              key: Key('agenda-request-approve-${request.id}'),
                              onPressed: () => _decide(request, true),
                              child: const Text('Aprovar e criar rascunho'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CoeloSpacing.space3),
            ],
          ],
        );
      },
    ),
  );
}

final class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.step,
    required this.child,
    required this.title,
    required this.details,
    required this.date,
    required this.start,
    required this.end,
    required this.startAt,
    required this.endAt,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onChildChanged,
    required this.onPrevious,
    required this.onContinue,
    required this.onCancel,
    required this.onSubmit,
  });

  final int step;
  final String child;
  final TextEditingController title, details, date, start, end;
  final DateTime? startAt, endAt;
  final ValueChanged<DateTime?> onStartChanged, onEndChanged;
  final ValueChanged<String> onChildChanged;
  final VoidCallback onPrevious, onContinue, onCancel, onSubmit;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Solicitação de aniversário. Etapa ${step + 1} de 3',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              const ['1. Criança e contexto', '2. Data e detalhes', '3. Revisão'][step],
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            if (step == 0) ...[
              CoeloAdminSingleSelectField<String>(
                label: 'Criança',
                value: child,
                options: const ['Lia', 'Noah'],
                optionLabel: (value) => value,
                onChanged: onChildChanged,
                prefixIcon: Icons.child_care_rounded,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Contexto escolar resolvido',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                child: Text(
                  child == 'Lia'
                      ? 'Centro Horizonte → Turma Girassol'
                      : 'Escola Aurora → Turma Estrelas',
                ),
              ),
            ] else if (step == 1) ...[
              CoeloFormTextField(
                controller: title,
                labelText: 'Título',
                prefixIcon: Icons.cake_outlined,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloDateTimeField(
                value: startAt,
                onChanged: onStartChanged,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030, 12, 31),
                currentDate: DateTime(2026, 8, 3),
                labelText: 'Início',
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloDateTimeField(
                value: endAt,
                onChanged: onEndChanged,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030, 12, 31),
                currentDate: DateTime(2026, 8, 3),
                labelText: 'Fim',
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                controller: details,
                labelText: 'Detalhes mínimos',
                prefixIcon: Icons.notes_rounded,
                maxLines: 3,
              ),
            ] else ...[
              Text(title.text, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: CoeloSpacing.space2),
              Text('$child · ${date.text} · ${start.text}–${end.text}'),
              const SizedBox(height: CoeloSpacing.space2),
              const Text(
                'Tipo fixo: festa de aniversário. A audiência será definida pela escola; o responsável não publica diretamente.',
              ),
            ],
            const SizedBox(height: CoeloSpacing.space5),
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                TextButton(onPressed: onCancel, child: const Text('Cancelar')),
                if (step > 0) OutlinedButton(onPressed: onPrevious, child: const Text('Anterior')),
                if (step < 2)
                  FilledButton(
                    key: const Key('agenda-request-continue'),
                    onPressed: onContinue,
                    child: const Text('Continuar'),
                  )
                else
                  FilledButton(
                    key: const Key('agenda-request-submit'),
                    onPressed: onSubmit,
                    child: const Text('Enviar solicitação'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

final class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(CoeloRadius.full),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space3,
        vertical: CoeloSpacing.space1,
      ),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
    ),
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _label(String value) =>
    '${value[0].toUpperCase()}${value.substring(1).replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)!.toLowerCase()}')}';

DateTime? _parseDate(String value) {
  final parts = value.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  final parsed = DateTime(year, month, day);
  return parsed.day == day && parsed.month == month && parsed.year == year ? parsed : null;
}

DateTime? _parseTime(DateTime? date, String value) {
  if (date == null) return null;
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return DateTime(date.year, date.month, date.day, hour, minute);
}
