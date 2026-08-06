import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_directory.dart';

final class SupabaseActivityDirectoryRepository implements ActivityDirectoryRepository {
  const SupabaseActivityDirectoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    try {
      var request = _client
          .from('activity_definitions')
          .select(
            'id,institution_id,name,description,origin_scope_kind,status,'
            'distribution_scope,governance_kind,updated_at,'
            'institutions(name),activity_unit_links(id,status),'
            'activity_group_links(id,status)',
          );
      final search = query.search.trim();
      if (search.isNotEmpty) {
        final pattern = '*${_escapeFilter(search)}*';
        request = request.or('name.ilike.$pattern,description.ilike.$pattern');
      }
      if (query.institutionIds.isNotEmpty) {
        request = request.inFilter('institution_id', query.institutionIds.toList(growable: false));
      }
      if (query.statuses.isNotEmpty) {
        request = request.inFilter(
          'status',
          query.statuses.map((status) => status.databaseValue).toList(growable: false),
        );
      }
      if (query.origins.isNotEmpty) {
        request = request.inFilter(
          'origin_scope_kind',
          query.origins.map((origin) => origin.databaseValue).toList(growable: false),
        );
      }
      final response = await request
          .order('name', ascending: query.sortAscending)
          .order('id', ascending: true)
          .range(query.offset, query.offset + query.pageSize - 1)
          .count(CountOption.exact);
      return ActivityDirectoryResult(
        items: response.data
            .map((row) => ActivityDirectoryItem.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false),
        totalCount: response.count,
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
      final rows = await _client.from('institutions').select('id,name').order('name');
      return ActivityFilterOptions(
        institutions: rows
            .map((row) => Map<String, dynamic>.from(row))
            .map(
              (row) => ActivityFilterOption(id: row['id'] as String, label: row['name'] as String),
            )
            .toList(growable: false),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ActivityFormOptions> fetchFormOptions() async {
    try {
      final institutions = await _client.from('institutions').select('id,name').order('name');
      final units = await _client
          .from('units')
          .select('id,institution_id,name,status')
          .eq('status', ActivityStatus.active.databaseValue)
          .order('name');
      return ActivityFormOptions(
        institutions: institutions
            .map((row) => Map<String, dynamic>.from(row))
            .map(
              (row) => ActivityFormInstitutionOption(
                id: row['id'] as String,
                name: row['name'] as String,
              ),
            )
            .toList(growable: false),
        units: units
            .map((row) => Map<String, dynamic>.from(row))
            .map(
              (row) => ActivityFormUnitOption(
                id: row['id'] as String,
                institutionId: row['institution_id'] as String,
                name: row['name'] as String,
              ),
            )
            .toList(growable: false),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ActivityDetail?> fetchById(String activityId) async {
    try {
      final rows = await _client
          .from('activity_definitions')
          .select(
            'id,institution_id,name,description,origin_scope_kind,origin_unit_id,status,'
            'distribution_scope,governance_kind,created_at,updated_at,archived_at,'
            'institutions(name),'
            'activity_unit_links(id,unit_id,status,starts_at,ends_at,units(name)),'
            'activity_group_links(id,group_id,unit_id,status,participation_mode,'
            'groups(name),units(name),activity_group_assignments(id,status),'
            'activity_group_participants(id,status))',
          )
          .eq('id', activityId)
          .limit(1);
      if (rows.isEmpty) return null;
      return _detailFromJson(Map<String, dynamic>.from(rows.first));
    } on PostgrestException catch (error) {
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
  Future<ActivityFormOptions> fetchFormOptions() => _unavailable();

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) => _unavailable();
}

ActivityDetail _detailFromJson(Map<String, dynamic> json) {
  final unitRows = _rows(json['activity_unit_links']);
  final groupRows = _rows(json['activity_group_links']);
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
  );
}

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList(growable: false)
    : const [];

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
    : error;

String _escapeFilter(String value) =>
    value.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll('.', '\\.');
