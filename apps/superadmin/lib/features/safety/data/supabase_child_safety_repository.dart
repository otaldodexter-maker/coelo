import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_safety.dart';
import '../domain/child_safety_contract.dart';
import 'child_safety_response_decoder.dart';

final class SupabaseChildSafetyRepository implements ChildSafetyRepository {
  const SupabaseChildSafetyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    final payload = await _rpc('superadmin_child_safety_directory', {
      'p_search': query.search.trim(),
      'p_institution_ids': query.institutionIds.toList(),
      'p_unit_ids': query.unitIds.toList(),
      'p_segment': query.segment.databaseValue,
      'p_limit': query.pageSize,
      'p_cursor': _decodeCursor(query.cursor),
    });
    return decodeChildSafetyDirectory(payload);
  }

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async {
    final payload = await _rpc('superadmin_child_safety_get', {'p_child_id': childId});
    return decodeChildSafetyRecord(payload);
  }

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async {
    final payload = await _rpc('superadmin_child_safety_search_children', {
      'p_search': query.trim(),
      'p_limit': limit,
    });
    return decodeChildSafetyOptions(payload);
  }

  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {
    final payload = <String, Object?>{
      'child_id': command.childId,
      'child_context_id': command.childContextId,
      'unit_id': command.unitId,
      'person_id': command.personId,
      'relationship_code': command.relationshipCode,
      'relationship_detail': command.relationshipDetail,
      'capability_codes': command.capabilityCodes.toList()..sort(),
      'valid_from': command.validFrom?.toUtc().toIso8601String(),
      'valid_until': command.validUntil?.toUtc().toIso8601String(),
      'request_reason': command.requestReason.trim(),
    };
    if (command.authorizationId case final authorizationId?) {
      await _rpc('child_safety_edit_pending_authorization', {
        'p_request_id': command.requestId,
        'p_authorization_id': authorizationId,
        'p_expected_version': command.expectedVersion,
        'p_payload': payload,
      });
    } else {
      await _rpc('child_safety_request_authorization', {
        'p_request_id': command.requestId,
        'p_payload': payload,
      });
    }
  }

  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) async {
    await _rpc('child_safety_decide_authorization', {
      'p_request_id': command.requestId,
      'p_authorization_id': command.authorizationId,
      'p_expected_version': command.expectedVersion,
      'p_decision': command.status.name,
      'p_reason': command.reason.trim(),
    });
  }

  @override
  Future<void> removeAuthorization(RemovePickupAuthorizationCommand command) async {
    await _rpc('child_safety_change_lifecycle', {
      'p_request_id': command.requestId,
      'p_authorization_id': command.authorizationId,
      'p_expected_version': command.expectedVersion,
      'p_lifecycle_status': 'archived',
      'p_reason': command.reason.trim(),
    });
  }

  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {
    await _rpc('superadmin_request_child_safety_export', {
      'p_request_id': command.requestId,
      'p_format': command.format,
      'p_filters': command.filters,
    });
  }

  Future<Object?> _rpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc(function, params: params);
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '42501' => const ChildSafetyUnauthorizedException(),
        'P0002' => const ChildSafetyNotFoundException(),
        '23505' || '40001' => const ChildSafetyConflictException(),
        '22023' || '23514' => const ChildSafetyValidationException(),
        _ => const ChildSafetyUnavailableException(),
      };
    }
  }
}

Object? _decodeCursor(String? cursor) {
  if (cursor == null || cursor.isEmpty) return null;
  try {
    return jsonDecode(cursor);
  } on FormatException {
    throw const ChildSafetyValidationException();
  }
}
