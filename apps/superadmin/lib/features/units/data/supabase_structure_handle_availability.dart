import 'dart:math' as math;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/unit_handle_availability.dart';

/// Chama `superadmin_structure_handle_availability_v1` (pacote
/// structure_handles_v1, lote 42). Qualquer falha vira `unavailable`: a
/// verificacao enquanto digita nunca bloqueia o formulario, o servidor
/// continua sendo quem recusa o @ ao salvar.
final class SupabaseStructureHandleAvailability {
  const SupabaseStructureHandleAvailability(this._client);

  final SupabaseClient _client;

  Future<UnitHandleAvailability> check(String kind, String handle, {String? excludeId}) async {
    try {
      final response = await _client.rpc<Object?>(
        'superadmin_structure_handle_availability_v1',
        params: {'p_kind': kind, 'p_handle': handle, 'p_exclude_id': excludeId},
      );
      if (response is! Map || response['ok'] != true || response['data'] is! Map) {
        return const UnitHandleAvailability(reason: UnitHandleAvailabilityReason.unavailable);
      }
      final data = response['data'] as Map;
      final normalized = data['normalized'];
      return UnitHandleAvailability(
        normalized: normalized is String ? normalized : '',
        reason: switch (data['reason']) {
          null when data['available'] == true => UnitHandleAvailabilityReason.available,
          'HANDLE_TAKEN' => UnitHandleAvailabilityReason.taken,
          'HANDLE_INVALID' => UnitHandleAvailabilityReason.invalid,
          'HANDLE_EMPTY' => UnitHandleAvailabilityReason.empty,
          _ => UnitHandleAvailabilityReason.unavailable,
        },
      );
    } on PostgrestException {
      return const UnitHandleAvailability(reason: UnitHandleAvailabilityReason.unavailable);
    } on ClientException {
      return const UnitHandleAvailability(reason: UnitHandleAvailabilityReason.unavailable);
    }
  }

  /// Chama `superadmin_structure_handle_set_v1` (trava de 30 dias). O
  /// request_id e novo a cada tentativa: o recibo do servidor cobre o replay
  /// da mesma chamada, nao tentativas diferentes do usuario.
  Future<StructureHandleChange> set(
    String kind,
    String entityId,
    int expectedVersion,
    String handle,
  ) async {
    try {
      final response = await _client.rpc<Object?>(
        'superadmin_structure_handle_set_v1',
        params: {
          'p_request_id': _uuidV4(),
          'p_kind': kind,
          'p_entity_id': entityId,
          'p_expected_version': expectedVersion,
          'p_handle': handle,
        },
      );
      if (response is! Map) {
        return const StructureHandleChange(outcome: StructureHandleChangeOutcome.unavailable);
      }
      if (response['ok'] == true && response['data'] is Map) {
        final data = response['data'] as Map;
        final version = data['management_version'];
        return StructureHandleChange(
          outcome: StructureHandleChangeOutcome.changed,
          handle: data['handle'] is String ? data['handle'] as String : handle,
          managementVersion: version is num ? version.toInt() : expectedVersion + 1,
        );
      }
      final error = response['error'];
      final code = error is Map ? error['code'] : null;
      final message = error is Map && error['message'] is String ? error['message'] as String : null;
      return StructureHandleChange(
        outcome: switch (code) {
          'SAI_HANDLE_COOLDOWN' => StructureHandleChangeOutcome.cooldown,
          'SAI_HANDLE_TAKEN' => StructureHandleChangeOutcome.taken,
          'SAI_INVALID_ARGUMENT' => StructureHandleChangeOutcome.invalid,
          'SAI_CONCURRENT_CHANGE' => StructureHandleChangeOutcome.stale,
          _ => StructureHandleChangeOutcome.unavailable,
        },
        serverMessage: code == 'SAI_HANDLE_COOLDOWN' ? message : null,
      );
    } on PostgrestException {
      return const StructureHandleChange(outcome: StructureHandleChangeOutcome.unavailable);
    } on ClientException {
      return const StructureHandleChange(outcome: StructureHandleChangeOutcome.unavailable);
    }
  }
}

String _uuidV4() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
