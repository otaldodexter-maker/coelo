import '../../institutions/data/fake_institution_directory_repository.dart';
import '../domain/group_directory.dart';

final class FakeGroupDirectoryRepository implements GroupDirectoryRepository {
  FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository institutions)
    : _institutions = institutions,
      _records = [
        for (final institution in institutions.records)
          for (final unit in institution.units)
            for (var index = 0; index < unit.groups.length; index++)
              GroupRecord(
                id: unit.groups[index].id,
                institutionId: institution.id,
                institutionName: institution.publicName,
                unitId: unit.id,
                unitName: unit.name,
                name: unit.groups[index].name,
                groupType: index.isEven ? 'class' : 'Atividade',
                status: GroupStatus.values[index % GroupStatus.values.length],
                createdAt: DateTime(2026, 1, 1).add(Duration(days: index)),
                updatedAt: DateTime(2026, 7, 29),
              ),
      ];

  final FakeInstitutionDirectoryRepository _institutions;
  final List<GroupRecord> _records;

  @override
  List<GroupRecord> get records => List.unmodifiable(_records);

  @override
  GroupRecord? findById(String id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  String createId(String institutionId, String unitId, String name) {
    final normalized = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final base = '$institutionId-$unitId-group-${normalized.isEmpty ? 'novo' : normalized}';
    var candidate = base;
    var suffix = 2;
    while (findById(candidate) != null) {
      candidate = '$base-${suffix++}';
    }
    return candidate;
  }

  @override
  Future<void> upsert(GroupRecord record) async {
    final institution = _institutions.findById(record.institutionId);
    if (institution == null || !institution.units.any((unit) => unit.id == record.unitId)) {
      throw ArgumentError('Group must belong to a unit in its institution.');
    }
    final index = _records.indexWhere((candidate) => candidate.id == record.id);
    if (index != -1 &&
        (_records[index].institutionId != record.institutionId ||
            _records[index].unitId != record.unitId)) {
      throw ArgumentError('Changing an existing group hierarchy is not supported.');
    }
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
  }

  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) async {
    final search = query.search.trim().toLowerCase();
    final filtered =
        _records.where((record) {
          return (search.isEmpty || record.name.toLowerCase().contains(search)) &&
              (query.institutionIds.isEmpty ||
                  query.institutionIds.contains(record.institutionId)) &&
              (query.unitIds.isEmpty || query.unitIds.contains(record.unitId)) &&
              (query.typeIds.isEmpty || query.typeIds.contains(record.groupType)) &&
              (query.statuses.isEmpty || query.statuses.contains(record.status));
        }).toList()..sort((first, second) {
          final comparison = _compare(first, second, query.sortColumn);
          return comparison == 0
              ? first.id.compareTo(second.id)
              : query.sortAscending
              ? comparison
              : -comparison;
        });
    final start = query.offset.clamp(0, filtered.length);
    final end = (start + query.pageSize).clamp(start, filtered.length);
    return GroupDirectoryPage(
      items: List.unmodifiable(filtered.sublist(start, end).map(GroupDirectoryItem.new)),
      totalCount: filtered.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({
    Set<String> institutionIds = const {},
  }) async {
    List<GroupDirectoryFilterOption> options(Map<String, GroupDirectoryFilterOption> values) {
      return values.values.toList()..sort((first, second) => first.label.compareTo(second.label));
    }

    final institutions = <String, GroupDirectoryFilterOption>{};
    final units = <String, GroupDirectoryFilterOption>{};
    final types = <String, GroupDirectoryFilterOption>{};
    for (final record in _records) {
      institutions[record.institutionId] = GroupDirectoryFilterOption(
        id: record.institutionId,
        label: record.institutionName,
      );
      if (institutionIds.isEmpty || institutionIds.contains(record.institutionId)) {
        units[record.unitId] = GroupDirectoryFilterOption(
          id: record.unitId,
          label: record.unitName,
          institutionId: record.institutionId,
        );
      }
      types[record.groupType] = GroupDirectoryFilterOption(
        id: record.groupType,
        label: record.groupTypeLabel,
      );
    }
    return GroupDirectoryFilterOptions(
      institutions: options(institutions),
      units: options(units),
      types: options(types),
    );
  }
}

int _compare(GroupRecord first, GroupRecord second, GroupDirectorySortColumn column) =>
    switch (column) {
      GroupDirectorySortColumn.name => first.name.compareTo(second.name),
      GroupDirectorySortColumn.institutionName => first.institutionName.compareTo(
        second.institutionName,
      ),
      GroupDirectorySortColumn.unitName => first.unitName.compareTo(second.unitName),
      GroupDirectorySortColumn.groupType => first.groupType.compareTo(second.groupType),
      GroupDirectorySortColumn.status => first.status.databaseValue.compareTo(
        second.status.databaseValue,
      ),
    };
