import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_directory.dart';

final class SupabaseActivityDirectoryRepository implements ActivityDirectoryRepository {
  const SupabaseActivityDirectoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    try {
      final response = _asMap(
        await _client.rpc<Object?>(
          'superadmin_activity_directory',
          params: {
            'p_search': query.search.trim(),
            'p_institution_ids': query.institutionIds.toList(growable: false),
            'p_unit_ids': query.unitIds.toList(growable: false),
            'p_group_ids': query.groupIds.toList(growable: false),
            'p_statuses': query.statuses
                .map((status) => status.databaseValue)
                .toList(growable: false),
            'p_origins': query.origins
                .map((origin) => origin.databaseValue)
                .toList(growable: false),
            'p_limit': query.pageSize,
            'p_offset': query.offset,
            'p_sort': 'name',
            'p_sort_ascending': query.sortAscending,
          },
        ),
      );
      final rows = response['items'] as List<dynamic>? ?? const [];
      return ActivityDirectoryResult(
        items: rows
            .map((row) => ActivityDirectoryItem.fromJson(_asMap(row)))
            .toList(growable: false),
        totalCount: (response['total_count'] as num?)?.toInt() ?? 0,
        page: query.page,
        pageSize: query.pageSize,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async {
    try {
      final payload = _asMap(await _client.rpc<Object?>('superadmin_activity_filter_options'));
      return ActivityFilterOptions(
        institutions: _filterOptions(payload['institutions']),
        units: _filterOptions(payload['units'], parentKey: 'institution_id'),
        groups: _filterOptions(payload['groups'], parentKey: 'unit_id'),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

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
        taxonomy: _taxonomyOptions(payload['taxonomy']),
        templates: _templateOptions(payload['templates']),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async {
    try {
      final payload = _asMap(
        await _client.rpc<Object?>(
          'superadmin_get_activity_form_options',
          params: {'p_institution_id': institutionId},
        ),
      );
      return ActivityFormOptions(
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
        locations: _rows(payload['locations'])
            .map(
              (row) => ActivityFormLocationOption(
                id: row['id'] as String,
                unitId: row['unit_id'] as String,
                name: row['name'] as String,
              ),
            )
            .toList(growable: false),
        groups: _rows(payload['groups'])
            .map(
              (row) => ActivityFormGroupOption(
                id: row['id'] as String,
                unitId: row['unit_id'] as String,
                name: row['name'] as String,
                participantCount: (row['participant_count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(growable: false),
        professionals: _rows(payload['professionals'])
            .map(
              (row) => ActivityFormProfessionalOption(
                id: row['membership_id'] as String,
                name: row['name'] as String,
                role: row['role'] as String? ?? '',
                personId: row['person_id'] as String?,
              ),
            )
            .toList(growable: false),
        students: _rows(payload['students'])
            .map(
              (row) => ActivityFormStudentOption(
                childGroupLinkId: row['child_group_link_id'] as String,
                id: (row['child_id'] ?? row['id']) as String,
                groupId: row['group_id'] as String,
                name: row['name'] as String,
                age: (row['age'] as num?)?.toInt(),
                gender: row['gender'] as String?,
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

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async {
    try {
      final payload = _asMap(
        await _client.rpc<Object?>(
          'superadmin_search_activity_professionals',
          params: {
            'p_institution_id': institutionId,
            'p_query': query.trim(),
            'p_limit': limit.clamp(1, 20),
          },
        ),
      );
      return _rows(payload['items'])
          .map(
            (row) => ActivityFormProfessionalOption(
              id: row['membership_id'] as String,
              personId: row['person_id'] as String?,
              name: row['name'] as String,
              role: row['role'] as String? ?? '',
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ActivityDetail?> fetchById(String activityId) async {
    try {
      final payload = await _client.rpc<Object?>(
        'superadmin_activity_detail',
        params: {'p_activity_id': activityId},
      );
      if (payload == null) return null;
      return _detailFromJson(_asMap(payload));
    } on PostgrestException catch (error) {
      if (error.code == 'P0002') return null;
      throw _mapError(error);
    }
  }
}

final class UnavailableActivityDirectoryRepository implements ActivityDirectoryRepository {
  const UnavailableActivityDirectoryRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const ActivityDirectoryUnavailableException());

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _unavailable();

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _unavailable();

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) => _unavailable();

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) => _unavailable();

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) => _unavailable();

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) => _unavailable();
}

ActivityDetail _detailFromJson(Map<String, dynamic> json) {
  final unitRows = _rows(json['activity_unit_links']);
  final groupRows = _rows(json['activity_group_links']);
  final participants = _rows(json['participants'])
      .map((row) {
        final groupId =
            row['group_id'] as String? ??
            groupRows
                .where((group) => group['id'] == row['activity_group_link_id'])
                .map((group) => group['group_id'] as String)
                .firstOrNull;
        return groupId == null
            ? null
            : ActivityDetailParticipant(
                groupId: groupId,
                childGroupLinkId: row['child_group_link_id'] as String,
                belongs:
                    row['belongs'] as bool? ?? row['status'] == ActivityStatus.active.databaseValue,
              );
      })
      .whereType<ActivityDetailParticipant>()
      .toList(growable: false);
  final professionalAssignments =
      [..._rows(json['professional_assignments']), ..._rows(json['activity_admins'])]
          .map((row) {
            final membershipId = row['membership_id'] as String?;
            if (membershipId == null) return null;
            final role = switch (row['role']) {
              'activity_admin' => ActivityDetailProfessionalRole.activityAdmin,
              'instructor' => ActivityDetailProfessionalRole.instructor,
              _ => null,
            };
            if (role == null) return null;
            return ActivityDetailProfessionalAssignment(
              groupId: role == ActivityDetailProfessionalRole.activityAdmin
                  ? null
                  : row['group_id'] as String?,
              membershipId: membershipId,
              role: role,
              capabilities: _stringMap(row['capabilities']),
            );
          })
          .whereType<ActivityDetailProfessionalAssignment>()
          .toList(growable: false);
  final identityBucket = json['identity_storage_bucket'] as String?;
  final identityPath = json['identity_storage_path'] as String?;
  final originUnitId = json['origin_unit_id'] as String?;
  final units = unitRows
      .map(
        (row) => ActivityUnitLink(
          id: row['id'] as String,
          name: _relatedName(row['units'], 'Unidade não identificada'),
          status: ActivityStatus.fromDatabase(row['status'] as String),
          startsAt: DateTime.parse(row['starts_at'] as String),
          endsAt: _date(row['ends_at']),
        ),
      )
      .toList(growable: false);
  final groups = groupRows
      .map(
        (row) => ActivityGroupLink(
          id: row['id'] as String,
          name: _relatedName(row['groups'], 'Grupo não identificado'),
          unitName: _relatedName(row['units'], 'Unidade não identificada'),
          status: ActivityStatus.fromDatabase(row['status'] as String),
          participation: ActivityParticipation.fromDatabase(row['participation_mode'] as String),
          assigneeCount: _activeRows(row['activity_group_assignments']),
          participantCount: _activeRows(row['activity_group_participants']),
        ),
      )
      .toList(growable: false);
  return ActivityDetail(
    item: ActivityDirectoryItem.fromJson(json),
    createdAt: DateTime.parse(json['created_at'] as String),
    archivedAt: _date(json['archived_at']),
    originUnitName: originUnitId == null
        ? null
        : unitRows
              .where((row) => row['unit_id'] == originUnitId)
              .map((row) => _relatedName(row['units'], 'Unidade não identificada'))
              .firstOrNull,
    units: units,
    groups: groups,
    taxonomyId: json['taxonomy_id'] as String?,
    subtypeId: json['subtype_id'] as String?,
    templateId: json['template_id'] as String?,
    taxonomyOtherDescription: json['taxonomy_other_description'] as String? ?? '',
    identity: ActivityDetailIdentity(
      kind: switch (json['identity_mode']) {
        'photo' => ActivityDetailIdentityKind.photo,
        'icon' => ActivityDetailIdentityKind.icon,
        _ => ActivityDetailIdentityKind.initials,
      },
      initials: json['identity_initials'] as String?,
      color: json['identity_color'] as String?,
      icon: json['identity_icon'] as String?,
      storageRef: identityBucket == null || identityPath == null
          ? null
          : ActivityIdentityStorageRef(bucket: identityBucket, path: identityPath),
    ),
    participants: participants,
    professionalAssignments: professionalAssignments,
  );
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
        governance: ActivityGovernance.fromDatabase(
          row['governance_kind'] as String? ?? 'optional',
        ),
      ),
    )
    .toList(growable: false);

Map<String, String> _stringMap(Object? value) => value is Map
    ? Map<String, dynamic>.from(value).map((key, value) => MapEntry(key, value.toString()))
    : const {};

int _activeRows(Object? value) =>
    _rows(value).where((row) => row['status'] == ActivityStatus.active.databaseValue).length;

String _relatedName(Object? value, String fallback) {
  if (value is Map) {
    return Map<String, dynamic>.from(value)['name'] as String? ?? fallback;
  }
  return fallback;
}

DateTime? _date(Object? value) => value is String ? DateTime.parse(value) : null;

Exception _mapError(PostgrestException error) => error.code == '42501' || error.code == 'PGRST301'
    ? const ActivityDirectoryUnauthorizedException()
    : error.code == '0A000'
    ? const ActivityDirectoryUnavailableException()
    : error;

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const ActivityDirectoryUnavailableException();
}

List<ActivityFilterOption> _filterOptions(Object? value, {String? parentKey}) => _rows(value)
    .map(
      (row) => ActivityFilterOption(
        id: row['id'] as String,
        label: (row['label'] ?? row['name']) as String,
        parentId: parentKey == null ? null : row[parentKey] as String?,
      ),
    )
    .toList(growable: false);
