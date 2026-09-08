import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/agenda_models.dart';
import '../domain/agenda_read_repository.dart';

final class SupabaseAgendaReadRepository implements AgendaReadRepository {
  const SupabaseAgendaReadRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<AgendaReadPage> fetchEvents({
    required DateTime from,
    required DateTime to,
    String? institutionId,
    String search = '',
    int limit = 100,
    int offset = 0,
  }) => _guard(() async {
    final data = await _rpc('superadmin_agenda_list_v2', {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_institution_id': institutionId,
      'p_search': search,
      'p_limit': limit,
      'p_offset': offset,
    });
    _fields(data, {'items', 'total_items', 'limit', 'offset', 'correlation_id'});
    final items = _list(data['items']).map((raw) => _item(raw, detail: false)).toList();
    final total = _integer(data['total_items']);
    final actualLimit = _integer(data['limit'], minimum: 1);
    final actualOffset = _integer(data['offset']);
    if (actualLimit != limit ||
        actualOffset != offset ||
        actualLimit > 200 ||
        items.length > actualLimit ||
        (items.isNotEmpty && total < actualOffset + items.length) ||
        items.map((item) => item.id).toSet().length != items.length ||
        (institutionId != null &&
            items.any((item) => item.institutionId != institutionId.toLowerCase()))) {
      throw const FormatException('Invalid Agenda page.');
    }
    return AgendaReadPage(
      items: items,
      total: total,
      limit: actualLimit,
      offset: actualOffset,
      correlationId: _uuid(data['correlation_id']),
    );
  });
  @override
  Future<AgendaReadDetail> fetchEvent(String id) => _guard(() async {
    final data = await _rpc('superadmin_agenda_get_v2', {'p_event_id': id});
    _fields(data, {'item', 'correlation_id'});
    final item = _item(data['item'], detail: true);
    if (item.id != id.toLowerCase()) throw const FormatException('Wrong Agenda resource.');
    return AgendaReadDetail(item: item, correlationId: _uuid(data['correlation_id']));
  });
  @override
  Future<AgendaReadContexts> fetchContexts() => _guard(() async {
    final data = await _rpc('superadmin_agenda_contexts_v2', const {});
    _fields(data, {'contexts', 'mutation_actions_available', 'correlation_id'});
    if (data['mutation_actions_available'] != false) {
      throw const FormatException('Invalid mutation availability.');
    }
    final contexts = _list(data['contexts']).map(_context).toList();
    if (contexts.map((context) => context.id).toSet().length != contexts.length) {
      throw const FormatException('Duplicate Agenda context.');
    }
    final byId = {for (final context in contexts) context.id: context};
    for (final context in contexts) {
      if (context.level == AgendaContextLevel.institution) {
        if (context.id != context.institutionId || context.parentId != null) {
          throw const FormatException('Invalid root context.');
        }
      } else {
        final parent = byId[context.parentId];
        if (parent == null ||
            parent.institutionId != context.institutionId ||
            (context.level == AgendaContextLevel.unit &&
                parent.level != AgendaContextLevel.institution) ||
            (context.level == AgendaContextLevel.group &&
                parent.level != AgendaContextLevel.unit) ||
            (context.level == AgendaContextLevel.activity &&
                parent.level != AgendaContextLevel.unit &&
                parent.level != AgendaContextLevel.institution)) {
          throw const FormatException('Invalid Agenda hierarchy.');
        }
      }
    }
    return AgendaReadContexts(contexts: contexts, correlationId: _uuid(data['correlation_id']));
  });

  Future<Map<String, Object?>> _rpc(String name, Map<String, Object?> params) async {
    final envelope = _map(await _client.rpc<Object?>(name, params: params));
    _fields(envelope, {'ok', 'data', 'error'});
    if (envelope['ok'] == true && envelope['error'] == null) {
      final data = _map(envelope['data']);
      _uuid(data['correlation_id']);
      return data;
    }
    if (envelope['ok'] != false || envelope['data'] != null) {
      throw const FormatException('Invalid Agenda envelope.');
    }
    final error = _map(envelope['error']);
    _fields(error, {'code', 'message', 'http_status', 'correlation_id'});
    final code = _string(error['code']);
    final status = _integer(error['http_status']);
    _string(error['message']); // Validate shape, never expose server details.
    final correlation = _uuid(error['correlation_id']);
    final expectedStatus = switch (code) {
      'SAI_AUTH_REQUIRED' || 'SAI_SESSION_INVALID' => 401,
      'SAI_INTERNAL_CONTEXT_DENIED' ||
      'SAI_MEMBERSHIP_SUSPENDED' ||
      'SAI_MEMBERSHIP_REVOKED' ||
      'SAI_PERMISSION_DENIED' ||
      'SAI_MFA_REQUIRED' => 403,
      'AGENDA_NOT_FOUND' => 404,
      'AGENDA_INVALID_ARGUMENT' => 400,
      'SAI_LAST_OWNER_PROTECTED' || 'SAI_CONCURRENT_CHANGE' => 409,
      'SAI_INTERNAL_ERROR' => 500,
      _ => null,
    };
    if (expectedStatus != status) throw const FormatException('Unknown Agenda denial.');
    throw AgendaReadException(
      switch (status) {
        401 || 403 => AgendaReadFailure.unauthorized,
        404 => AgendaReadFailure.notFound,
        400 => AgendaReadFailure.invalidArgument,
        _ => AgendaReadFailure.unavailable,
      },
      code: code,
      correlationId: correlation,
    );
  }

