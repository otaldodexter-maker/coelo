import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/agenda_models.dart';
import '../domain/agenda_repository.dart';

final class SupabaseAgendaRepository extends AgendaRepository {
  SupabaseAgendaRepository(
    this._client, {
    List<AgendaContext> contexts = const [],
    DateTime Function()? clock,
    String Function()? requestId,
  }) : _contexts = List.unmodifiable(contexts),
       _clock = clock ?? DateTime.now,
       _requestId = requestId ?? _uuid;

  final SupabaseClient _client;
  final DateTime Function() _clock;
  final String Function() _requestId;
  final List<AgendaContext> _contexts;
  List<AgendaItem> _items = const [];
  List<GuardianBirthdayRequest> _requests = const [];
  List<AgendaPublicationRequest> _publicationRequests = const [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastSavedItemId;

  @override
  DateTime get referenceDate => _clock();
  @override
  List<AgendaItem> get items => List.unmodifiable(_items);
  @override
  List<AgendaContext> get contexts => _contexts;
  @override
  List<GuardianBirthdayRequest> get requests => List.unmodifiable(_requests);
  @override
  List<AgendaPublicationRequest> get publicationRequests => List.unmodifiable(_publicationRequests);
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  String? get lastSavedItemId => _lastSavedItemId;
  @override
  bool get supportsOccurrenceScopedEdits => false;

  @override
  AgendaItem? itemById(String id) => _firstOrNull(_items.where((item) => item.id == id));
  @override
  GuardianBirthdayRequest? requestById(String id) =>
      _firstOrNull(_requests.where((request) => request.id == id));

  @override
  Future<void> loadEvents({
    required DateTime from,
    required DateTime to,
    String? institutionId,
    String search = '',
  }) => _load(() async {
    final value = _map(
      await _client.rpc<Object?>(
        'superadmin_agenda_list',
        params: <String, Object?>{
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
          'p_institution_id': institutionId,
          'p_search': search,
          'p_limit': 200,
          'p_offset': 0,
        },
      ),
    );
    _items = _list(value['items']).map(_item).toList(growable: false);
  });

  @override
  Future<void> loadItem(String id) => _load(() async {
    _upsertItem(
      _item(await _client.rpc<Object?>('superadmin_agenda_get', params: {'p_event_id': id})),
    );
  });

  @override
  Future<void> loadRequests() => _load(() async {
    final values = await Future.wait<Object?>([
      _client.rpc<Object?>(
        'superadmin_agenda_requests',
        params: const {'p_kind': 'publication', 'p_status': null, 'p_limit': 50, 'p_offset': 0},
      ),
      _client.rpc<Object?>(
        'superadmin_agenda_requests',
        params: const {'p_kind': 'guardian', 'p_status': null, 'p_limit': 50, 'p_offset': 0},
      ),
    ]);
    _publicationRequests = _list(values[0]).map(_publicationRequest).toList(growable: false);
    _requests = _list(values[1]).map(_guardianRequest).toList(growable: false);
  });

  @override
  Future<AgendaMutationResult> requestPublication(String itemId, {required String requestedBy}) =>
      _command(itemId, 'request_publication');

  @override
  Future<AgendaMutationResult> decidePublicationRequest({
    required String requestId,
    required bool approve,
    required String decidedBy,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) return AgendaMutationResult.reasonRequired;
    try {
      final mapped = _publicationRequest(
        await _client.rpc<Object?>(
          'superadmin_agenda_decide_publication',
          params: {
            'p_request_id': _requestId(),
            'p_publication_request_id': requestId,
            'p_approve': approve,
            'p_reason': reason.trim(),
          },
        ),
      );
      final index = _publicationRequests.indexWhere((request) => request.id == mapped.id);
      _publicationRequests = [..._publicationRequests];
      if (index < 0) {
        _publicationRequests = [..._publicationRequests, mapped];
      } else {
        _publicationRequests[index] = mapped;
      }
      await loadItem(mapped.itemId);
      return AgendaMutationResult.success;
    } on PostgrestException catch (error) {
      return _mutationError(error);
    } on FormatException {
      return AgendaMutationResult.unavailable;
    }
  }

  @override
  Future<AgendaMutationResult> cancelItem(String id, {required String actorName}) =>
      _command(id, 'cancel');

  @override
  Future<AgendaMutationResult> restoreItem(
    String id, {
    required String actorName,
    String? actorContextId,
    bool overrideConflict = false,
    String? reason,
  }) => _command(id, 'restore', reason: reason);

  @override
  Future<AgendaMutationResult> deleteDraft(String id) => _command(id, 'delete_draft');

  @override
  Future<AgendaMutationResult> recordOccurrenceEdit({
    required String itemId,
    required DateTime occurrenceStartsAt,
    required AgendaOccurrenceEditScope scope,
    required String actorName,
  }) async => scope == AgendaOccurrenceEditScope.series
      ? AgendaMutationResult.success
      : AgendaMutationResult.unavailable;

  @override
  Future<AgendaMutationResult> saveItem(
    AgendaItem item, {
    required String actorContextId,
    String actorName = 'Owner Coelo',
    bool overrideConflict = false,
    String? reason,
  }) async {
    final existing = itemById(item.id);
    try {
      final saved = _item(
        await _client.rpc<Object?>(
          'superadmin_agenda_save',
          params: {
            'p_request_id': _requestId(),
            'p_event_id': existing?.id,
            'p_expected_revision': existing?.revision,
            'p_payload': _payload(item),
            'p_reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
            'p_override_reservation': overrideConflict,
          },
        ),
      );
      _lastSavedItemId = saved.id;
      _upsertItem(saved);
      notifyListeners();
      return AgendaMutationResult.success;
    } on PostgrestException catch (error) {
      return _mutationError(error);
    } on FormatException {
      return AgendaMutationResult.unavailable;
    }
  }

  @override
  List<AgendaItem> itemsForInstitution(String id) =>
      _items.where((item) => item.audience.institutionId == id).toList(growable: false);

  @override
  List<AgendaItem> itemsForContext(String id) =>
      _items.where((item) => item.audience.includesContext(contextId: id)).toList(growable: false);

  @override
  List<AgendaOccurrence> occurrencesBetween(DateTime start, DateTime end) {
    final result = <AgendaOccurrence>[];
    for (final item in _items) {
      if (item.recurrence == null) {
        if (item.startsAt.isBefore(end) && item.endsAt.isAfter(start)) {
          result.add(AgendaOccurrence(item: item, startsAt: item.startsAt, endsAt: item.endsAt));
        }
        continue;
      }
      var current = item.startsAt;
      var emitted = 0;
      final recurrence = item.recurrence!;
      while (current.isBefore(end) &&
          (recurrence.until == null || !current.isAfter(recurrence.until!)) &&
          (recurrence.occurrenceCount == null || emitted < recurrence.occurrenceCount!)) {
        if (!recurrence.isException(current) && current.add(item.duration).isAfter(start)) {
          result.add(
            AgendaOccurrence(item: item, startsAt: current, endsAt: current.add(item.duration)),
          );
        }
        emitted++;
        current = _nextOccurrence(current, item.startsAt.day, recurrence);
      }
    }
    return result..sort(AgendaOccurrence.compareChronologically);
  }

  @override
  PermissionResolution resolveCapability(String contextId, AgendaCapability capability) {
    var current = _firstOrNull(_contexts.where((value) => value.id == contextId));
    if (current == null) return const PermissionResolution(state: PermissionState.restrictedHere);
    while (current != null) {
      if (current.restrictedCapabilities.contains(capability)) {
        return PermissionResolution(
          state: current.id == contextId
              ? PermissionState.restrictedHere
              : PermissionState.blockedByAncestor,
          blockedByContextName: current.name,
        );
      }
      if (current.grantedCapabilities.contains(capability)) {
        return PermissionResolution(
          state: current.id == contextId ? PermissionState.allowed : PermissionState.inherited,
          grantedByContextName: current.name,
        );
      }
      final parentId = current.parentId;
      current = parentId == null
          ? null
          : _firstOrNull(_contexts.where((value) => value.id == parentId));
    }
    return const PermissionResolution(state: PermissionState.restrictedHere);
  }

  @override
  bool setCapabilityRestricted(String contextId, AgendaCapability capability, bool restricted) =>
      false;

  @override
  Future<RequestDecisionResult> decideRequest({
    required String requestId,
    required String actorContextId,
    required String actorName,
    required bool approve,
    String? reason,
  }) async => RequestDecisionResult.notAuthorized;

  Future<AgendaMutationResult> _command(String id, String action, {String? reason}) async {
    final item = itemById(id);
    if (item == null) return AgendaMutationResult.notFound;
    try {
      final value = _map(
        await _client.rpc<Object?>(
          'superadmin_agenda_command',
          params: {
            'p_request_id': _requestId(),
            'p_event_id': id,
            'p_expected_revision': item.revision,
            'p_action': action,
            'p_reason': reason,
          },
        ),
      );
      if (value['deleted'] == true) {
        _items = _items.where((candidate) => candidate.id != id).toList(growable: false);
      } else if (value['event'] is Map) {
        _upsertItem(_item(value['event']));
      } else {
        _upsertItem(_item(value));
      }
      if (action == 'request_publication') await loadRequests();
      notifyListeners();
      return AgendaMutationResult.success;
    } on PostgrestException catch (error) {
      return _mutationError(error);
    } on FormatException {
      return AgendaMutationResult.unavailable;
    }
  }

  Future<void> _load(Future<void> Function() operation) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } on PostgrestException catch (error) {
      _errorMessage = error.code == '42501'
          ? 'Você não tem permissão para consultar a Agenda.'
          : 'Não foi possível carregar a Agenda.';
    } on FormatException {
      _errorMessage = 'A Agenda retornou dados inválidos.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _upsertItem(AgendaItem item) {
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    _items = [..._items];
    if (index < 0) {
      _items = [..._items, item];
    } else {
      _items[index] = item;
    }
  }
}

