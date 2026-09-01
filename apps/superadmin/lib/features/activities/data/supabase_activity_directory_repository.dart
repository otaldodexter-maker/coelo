import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_directory.dart';

/// Production reads stay closed until the v2 projections are shape-equivalent
/// to the editor DTO. Template options are the only approved equivalent read.
final class SupabaseActivityDirectoryRepository implements ActivityDirectoryRepository {
  const SupabaseActivityDirectoryRepository(this._client);

  final SupabaseClient _client;

  Future<T> _unavailable<T>() => Future.error(const ActivityDirectoryUnavailableException());

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) => _unavailable();

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _unavailable();

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
