import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_safety.dart';
import '../domain/child_safety_contract.dart';
import 'child_safety_response_decoder.dart';

/// Internal read-only adapter. Activation requires the nominal v2 SQL package.
/// Unsupported commands never fall back to the global-person authorization path.
final class SupabaseInternalChildSafetyRepository implements ChildSafetyRepository {
  const SupabaseInternalChildSafetyRepository(this._client);

  final SupabaseClient _client;
  static const _unavailable = UnavailableChildSafetyRepository();

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    final payload = await _read('superadmin_child_safety_directory_v2', {
      'p_search': query.search.trim(),
      'p_institution_ids': query.institutionIds.toList(),
      'p_unit_ids': query.unitIds.toList(),
      'p_segment': query.segment.databaseValue,
      'p_limit': query.pageSize,
      'p_cursor': _cursor(query.cursor),
    });
    if (payload is! Map<String, dynamic> ||
        !_childRows(payload['items']) ||
        payload['total_count'] is! int ||
        payload['segment_counts'] is! Map) {
      throw const ChildSafetyUnavailableException();
    }
    return _decode(() => decodeChildSafetyDirectory({...payload, 'can_create': false}));
  }

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async {
    final payload = await _read('superadmin_child_safety_get_v2', {'p_child_id': childId});
    if (payload is! Map<String, dynamic> ||
        payload['child_id'] != childId ||
        !_identifier(payload['child_id']) ||
        payload['child_name'] is! String ||
        !_contextRows(payload['contexts']) ||
        !_authorizationRows(payload['authorizations'])) {
      throw const ChildSafetyUnavailableException();
    }
    return _decode(() => decodeChildSafetyRecord(payload));
  }

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async {
    final payload = await _read('superadmin_child_safety_search_children_v2', {
      'p_search': query.trim(),
      'p_limit': limit,
    });
    if (payload is! List ||
        payload.any(
          (item) =>
              item is! Map ||
              !_identifier(item['id']) ||
              item['display_name'] is! String ||
              !_contextRows(item['contexts']),
        )) {
      throw const ChildSafetyUnavailableException();
    }
    return _decode(() => decodeChildSafetyOptions(payload));
  }

  Future<Object> _read(String function, Map<String, Object?> params) async {
    final Object? envelope;
    try {
      envelope = await _client.rpc(function, params: params);
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '42501' || 'PGRST301' || 'PGRST302' => const ChildSafetyUnauthorizedException(),
        _ => const ChildSafetyUnavailableException(),
      };
    } catch (_) {
      throw const ChildSafetyUnavailableException();
    }
    if (envelope is! Map || envelope['ok'] is! bool) {
      throw const ChildSafetyUnavailableException();
    }
    if (envelope['ok'] == false) {
      final error = envelope['error'];
      final code = error is Map ? error['code'] : null;
      throw switch (code) {
        'SAI_AUTH_REQUIRED' ||
        'SAI_SESSION_INVALID' ||
        'SAI_INTERNAL_CONTEXT_DENIED' ||
        'SAI_MEMBERSHIP_SUSPENDED' ||
        'SAI_MEMBERSHIP_REVOKED' ||
        'SAI_PERMISSION_DENIED' => const ChildSafetyUnauthorizedException(),
        'SAI_INVALID_ARGUMENT' => const ChildSafetyValidationException(),
        'SAI_CONCURRENT_CHANGE' => const ChildSafetyConflictException(),
        _ => const ChildSafetyUnavailableException(),
      };
    }
    final Object? data = envelope['data'];
    if (data == null || !envelope.containsKey('error') || envelope['error'] != null) {
      throw const ChildSafetyUnavailableException();
    }
    return data;
  }

  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) =>
      _unavailable.saveAuthorization(command);
  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) =>
      _unavailable.transitionAuthorization(command);
  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) =>
      _unavailable.suspendAuthorization(command);
  @override
  Future<void> requestExport(ChildSafetyExportCommand command) =>
      _unavailable.requestExport(command);
}

Object? _cursor(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map) throw const ChildSafetyValidationException();
    return decoded;
  } on FormatException {
    throw const ChildSafetyValidationException();
  }
}

// Validate the identity/scope fields guaranteed by the nominal SQL projection.
// Names remain strings without adding new length restrictions to legacy data.
bool _identifier(Object? value) => value is String && value.isNotEmpty;
bool _contextRow(Object? value) =>
    value is Map &&
    _identifier(value['child_context_id']) &&
    _identifier(value['institution_id']) &&
    _identifier(value['unit_id']) &&
    value['institution_name'] is String &&
    value['unit_name'] is String;
bool _contextRows(Object? value) => value is List && value.every(_contextRow);
bool _authorizationRows(Object? value) =>
    value is List &&
    value.every(
      (item) =>
          item is Map &&
          _identifier(item['id']) &&
          _identifier(item['child_context_id']) &&
          _identifier(item['unit_id']) &&
          item['name'] is String,
    );
bool _childRows(Object? value) =>
    value is List &&
    value.every(
      (item) =>
          item is Map &&
          _identifier(item['child_id']) &&
          item['child_name'] is String &&
          _contextRow(item),
    );

T _decode<T>(T Function() decode) {
  try {
    return decode();
  } catch (_) {
    throw const ChildSafetyUnavailableException();
  }
}