Map<String, Object?> _payload(AgendaItem item) {
  final context = item.audience.activityIds.isNotEmpty
      ? ('activity', item.audience.activityIds.first)
      : item.audience.groupIds.isNotEmpty
      ? ('group', item.audience.groupIds.first)
      : item.audience.unitIds.isNotEmpty
      ? ('unit', item.audience.unitIds.first)
      : ('institution', item.audience.institutionId);
  return {
    'institutionId': item.audience.institutionId,
    'contextKind': context.$1,
    'contextId': context.$2,
    'title': item.title,
    'type': item.type.name,
    'priority': item.priority.name,
    'status': item.status.name,
    'origin': item.origin == AgendaItemOrigin.guardianRequest ? 'guardianRequest' : 'institution',
    'startsAt': item.startsAt.toUtc().toIso8601String(),
    'endsAt': item.endsAt.toUtc().toIso8601String(),
    'allDay': item.allDay,
    'timeZoneId': item.timeZoneId,
    'location': item.location,
    'description': item.description,
    'responseMode': item.responseMode.name,
    'guardianResponsePolicy': item.guardianResponsePolicy.name,
    'recurrence': _recurrenceJson(item.recurrence),
    'audience': {
      'institutionId': item.audience.institutionId,
      'unitIds': item.audience.unitIds.toList(growable: false),
      'groupIds': item.audience.groupIds.toList(growable: false),
      'activityIds': item.audience.activityIds.toList(growable: false),
      'personIds': item.audience.personIds.toList(growable: false),
    },
    'reminders': item.reminders.toList(growable: false),
    'questions': [
      for (final question in item.questions)
        {'id': question.id, 'title': question.title, 'type': question.type.name},
    ],
  };
}

