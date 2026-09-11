enum ActivityReadDetailFailure { invalidId, denied, unavailable }

class ActivityReadDetailException implements Exception {
  const ActivityReadDetailException(this.failure);
  final ActivityReadDetailFailure failure;
  @override
  String toString() => 'ActivityReadDetailException(${failure.name})';
}

abstract interface class ActivityReadDetailRepository {
  Future<ActivityReadDetail> fetchById(String activityId);
}

class UnavailableActivityReadDetailRepository implements ActivityReadDetailRepository {
  const UnavailableActivityReadDetailRepository();

  @override
  Future<ActivityReadDetail> fetchById(String activityId) async {
    throw const ActivityReadDetailException(ActivityReadDetailFailure.unavailable);
  }
}

/// Base projection of superadmin_activity_detail_v2 with no optional sections.
/// Unit/group statuses describe the links, not the referenced entities.
class ActivityReadDetail {
  ActivityReadDetail._(Map<String, dynamic> activity, this.units, this.groups, this.counts)
    : id = _uuid(activity['activity_id']),
      institutionId = _uuid(activity['institution_id']),
      name = _text(activity['name']),
      description = _nullableText(activity['description']),
      taxonomyId = activity['taxonomy_id'] == null ? null : _uuid(activity['taxonomy_id']),
      taxonomyName = _nullableText(activity['taxonomy_name']),
      status = _choice(activity['status'], const {
        'draft',
        'active',
        'inactive',
        'suspended',
        'archived',
      }),
      managementVersion = _integer(activity['management_version'], minimum: 1),
      iconKey = _nullableText(activity['icon_key']),
      initials = _nullableText(activity['initials']),
      createdAt = _timestamp(activity['created_at']),
      updatedAt = _timestamp(activity['updated_at']);

  final String id;
  final String institutionId;
  final String name;
  final String? description;
  final String? taxonomyId;
  final String? taxonomyName;
  final String status;
  final int managementVersion;
  final String? iconKey;
  final String? initials;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ActivityReadUnit> units;
  final List<ActivityReadGroup> groups;
  final ActivityReadCounts counts;

  factory ActivityReadDetail.fromJson(Object? value) {
    final data = _map(value, const {'activity', 'units', 'groups', 'counts'});
    final activity = _map(data['activity'], const {
      'activity_id',
      'institution_id',
      'name',
      'description',
      'taxonomy_id',
      'taxonomy_name',
      'status',
      'management_version',
      'icon_key',
      'initials',
      'created_at',
      'updated_at',
    });
    final units = List<ActivityReadUnit>.unmodifiable(_rows(data['units']).map(ActivityReadUnit._));
    final groups = List<ActivityReadGroup>.unmodifiable(
      _rows(data['groups']).map(ActivityReadGroup._),
    );
    final counts = ActivityReadCounts._(data['counts']);
    final unitIds = units.map((u) => u.unitId).toSet();
    if (unitIds.length != units.length ||
        groups.map((g) => g.groupId).toSet().length != groups.length ||
        groups.any((g) => !unitIds.contains(g.unitId)) ||
        counts.units != units.length ||
        counts.groups != groups.length) {
      throw const FormatException('Invalid activity relationships');
    }
    return ActivityReadDetail._(activity, units, groups, counts);
  }
}

class ActivityReadUnit {
  ActivityReadUnit._(Object? value) {
    final row = _map(value, const {'unit_id', 'name', 'status'});
    unitId = _uuid(row['unit_id']);
    name = _text(row['name']);
    status = _choice(row['status'], const {'active'});
  }
  late final String unitId;
  late final String name;
  late final String status;
}

class ActivityReadGroup {
  ActivityReadGroup._(Object? value) {
    final row = _map(value, const {'group_id', 'unit_id', 'name', 'status', 'participation_mode'});
    groupId = _uuid(row['group_id']);
    unitId = _uuid(row['unit_id']);
    name = _text(row['name']);
    status = _choice(row['status'], const {'active'});
    participationMode = _choice(row['participation_mode'], const {'all', 'selected'});
  }
  late final String groupId;
  late final String unitId;
  late final String name;
  late final String status;
  late final String participationMode;
}

/// Counts retain the RPC's predicates; they are not per-group people counts.
class ActivityReadCounts {
  ActivityReadCounts._(Object? value) {
    final row = _map(value, const {
      'units',
      'groups',
      'participants',
      'instructors',
      'activity_admins',
    });
    units = _integer(row['units']);
    groups = _integer(row['groups']);
    participants = _integer(row['participants']);
    instructors = _integer(row['instructors']);
    activityAdmins = _integer(row['activity_admins']);
  }
  late final int units;
  late final int groups;
  late final int participants;
  late final int instructors;
  late final int activityAdmins;
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
bool isActivityReadDetailId(String value) => _uuidPattern.hasMatch(value);
String _uuid(Object? value) {
  if (value is! String || !isActivityReadDetailId(value)) {
    throw const FormatException('Invalid identifier');
  }
  return value.toLowerCase();
}

/// Exige as chaves conhecidas e ignora chaves aditivas do servidor (a regra
/// do @ acrescenta campos aos detail_v2 sem quebrar o cliente).
Map<String, dynamic> _map(Object? value, Set<String> keys) {
  if (value is! Map || !keys.every(value.containsKey)) {
    throw const FormatException('Invalid object');
  }
  return {for (final key in keys) key: value[key]};
}

List<dynamic> _rows(Object? value) {
  if (value is! List) throw const FormatException('Invalid rows');
  return value;
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) throw const FormatException('Invalid text');
  return value;
}

String? _nullableText(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid nullable text');
  return value;
}

String _choice(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) throw const FormatException('Invalid status');
  return value;
}

int _integer(Object? value, {int minimum = 0}) {
  // Flutter web must not silently round bigint/count values beyond safe integers.
  if (value is! int || value < minimum || value > 9007199254740991) {
    throw const FormatException('Invalid count');
  }
  return value;
}

DateTime _timestamp(Object? value) {
  if (value is! String) throw const FormatException('Invalid timestamp');
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null) throw const FormatException('Invalid timestamp');
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] ||
      date.month != parts[1] ||
      date.day != parts[2] ||
      parts[3] > 23 ||
      parts[4] > 59 ||
      parts[5] > 59) {
    throw const FormatException('Invalid timestamp');
  }
  final zone = match.group(7)!;
  if (zone != 'Z' && (int.parse(zone.substring(1, 3)) > 23 || int.parse(zone.substring(4)) > 59)) {
    throw const FormatException('Invalid timezone');
  }
  return DateTime.parse(value).toUtc();
}
