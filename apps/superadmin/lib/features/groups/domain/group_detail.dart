enum GroupDetailFailure { invalidId, denied, unavailable }

final class GroupDetailException implements Exception {
  const GroupDetailException(this.failure);
  final GroupDetailFailure failure;
  @override
  String toString() => 'GroupDetailException(${failure.name})';
}

abstract interface class GroupDetailRepository {
  Future<GroupDetail> fetchById(String groupId);
}

/// Local read preflight; backend authorization remains mandatory for real reads.
final class DeniedGroupDetailRepository implements GroupDetailRepository {
  const DeniedGroupDetailRepository();
  @override
  Future<GroupDetail> fetchById(String groupId) async =>
      throw const GroupDetailException(GroupDetailFailure.denied);
}

final class UnavailableGroupDetailRepository implements GroupDetailRepository {
  const UnavailableGroupDetailRepository();
  @override
  Future<GroupDetail> fetchById(String groupId) async =>
      throw const GroupDetailException(GroupDetailFailure.unavailable);
}

/// Only the physical fields authorized by spec 045; no inferred relationships.
final class GroupDetail {
  const GroupDetail({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.name,
    required this.groupType,
    required this.groupTypeOtherText,
    required this.status,
    required this.inheritAppearance,
    required this.inheritAccess,
    required this.inheritActivities,
    required this.managementVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String institutionId;
  final String institutionName;
  final String unitId;
  final String unitName;
  final String name;
  final String groupType;
  final String? groupTypeOtherText;
  final String status;
  final bool inheritAppearance;
  final bool inheritAccess;
  final bool inheritActivities;
  final int managementVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GroupDetail.fromJson(Object? value) {
    final data = _map(value, const {
      'id',
      'institution',
      'unit',
      'name',
      'group_type',
      'group_type_other_text',
      'status',
      'inherit_appearance',
      'inherit_access',
      'inherit_activities',
      'management_version',
      'created_at',
      'updated_at',
    });
    final institution = _map(data['institution'], const {'id', 'name'});
    final unit = _map(data['unit'], const {'id', 'name'});
    final status = _string(data['status']);
    final version = data['management_version'];
    if (!const {'draft', 'active', 'inactive', 'suspended', 'archived'}.contains(status) ||
        version is! int ||
        version < 1) {
      throw const FormatException('Invalid group detail');
    }
    return GroupDetail(
      id: _uuid(data['id']),
      institutionId: _uuid(institution['id']),
      institutionName: _string(institution['name']),
      unitId: _uuid(unit['id']),
      unitName: _string(unit['name']),
      name: _string(data['name']),
      groupType: _string(data['group_type']),
      groupTypeOtherText: data['group_type_other_text'] == null
          ? null
          : _string(data['group_type_other_text']),
      status: status,
      inheritAppearance: _bool(data['inherit_appearance']),
      inheritAccess: _bool(data['inherit_access']),
      inheritActivities: _bool(data['inherit_activities']),
      managementVersion: version,
      createdAt: DateTime.parse(_string(data['created_at'])),
      updatedAt: DateTime.parse(_string(data['updated_at'])),
    );
  }
}

bool isGroupDetailId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

/// Exige as chaves conhecidas e ignora chaves aditivas (superadmin_group_detail_v2
/// passou a devolver `handle` na R05, regra do @).
Map<String, Object?> _map(Object? value, Set<String> keys) {
  if (value is! Map || !keys.every(value.containsKey)) {
    throw const FormatException('Invalid group detail');
  }
  return {for (final key in keys) key: value[key]};
}

String _string(Object? value) =>
    value is String ? value : throw const FormatException('Invalid group detail');
bool _bool(Object? value) =>
    value is bool ? value : throw const FormatException('Invalid group detail');
String _uuid(Object? value) {
  final id = _string(value);
  if (!isGroupDetailId(id)) throw const FormatException('Invalid group detail');
  return id;
}
