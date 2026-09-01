import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_directory.dart';

final class SupabaseGroupDirectoryRepository implements GroupDirectoryRepository {
  SupabaseGroupDirectoryRepository(this._client);

  final SupabaseClient _client;
  final Map<String, GroupRecord> _cache = {};

  @override
  Future<GroupRecord?> findById(String id) async {
    try {
      final record = _record(
        _map(await _client.rpc<Object?>('superadmin_group_get', params: {'p_group_id': id})),
      );
      _cache[record.id] = record;
      return record;
    } on PostgrestException catch (error) {
      if (error.code == 'P0002' || error.code == 'PGRST116') return null;
      throw _mapError(error);
    } on ClientException {
      throw const GroupDirectoryUnavailableException();
    }
  }

  @override
  String createId(String institutionId, String unitId, String name) => _uuidV4();

  @override
  Future<void> upsert(GroupRecord record) async {
    final result = await saveComposition(
      GroupDirectorySaveRequest(requestId: _uuidV4(), record: record),
    );
    if (result.hasFailure) throw const GroupDirectoryUnavailableException();
  }

  @override
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request) async {
    try {
      final response = _map(
        await _client.rpc<Object?>(
          'superadmin_group_save',
          params: {
            'p_request_id': _requestUuid(request.requestId),
            'p_group_id': request.record.managementVersion == 0 ? null : request.record.id,
            'p_expected_version': request.record.managementVersion,
            'p_payload': _savePayload(request),
          },
        ),
      );
      final saved = _record(response);
      _cache[saved.id] = saved;
      return GroupDirectorySaveResult(
        requestId: request.requestId,
        steps: [
          for (final stage in GroupDirectorySaveStage.values)
            GroupDirectorySaveStepResult.success(stage: stage),
        ],
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const GroupDirectoryUnavailableException();
    }
  }

  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'superadmin_group_directory',
          params: {
            'p_search': query.search.trim(),
            'p_institution_ids': query.institutionIds.toList(growable: false),
            'p_unit_ids': query.unitIds.toList(growable: false),
            'p_type_ids': query.typeIds.toList(growable: false),
            'p_statuses': query.statuses.map((item) => item.databaseValue).toList(),
            'p_limit': query.pageSize,
            'p_offset': query.offset,
            'p_sort': _sort(query.sortColumn),
            'p_sort_ascending': query.sortAscending,
          },
        ),
      );
      final items = <GroupDirectoryItem>[];
      for (final row in _rows(payload['items'])) {
        final record = _record(row);
        _cache[record.id] = record;
        items.add(GroupDirectoryItem(record));
      }
      return GroupDirectoryPage(
        items: items,
        totalCount: _int(payload['total_count']),
        page: query.page,
        pageSize: query.pageSize,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const GroupDirectoryUnavailableException();
    }
  }

  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({
    Set<String> institutionIds = const {},
  }) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'unit_directory_filter_options',
          params: const {'p_states': <String>[], 'p_cities': <String>[]},
        ),
      );
      final unitPayload = _map(
        await _client.rpc<Object?>(
          'list_units_for_superadmin',
          params: {
            'p_search': '',
            'p_institution_ids': institutionIds.toList(growable: false),
            'p_institution_type_ids': <String>[],
            'p_unit_type_ids': <String>[],
            'p_unit_statuses': const ['active'],
            'p_plan_ids': <String>[],
            'p_states': <String>[],
            'p_cities': <String>[],
            'p_districts': <String>[],
            'p_sort': 'name',
            'p_ascending': true,
            'p_offset': 0,
            'p_limit': 100,
          },
        ),
      );
      final institutions = _options(payload['institutions']);
      final units = _rows(unitPayload['items'])
          .map(
            (row) => GroupDirectoryFilterOption(
              id: _string(row, 'id'),
              label: _string(row, 'name'),
              institutionId: row['institution_id'] as String?,
            ),
          )
          .toList(growable: false);
      return GroupDirectoryFilterOptions(
        institutions: institutions,
        units: units,
        types: _groupTypes,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const GroupDirectoryUnavailableException();
    }
  }

  @override
  Future<GroupDirectoryFormContext> fetchFormContext({String? institutionId}) async {
    final options = await fetchFilterOptions(
      institutionIds: institutionId == null ? const {} : {institutionId},
    );
    return GroupDirectoryFormContext(
      institutions: options.institutions,
      units: options.units,
      types: options.types,
    );
  }

  @override
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'superadmin_group_export_create',
          params: {
            'p_request_id': _uuidV4(),
            'p_payload': {
              'search': query.search.trim(),
              'institution_ids': query.institutionIds.toList(growable: false),
              'unit_ids': query.unitIds.toList(growable: false),
              'type_ids': query.typeIds.toList(growable: false),
              'statuses': query.statuses.map((item) => item.databaseValue).toList(),
              'format': 'xlsx',
            },
          },
        ),
      );
      return GroupDirectoryExportResult(
        jobId: (payload['job_id'] ?? payload['id']) as String,
        downloadUrl: payload['download_url'] as String? ?? '',
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const GroupDirectoryUnavailableException();
    }
  }
}

const _groupTypes = <GroupDirectoryFilterOption>[
  GroupDirectoryFilterOption(id: 'class', label: 'Turma'),
  GroupDirectoryFilterOption(id: 'workshop', label: 'Workshop'),
  GroupDirectoryFilterOption(id: 'other', label: 'Outro'),
];

