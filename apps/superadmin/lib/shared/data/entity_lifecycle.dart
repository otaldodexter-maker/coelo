import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de uma transição de ciclo de vida (spec 066) de unidade ou turma.
final class EntityLifecycleResult {
  const EntityLifecycleResult({
    required this.entityId,
    required this.status,
    required this.hardDeleted,
    this.managementVersion,
  });

  final String entityId;

  /// `deleted` quando a exclusão foi real (linha removida).
  final String status;
  final bool hardDeleted;
  final int? managementVersion;
}

/// Comandos de ciclo de vida (spec 066) para unidades e turmas. Interface
/// pequena implementada pelos gateways Supabase; a tela só a recebe quando o
/// ator pode mutar a estrutura.
abstract interface class EntityLifecycleCommands {
  Future<EntityLifecycleResult> changeStatus(
    String entityId, {
    required int expectedVersion,
    required bool active,
    required String requestId,
    String? reason,
  });

  Future<EntityLifecycleResult> delete(
    String entityId, {
    required int expectedVersion,
    required String requestId,
    required String reason,
  });
}

final class EntityLifecycleConflictException implements Exception {
  const EntityLifecycleConflictException();
}

final class EntityLifecycleUnauthorizedException implements Exception {
  const EntityLifecycleUnauthorizedException();
}

final class EntityLifecycleValidationException implements Exception {
  const EntityLifecycleValidationException(this.message);
  final String message;
}

final class EntityLifecycleUnavailableException implements Exception {
  const EntityLifecycleUnavailableException();
}

/// Chama as RPCs `superadmin_<entity>_change_status_v1` / `_delete_v1` (lote 97)
/// e traduz o envelope `{ok,data,error}` nas exceções acima.
final class SupabaseEntityLifecycleCommands implements EntityLifecycleCommands {
  const SupabaseEntityLifecycleCommands(this._client, {required this.entity});

  final SupabaseClient _client;

  /// `unit` ou `group`.
  final String entity;

  @override
  Future<EntityLifecycleResult> changeStatus(
    String entityId, {
    required int expectedVersion,
    required bool active,
    required String requestId,
    String? reason,
  }) => _call('superadmin_${entity}_change_status_v1', {
    'p_request_id': requestId,
    'p_${entity}_id': entityId,
    'p_expected_version': expectedVersion,
    'p_status': active ? 'active' : 'inactive',
    'p_reason': reason,
  });

  @override
  Future<EntityLifecycleResult> delete(
    String entityId, {
    required int expectedVersion,
    required String requestId,
    required String reason,
  }) => _call('superadmin_${entity}_delete_v1', {
    'p_request_id': requestId,
    'p_${entity}_id': entityId,
    'p_expected_version': expectedVersion,
    'p_reason': reason,
  });

  Future<EntityLifecycleResult> _call(String rpc, Map<String, Object?> params) async {
    final entityId = params['p_${entity}_id']?.toString() ?? '';
    final Object? raw;
    try {
      raw = await _client.rpc<Object?>(rpc, params: params);
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const EntityLifecycleUnauthorizedException();
      }
      throw const EntityLifecycleUnavailableException();
    } on ClientException {
      throw const EntityLifecycleUnavailableException();
    }
    final envelope = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    if (envelope['ok'] == true) {
      final data = envelope['data'] is Map
          ? Map<String, dynamic>.from(envelope['data'] as Map)
          : const <String, dynamic>{};
      return EntityLifecycleResult(
        entityId: data['id']?.toString() ?? entityId,
        status: data['status']?.toString() ?? '',
        hardDeleted: data['hard_deleted'] == true,
        managementVersion: (data['management_version'] as num?)?.toInt(),
      );
    }
    final error = envelope['error'] is Map
        ? Map<String, dynamic>.from(envelope['error'] as Map)
        : const <String, dynamic>{};
    switch (error['code']?.toString()) {
      case 'SAI_CONCURRENT_CHANGE':
        throw const EntityLifecycleConflictException();
      case 'SAI_INVALID_ARGUMENT':
        throw EntityLifecycleValidationException(
          error['message']?.toString() ?? 'Revise os dados enviados.',
        );
      case 'SAI_PERMISSION_DENIED':
      case 'SAI_MFA_REQUIRED':
      case 'SAI_AUTH_REQUIRED':
      case 'SAI_SESSION_INVALID':
      case 'SAI_INTERNAL_CONTEXT_DENIED':
      case 'SAI_MEMBERSHIP_SUSPENDED':
      case 'SAI_MEMBERSHIP_REVOKED':
        throw const EntityLifecycleUnauthorizedException();
      default:
        throw const EntityLifecycleUnavailableException();
    }
  }
}
