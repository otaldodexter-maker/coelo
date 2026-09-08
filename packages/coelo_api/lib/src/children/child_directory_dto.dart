import 'dart:convert';

/// Transport budget, not a cadastral name limit.
const childDirectoryCursorNameMaxBytes = 8192;

final class ChildDirectoryCursor {
  const ChildDirectoryCursor({required this.name, required this.contextId});
  final String name;
  final String contextId;
}

final class ChildDirectoryRequest {
  const ChildDirectoryRequest({this.institutionId, this.after, this.limit = 20});
  final String? institutionId;
  final ChildDirectoryCursor? after;
  final int limit;
  Map<String, Object?> toRpcParams() {
    if (limit < 1 || limit > 50) _invalid();
    return {
      'p_institution_id': institutionId == null ? null : _uuid(institutionId),
      'p_after_name': after == null ? null : _cursorName(after!.name),
      'p_after_context_id': after == null ? null : _uuid(after!.contextId),
      'p_limit': limit,
    };
  }
}

final class ChildDirectoryItem {
  const ChildDirectoryItem({
    required this.contextId,
    required this.personId,
    required this.personName,
    required this.institutionId,
    required this.institutionName,
  });
  final String contextId;
  final String personId;
  final String personName;
  final String institutionId;
  final String institutionName;
}

final class ChildDirectoryPage {
  ChildDirectoryPage({required List<ChildDirectoryItem> items, this.nextCursor})
    : items = List.unmodifiable(items);
  final List<ChildDirectoryItem> items;
  final ChildDirectoryCursor? nextCursor;
}

final class ChildDirectoryDeniedException implements Exception {
  const ChildDirectoryDeniedException();
  @override
  String toString() => 'Child directory denied';
}

/// Integrity checks only; the server must authorize every page independently.
ChildDirectoryPage decodeChildDirectory(Object? value, {required ChildDirectoryRequest request}) {
  final params = request.toRpcParams();
  final envelope = _map(value, {'ok', 'data', 'error'});
  if (envelope['ok'] == false) {
    if (envelope['data'] != null) _invalid();
    final error = _map(envelope['error'], {'code', 'message', 'correlation_id', 'http_status'});
    if (error['code'] is! String ||
        error['message'] is! String ||
        error['http_status'] is! int ||
        (error['http_status'] as int) < 400 ||
        (error['http_status'] as int) > 599) {
      _invalid();
    }
    _uuid(error['correlation_id']);
    if (const {
      'SAI_AUTH_REQUIRED',
      'SAI_SESSION_INVALID',
      'SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED',
      'SAI_MEMBERSHIP_REVOKED',
      'SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED',
    }.contains(error['code'])) {
      throw const ChildDirectoryDeniedException();
    }
    _invalid();
  }
  if (envelope['ok'] != true || envelope['error'] != null) _invalid();
  final data = _map(envelope['data'], {'items', 'next_cursor'});
  final rows = data['items'];
  if (rows is! List || rows.length > request.limit) _invalid();
  final ids = <String>{};
  final items = <ChildDirectoryItem>[];
  for (final row in rows) {
    final raw = _map(row, {
      'context_id',
      'person_id',
      'person_name',
      'institution_id',
      'institution_name',
    });
    final id = _uuid(raw['context_id']);
    final institution = _uuid(raw['institution_id']);
    if (!ids.add(id) ||
        params['p_institution_id'] != null && params['p_institution_id'] != institution) {
      _invalid();
    }
    items.add(
      ChildDirectoryItem(
        contextId: id,
        personId: _uuid(raw['person_id']),
        personName: _text(raw['person_name']),
        institutionId: institution,
        institutionName: _text(raw['institution_name']),
      ),
    );
  }
  ChildDirectoryCursor? cursor;
  if (data['next_cursor'] != null) {
    final raw = _map(data['next_cursor'], {'name', 'context_id'});
    final id = _uuid(raw['context_id']);
    if (items.isEmpty || items.length != request.limit || items.last.contextId != id) _invalid();
    cursor = ChildDirectoryCursor(name: _cursorName(raw['name']), contextId: id);
    if (cursor.contextId == params['p_after_context_id'] && cursor.name == params['p_after_name']) {
      _invalid();
    }
  }
  return ChildDirectoryPage(items: items, nextCursor: cursor);
}

Map<String, Object?> _map(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.length != keys.length ||
      value.keys.any((key) => key is! String || !keys.contains(key))) {
    _invalid();
  }
  return Map<String, Object?>.from(value);
}

String _uuid(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    _invalid();
  }
  return value.toLowerCase();
}

String _text(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff) ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    _invalid();
  }
  return value;
}

String _cursorName(Object? value) {
  final name = _text(value);
  if (utf8.encode(name).length > childDirectoryCursorNameMaxBytes) _invalid();
  return name;
}

Never _invalid() => throw const FormatException('Invalid child directory transport');