  Future<T> _guard<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on AgendaReadException {
      rethrow;
    } on PostgrestException catch (error) {
      throw AgendaReadException(
        {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)
            ? AgendaReadFailure.unauthorized
            : AgendaReadFailure.unavailable,
      );
    } on AuthException {
      throw const AgendaReadException(AgendaReadFailure.unauthorized);
    } on TypeError {
      throw const AgendaReadException(AgendaReadFailure.unavailable);
    } on Exception {
      throw const AgendaReadException(AgendaReadFailure.unavailable);
    }
  }
}

AgendaReadItem _item(Object? raw, {required bool detail}) {
  final json = _map(raw);
  _fields(json, {
    'id',
    'institution_id',
    'context_kind',
    'context_id',
    'title',
    'item_type',
    'priority',
    'status',
    'origin',
    'starts_at',
    'ends_at',
    'all_day',
    'time_zone_id',
    'location',
    'description',
    'response_mode',
    'guardian_response_policy',
    'recurrence',
    'audience',
    'reminders',
    'questions',
    'revision',
    if (detail) 'history',
  });
  final institution = _uuid(json['institution_id']);
  final audience = _map(json['audience']);
  _fields(audience, {
    'institutionId',
    'unitIds',
    'groupIds',
    'activityIds',
    'individual_details_available',
  });
  if (audience['individual_details_available'] != false ||
      _uuid(audience['institutionId']) != institution) {
    throw const FormatException('Invalid partial audience.');
  }
  final starts = _date(json['starts_at']);
  final ends = _date(json['ends_at']);
  if (!ends.isAfter(starts) || json['all_day'] is! bool) {
    throw const FormatException('Invalid event period.');
  }
  final contextKind = _enum(AgendaContextLevel.values, json['context_kind']);
  final contextId = _uuid(json['context_id']);
  if (contextKind == AgendaContextLevel.institution && contextId != institution) {
    throw const FormatException('Invalid institution context.');
  }
  final origin = _enum(AgendaItemOrigin.values, json['origin']);
  if (origin == AgendaItemOrigin.fixture) throw const FormatException('Nonproduction origin.');
  return AgendaReadItem(
    id: _uuid(json['id']),
    institutionId: institution,
    contextId: contextId,
    contextKind: contextKind,
    title: _string(json['title']),
    type: _enum(AgendaItemType.values, json['item_type']),
    priority: _enum(AgendaPriority.values, json['priority']),
    status: _enum(AgendaItemStatus.values, json['status']),
    origin: origin,
    startsAt: starts,
    endsAt: ends,
    allDay: json['all_day'] as bool,
    timeZoneId: _string(json['time_zone_id']),
    location: _string(json['location'], empty: true),
    description: _string(json['description'], empty: true),
    responseMode: _enum(AgendaResponseMode.values, json['response_mode']),
    guardianResponsePolicy: _enum(GuardianResponsePolicy.values, json['guardian_response_policy']),
    audience: AgendaReadAudience(
      institutionId: institution,
      unitIds: _ids(audience['unitIds']),
      groupIds: _ids(audience['groupIds']),
      activityIds: _ids(audience['activityIds']),
    ),
    recurrence: _recurrence(json['recurrence']),
    reminders: _list(json['reminders']).map((value) => _string(value, empty: true)).toSet(),
    questions: _list(json['questions']).map((raw) {
      final question = _map(raw);
      _fields(question, {'id', 'title', 'type'});
      return AgendaQuestion(
        id: _string(question['id']),
        title: _string(question['title']),
        type: _enum(AgendaQuestionType.values, question['type']),
      );
    }).toList(),
    revision: _integer(json['revision'], minimum: 1),
    history: detail ? _list(json['history']).map(_history).toList() : null,
  );
}