AgendaItem _item(Object? raw) {
  final json = _map(raw);
  final audience = _map(json['audience']);
  final institutionId = _required(json, 'institution_id');
  return AgendaItem(
    id: _required(json, 'id'),
    title: _required(json, 'title'),
    type: _enum(AgendaItemType.values, _required(json, 'item_type')),
    audience: AgendaAudience(
      institutionId: audience['institutionId']?.toString() ?? institutionId,
      unitIds: _strings(audience['unitIds']),
      groupIds: _strings(audience['groupIds']),
      activityIds: _strings(audience['activityIds']),
      personIds: _strings(audience['personIds']),
    ),
    priority: _enum(AgendaPriority.values, _required(json, 'priority')),
    status: _enum(AgendaItemStatus.values, _required(json, 'status')),
    origin: _enum(AgendaItemOrigin.values, _required(json, 'origin')),
    startsAt: _date(json, 'starts_at'),
    endsAt: _date(json, 'ends_at'),
    location: json['location']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    recurrence: _recurrence(json['recurrence']),
    allDay: json['all_day'] == true,
    requiresRsvp: json['response_mode'] == 'rsvp',
    timeZoneId: json['time_zone_id']?.toString() ?? 'America/Sao_Paulo',
    responseMode: _enum(AgendaResponseMode.values, json['response_mode']?.toString() ?? 'none'),
    guardianResponsePolicy: _enum(
      GuardianResponsePolicy.values,
      json['guardian_response_policy']?.toString() ?? 'oneIsEnough',
    ),
    audienceLabels: _strings(audience['labels']),
    reminders: _strings(json['reminders']),
    questions: _list(json['questions'])
        .map((value) {
          final question = _map(value);
          return AgendaQuestion(
            id: _required(question, 'id'),
            title: _required(question, 'title'),
            type: _enum(AgendaQuestionType.values, _required(question, 'type')),
          );
        })
        .toList(growable: false),
    history: _list(json['history']).map(_history).whereType<AgendaHistoryEntry>().toList(),
    revision: _integer(json['revision'], fallback: 1),
  );
}

