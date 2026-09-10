import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_reader.dart' show sameLocationScope;
import '../domain/location_reservation_gateway.dart';
import 'location_form_panel.dart' show newLocationRequestId;

enum _PolicyChoice { unset, block, warn }

const _weekdayLabels = <String>[
  'Domingo',
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
];

/// Consumer-scoped reservation management for one catalogued location.
///
/// Weekly availability is intentionally absent: it describes when a location
/// is offered, while this panel manages moments actually held by a consumer.
class LocationReservationPanel extends StatefulWidget {
  const LocationReservationPanel({
    required this.locationId,
    required this.scope,
    required this.consumer,
    this.gateway = const UnavailableLocationReservationGateway(),
    required this.sessionAvailable,
    required this.contextRevision,
    this.canRead = false,
    this.canManage = false,
    this.canOverride = false,
    this.locationStatus = LocationCatalogStatus.active,
    this.requestIdFactory,
    super.key,
  });

  final String locationId;
  final LocationScope scope;
  final LocationReservationConsumer consumer;
  final LocationReservationGateway gateway;
  final bool sessionAvailable;
  final int contextRevision;
  final bool canRead;
  final bool canManage;
  final bool canOverride;

  /// Read status hint; every write still reauthorizes the current catalog row.
  final LocationCatalogStatus locationStatus;
  final String Function()? requestIdFactory;

  @override
  State<LocationReservationPanel> createState() => _LocationReservationPanelState();
}

class _LocationReservationPanelState extends State<LocationReservationPanel> {
  final _justification = TextEditingController();
  final _timeZone = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  DateTime? _until;
  final Set<int> _weekdays = {};

  LocationSchedulingPolicyState? _policy;
  LocationSchedulingPolicy? _selectedPolicy;
  List<LocationReservation> _items = const [];
  String? _nextId;
  bool _weekly = false;
  LocationReservationDraft? _pendingDraft;
  String? _pendingRequestId;
  ({LocationSchedulingPolicy policy, int expectedVersion, String requestId})? _policyAttempt;
  final Map<String, ({int expectedVersion, String requestId})> _cancelAttempts = {};
  bool _loading = false;
  bool _busy = false;
  int _generation = 0;
  String? _error;
  String? _notice;

  bool get _mayRead => widget.sessionAvailable && widget.canRead && widget.gateway.available;

  bool get _mayManage => _mayRead && widget.canManage;

  bool get _mayCreate => _mayManage && widget.locationStatus == LocationCatalogStatus.active;

