import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_directory.dart';

/// Directory reads use the nominal internal v2 contract. Editor reads remain
/// closed until their projections are equivalent; no legacy fallback is used.
final class SupabaseActivityDirectoryRepository implements ActivityDirectoryRepository {
  const SupabaseActivityDirectoryRepository(this._client);

  final SupabaseClient _client;

  Future<T> _unavailable<T>() => Future.error(const ActivityDirectoryUnavailableException());

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    try {
      final data = _v2Data(
        await _client.rpc<Object?>(
          'superadmin_activity_directory_v2',
          params: {
            'p_filters': {
              'search': query.search,
              'institution_ids': query.institutionIds.toList(growable: false),
              'unit_ids': query.unitIds.toList(growable: false),
              'group_ids': query.groupIds.toList(growable: false),
              'statuses': query.statuses
                  .map((value) => value.databaseValue)
                  .toList(growable: false),
              'origins': query.origins.map((value) => value.databaseValue).toList(growable: false),
            },
            'p_limit': query.pageSize,
            'p_offset': query.offset,
            'p_sort': query.sortColumn.name,
            'p_sort_ascending': query.sortAscending,
          },
        ),
      );
      final rows = _v2Rows(data['items']);
      final total = _nonNegativeInt(data['total']);
      if (data['limit'] != query.pageSize ||
          data['offset'] != query.offset ||
          rows.length > query.pageSize ||
          (rows.isNotEmpty && total < query.offset + rows.length)) {
        throw const ActivityDirectoryUnavailableException();
      }
      return ActivityDirectoryResult(
        items: rows.map(_directoryItem).toList(growable: false),
        totalCount: total,
        page: query.page,
        pageSize: query.pageSize,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ActivityDirectoryUnavailableException();
    } on TypeError {
      throw const ActivityDirectoryUnavailableException();
    } on StateError {
      throw const ActivityDirectoryUnavailableException();
    }
  }

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async {
    try {
      final data = _v2Data(await _client.rpc<Object?>('superadmin_activity_filter_options_v2'));
      return ActivityFilterOptions(
        institutions: _filterOptions(data['institutions']),
        units: _filterOptions(data['units'], requireParent: true),
        groups: _filterOptions(data['groups'], requireParent: true),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on TypeError {
      throw const ActivityDirectoryUnavailableException();
    }
  }

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) => _unavailable();

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) => _unavailable();

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _unavailable();

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async {
    try {
      final payload = _asMap(
        await _client.rpc<Object?>(
          'superadmin_activity_template_options',
          params: {'p_institution_id': institutionId},
        ),
      );
      return ActivityTemplateOptions(
        institutions: _rows(payload['institutions'])
            .map(
              (row) => ActivityFormInstitutionOption(
                id: row['id'] as String,
                name: row['name'] as String,
              ),
            )
            .toList(growable: false),
        units: _rows(payload['units'])
            .map(
              (row) => ActivityFormUnitOption(
                id: row['id'] as String,
                institutionId: row['institution_id'] as String,
                name: row['name'] as String,
              ),
            )
            .toList(growable: false),
        taxonomy: _taxonomyOptions(payload['taxonomy']),
        templates: _templateOptions(payload['templates']),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }
}

Map<String, dynamic> _v2Data(Object? value) {
  final envelope = _asMap(value);
  if (envelope['ok'] == false) {
    final error = _asMap(envelope['error']);
    if (const {
      'SAI_AUTH_REQUIRED',
      'SAI_SESSION_INVALID',
      'SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED',
      'SAI_MEMBERSHIP_REVOKED',
      'SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED',
    }.contains(error['code'])) {
      throw const ActivityDirectoryUnauthorizedException();
    }
    throw const ActivityDirectoryUnavailableException();
  }
  if (envelope['ok'] != true || envelope['error'] != null) {
    throw const ActivityDirectoryUnavailableException();
  }
  return _asMap(envelope['data']);
}

List<Map<String, dynamic>> _v2Rows(Object? value) {
  if (value is! List) throw const ActivityDirectoryUnavailableException();
  return value.map(_asMap).toList(growable: false);
}

int _nonNegativeInt(Object? value) {
  if (value is! int || value < 0) throw const ActivityDirectoryUnavailableException();
  return value;
}

String _requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const ActivityDirectoryUnavailableException();
  }
  return value;
}

ActivityDirectoryItem _directoryItem(Map<String, dynamic> row) {
  // Fail closed against older/incomplete v2 deployments instead of inventing
  // origin, governance, link counts or an empty contextual table.
  for (final key in [
    'id',
    'institution_id',
    'institution_name',
    'name',
    'origin_scope_kind',
    'distribution_scope',
    'governance_kind',
    'status',
    'handle_stem',
    'canonical_handle',
    'updated_at',
  ]) {
    _requiredText(row[key]);
  }
  final unitCount = _nonNegativeInt(row['active_unit_count']);
  final groupCount = _nonNegativeInt(row['active_group_count']);
  if (_nonNegativeInt(row['management_version']) == 0) {
    throw const ActivityDirectoryUnavailableException();
  }
  if (_v2Rows(row['linked_units']).length != unitCount ||
      _v2Rows(row['linked_groups']).length != groupCount) {
    throw const ActivityDirectoryUnavailableException();
  }
  return ActivityDirectoryItem.fromJson(row);
}

List<ActivityFilterOption> _filterOptions(Object? value, {bool requireParent = false}) =>
    _v2Rows(value)
        .map(
          (row) => ActivityFilterOption(
            id: _requiredText(row['id']),
            label: _requiredText(row['label']),
            parentId: requireParent ? _requiredText(row['parent_id']) : null,
          ),
        )
        .toList(growable: false);

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList(growable: false)
    : const [];

List<ActivityTaxonomyOption> _taxonomyOptions(Object? value) => _rows(value)
    .map(
      (row) => ActivityTaxonomyOption(
        id: row['id'] as String,
        label: row['label'] as String,
        isOther: row['is_other'] as bool? ?? false,
        subtypes: _rows(row['subtypes'])
            .map(
              (subtype) => ActivityTaxonomySubtypeOption(
                id: subtype['id'] as String,
                label: subtype['label'] as String,
              ),
            )
            .toList(growable: false),
      ),
    )
    .toList(growable: false);

List<ActivityTemplateOption> _templateOptions(Object? value) => _rows(value)
    .map(
      (row) => ActivityTemplateOption(
        id: row['id'] as String,
        name: row['name'] as String,
        taxonomyId: row['taxonomy_id'] as String,
        subtypeId: row['subtype_id'] as String?,
        description: row['description'] as String? ?? '',
        scopeKind: ActivityTemplateScopeKind.fromDatabase(
          row['scope_kind'] as String? ?? 'platform',
        ),
        institutionId: row['institution_id'] as String?,
        unitId: row['unit_id'] as String?,
        governance: ActivityGovernance.fromDatabase(
          row['governance_kind'] as String? ?? 'optional',
        ),
        status: ActivityStatus.fromDatabase(row['status'] as String? ?? 'active'),
      ),
    )
    .toList(growable: false);

Exception _mapError(PostgrestException error) => error.code == '42501' || error.code == 'PGRST301'
    ? const ActivityDirectoryUnauthorizedException()
    : const ActivityDirectoryUnavailableException();

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const ActivityDirectoryUnavailableException();
}