Map<String, Object?> _savePayload(GroupDirectorySaveRequest request) => {
  'institution_id': request.record.institutionId,
  'unit_id': request.record.unitId,
  'name': request.record.name.trim(),
  'group_type': request.record.groupType.trim().toLowerCase(),
  'group_type_other_text': request.record.groupTypeOtherText,
  'status': request.record.statusDatabaseValue,
  'inherit_appearance': request.record.inheritAppearance,
  'inherit_access': request.record.inheritAccess,
  'inherit_activities': request.record.inheritActivities,
  if (!request.record.inheritAppearance) 'branding': request.branding,
  'local_people': [
    for (final person in [...request.people, ...request.professionals])
      {'person_id': person.id, 'role_code': person.role},
  ],
  'activity_ids': request.activityIds,
  'invites': [
    for (final invite in request.invites)
      {
        if (_isUuid(invite.id)) 'invitation_id': invite.id,
        'person_id': invite.id,
        'role_code': invite.role,
        if (invite.status == 'resend') 'command': 'resend',
      },
  ],
  if (request.typeRequestLabel?.trim().isNotEmpty == true)
    'type_request': {
      'label': request.typeRequestLabel!.trim(),
      'justification': request.typeRequestJustification?.trim(),
    },
};

GroupRecord _record(Map<String, dynamic> row) {
  final access = _rows(row['effective_access'])
      .map((item) {
        final profile = _mapOrEmpty(item['profile']);
        return GroupEffectiveAccess(
          personId: item['person_id'] as String? ?? '',
          displayName: item['display_name'] as String? ?? '',
          origin: item['origin'] as String? ?? 'group',
          inherited: item['inherited'] == true,
          profileId: profile['id'] as String? ?? '',
          profileCode: profile['code'] as String? ?? '',
          profileName: profile['name'] as String? ?? '',
          capabilities: _strings(item['capabilities']),
          restrictions: _strings(item['restrictions']),
        );
      })
      .toList(growable: false);
  final activities = _strings(row['activity_ids']);
  return GroupRecord(
    id: _string(row, 'id'),
    institutionId: _string(row, 'institution_id'),
    institutionName: row['institution_name'] as String? ?? '',
    unitId: _string(row, 'unit_id'),
    unitName: row['unit_name'] as String? ?? '',
    name: _string(row, 'name'),
    groupType: row['group_type'] as String? ?? 'class',
    status: GroupStatus.fromDatabaseValue(row['status'] as String?),
    statusValue: row['status'] as String?,
    createdAt: _date(row['created_at']),
    updatedAt: _date(row['updated_at']),
    groupTypeOtherText: row['group_type_other_text'] as String?,
    inheritAppearance: row['inherit_appearance'] != false,
    inheritAccess: row['inherit_access'] != false,
    inheritActivities: row['inherit_activities'] != false,
    managementVersion: _int(row['management_version']),
    appearanceOrigin: row['appearance_origin'] as String? ?? 'unit',
    effectiveAppearance: _mapOrEmpty(
      row['effective_appearance'],
    ).map((key, value) => MapEntry(key, value as String?)),
    effectiveAccess: access,
    activityIds: activities,
    invites: [
      for (final invite in _rows(row['invites']))
        GroupDirectoryInviteBinding(
          id: invite['id'] as String? ?? '',
          identifier: invite['identifier'] as String? ?? '',
          role: invite['role_code'] as String? ?? '',
          profile: invite['profile'] as String? ?? '',
          status: invite['status'] as String? ?? 'pending',
        ),
    ],
    studentCount: _int(row['student_count']),
    teacherOrResponsibleNames: access
        .where((item) => item.profileCode == 'teacher' || item.profileCode == 'professional')
        .map((item) => item.displayName)
        .where((name) => name.isNotEmpty)
        .toList(growable: false),
  );
}

List<GroupDirectoryFilterOption> _options(Object? value) => _rows(value)
    .map(
      (row) => GroupDirectoryFilterOption(
        id: _string(row, 'id'),
        label: _string(row, 'label'),
        institutionId: row['institution_id'] as String?,
      ),
    )
    .toList(growable: false);

String _sort(GroupDirectorySortColumn column) => switch (column) {
  GroupDirectorySortColumn.name => 'name',
  GroupDirectorySortColumn.institutionName => 'institution_name',
  GroupDirectorySortColumn.unitName => 'unit_name',
  GroupDirectorySortColumn.groupType => 'group_type',
  GroupDirectorySortColumn.status => 'status',
};

Map<String, dynamic> _map(Object? value) {
  if (value is Map<Object?, Object?>) return Map<String, dynamic>.from(value);
  if (value is String) return Map<String, dynamic>.from(jsonDecode(value) as Map<Object?, Object?>);
  throw const GroupDirectoryUnavailableException();
}

Map<String, dynamic> _mapOrEmpty(Object? value) =>
    value is Map<Object?, Object?> ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value
          .whereType<Map<Object?, Object?>>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false)
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.whereType<Object>().map((item) => item.toString()).toList(growable: false)
    : const [];

String _string(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is String && value.isNotEmpty) return value;
  throw const GroupDirectoryUnavailableException();
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

DateTime _date(Object? value) =>
    value is String ? DateTime.parse(value) : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Exception _mapError(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' => const GroupDirectoryUnauthorizedException(),
  _ => const GroupDirectoryUnavailableException(),
};

String _requestUuid(String value) {
  if (_isUuid(value)) return value.toLowerCase();
  final hex = sha256.convert(utf8.encode(value)).toString();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-'
      '8${hex.substring(17, 20)}-${hex.substring(20, 32)}';
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

String _uuidV4() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
