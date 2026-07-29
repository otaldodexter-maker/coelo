import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/access_profile.dart';

final class SupabaseAccessProfileRepository implements AccessProfileRepository {
  const SupabaseAccessProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isDemo => false;

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) async {
    if (query.domain == AccessProfileDomain.principal) {
      return const AccessProfilePage.empty();
    }
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_access_profiles_list',
        params: {
          'p_domain': query.domain.databaseValue,
          'p_search': query.search.trim(),
          'p_status': query.statuses.isEmpty
              ? null
              : query.statuses.map((value) => value.databaseValue).join(','),
          'p_scope': query.scopes.isEmpty
              ? null
              : query.scopes.map((value) => value.databaseValue).join(','),
          'p_page': query.page + 1,
          'p_page_size': query.pageSize,
        },
      );
      final payload = Map<String, dynamic>.from(response as Map);
      final rows = payload['items'] as List<dynamic>? ?? const [];
      return AccessProfilePage(
        items: rows
            .map(
              (row) => AccessProfile.fromJson(query.domain, Map<String, dynamic>.from(row as Map)),
            )
            .toList(growable: false),
        totalCount: (payload['total'] as num?)?.toInt() ?? 0,
        page: ((payload['page'] as num?)?.toInt() ?? 1) - 1,
        pageSize: (payload['page_size'] as num?)?.toInt() ?? query.pageSize,
        isDemo: payload['demo'] as bool? ?? false,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_access_profile_detail',
        params: {'p_domain': domain.databaseValue, 'p_profile_id': profileId},
      );
      return AccessProfile.fromJson(domain, Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_access_profile_detail',
        params: {'p_domain': domain.databaseValue, 'p_profile_id': null},
      );
      return AccessProfile.fromJson(domain, Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_principal_capabilities_summary',
      );
      final payload = Map<String, dynamic>.from(response as Map);
      final rows = payload['items'] as List<dynamic>? ?? const [];
      return rows
          .map((row) => PrincipalCapability.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_access_profile_save',
        params: {
          'p_request_id': requestId,
          'p_expected_version': expectedVersion,
          'p_reason': reason,
          'p_draft': draft.toDraftJson(),
        },
      );
      return AccessProfile.fromJson(draft.domain, Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  }) async {
    try {
      await _client.rpc<Map<String, dynamic>>(
        'superadmin_access_profile_delete_and_reassign',
        params: {
          'p_request_id': requestId,
          'p_domain': domain.databaseValue,
          'p_profile_id': profileId,
          'p_expected_version': expectedVersion,
          'p_replacement_profile_id': replacementProfileId,
          'p_reason': reason,
        },
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }
}

Exception _mapError(PostgrestException error) {
  final message = error.message.toLowerCase();
  if (error.code == '42501' || error.code == 'PGRST301') {
    return const AccessProfileUnauthorizedException();
  }
  if (error.code == '40001' || message.contains('stale profile version')) {
    return const AccessProfileConflictException();
  }
  return const AccessProfileException('Não foi possível concluir a operação. Tente novamente.');
}

final class UnavailableAccessProfileRepository implements AccessProfileRepository {
  const UnavailableAccessProfileRepository();

  Never _unavailable() => throw const AccessProfileUnavailableException();

  @override
  bool get isDemo => false;

  @override
  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  }) async => _unavailable();

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async =>
      _unavailable();

  @override
  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain) async => _unavailable();

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async => _unavailable();

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) async => _unavailable();

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async => _unavailable();
}
