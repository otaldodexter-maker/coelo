import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/audit.dart';

/// RPC-only adapter. Authorization, tenant scope and minimization stay in SQL/RLS.
final class SupabaseAuditRepository implements AuditRepository {
  const SupabaseAuditRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AuditPage> fetchPage(AuditQuery query) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'audit_list_events_for_superadmin',
          params: {
            'p_search': query.search.trim(),
            'p_actor_ids': query.actorIds.toList(growable: false),
            'p_context_kinds': query.contextKinds.toList(growable: false),
            'p_action_codes': query.actionCodes.toList(growable: false),
            'p_resource_types': query.resourceTypes.toList(growable: false),
            'p_outcomes': query.outcomes
                .map((outcome) => outcome.databaseValue)
                .toList(growable: false),
            'p_origins': query.origins.toList(growable: false),
            'p_institution_id': query.institutionId,
            'p_from': _timestamp(query.from),
            'p_to': _timestamp(query.to),
            'p_cursor_occurred_at': _timestamp(query.cursor?.occurredAt),
            'p_cursor_id': query.cursor?.eventId,
            'p_limit': query.pageSize,
          },
        ),
      );
      final cursorPayload = payload['next_cursor'];
      final cursor = cursorPayload == null ? null : _cursor(_map(cursorPayload));
      final hasMore = _boolean(payload, 'has_more');
      if (hasMore != (cursor != null)) throw const AuditUnavailableException();
      return AuditPage(
        events: _rows(payload['items']).map(_event).toList(growable: false),
        hasMore: hasMore,
        nextCursor: cursor,
        totalCount: _integer(payload, 'total_count'),
        canExport: _boolean(payload, 'can_export'),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<AuditEventDetail> fetchDetail(String eventId) async {
    try {
      final response = await _client.rpc<Object?>(
        'audit_get_event_for_superadmin',
        params: {'p_event_id': eventId},
      );
      if (response == null) throw const AuditNotFoundException();
      final payload = _map(response);
      return AuditEventDetail(
        event: _event(payload),
        before: _objectMap(payload['before']),
        after: _objectMap(payload['after']),
        reason: _optionalString(payload['reason']),
        integrity: _integrity(_map(payload['integrity'])),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<AuditExportJob> startExport(AuditExportRequest request) async {
    final query = request.query.withoutCursor();
    return _invokeExport({
      'action': 'generate',
      'format': request.format.name,
      'filters': _exportFilters(query),
      'idempotency_key': request.idempotencyKey,
    });
  }

  @override
  Future<AuditExportJob> fetchExportStatus(String jobId) =>
      _invokeExport({'action': 'status', 'job_id': jobId});

  Future<AuditExportJob> _invokeExport(Map<String, Object?> body) async {
    try {
      final response = await _client.functions.invoke('audit-export', body: body);
      if (response.status < 200 || response.status >= 300) {
        throw const AuditUnavailableException();
      }
      return _exportJob(_map(response.data));
    } on FunctionException catch (error) {
      if (error.status == 401 || error.status == 403) {
        throw const AuditUnauthorizedException();
      }
      if (error.status == 400 || error.status == 409) {
        throw const AuditValidationException();
      }
      throw const AuditUnavailableException();
    } catch (error) {
      throw _mapError(error);
    }
  }
}

Map<String, Object?> _exportFilters(AuditQuery query) {
  final from = _timestamp(query.from);
  final to = _timestamp(query.to);
  return {
    if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
    if (query.actorIds.isNotEmpty) 'actor_ids': query.actorIds.toList(growable: false),
    if (query.contextKinds.isNotEmpty) 'context_kinds': query.contextKinds.toList(growable: false),
    if (query.actionCodes.isNotEmpty) 'action_codes': query.actionCodes.toList(growable: false),
    if (query.resourceTypes.isNotEmpty)
      'resource_types': query.resourceTypes.toList(growable: false),
    if (query.outcomes.isNotEmpty)
      'outcomes': query.outcomes.map((outcome) => outcome.databaseValue).toList(growable: false),
    if (query.origins.isNotEmpty) 'origins': query.origins.toList(growable: false),
    'institution_id': ?query.institutionId,
    'from': ?from,
    'to': ?to,
  };
}

AuditExportJob _exportJob(Map<String, Object?> payload) {
  final summary = payload['summary'] == null ? const <String, Object?>{} : _map(payload['summary']);
  return AuditExportJob(
    id: _string(payload, 'job_id'),
    status: AuditExportStatus.fromDatabase(_string(payload, 'state')),
    format: _enumByName(AuditExportFormat.values, _string(payload, 'format')),
    createdAt: _optionalDate(payload['created_at']),
    phase: _optionalString(summary['phase']),
    rowCount: _optionalInteger(payload['row_count']) ?? _optionalInteger(summary['row_count']),
    retentionExpiresAt: _optionalDate(summary['retention_expires_at']),
    errorCode: _optionalString(payload['error_code']),
    downloadUrl: _safeHttpsUri(payload['download_url']),
    downloadExpiresInSeconds: _optionalInteger(payload['expires_in']),
  );
}

AuditEvent _event(Map<String, Object?> json) => AuditEvent(
  id: _string(json, 'id'),
  actor: _actor(_map(json['actor'])),
  institution: json['institution'] == null ? null : _institution(_map(json['institution'])),
  actionCode: _string(json, 'action_code'),
  resourceType: _optionalString(json['object_type']),
  resourceId: _optionalString(json['object_id']),
  outcome: AuditOutcome.fromDatabase(_string(json, 'outcome')),
  correlationId: _optionalString(json['correlation_id']),
  origin: _string(json, 'origin'),
  context: _context(_map(json['context'])),
  occurredAt: _date(json, 'occurred_at'),
);

AuditActor _actor(Map<String, Object?> json) => AuditActor(
  id: _optionalString(json['id']),
  displayName: _string(json, 'display_name'),
  roleCode: _string(json, 'role_code'),
);

AuditInstitution _institution(Map<String, Object?> json) =>
    AuditInstitution(id: _string(json, 'id'), name: _string(json, 'name'));

AuditContext _context(Map<String, Object?> json) =>
    AuditContext(kind: _string(json, 'kind'), id: _optionalString(json['id']));

AuditIntegrity _integrity(Map<String, Object?> json) => AuditIntegrity(
  position: _integer(json, 'position'),
  previousHash: _optionalString(json['previous_hash']),
  hash: _string(json, 'hash'),
  verified: _boolean(json, 'verified'),
);

AuditCursor _cursor(Map<String, Object?> json) =>
    AuditCursor(occurredAt: _date(json, 'occurred_at'), eventId: _string(json, 'event_id'));

Exception _mapError(Object error) {
  if (error is AuditUnauthorizedException ||
      error is AuditNotFoundException ||
      error is AuditValidationException ||
      error is AuditUnavailableException) {
    return error as Exception;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '42501' || 'PGRST301' => const AuditUnauthorizedException(),
      'P0002' => const AuditNotFoundException(),
      '22023' || '23514' || 'P0001' || '22P02' => const AuditValidationException(),
      _ => const AuditUnavailableException(),
    };
  }
  if (error is TimeoutException || error is ClientException) {
    return const AuditUnavailableException();
  }
  return const AuditUnavailableException();
}

Map<String, Object?> _map(Object? value) {
  if (value case Map<Object?, Object?> map) return Map<String, Object?>.from(map);
  throw const AuditUnavailableException();
}

Map<String, Object?> _objectMap(Object? value) => value == null ? const {} : _map(value);

List<Map<String, Object?>> _rows(Object? value) {
  if (value is! List<Object?>) throw const AuditUnavailableException();
  return value.map(_map).toList(growable: false);
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value case String text when text.isNotEmpty) return text;
  throw const AuditUnavailableException();
}

String? _optionalString(Object? value) => value is String && value.isNotEmpty ? value : null;

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value case num number) return number.toInt();
  throw const AuditUnavailableException();
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw const AuditUnavailableException();
}

DateTime _date(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value case String text) {
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
  }
  throw const AuditUnavailableException();
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  if (value case String text) {
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
  }
  throw const AuditUnavailableException();
}

int? _optionalInteger(Object? value) {
  if (value == null) return null;
  if (value case num number) return number.toInt();
  throw const AuditUnavailableException();
}

Uri? _safeHttpsUri(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const AuditUnavailableException();
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const AuditUnavailableException();
  }
  return uri;
}

String? _timestamp(DateTime? value) => value?.toUtc().toIso8601String();

T _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw const AuditUnavailableException();
}
