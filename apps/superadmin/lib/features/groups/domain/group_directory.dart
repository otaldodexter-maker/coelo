enum GroupStatus {
  draft('draft', 'Rascunho'),
  active('active', 'Ativo'),
  inactive('inactive', 'Inativo'),
  suspended('suspended', 'Suspenso'),
  archived('archived', 'Arquivado');

  const GroupStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;
}

final class GroupRecord {
  const GroupRecord({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.name,
    required this.groupType,
    required this.status,
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
  final GroupStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get groupTypeLabel => groupTypeLabelFor(groupType);

  static String groupTypeLabelFor(String value) => value == 'class' ? 'Turma' : value;

  GroupRecord copyWith({
    String? id,
    String? institutionId,
    String? institutionName,
    String? unitId,
    String? unitName,
    String? name,
    String? groupType,
    GroupStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (institutionId != null && institutionId != this.institutionId) {
      throw ArgumentError('Changing an existing group institution is not supported.');
    }
    if (unitId != null && unitId != this.unitId) {
      throw ArgumentError('Changing an existing group unit is not supported.');
    }
    return GroupRecord(
      id: id ?? this.id,
      institutionId: this.institutionId,
      institutionName: institutionName ?? this.institutionName,
      unitId: this.unitId,
      unitName: unitName ?? this.unitName,
      name: name ?? this.name,
      groupType: groupType ?? this.groupType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class GroupDirectoryItem {
  const GroupDirectoryItem(this.record);

  final GroupRecord record;

  String get id => record.id;
  String get institutionId => record.institutionId;
  String get institutionName => record.institutionName;
  String get unitId => record.unitId;
  String get unitName => record.unitName;
  String get name => record.name;
  String get groupType => record.groupType;
  String get groupTypeLabel => record.groupTypeLabel;
  GroupStatus get status => record.status;
}

enum GroupDirectorySortColumn { name, institutionName, unitName, groupType, status }

final class GroupDirectoryQuery {
  static const defaultPageSize = 11;
  static const allowedPageSizes = <int>[8, 11, 20, 50, 100];

  GroupDirectoryQuery({
    this.search = '',
    Set<String> institutionIds = const {},
    Set<String> unitIds = const {},
    Set<String> typeIds = const {},
    Set<GroupStatus> statuses = const {},
    this.page = 0,
    this.pageSize = defaultPageSize,
    this.sortColumn = GroupDirectorySortColumn.name,
    this.sortAscending = true,
  }) : assert(page >= 0),
       assert(allowedPageSizes.contains(pageSize)),
       institutionIds = Set.unmodifiable(institutionIds),
       unitIds = Set.unmodifiable(unitIds),
       typeIds = Set.unmodifiable(typeIds),
       statuses = Set.unmodifiable(statuses);

  final String search;
  final Set<String> institutionIds;
  final Set<String> unitIds;
  final Set<String> typeIds;
  final Set<GroupStatus> statuses;
  final int page;
  final int pageSize;
  final GroupDirectorySortColumn sortColumn;
  final bool sortAscending;

  int get offset => page * pageSize;
  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      institutionIds.isNotEmpty ||
      unitIds.isNotEmpty ||
      typeIds.isNotEmpty ||
      statuses.isNotEmpty;
}

final class GroupDirectoryPage {
  const GroupDirectoryPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<GroupDirectoryItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
}

final class GroupDirectoryFilterOption {
  const GroupDirectoryFilterOption({required this.id, required this.label, this.institutionId});

  final String id;
  final String label;
  final String? institutionId;
}

final class GroupDirectoryFilterOptions {
  const GroupDirectoryFilterOptions({
    this.institutions = const [],
    this.units = const [],
    this.types = const [],
  });

  final List<GroupDirectoryFilterOption> institutions;
  final List<GroupDirectoryFilterOption> units;
  final List<GroupDirectoryFilterOption> types;
}

abstract interface class GroupDirectoryRepository {
  List<GroupRecord> get records;
  GroupRecord? findById(String id);
  String createId(String institutionId, String unitId, String name);
  Future<void> upsert(GroupRecord record);
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query);
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({Set<String> institutionIds = const {}});
}

final class GroupDirectoryUnauthorizedException implements Exception {
  const GroupDirectoryUnauthorizedException();
}
