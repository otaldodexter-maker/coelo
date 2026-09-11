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
}