  bool _isCurrent(int generation, {bool manage = false}) =>
      mounted && generation == _generation && (manage ? _mayManage : _mayRead);

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  void didUpdateWidget(LocationReservationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationId != widget.locationId ||
        oldWidget.consumer != widget.consumer ||
        !sameLocationScope(oldWidget.scope, widget.scope) ||
        oldWidget.gateway != widget.gateway ||
        oldWidget.contextRevision != widget.contextRevision ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.canRead != widget.canRead ||
        oldWidget.canManage != widget.canManage ||
        oldWidget.canOverride != widget.canOverride) {
      _generation++;
      _clearAttempt();
      _policyAttempt = null;
      _cancelAttempts.clear();
      _loading = false;
      _busy = false;
      _policy = null;
      _selectedPolicy = null;
      _items = const [];
      _nextId = null;
      _error = null;
      _notice = null;
      _startsAt = null;
      _endsAt = null;
      _until = null;
      _weekdays.clear();
      _weekly = false;
      _justification.clear();
      _timeZone.clear();
      unawaited(_load(reset: true));
    }
  }

  @override
  void dispose() {
    _justification.dispose();
    _timeZone.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (!_mayRead || _loading || _busy) return;
    final generation = _generation;
    final locationId = widget.locationId;
    final consumer = widget.consumer;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        widget.gateway.getPolicy(locationId: locationId, scope: widget.scope),
        widget.gateway.listPaged(
          locationId: locationId,
          consumer: consumer,
          afterId: reset ? null : _nextId,
        ),
      ]);
      if (!_isCurrent(generation)) return;
      final policy = values[0] as LocationSchedulingPolicyState;
      final page = values[1] as LocationReservationPage;
      setState(() {
        _loading = false;
        _policy = policy;
        _selectedPolicy = _policyAttempt?.policy ?? policy.policy;
        _items = reset ? page.items : [..._items, ...page.items];
        _nextId = page.nextId;
      });
    } on LocationReservationDeniedException {
      if (!_isCurrent(generation)) return;
      _fail('Você não tem permissão para ver as reservas deste local.');
    } on Object {
      if (!_isCurrent(generation)) return;
      _fail('Não foi possível carregar as reservas. Tente novamente.');
    }
  }

  Future<void> _savePolicy() async {
    final policy = _policyAttempt?.policy ?? _selectedPolicy;
    final current = _policy;
    if (!_mayManage || policy == null || current == null || _loading || _busy) return;
    final attempt =
        _policyAttempt ??
        (
          policy: policy,
          expectedVersion: current.managementVersion,
          requestId: (widget.requestIdFactory ?? newLocationRequestId)(),
        );
    _policyAttempt = attempt;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.gateway.setPolicy(
        locationId: widget.locationId,
        scope: widget.scope,
        policy: attempt.policy,
        expectedVersion: attempt.expectedVersion,
        requestId: attempt.requestId,
      );
      if (!_isCurrent(generation, manage: true)) return;
      setState(() {
        _busy = false;
        _policy = result;
        _selectedPolicy = result.policy;
        _policyAttempt = null;
        _notice = 'Política de conflito atualizada.';
      });
    } on LocationReservationConflictException {
      if (!_isCurrent(generation, manage: true)) return;
      _policyAttempt = null;
      _fail('A política mudou enquanto esta tela estava aberta. Recarregue.');
    } on LocationReservationDeniedException {
      if (!_isCurrent(generation, manage: true)) return;
      _fail('Você não tem permissão para alterar a política.');
    } on Object {
      if (!_isCurrent(generation, manage: true)) return;
      _fail('Não foi possível salvar a política. Tente novamente.');
    }
  }

  LocationReservationDraft? _draft() {
    final start = _startsAt?.toUtc();
    final end = _endsAt?.toUtc();
    if (start == null || end == null || !end.isAfter(start)) {
      _fail('Escolha início e fim válidos, com o fim após o início.');
      return null;
    }
    LocationReservationRecurrence recurrence;
    if (!_weekly) {
      recurrence = const LocationReservationRecurrence.once();
    } else {
      final until = _until;
      final weekdays = _weekdays;
      if (until == null || weekdays.isEmpty || _timeZone.text.trim().isEmpty) {
        _fail('Na recorrência semanal, informe dias, data final e fuso.');
        return null;
      }
      try {
        recurrence = LocationReservationRecurrence.weekly(
          weekdays: weekdays,
          until: DateTime.utc(until.year, until.month, until.day),
          timeZone: _timeZone.text.trim(),
        );
      } on ArgumentError {
        _fail('Revise os dias e o fuso da recorrência semanal.');
        return null;
      }
    }
    return LocationReservationDraft(
      locationId: widget.locationId,
      consumer: widget.consumer,
      firstOccurrence: LocationReservationOccurrence(startsAt: start, endsAt: end),
      recurrence: recurrence,
    );
  }

  Future<void> _assess() async {
    if (!_mayCreate || _loading || _busy || _policy?.policy == null) return;
    final draft = _draft();
    if (draft == null) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final assessment = await widget.gateway.assess(draft);
      if (!_isCurrent(generation, manage: true)) return;
      if (!_mayCreate) {
        _fail(_newReservationUnavailable);
        return;
      }
      switch (assessment.conflict) {
        case LocationReservationConflict.none:
          await _create(draft);
        case LocationReservationConflict.confirmable:
          setState(() {
            _busy = false;
            _pendingDraft = draft;
            _notice = 'Há conflito. Informe a justificativa para confirmar a sobreposição.';
          });
        case LocationReservationConflict.refused:
          _fail('O horário está ocupado e a política bloqueia sobreposições.');
        case LocationReservationConflict.notConfirmable:
          _fail('O horário está ocupado e você não pode confirmar a sobreposição.');
      }
    } on LocationReservationDeniedException {
      if (!_isCurrent(generation, manage: true)) return;
      _fail('Você não tem permissão para criar esta reserva.');
    } on Object {
      if (!_isCurrent(generation, manage: true)) return;
      _fail('Não foi possível avaliar o horário. Tente novamente.');
    }
  }

  Future<void> _confirmConflict() async {
    if (!_mayCreate || _loading || _busy) return;
    final base = _pendingDraft;
    final justification = _justification.text.trim();
    if (base == null || justification.isEmpty) {
      _fail('Explique por que a sobreposição deve ser confirmada.');
      return;
    }
    if (!widget.canOverride) {
      _fail('Você não tem permissão para confirmar sobreposições.');
      return;
    }
    await _create(
      LocationReservationDraft(
        locationId: base.locationId,
        consumer: base.consumer,
        firstOccurrence: base.firstOccurrence,
        recurrence: base.recurrence,
        conflictJustification: justification,
      ),
    );
  }

  Future<void> _create(LocationReservationDraft draft) async {
    if (!_mayManage || _loading) return;
    // A lost response may already have committed. Keep its existing request ID
    // available for authoritative replay even if the location is now inactive.
    if (_pendingRequestId == null && !_mayCreate) {
      _fail(_newReservationUnavailable);
      return;
    }
    final generation = _generation;
    final requestId = _pendingRequestId ??= (widget.requestIdFactory ?? newLocationRequestId)();
    _pendingDraft = draft;
    if (mounted) setState(() => _busy = true);
    try {
      final created = await widget.gateway.create(draft: draft, requestId: requestId);
      if (!_isCurrent(generation, manage: true)) return;
      setState(() {
        _busy = false;
        _items = [created, ..._items.where((item) => item.id != created.id)];
        _notice = 'Reserva criada.';
        _error = null;
        _justification.clear();
        _clearAttempt();
      });
    } on LocationReservationDeniedException {
      if (!_isCurrent(generation, manage: true)) return;
      _fail('Você não tem permissão para criar esta reserva.');
    } on LocationReservationRejectedException {
      if (!_isCurrent(generation, manage: true)) return;
      _clearAttempt();
      _fail('A reserva foi recusada. Revise os dados e a política vigente.');
    } on LocationReservationConflictException {
      if (!_isCurrent(generation, manage: true)) return;
      _clearAttempt();
      _fail('A agenda mudou. Avalie o horário novamente.');
    } on Object {
      if (!_isCurrent(generation, manage: true)) return;
      _fail('Não foi possível concluir a reserva. Use Tentar novamente.');
    }
  }

  Future<void> _retryCreate() async {
    if (!_mayManage || _loading) return;
    final draft = _pendingDraft;
    if (draft != null && !_busy) await _create(draft);
  }

  Future<void> _cancel(LocationReservation reservation) async {
    if (!_mayManage || _loading || _busy) return;
    final attempt = _cancelAttempts.putIfAbsent(
      reservation.id,
      () => (
        expectedVersion: reservation.managementVersion,
        requestId: (widget.requestIdFactory ?? newLocationRequestId)(),
      ),
    );
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cancelled = await widget.gateway.cancel(
        locationId: widget.locationId,
        consumer: widget.consumer,
        reservationId: reservation.id,
        expectedVersion: attempt.expectedVersion,
        requestId: attempt.requestId,
      );
      if (!_isCurrent(generation, manage: true)) return;
      setState(() {
        _busy = false;
        _cancelAttempts.remove(reservation.id);
        _items = [
          for (final item in _items)
            if (item.id == cancelled.id) cancelled else item,
        ];
        _notice = 'Reserva cancelada.';
      });
    } on LocationReservationConflictException {
      if (!_isCurrent(generation, manage: true)) return;
      _cancelAttempts.remove(reservation.id);
      _fail('A reserva mudou enquanto esta tela estava aberta. Recarregue.');
    } on LocationReservationDeniedException {
      if (!_isCurrent(generation, manage: true)) return;
      _fail('Você não tem permissão para cancelar esta reserva.');
    } on Object {
      if (!_isCurrent(generation, manage: true)) return;
      _fail('Não foi possível cancelar a reserva. Tente novamente.');
    }
  }

  void _clearAttempt() {
    _pendingDraft = null;
    _pendingRequestId = null;
  }

  void _changeDraft(VoidCallback change) {
    setState(() {
      change();
      if (_pendingRequestId == null) {
        _pendingDraft = null;
        _justification.clear();
      }
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _busy = false;
      _error = message;
      _notice = null;
    });
  }

  String _occurrenceLabel(BuildContext context, LocationReservationOccurrence occurrence) {
    final start = occurrence.startsAt.toLocal();
    final end = occurrence.endsAt.toLocal();
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatFullDate(start)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start))} às '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end))}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.sessionAvailable || !widget.canRead) {
      return const CoeloStatePanel(
        key: Key('location-reservations-denied'),
        icon: Icons.lock_outline_rounded,
        title: 'Reservas indisponíveis',
        message: 'Sua sessão não permite consultar as reservas deste local.',
      );
    }
    if (!widget.gateway.available) {
      return const CoeloStatePanel(
        key: Key('location-reservations-unavailable'),
        icon: Icons.cloud_off_outlined,
        title: 'Reservas indisponíveis',
        message: 'O serviço de reservas não está disponível.',
      );
    }
    return Card(
      key: const Key('location-reservation-panel'),
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Reservas', style: theme.textTheme.titleMedium)),
                TextButton.icon(
                  key: const Key('location-reservation-reload'),
                  onPressed: _loading || _busy ? null : () => unawaited(_load(reset: true)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recarregar'),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space2),
            if (_loading && _policy == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text('Política de conflito', style: theme.textTheme.titleSmall),
              const SizedBox(height: CoeloSpacing.space2),
              CoeloAdminSingleSelectField<_PolicyChoice>(
                key: const Key('location-reservation-policy'),
                value: switch (_selectedPolicy) {
                  LocationSchedulingPolicy.block => _PolicyChoice.block,
                  LocationSchedulingPolicy.warn => _PolicyChoice.warn,
                  null => _PolicyChoice.unset,
                },
                label: 'Política',
                prefixIcon: Icons.rule_rounded,
                options: const [_PolicyChoice.unset, _PolicyChoice.block, _PolicyChoice.warn],
                optionLabel: (value) => switch (value) {
                  _PolicyChoice.unset => 'Escolha uma política',
                  _PolicyChoice.block => 'Bloquear sobreposição',
                  _PolicyChoice.warn => 'Alertar e exigir confirmação',
                },
                enabled: _mayManage && !_busy && _policyAttempt == null,
                onChanged: (value) => setState(
                  () => _selectedPolicy = switch (value) {
                    _PolicyChoice.unset => null,
                    _PolicyChoice.block => LocationSchedulingPolicy.block,
                    _PolicyChoice.warn => LocationSchedulingPolicy.warn,
                  },
                ),
              ),
              if (_policy?.policy == null) ...[
                const SizedBox(height: CoeloSpacing.space2),
                const Text(
                  'Nenhuma política foi definida. Escolha uma antes de reservar.',
                  key: Key('location-reservation-policy-unset'),
                ),
              ],
              const SizedBox(height: CoeloSpacing.space2),
              OutlinedButton.icon(
                key: const Key('location-reservation-policy-save'),
                onPressed: _mayManage && !_loading && !_busy && _selectedPolicy != null
                    ? () => unawaited(_savePolicy())
                    : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar política'),
              ),
              if (_mayManage && !_mayCreate) ...[
                const SizedBox(height: CoeloSpacing.space3),
                const Text(
                  _newReservationUnavailable,
                  key: Key('location-reservation-new-unavailable'),
                ),
              ],
              if (_mayCreate && _policy?.policy != null) ...[
                const SizedBox(height: CoeloSpacing.space4),
                Text('Nova reserva', style: theme.textTheme.titleSmall),
                const SizedBox(height: CoeloSpacing.space2),
                Text(
                  'Início e fim aparecem no horário deste dispositivo.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: CoeloSpacing.space2),
                Wrap(
                  spacing: CoeloSpacing.space2,
                  runSpacing: CoeloSpacing.space2,
                  children: [
                    SizedBox(
                      width: 280,
                      child: CoeloDateTimeField(
                        key: const Key('location-reservation-start'),
                        value: _startsAt,
                        onChanged: (value) => _changeDraft(() => _startsAt = value),
                        firstDate: DateTime(1),
                        lastDate: DateTime(9999, 12, 31),
                        labelText: 'Início',
                        emptyLabel: 'Definir início',
                        enabled: !_busy && _pendingRequestId == null,
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: CoeloDateTimeField(
                        key: const Key('location-reservation-end'),
                        value: _endsAt,
                        onChanged: (value) => _changeDraft(() => _endsAt = value),
                        firstDate: _startsAt ?? DateTime(1),
                        lastDate: DateTime(9999, 12, 31),
                        labelText: 'Fim',
                        emptyLabel: 'Definir fim',
                        enabled: !_busy && _pendingRequestId == null,
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: CoeloAdminSingleSelectField<bool>(
                        key: const Key('location-reservation-recurrence'),
                        value: _weekly,
                        label: 'Recorrência',
                        prefixIcon: Icons.repeat_rounded,
                        options: const [false, true],
                        optionLabel: (weekly) => weekly ? 'Semanal' : 'Uma vez',
                        enabled: !_busy && _pendingRequestId == null,
                        onChanged: (weekly) => _changeDraft(() => _weekly = weekly),
                      ),
                    ),
                  ],
                ),
                if (_weekly) ...[
                  const SizedBox(height: CoeloSpacing.space2),
                  Wrap(
                    spacing: CoeloSpacing.space2,
                    runSpacing: CoeloSpacing.space2,
                    children: [
                      SizedBox(
                        width: 220,
                        child: CoeloAdminMultiSelectField<int>(
                          key: const Key('location-reservation-weekdays'),
                          label: 'Dias da semana',
                          options: const [0, 1, 2, 3, 4, 5, 6],
                          selectedValues: _weekdays,
                          optionLabel: (value) => _weekdayLabels[value],
                          onChanged: (values) => _changeDraft(() {
                            _weekdays
                              ..clear()
                              ..addAll(values);
                          }),
                          prefixIcon: Icons.date_range_outlined,
                          enabled: !_busy && _pendingRequestId == null,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: CoeloDateRangeField(
                          key: const Key('location-reservation-until'),
                          value: _until == null
                              ? null
                              : DateTimeRange(start: _until!, end: _until!),
                          onChanged: (value) => _changeDraft(() => _until = value?.start),
                          firstDate: _startsAt ?? DateTime(1),
                          lastDate: DateTime(9999, 12, 31),
                          selectionMode: CoeloDateSelectionMode.single,
                          labelText: 'Repetir até',
                          enabled: !_busy && _pendingRequestId == null,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: CoeloFormTextField(
                          fieldKey: const Key('location-reservation-time-zone'),
                          controller: _timeZone,
                          onChanged: (_) => _changeDraft(() {}),
                          labelText: 'Fuso da recorrência',
                          prefixIcon: Icons.public_rounded,
                          enabled: !_busy && _pendingRequestId == null,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: CoeloSpacing.space3),
                FilledButton.icon(
                  key: const Key('location-reservation-assess'),
                  onPressed: !_loading && !_busy && _pendingRequestId == null
                      ? () => unawaited(_assess())
                      : null,
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(_busy ? 'Verificando…' : 'Verificar e reservar'),
                ),
              ],
              if (_mayCreate && _pendingDraft != null && _pendingRequestId == null) ...[
                const SizedBox(height: CoeloSpacing.space3),
                CoeloFormTextField(
                  fieldKey: const Key('location-reservation-justification'),
                  controller: _justification,
                  labelText: 'Justificativa da sobreposição',
                  prefixIcon: Icons.edit_note_rounded,
                  enabled: !_busy && widget.canOverride,
                  maxLength: 1000,
                ),
                const SizedBox(height: CoeloSpacing.space2),
                FilledButton(
                  key: const Key('location-reservation-confirm-conflict'),
                  onPressed: !_loading && !_busy && widget.canOverride
                      ? () => unawaited(_confirmConflict())
                      : null,
                  child: const Text('Confirmar sobreposição'),
                ),
              ],
              if (_pendingRequestId != null && !_busy) ...[
                const SizedBox(height: CoeloSpacing.space2),
                OutlinedButton.icon(
                  key: const Key('location-reservation-retry'),
                  onPressed: _loading ? null : () => unawaited(_retryCreate()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ],
              const SizedBox(height: CoeloSpacing.space4),
              Text('Reservas deste vínculo', style: theme.textTheme.titleSmall),
              const SizedBox(height: CoeloSpacing.space2),
              if (_items.isEmpty)
                const Text(
                  'Nenhuma reserva encontrada para este vínculo.',
                  key: Key('location-reservation-empty'),
                )
              else
                for (final reservation in _items)
                  Padding(
                    key: Key('location-reservation-${reservation.id}'),
                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_occurrenceLabel(context, reservation.occurrences.first)} · '
                            '${reservation.state == LocationReservationState.active ? 'Ativa' : 'Cancelada'}',
                          ),
                        ),
                        if (_mayManage && reservation.state == LocationReservationState.active)
                          OutlinedButton.icon(
                            key: Key('location-reservation-cancel-${reservation.id}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                            onPressed: _loading || _busy
                                ? null
                                : () => unawaited(_cancel(reservation)),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancelar reserva'),
                          ),
                      ],
                    ),
                  ),
              if (_nextId != null) ...[
                const SizedBox(height: CoeloSpacing.space2),
                OutlinedButton(
                  key: const Key('location-reservation-load-more'),
                  onPressed: _loading || _busy ? null : () => unawaited(_load(reset: false)),
                  child: Text(_loading ? 'Carregando…' : 'Carregar mais'),
                ),
              ],
            ],
            if (_notice case final notice?) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Semantics(
                liveRegion: true,
                child: Text(notice, key: const Key('location-reservation-notice')),
              ),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const Key('location-reservation-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _newReservationUnavailable =
    'Este local n\u00e3o est\u00e1 dispon\u00edvel para novas reservas.';
