import '../../institutions/data/fake_institution_directory_repository.dart';
import '../domain/group_directory.dart';

/// Deterministic repository restricted to tests, previews, and goldens.
final class FakeGroupDirectoryRepository implements GroupDirectoryRepository {
  FakeGroupDirectoryRepository(this._institutions, {List<GroupRecord>? records})
    : _records = [...?records] {
    if (records == null) {
      final now = DateTime(2026, 7, 29);
      var index = 0;
      for (final institution in _institutions.records) {
        for (final unit in institution.units) {
          for (final group in unit.groups) {
            _records.add(
              GroupRecord(
                id: group.id,
                institutionId: institution.id,
                institutionName: institution.publicName,
                unitId: unit.id,
                unitName: unit.name,
                name: group.name,
                groupType: index.isEven ? 'class' : 'workshop',
                status: index % 3 == 0 ? GroupStatus.draft : GroupStatus.active,
                createdAt: now,
                updatedAt: now,
                studentCount: 8 + index % 23,
                activityIds: index % 5 == 0
                    ? const []
                    : [
                        for (var activity = 0; activity < 1 + index % 4; activity += 1)
                          'activity-${(index + activity) % 30 + 1}',
                      ],
                teacherOrResponsibleNames: index.isEven
                    ? const ['Ana Souza', 'Marcos Lima']
                    : const ['Beatriz Nunes'],
              ),
            );
            index += 1;
          }
        }
      }
    }
  }

  final FakeInstitutionDirectoryRepository _institutions;
  final List<GroupRecord> _records;

  List<GroupRecord> get records => List.unmodifiable(_records);

  @override
  Future<GroupRecord?> findById(String id) async {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  String createId(String institutionId, String unitId, String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final base = 'fixture-$institutionId-$unitId-${slug.isEmpty ? 'turma' : slug}';
    var candidate = base;
    var suffix = 2;
    while (_records.any((record) => record.id == candidate)) {
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
    if (index >= 0 &&
        (_records[index].institutionId != record.institutionId ||
            _records[index].unitId != record.unitId)) {
      throw ArgumentError('Changing an existing group hierarchy is not supported.');
    }
    if (index < 0) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
  }

  @override
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request) async {
    final inheritedAccess = request.record.effectiveAccess
        .where((access) => access.inherited)
        .toList(growable: false);
    final localBindings = [...request.people, ...request.professionals];
    await upsert(
      request.record.copyWith(
        effectiveAccess: [
          ...inheritedAccess,
          for (final binding in localBindings)
            GroupEffectiveAccess(
              personId: binding.id,
              displayName: binding.name,
              origin: 'group',
              inherited: false,
              profileId: 'preview-${binding.profile ?? binding.role}',
              profileCode: binding.role,
              profileName: binding.profile ?? binding.role,
            ),
        ],
        invites: request.invites,
      ),
    );
    return GroupDirectorySaveResult(
      requestId: request.requestId,
      steps: [
        for (final stage in GroupDirectorySaveStage.values)
          GroupDirectorySaveStepResult.success(stage: stage),
      ],
    );
  }

  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) async {
    final search = query.search.trim().toLowerCase();
    final filtered = _records.where((record) {
      if (search.isNotEmpty &&
          !record.name.toLowerCase().contains(search) &&
          !record.institutionName.toLowerCase().contains(search) &&
          !record.unitName.toLowerCase().contains(search)) {
        return false;
      }
      if (query.institutionIds.isNotEmpty && !query.institutionIds.contains(record.institutionId)) {
        return false;
      }
      if (query.unitIds.isNotEmpty && !query.unitIds.contains(record.unitId)) {
        return false;
      }
      if (query.typeIds.isNotEmpty && !query.typeIds.contains(record.groupType)) {
        return false;
      }
      return query.statuses.isEmpty || query.statuses.contains(record.status);
    }).toList();

    int compare(GroupRecord first, GroupRecord second) {
      final result = switch (query.sortColumn) {
        GroupDirectorySortColumn.name => first.name.compareTo(second.name),
        GroupDirectorySortColumn.institutionName => first.institutionName.compareTo(
          second.institutionName,
        ),
        GroupDirectorySortColumn.unitName => first.unitName.compareTo(second.unitName),
        GroupDirectorySortColumn.groupType => first.groupType.compareTo(second.groupType),
        GroupDirectorySortColumn.status => first.statusDatabaseValue.compareTo(
          second.statusDatabaseValue,
        ),
      };
      return query.sortAscending ? result : -result;
    }

    filtered.sort(compare);
    final start = query.offset.clamp(0, filtered.length);
    final end = (start + query.pageSize).clamp(start, filtered.length);
    return GroupDirectoryPage(
      items: filtered.sublist(start, end).map(GroupDirectoryItem.new).toList(),
      totalCount: filtered.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({
    Set<String> institutionIds = const {},
  }) async {
    final institutions =
        _institutions.records
            .map((record) => GroupDirectoryFilterOption(id: record.id, label: record.publicName))
            .toList()
          ..sort((first, second) => first.label.compareTo(second.label));
    final units = [
      for (final institution in _institutions.records)
        if (institutionIds.isEmpty || institutionIds.contains(institution.id))
          for (final unit in institution.units)
            GroupDirectoryFilterOption(
              id: unit.id,
              label: unit.name,
              institutionId: institution.id,
            ),
    ]..sort((first, second) => first.label.compareTo(second.label));
    final types =
        _records
            .map((record) => record.groupType)
            .toSet()
            .map(
              (type) =>
                  GroupDirectoryFilterOption(id: type, label: GroupRecord.groupTypeLabelFor(type)),
            )
            .toList()
          ..sort((first, second) => first.label.compareTo(second.label));
    return GroupDirectoryFilterOptions(institutions: institutions, units: units, types: types);
  }

  @override
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query) async =>
      GroupDirectoryExportResult(
        jobId: 'fixture-export-${query.offset}',
        downloadUrl: 'https://example.invalid/fixture-export-${query.offset}.xlsx',
      );
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
}