AgendaHistoryEntry? _history(Object? raw) {
  final json = _map(raw);
  final action = switch (json['action']) {
    'cancel' => AgendaHistoryAction.canceled,
    'restore' => AgendaHistoryAction.restored,
    'override_reservation' => AgendaHistoryAction.reservationConflictOverridden,
    _ => null,
  };
  if (action == null) return null;
  return AgendaHistoryEntry(
    action: action,
    actorName: 'Sistema Coelo',
    occurredAt: _date(json, 'occurred_at'),
    reason: json['reason']?.toString(),
  );
}

AgendaPublicationRequest _publicationRequest(Object? raw) {
  final json = _map(raw);
  final itemId = _required(json, 'event_id');
  return AgendaPublicationRequest(
    id: _required(json, 'id'),
    itemId: itemId,
    title: json['title']?.toString() ?? 'Evento $itemId',
    contextLabel: json['institution_id']?.toString() ?? 'Contexto institucional',
    requestedBy: json['requested_by_person_id']?.toString() ?? 'Usuário interno',
    requestedAt: _date(json, 'requested_at'),
    status: _enum(AgendaPublicationRequestStatus.values, json['status']?.toString() ?? 'pending'),
    decidedBy: json['decided_by_person_id']?.toString(),
    decidedAt: _nullableDate(json['decided_at']),
    reason: json['reason']?.toString(),
  );
}

GuardianBirthdayRequest _guardianRequest(Object? raw) {
  final json = _map(raw);
  final child = _required(json, 'child_person_id');
  final guardian = _required(json, 'guardian_person_id');
  return GuardianBirthdayRequest(
    id: _required(json, 'id'),
    childId: child,
    childName: child,
    guardianName: guardian,
    contextId: _required(json, 'context_id'),
    institutionId: _required(json, 'institution_id'),
    title: _required(json, 'title'),
    startsAt: _date(json, 'starts_at'),
    endsAt: _date(json, 'ends_at'),
    status: _enum(GuardianRequestStatus.values, _required(json, 'status')),
    details: json['details']?.toString() ?? '',
    decision: json['decided_at'] == null
        ? null
        : GuardianRequestDecision(
            approved: json['status'] == 'approved' || json['status'] == 'convertedToDraft',
            actorName: json['decided_by_person_id']?.toString() ?? 'Usuário interno',
            actorContextId: _required(json, 'context_id'),
            decidedAt: _date(json, 'decided_at'),
            reason: json['decision_reason']?.toString(),
          ),
    linkedAgendaItemId: json['linked_event_id']?.toString(),
  );
}

