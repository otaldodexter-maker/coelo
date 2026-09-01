import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/access_profile.dart';
import '../domain/access_profile_model.dart';

final class SupabaseAccessProfileRepository
    implements AccessProfileRepository, AccessProfileModelRepository {
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

  @override
  Future<AccessProfileModelPage> fetchModels(AccessProfileModelQuery query) async {
    final response = await _modelRpc(
      'superadmin_access_profile_models_cursor',
      params: {
        'p_query': query.search.trim().isEmpty ? null : query.search.trim(),
        'p_domain': query.domain.databaseValue,
        'p_status': query.status?.databaseValue,
        'p_scope': query.scope,
        'p_limit': query.limit,
        'p_after_name': query.afterName,
        'p_after_id': query.afterId,
      },
    );
    return AccessProfileModelPage.fromJson(response);
  }

  @override
  Future<AccessProfileModel> fetchModel(String modelId) async => AccessProfileModel.fromJson(
    await _modelRpc('superadmin_access_profile_model_detail', params: {'p_model_id': modelId}),
  );

  @override
  Future<AccessProfileModel> createModel(String requestId, AccessProfileModelDraft draft) async =>
      _modelFromReceipt(
        await _modelRpc(
          'superadmin_access_profile_model_create',
          params: {'p_request_id': requestId, 'p_draft': draft.toJson()},
        ),
      );

  @override
  Future<AccessProfileModel> updateModel(String requestId, AccessProfileModelDraft draft) async =>
      _modelFromReceipt(
        await _modelRpc(
          'superadmin_access_profile_model_update',
          params: {'p_request_id': requestId, 'p_draft': draft.toJson()},
        ),
      );

  @override
  Future<void> deleteModel({
    required String requestId,
    required String modelId,
    required int expectedVersion,
    required String reason,
  }) async {
    await _modelRpc(
      'superadmin_access_profile_model_delete',
      params: {
        'p_request_id': requestId,
        'p_model_id': modelId,
        'p_expected_version': expectedVersion,
        'p_reason': reason.trim(),
      },
    );
  }

  @override
  Future<AccessProfileModel> duplicateModel(
    String requestId,
    AccessProfileModelDraft draft,
  ) async => _modelFromReceipt(
    await _modelRpc(
      'superadmin_access_profile_model_duplicate',
      params: {'p_request_id': requestId, 'p_draft': draft.toJson()},
    ),
  );

  @override
  Future<AccessProfileModelExport> exportModels(AccessProfileDomain domain) async =>
      AccessProfileModelExport.fromJson(
        await _modelRpc(
          'superadmin_access_profile_models_export',
          params: {'p_domain': domain.databaseValue},
        ),
      );

  @override
  Future<AccessProfileModelImportPreview> previewModelImport(
    AccessProfileDomain domain,
    List<Map<String, dynamic>> rows,
  ) async => AccessProfileModelImportPreview.fromJson(
    await _modelRpc(
      'superadmin_access_profile_models_import_preview',
      params: {'p_domain': domain.databaseValue, 'p_rows': rows},
    ),
  );

  @override
  Future<List<AccessProfileModel>> confirmModelImport({
    required String requestId,
    required AccessProfileDomain domain,
    required List<Map<String, dynamic>> rows,
    required String reason,
  }) async {
    final response = await _modelRpc(
      'superadmin_access_profile_models_import_confirm',
      params: {
        'p_request_id': requestId,
        'p_domain': domain.databaseValue,
        'p_rows': rows,
        'p_reason': reason.trim(),
      },
    );
    final created = response['models'] as List<dynamic>? ?? const [];
    return Future.wait(
      created.map((row) => fetchModel(Map<String, dynamic>.from(row as Map)['id'] as String)),
    );
  }

  @override
  Future<List<AccessPermissionCatalogItem>> fetchPermissionCatalog() async {
    final response = await _modelRpc('superadmin_access_permission_catalog');
    final rows = response['items'] as List<dynamic>? ?? const [];
    return rows
        .map((row) => AccessPermissionCatalogItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _modelRpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(functionName, params: params);
      return Map<String, dynamic>.from(response as Map);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }
}

AccessProfileModel _modelFromReceipt(Map<String, dynamic> response) =>
    AccessProfileModel.fromJson(Map<String, dynamic>.from(response['model'] as Map));

Exception _mapError(PostgrestException error) {
  final message = error.message.toLowerCase();
  if (error.code == '42501' || error.code == 'PGRST301') {
    return const AccessProfileUnauthorizedException();
  }
  if (error.code == '40001' ||
      message.contains('stale profile version') ||
      message.contains('stale access model version')) {
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
