import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/person_directory.dart';

final class SupabasePersonDirectoryRepository implements PersonDirectoryRepository {
  const SupabasePersonDirectoryRepository(this._client);

  final SupabaseClient _client;

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
      if (response is! Map) throw const PersonDirectoryUnavailableException();
      final envelope = Map<String, dynamic>.from(response);
      if (envelope['ok'] != true) {
        final error = envelope['error'] is Map
            ? Map<String, dynamic>.from(envelope['error'] as Map)
            : const <String, dynamic>{};
        final code = error['code'];
        throw _mapInternalError(code is String ? code : null);
      }
      final data = envelope['data'];
      if (data is! Map) throw const PersonDirectoryUnavailableException();
      return PersonDirectoryItem.fromJson(Map<String, dynamic>.from(data));
    } on PostgrestException catch (error) {
      throw _mapError(error);
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

Exception _mapInternalError(String? code) => switch (code) {
  'SAI_PERMISSION_DENIED' ||
  'SAI_INTERNAL_CONTEXT_DENIED' ||
  'SAI_SESSION_INVALID' ||
  'SAI_MFA_REQUIRED' => const PersonDirectoryUnauthorizedException(),
  _ => const PersonDirectoryUnavailableException(),
};

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
        ),
      )
      .toList(growable: false);
}

Exception _mapError(PostgrestException error) {
  final message = error.message.toLowerCase();
  if (error.code == '42501' || error.code == 'PGRST301') {
    return const PersonDirectoryUnauthorizedException();
  }
  if (error.code == '40001' || message.contains('version')) {
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