AgendaRecurrence? _recurrence(Object? raw) {
  if (raw == null) return null;
  final json = _map(raw);
  final frequency = _enum(AgendaRecurrenceFrequency.values, _required(json, 'frequency'));
  final interval = _integer(json['interval'], fallback: 1);
  final until = _nullableDate(json['until']);
  final count = json['occurrenceCount'] == null ? null : _integer(json['occurrenceCount']);
  if ((until == null) == (count == null)) throw const FormatException('Invalid recurrence end.');
  final exceptions = _strings(json['exceptions']).map(DateTime.parse).toSet();
  return switch (frequency) {
    AgendaRecurrenceFrequency.daily => AgendaRecurrence.daily(
      interval: interval,
      until: until,
      occurrenceCount: count,
      exceptions: exceptions,
    ),
    AgendaRecurrenceFrequency.weekly => AgendaRecurrence.weekly(
      interval: interval,
      until: until,
      occurrenceCount: count,
      exceptions: exceptions,
    ),
    AgendaRecurrenceFrequency.monthly => AgendaRecurrence.monthly(
      interval: interval,
      until: until,
      occurrenceCount: count,
      exceptions: exceptions,
    ),
  };
}

Map<String, Object?>? _recurrenceJson(AgendaRecurrence? value) => value == null
    ? null
    : {
        'frequency': value.frequency.name,
        'interval': value.interval,
        'until': value.until?.toUtc().toIso8601String(),
        'occurrenceCount': value.occurrenceCount,
        'exceptions': value.exceptions.map((date) => date.toUtc().toIso8601String()).toList(),
      };

AgendaMutationResult _mutationError(PostgrestException error) => switch (error.code) {
  '23P01' => AgendaMutationResult.reservationConflict,
  '42501' || 'PGRST301' || 'PGRST302' => AgendaMutationResult.notAuthorized,
  'P0002' || 'PGRST116' => AgendaMutationResult.notFound,
  '40001' => AgendaMutationResult.conflict,
  '22023' when error.message.contains('reason') => AgendaMutationResult.reasonRequired,
  '22023' => AgendaMutationResult.invalidLifecycle,
  _ => AgendaMutationResult.unavailable,
};

DateTime _nextOccurrence(DateTime current, int baseDay, AgendaRecurrence recurrence) =>
    switch (recurrence.frequency) {
      AgendaRecurrenceFrequency.daily => current.add(Duration(days: recurrence.interval)),
      AgendaRecurrenceFrequency.weekly => current.add(Duration(days: recurrence.interval * 7)),
      AgendaRecurrenceFrequency.monthly => _monthOccurrence(current, baseDay, recurrence.interval),
    };

DateTime _monthOccurrence(DateTime current, int baseDay, int interval) {
  final monthStart = DateTime(current.year, current.month + interval);
  final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  return DateTime(
    monthStart.year,
    monthStart.month,
    math.min(baseDay, lastDay),
    current.hour,
    current.minute,
    current.second,
    current.millisecond,
    current.microsecond,
  );
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw const FormatException('Invalid Agenda payload.');
}

List<Object?> _list(Object? value) => value is List ? List<Object?>.from(value) : const <Object?>[];
Set<String> _strings(Object? value) => _list(value).map((entry) => entry.toString()).toSet();
String _required(Map<String, Object?> value, String key) {
  final field = value[key]?.toString().trim() ?? '';
  if (field.isEmpty) throw FormatException('Missing Agenda field: $key.');
  return field;
}

int _integer(Object? value, {int? fallback}) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed != null) return parsed;
  if (fallback != null) return fallback;
  throw const FormatException('Invalid Agenda integer.');
}

DateTime _date(Map<String, Object?> value, String key) =>
    _nullableDate(value[key]) ?? (throw FormatException('Invalid Agenda date: $key.'));
DateTime? _nullableDate(Object? value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal();
T _enum<T extends Enum>(List<T> values, String name) => values.firstWhere(
  (value) => value.name == name,
  orElse: () => throw FormatException('Invalid Agenda enum: $name.'),
);
T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;

String _uuid() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final source = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${source.substring(0, 8)}-${source.substring(8, 12)}-${source.substring(12, 16)}-${source.substring(16, 20)}-${source.substring(20)}';
}