AgendaReadHistory _history(Object? raw) {
  final json = _map(raw);
  _fields(json, {'action', 'occurred_at', 'reason', 'previous_revision', 'next_revision'});
  final action = _string(json['action']);
  if (!{
    'create',
    'update',
    'cancel',
    'restore',
    'delete_draft',
    'request_publication',
    'approve_publication',
    'reject_publication',
    'approve_guardian_request',
    'reject_guardian_request',
    'override_reservation',
  }.contains(action)) {
    throw const FormatException('Unknown Agenda history.');
  }
  return AgendaReadHistory(
    action: action,
    occurredAt: _date(json['occurred_at']),
    reason: json['reason'] == null ? null : _string(json['reason']),
    previousRevision: json['previous_revision'] == null
        ? null
        : _integer(json['previous_revision'], minimum: 1),
    nextRevision: json['next_revision'] == null
        ? null
        : _integer(json['next_revision'], minimum: 1),
  );
}

AgendaRecurrence? _recurrence(Object? raw) {
  if (raw == null) return null;
  final json = _map(raw);
  const allowed = {'frequency', 'interval', 'until', 'occurrenceCount', 'exceptions'};
  if (!json.containsKey('frequency') || json.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Invalid recurrence shape.');
  }
  final frequency = _enum(AgendaRecurrenceFrequency.values, json['frequency']);
  final interval = json.containsKey('interval') ? _integer(json['interval'], minimum: 1) : 1;
  final until = json['until'] == null ? null : _date(json['until']);
  final count = json['occurrenceCount'] == null
      ? null
      : _integer(json['occurrenceCount'], minimum: 1);
  if ((until == null) == (count == null)) throw const FormatException('Invalid recurrence end.');
  final exceptions = Set<DateTime>.unmodifiable(
    (json.containsKey('exceptions') ? _list(json['exceptions']) : const <Object?>[]).map(_date),
  );
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

AgendaReadContext _context(Object? raw) {
  final json = _map(raw);
  _fields(json, {
    'id',
    'name',
    'institution_id',
    'parent_id',
    'level',
    'granted_capabilities',
    'restricted_capabilities',
  });
  Set<AgendaCapability> capabilities(Object? raw) {
    final list = _list(raw).map((value) => _enum(AgendaCapability.values, value)).toList();
    if (list.toSet().length != list.length) throw const FormatException('Duplicate capability.');
    return list.toSet();
  }

  final granted = capabilities(json['granted_capabilities']);
  final restricted = capabilities(json['restricted_capabilities']);
  if (granted.intersection(restricted).isNotEmpty ||
      granted.union(restricted).length != AgendaCapability.values.length) {
    throw const FormatException('Incomplete capability metadata.');
  }
  return AgendaReadContext(
    id: _uuid(json['id']),
    name: _string(json['name']),
    institutionId: _uuid(json['institution_id']),
    parentId: json['parent_id'] == null ? null : _uuid(json['parent_id']),
    level: _enum(AgendaContextLevel.values, json['level']),
    granted: granted,
    restricted: restricted,
  );
}

void _fields(Map<String, Object?> json, Set<String> keys) {
  if (json.length != keys.length || json.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('Unexpected Agenda projection.');
  }
}

Map<String, Object?> _map(Object? raw) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) {
    throw const FormatException('Expected object.');
  }
  return Map<String, Object?>.from(raw);
}

List<Object?> _list(Object? raw) {
  if (raw is! List) throw const FormatException('Expected list.');
  return List<Object?>.from(raw);
}

String _string(Object? raw, {bool empty = false}) {
  if (raw is! String || (!empty && raw.isEmpty)) throw const FormatException('Expected string.');
  return raw;
}

String _uuid(Object? raw) {
  final value = _string(raw);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    throw const FormatException('Expected UUID.');
  }
  return value.toLowerCase();
}

Set<String> _ids(Object? raw) {
  final values = _list(raw).map(_uuid).toList();
  if (values.toSet().length != values.length) throw const FormatException('Duplicate ID.');
  return values.toSet();
}

int _integer(Object? raw, {int minimum = 0}) {
  if (raw is! int || raw < minimum) throw const FormatException('Expected integer.');
  return raw;
}

DateTime _date(Object? raw) =>
    DateTime.tryParse(_string(raw)) ?? (throw const FormatException('Invalid date.'));
T _enum<T extends Enum>(List<T> values, Object? raw) {
  final name = _string(raw);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw const FormatException('Unknown enum.');
}
