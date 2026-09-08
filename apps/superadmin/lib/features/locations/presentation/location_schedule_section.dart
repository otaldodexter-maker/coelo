import 'dart:async';

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_writer.dart';
import 'location_form_panel.dart' show newLocationRequestId;

const _weekdays = <String>[
  'Domingo',
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
];

/// Formats minutes from midnight the way the operator reads a clock.
///
/// 1440 is midnight at the end of the day and is shown as 24:00, not 00:00: the
/// two are the same instant but not the same statement, and a window that ends
/// at 00:00 would read as a window that ends before it starts.
String locationScheduleTime(int minute) {
  final hour = minute ~/ 60;
  final rest = minute % 60;
  return '${hour.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

/// Parses HH:MM into minutes from midnight, or null when it is not a time.
int? parseLocationScheduleTime(String value) {
  final match = RegExp(r'^([0-9]{1,2}):([0-5][0-9])$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 24 || (hour == 24 && minute != 0)) return null;
  return hour * 60 + minute;
}

/// Publishes the weekly availability of one location.
///
/// Reading is on demand: the detail already spends a round trip, and an actor
/// who never opens the schedule should not pay for a second one. Publishing
/// replaces the whole week, because a half-applied week is not a week.
class LocationScheduleSection extends StatefulWidget {
  const LocationScheduleSection({
    required this.entry,
    required this.writer,
    required this.onPublished,
    this.enabled = true,
    this.requestIdFactory,
    super.key,
  });

  final LocationCatalogEntry entry;
  final LocationCatalogWriter writer;

  /// The location version moved, so the detail reads again.
  final VoidCallback onPublished;

  final bool enabled;
  final String Function()? requestIdFactory;

  @override
  State<LocationScheduleSection> createState() => _LocationScheduleSectionState();
}

class _LocationScheduleSectionState extends State<LocationScheduleSection> {
  final _start = TextEditingController(text: '08:00');
  final _end = TextEditingController(text: '12:00');

  LocationSchedule? _schedule;
  List<LocationScheduleWindow>? _draft;
  int _weekday = 1;
  bool _busy = false;
  String? _error;
  String? _windowError;
  String? _requestId;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different location, or a version that moved, means what is held here is
    // about something else.
    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.managementVersion != widget.entry.managementVersion) {
      _schedule = null;
      _draft = null;
      _error = null;
      _windowError = null;
      _requestId = null;
    }
  }

  bool get _dirty {
    final draft = _draft;
    final schedule = _schedule;
    if (draft == null || schedule == null) return false;
    if (draft.length != schedule.windows.length) return true;
    for (var index = 0; index < draft.length; index++) {
      if (draft[index] != schedule.windows[index]) return true;
    }
    return false;
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final schedule = await widget.writer.readSchedule(locationId: widget.entry.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _schedule = schedule;
        _draft = [...schedule.windows];
      });
    } on LocationWriteDeniedException {
      _fail('Você não tem permissão para ver a agenda deste local.');
    } on Object {
      _fail('Não foi possível carregar a agenda. Tente novamente.');
    }
  }

  void _add() {
    final draft = _draft;
    if (draft == null) return;
    final start = parseLocationScheduleTime(_start.text);
    final end = parseLocationScheduleTime(_end.text);
    if (start == null || end == null || start >= end || start > 1439 || end > 1440) {
      setState(() => _windowError = 'Use HH:MM, com início antes do fim e dentro do dia.');
      return;
    }
    final window = LocationScheduleWindow(
      weekday: _weekday,
      startsMinute: start,
      endsMinute: end,
    );
    if (draft.any(window.overlaps)) {
      // The catalog refuses an overlap too. Saying so here means the actor sees
      // which window is in the way while it is still on screen.
      setState(() => _windowError = 'Esse horário se sobrepõe a outra janela do mesmo dia.');
      return;
    }
    setState(() {
      _windowError = null;
      _draft = [...draft, window]..sort();
    });
  }

  void _remove(LocationScheduleWindow window) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _windowError = null;
      _draft = [...draft]..remove(window);
    });
  }

  Future<void> _publish() async {
    final draft = _draft;
    if (_busy || draft == null) return;
    final requestId = _requestId ??= (widget.requestIdFactory ?? newLocationRequestId)();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final schedule = await widget.writer.setSchedule(
        locationId: widget.entry.id,
        windows: draft,
        expectedVersion: widget.entry.managementVersion,
        requestId: requestId,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _schedule = schedule;
        _draft = [...schedule.windows];
        _requestId = null;
      });
      widget.onPublished();
    } on LocationWriteRejectedException {
      _requestId = null;
      _fail('Esta semana não pode ser publicada. Revise as janelas.');
    } on LocationWriteDeniedException {
      _fail('Você não tem permissão para publicar a agenda deste local.');
    } on LocationWriteConflictException {
      _fail('Alguém mudou este local enquanto a tela estava aberta. Recarregue antes de publicar.');
    } on Object {
      _fail('Não foi possível publicar a agenda. Tente novamente.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draft;
    return Card(
      key: const Key('location-schedule-section'),
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agenda semanal', style: theme.textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.space2),
            if (draft == null) ...[
              Text(
                'A agenda é carregada quando você pede, para não custar uma consulta a quem '
                'só veio ver o local.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              OutlinedButton.icon(
                key: const Key('location-schedule-load'),
                onPressed: widget.enabled && !_busy ? () => unawaited(_load()) : null,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(_busy ? 'Carregando…' : 'Ver agenda'),
              ),
            ] else ...[
              if (draft.isEmpty)
                Text(
                  // Silence is not a declaration, and the screen must not let
                  // anyone read it as one.
                  'Nenhuma janela publicada. Isso não quer dizer aberto sempre: quer dizer que '
                  'nada foi declarado.',
                  key: const Key('location-schedule-empty'),
                  style: theme.textTheme.bodyMedium,
                )
              else
                for (final window in draft)
                  Padding(
                    key: Key(
                      'location-schedule-window-${window.weekday}-${window.startsMinute}',
                    ),
                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_weekdays[window.weekday]} · '
                            '${locationScheduleTime(window.startsMinute)} às '
                            '${locationScheduleTime(window.endsMinute)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          key: Key(
                            'location-schedule-remove-${window.weekday}-${window.startsMinute}',
                          ),
                          onPressed: widget.enabled && !_busy ? () => _remove(window) : null,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            semanticLabel:
                                'Remover ${_weekdays[window.weekday]} '
                                '${locationScheduleTime(window.startsMinute)}',
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: CoeloSpacing.space3),
              Wrap(
                spacing: CoeloSpacing.space2,
                runSpacing: CoeloSpacing.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<int>(
                      key: const Key('location-schedule-weekday'),
                      initialValue: _weekday,
                      // Constrained width plus a day name that can be long: let
                      // the text shrink to the box instead of overflowing it.
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Dia'),
                      items: [
                        for (var index = 0; index < _weekdays.length; index++)
                          DropdownMenuItem(value: index, child: Text(_weekdays[index])),
                      ],
                      onChanged: widget.enabled && !_busy
                          ? (value) => setState(() => _weekday = value ?? _weekday)
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: CoeloFormTextField(
                      fieldKey: const Key('location-schedule-start'),
                      controller: _start,
                      labelText: 'Início',
                      prefixIcon: Icons.schedule_rounded,
                      enabled: widget.enabled && !_busy,
                      maxLength: 5,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: CoeloFormTextField(
                      fieldKey: const Key('location-schedule-end'),
                      controller: _end,
                      labelText: 'Fim',
                      prefixIcon: Icons.schedule_rounded,
                      enabled: widget.enabled && !_busy,
                      maxLength: 5,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('location-schedule-add'),
                    onPressed: widget.enabled && !_busy ? _add : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar janela'),
                  ),
                ],
              ),
              if (_windowError case final message?) ...[
                const SizedBox(height: CoeloSpacing.space2),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const Key('location-schedule-window-error'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: CoeloSpacing.space3),
              FilledButton(
                key: const Key('location-schedule-publish'),
                onPressed: widget.enabled && !_busy && _dirty ? () => unawaited(_publish()) : null,
                child: Text(_busy ? 'Publicando…' : 'Publicar semana'),
              ),
            ],
            if (_error case final message?) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  key: const Key('location-schedule-error'),
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
