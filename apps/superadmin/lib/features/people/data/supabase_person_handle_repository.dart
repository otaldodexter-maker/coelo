import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/person_detail_reader.dart';
import '../domain/person_handle.dart';

/// RPCs `superadmin_person_handle_get/availability/set` (pacote 20260911170100).
/// O servidor decide quem vê e quem edita; o cliente só pede e renderiza.
final class SupabasePersonHandleRepository implements PersonHandleRepository {
  SupabasePersonHandleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PersonHandle?> fetch(String personId) => _guard(() async {
    if (!isPersonDetailId(personId)) throw const PersonHandleUnauthorizedException();
    final data = _unwrap(
      await _client.rpc<Object?>('superadmin_person_handle_get', params: {'p_person_id': personId}),
    );
    return data == null ? null : PersonHandle.fromJson(data);
  });

  @override
  Future<PersonHandleAvailability> checkAvailability(String handle, {String? personId}) =>
      _guard(() async {
        final data = _unwrap(
          await _client.rpc<Object?>(
            'superadmin_person_handle_availability',
            params: {'p_handle': handle.trim(), 'p_person_id': personId},
          ),
        );
        return PersonHandleAvailability.fromReason(data?['reason'] as String?);
      });

  @override
  Future<PersonHandle> change({
    required String requestId,
    required String personId,
    required String handle,
    required String reason,
  }) => _guard(() async {
    final data = _unwrap(
      await _client.rpc<Object?>(
        'superadmin_person_handle_set',
        params: {
          'p_request_id': requestId,
          'p_person_id': personId,
          'p_handle': handle.trim(),
          'p_reason': reason.trim(),
        },
      ),
    );
    if (data == null) throw const PersonHandleException('O @ não foi salvo.');
    return PersonHandle.fromJson(data);
  });

  Map<String, dynamic>? _unwrap(Object? response) {
    final envelope = Map<String, dynamic>.from(response as Map);
    if (envelope['ok'] != true) throw const PersonHandleException('Não foi possível concluir.');
    final data = envelope['data'];
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const PersonHandleUnauthorizedException();
      }
      if (error.code == '22023') {
        throw PersonHandleException(switch (error.details) {
          'cooldown' => 'Este @ foi trocado há menos de 30 dias.',
          'taken' => PersonHandleAvailability.taken.message,
          'reserved' => PersonHandleAvailability.reserved.message,
          'invalid_format' => PersonHandleAvailability.invalidFormat.message,
          _ => 'Revise o @ e o motivo informados.',
        });
      }
      if (error.code == 'PGRST202') throw const PersonHandleUnavailableException();
      throw const PersonHandleException('Não foi possível concluir. Tente novamente.');
    } on PersonHandleException {
      rethrow;
    } on Object {
      throw const PersonHandleException('Não foi possível concluir. Tente novamente.');
    }
  }
}
