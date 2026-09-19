import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/staff_access.dart';

/// RPCs de staff_access_v1 (lote 84). O servidor valida ator, capacidade
/// `staff_access.manage`, escopo do vínculo, versão (PT409) e audita.
final class SupabaseStaffAccessRepository implements StaffAccessRepository {
  const SupabaseStaffAccessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<StaffAccessPage> fetchPage(StaffAccessQuery query) async {
    try {
      final response = await _client.rpc<dynamic>(
        'staff_access_list_v1',
        params: {
          'p_search': query.search.trim().isEmpty ? null : query.search.trim(),
          'p_institution_id': query.institutionId,
          'p_unit_id': query.unitId,
          'p_states': query.states.isEmpty
              ? null
              : query.states.map((s) => s.databaseValue).toList(growable: false),
          'p_page': query.page + 1,
          'p_page_size': query.pageSize,
          'p_sources': query.sources.isEmpty
              ? null
              : query.sources.map((s) => s.databaseValue).toList(growable: false),
        },
      );
      final payload = Map<String, dynamic>.from(response as Map);
      final filters = Map<String, dynamic>.from(payload['filters'] as Map? ?? const {});
      return StaffAccessPage(
        items: (payload['items'] as List<dynamic>? ?? const [])
            .map((row) => StaffAccessItem.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
        totalCount: (payload['total_count'] as num?)?.toInt() ?? 0,
        page: query.page,
        filterOptions: StaffAccessFilterOptions(
          institutions: _options(filters['institutions']),
          units: _options(filters['units']),
        ),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<StaffAccessItem> fetchDetail(String membershipId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'staff_access_rule_get_v1',
        params: {'p_membership_id': membershipId},
      );
      return StaffAccessItem.fromJson(Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<StaffAccessItem> saveRule(
    String membershipId,
    int? expectedVersion,
    StaffAccessRuleDraft draft,
  ) async {
    try {
      final response = await _client.rpc<dynamic>(
        'staff_access_rule_save_v1',
        params: {
          'p_membership_id': membershipId,
          'p_expected_version': expectedVersion,
          'p_payload': draft.toJson(),
        },
      );
      return StaffAccessItem.fromJson(Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<StaffAccessProfileRule> fetchProfileRule(String roleId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'staff_access_profile_rule_get_v1',
        params: {'p_role_id': roleId},
      );
      return StaffAccessProfileRule.fromJson(Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<StaffAccessProfileRule> saveProfileRule(
    String roleId,
    int? expectedVersion,
    StaffAccessRuleDraft draft,
  ) async {
    try {
      final response = await _client.rpc<dynamic>(
        'staff_access_profile_rule_save_v1',
        params: {
          'p_role_id': roleId,
          'p_expected_version': expectedVersion,
          'p_payload': draft.toJson(),
        },
      );
      return StaffAccessProfileRule.fromJson(Map<String, dynamic>.from(response as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<StaffLeavePage> fetchLeaves(StaffLeaveQuery query) async {
    try {
      final response = await _client.rpc<dynamic>(
        'staff_leaves_list_v1',
        params: {
          'p_search': query.search.trim().isEmpty ? null : query.search.trim(),
          'p_institution_id': query.institutionId,
          'p_unit_id': query.unitId,
          'p_period': query.period?.databaseValue,
          'p_page': query.page + 1,
          'p_page_size': query.pageSize,
        },
      );
      final payload = Map<String, dynamic>.from(response as Map);
      return StaffLeavePage(
        items: (payload['items'] as List<dynamic>? ?? const [])
            .map((row) => StaffLeave.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
        totalCount: (payload['total_count'] as num?)?.toInt() ?? 0,
        page: query.page,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<StaffLeave?> saveLeave({
    String? leaveId,
    required String membershipId,
    int? expectedVersion,
    required StaffLeaveDraft draft,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'staff_leave_save_v1',
        params: {
          'p_leave_id': leaveId,
          'p_membership_id': membershipId,
          'p_expected_version': expectedVersion,
          'p_payload': draft.toJson(),
        },
      );
      final payload = Map<String, dynamic>.from(response as Map);
      if (payload['removed'] == true) return null;
      return StaffLeave.fromJson(payload);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }
}

List<StaffAccessFilterOption> _options(Object? value) => [
  for (final item in (value as List<dynamic>? ?? const []))
    StaffAccessFilterOption(
      id: (item as Map)['id'] as String,
      label: item['name'] as String? ?? '',
      institutionId: item['institution_id'] as String?,
    ),
];

Exception _mapError(PostgrestException error) {
  // OQ-047: versão defasada chega como PT409 (nunca 40001).
  if (error.code == 'PT409' ||
      error.message.contains('STAFF_ACCESS_STALE_VERSION') ||
      (error.details?.toString().contains('STAFF_ACCESS_STALE_VERSION') ?? false)) {
    return const StaffAccessConflictException();
  }
  if (error.code == '42501' || error.code == 'PGRST301' || error.code == 'PGRST302') {
    return const StaffAccessUnauthorizedException();
  }
  if (error.code == '22023' || error.code == 'P0002') {
    return StaffAccessValidationException(error.message);
  }
  return const StaffAccessUnavailableException();
}
