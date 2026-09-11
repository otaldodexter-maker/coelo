import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/person_identity.dart';

/// Resolvedor de identidade de `people.create` sobre producao (R06).
///
/// `resolve` chama `superadmin_people_identity_lookup_v1` (candidato
/// 20260911170700): o servidor exige `people.create`, normaliza e-mail,
/// telefone, CPF, @ e nome, e devolve candidatos minimamente expostos; o
/// valor consultado nunca volta em claro. `checkHandle` reaproveita
/// `superadmin_person_handle_availability` (170100). Enquanto a RPC nova nao
/// estiver em producao, PGRST202 vira "indisponivel" e o gate continua
/// fail-closed.
final class SupabasePersonIdentityRepository implements PersonIdentityRepository {
  SupabasePersonIdentityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PersonIdentityCandidate>> resolve({
    required PersonIdentityLookupKind kind,
    required String query,
    String? institutionId,
    String? unitId,
    String? childContextId,
  }) => _guard(() async {
    final data = _unwrap(
      await _client.rpc<Object?>(
        'superadmin_people_identity_lookup_v1',
        params: {
          'p_kind': kind.databaseValue,
          'p_query': query.trim(),
          'p_institution_id': institutionId,
          'p_unit_id': unitId,
        },
      ),
    );
    return [
      for (final item in (data as List? ?? const []))
        PersonIdentityCandidate.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  });

  @override
  Future<PersonHandleCheck> checkHandle({required String handle, String? personId}) =>
      _guard(() async {
        final data = _unwrap(
          await _client.rpc<Object?>(
            'superadmin_person_handle_availability',
            params: {'p_handle': handle.trim(), 'p_person_id': personId},
          ),
        );
        final map = Map<String, dynamic>.from(data as Map);
        return PersonHandleCheck(
          handle: map['handle'] as String? ?? handle.trim(),
          availability: switch (map['reason'] as String?) {
            'ok' => PersonHandleAvailability.available,
            'reserved' => PersonHandleAvailability.forbidden,
            _ => PersonHandleAvailability.unavailable,
          },
        );
      });

  Object? _unwrap(Object? response) {
    final envelope = Map<String, dynamic>.from(response as Map);
    if (envelope['ok'] != true) throw const PersonIdentityUnavailableException();
    return envelope['data'];
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const PersonIdentityAccessDeniedException();
      }
      throw const PersonIdentityUnavailableException();
    } on PersonIdentityAccessDeniedException {
      rethrow;
    } on Object {
      throw const PersonIdentityUnavailableException();
    }
  }
}
