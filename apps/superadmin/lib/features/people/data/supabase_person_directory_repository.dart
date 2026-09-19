import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/entity_lifecycle.dart';
import '../domain/person_directory.dart';
import '../domain/person_detail_v2.dart';
import '../domain/person_suspension.dart';

final class SupabasePersonDirectoryRepository
    implements PersonDirectoryRepository, PersonSuspensionCommands {
  const SupabasePersonDirectoryRepository(
    this._client, {
    this.segmentFilterAvailable = false,
    this.contextFiltersAvailable = false,
  });

  final SupabaseClient _client;

  // spec 066 §3 (lote 98): suspensão por período pelo repositório do diretório.
  @override
  Future<PersonSuspensionResult> suspend(
    String personId, {
    required String requestId,
    required String reason,
    DateTime? from,
    DateTime? until,
  }) => _suspensionCall('superadmin_person_suspend_v1', personId, {
    'p_request_id': requestId,
    'p_person_id': personId,
    'p_from': (from ?? DateTime.now()).toUtc().toIso8601String(),
    'p_until': until?.toUtc().toIso8601String(),
    'p_reason': reason,
  });

  @override
  Future<PersonSuspensionResult> reactivate(
    String personId, {
    required String requestId,
    String? reason,
  }) => _suspensionCall('superadmin_person_reactivate_v1', personId, {
    'p_request_id': requestId,
    'p_person_id': personId,
    'p_reason': reason,
  });

  Future<PersonSuspensionResult> _suspensionCall(
    String rpc,
    String personId,
    Map<String, Object?> params,
  ) async {
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
      DateTime? instant(Object? value) =>
          value is String && value.isNotEmpty ? DateTime.tryParse(value)?.toUtc() : null;
      return PersonSuspensionResult(
        personId: data['person_id']?.toString() ?? personId,
        suspendedNow: data['suspended_now'] == true,
        suspendedFrom: instant(data['suspended_from']),
        suspendedUntil: instant(data['suspended_until']),
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

  /// Liga `p_segment` (abas no servidor) quando 20260911170400 estiver em
  /// producao; antes disso a RPC de 12 parametros nao aceita o argumento.
  final bool segmentFilterAvailable;

  /// Liga os filtros H28 somente depois da assinatura candidata ser serializada.
  /// Sem a RPC nova, omitir os argumentos preserva o diretório fail-closed.
  final bool contextFiltersAvailable;

  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_people_list',
        params: {
          'p_search': query.search.trim(),
          'p_types': query.types.map((item) => item.databaseValue).toList(growable: false),
          'p_statuses': query.statuses.map((item) => item.databaseValue).toList(growable: false),
          'p_institution_ids': query.institutionIds.toList(growable: false),
          'p_unit_ids': query.unitIds.toList(growable: false),
          'p_group_ids': query.groupIds.toList(growable: false),
          'p_contextual_roles': query.contextualRoles.toList(growable: false),
          'p_auth_links': query.authLinks.map((item) => item.databaseValue).toList(growable: false),
          'p_sort': query.sortColumn.databaseValue,
          'p_sort_ascending': query.sortAscending,
          'p_offset': query.offset,
          'p_limit': query.pageSize,
          // Abas do diretorio filtradas no servidor (20260911170400).
          if (segmentFilterAvailable) 'p_segment': query.segment.databaseValue,
          if (contextFiltersAvailable) ...{
            'p_activity_ids': query.activityIds.toList(growable: false),
            'p_state_codes': query.stateCodes.toList(growable: false),
            'p_municipality_ids': query.municipalityIds.toList(growable: false),
            'p_neighborhood_ids': query.neighborhoodIds.toList(growable: false),
          },
        },
      );
      final payload = Map<String, dynamic>.from(response as Map);
      final rows = payload['items'] as List<dynamic>? ?? const [];
      return PersonDirectoryPage(
        items: rows
            .map((row) => PersonDirectoryItem.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
        totalCount: (payload['total_count'] as num?)?.toInt() ?? 0,
        page: query.page,
        pageSize: query.pageSize,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>('superadmin_people_filter_options');
      final payload = Map<String, dynamic>.from(response as Map);
      return PersonDirectoryFilterOptions(
        institutions: _options(payload['institutions']),
        units: _options(payload['units']),
        groups: _options(payload['groups']),
        roles: _options(payload['roles']),
        activities: _options(payload['activities']),
        states: _options(payload['states']),
        municipalities: _options(payload['municipalities']),
        neighborhoods: _options(payload['neighborhoods']),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) async {
    try {
      final response = await _client.rpc<Object?>(
        'superadmin_person_detail_v2',
        params: {'p_person_id': personId},
      );
      return decodePersonDetailV2(response, requestedId: personId);
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const PersonDirectoryUnauthorizedException();
      }
      throw const PersonDirectoryUnavailableException();
    } on PersonDirectoryUnauthorizedException {
      rethrow;
    } on PersonDirectoryUnavailableException {
      rethrow;
    } on Object {
      throw const PersonDirectoryUnavailableException();
    }
  }

  @override
  Future<PersonDirectoryItem> createDraft(PersonDraft draft) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_people_create_draft',
        params: {'p_draft': draft.toJson()},
      );
      return PersonDirectoryItem.fromJson(Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_people_update',
        params: {'p_update': update.toJson()},
      );
      return PersonDirectoryItem.fromJson(Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }
}

List<PersonFilterOption> _options(Object? raw) {
  final rows = raw as List<dynamic>? ?? const [];
  return rows
      .map((row) => Map<String, dynamic>.from(row as Map))
      .map(
        (row) => PersonFilterOption(
          (row['code'] ?? row['id']) as String,
          row['label'] as String,
          institutionId: row['institution_id'] as String?,
          unitId: row['unit_id'] as String?,
          groupId: row['group_id'] as String?,
          stateCode: row['state_code'] as String?,
          municipalityId: row['municipality_id'] as String?,
        ),
      )
      .toList(growable: false);
}

Exception _mapError(PostgrestException error) {
  final message = error.message.toLowerCase();
  if (error.code == '42501' || error.code == 'PGRST301') {
    return const PersonDirectoryUnauthorizedException();
  }
  if (error.code == '40001' || error.code == 'PT409' || message.contains('version')) {
    return const PersonDirectoryConflictException();
  }
  if ((error.code == '22023' || error.code == 'P0001') &&
      (message.contains('read-only') ||
          message.contains('read only') ||
          message.contains('read.only'))) {
    return const PersonDirectoryReadOnlyException();
  }
  return error;
}

final class UnavailablePersonDirectoryRepository implements PersonDirectoryRepository {
  const UnavailablePersonDirectoryRepository();
  Future<T> _unavailable<T>() => Future.error(const PersonDirectoryUnavailableException());

  @override
  Future<PersonDirectoryItem> createDraft(PersonDraft draft) => _unavailable();
  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) => _unavailable();
  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() => _unavailable();
  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) => _unavailable();
  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) => _unavailable();
}
