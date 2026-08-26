import '../../institutions/data/fake_institution_directory_repository.dart';
import '../../institutions/domain/institution_record.dart';
import '../domain/unit_directory.dart';

final class FakeUnitDirectoryRepository implements UnitDirectoryRepository {
  const FakeUnitDirectoryRepository(this._institutions);

  final FakeInstitutionDirectoryRepository _institutions;

  @override
  List<UnitRecord> get records => List.unmodifiable([
    for (final institution in _institutions.records)
      for (var index = 0; index < institution.units.length; index++)
        UnitRecord(
          institution: institution,
          unit: _withPrototypeDefaults(institution, institution.units[index], index),
        ),
  ]);

  InstitutionUnit _withPrototypeDefaults(
    InstitutionRecord institution,
    InstitutionUnit unit,
    int index,
  ) {
    return unit.copyWith(
      slug: unit.slug.isEmpty ? unit.id : unit.slug,
      typeId: unit.typeId.isEmpty ? institution.typeId : unit.typeId,
      typeName: unit.typeName.isEmpty ? institution.typeName : unit.typeName,
      brandDisplayName: unit.brandDisplayName.isEmpty ? unit.name : unit.brandDisplayName,
      activitiesCount: unit.activitiesCount == 0
          ? (unit.groups.length / 3).ceil() + index
          : unit.activitiesCount,
    );
  }

  @override
  UnitRecord? findById(String id) {
    for (final record in records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  @override
  String createId(String institutionId, String slug) {
    final normalized = slug.trim().isEmpty ? 'nova' : slug.trim();
    final base = '$institutionId-unit-$normalized';
    var candidate = base;
    var suffix = 2;
    while (findById(candidate) != null) {
      candidate = '$base-${suffix++}';
    }
    return candidate;
  }

  @override
  Future<void> upsert(UnitRecord record) async {
    final parent = _institutions.findById(record.institutionId);
    if (parent == null) {
      throw ArgumentError.value(record.institutionId, 'institutionId', 'Institution not found.');
    }
    final existing = findById(record.id);
    if (existing != null && existing.institutionId != record.institutionId) {
      throw ArgumentError('Changing an existing unit institution is not supported.');
    }
    final duplicateSlug = records.any(
      (unit) =>
          unit.institutionId == record.institutionId &&
          unit.id != record.id &&
          unit.slug == record.slug,
    );
    if (duplicateSlug) {
      throw ArgumentError.value(record.slug, 'slug', 'Slug already exists in this institution.');
    }
    final units = [...parent.units];
    final index = units.indexWhere((unit) => unit.id == record.id);
    if (index == -1) {
      units.add(record.unit);
    } else {
      units[index] = record.unit;
    }
    await _institutions.upsert(parent.copyWith(units: List.unmodifiable(units)));
  }

  @override
  Future<UnitFormData> loadForm({String? unitId}) async {
    return UnitFormData(
      institutions: List.unmodifiable(_institutions.records),
      record: unitId == null ? null : findById(unitId),
    );
  }

  @override
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query) async {
    final search = query.search.trim().toLowerCase();
    final filtered =
        records.where((record) {
          return (search.isEmpty || record.name.toLowerCase().contains(search)) &&
              (query.institutionIds.isEmpty ||
                  query.institutionIds.contains(record.institutionId)) &&
              (query.typeIds.isEmpty || query.typeIds.contains(record.typeId)) &&
              (query.statuses.isEmpty || query.statuses.contains(record.status)) &&
              (query.planIds.isEmpty || query.planIds.contains(record.effectivePlan.id)) &&
              (query.states.isEmpty || query.states.contains(record.state)) &&
              (query.cities.isEmpty || query.cities.contains(record.city)) &&
              (query.districts.isEmpty || query.districts.contains(record.district));
        }).toList()..sort((first, second) {
          final comparison = _compareRecords(first, second, query.sortColumn);
          return query.sortAscending ? comparison : -comparison;
        });
    final start = query.offset.clamp(0, filtered.length);
    final end = (start + query.pageSize).clamp(start, filtered.length);
    return UnitDirectoryPage(
      items: filtered.sublist(start, end).map(UnitDirectoryItem.new).toList(growable: false),
      totalCount: filtered.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    final institutions = <String, String>{};
    final types = <String, String>{};
    final plans = <String, String>{};
    final stateOptions = <String, String>{};
    final cityOptions = <String, String>{};
    final districtOptions = <String, String>{};
    for (final record in records) {
      institutions[record.institutionId] = record.institutionName;
      if (record.typeId.isNotEmpty) {
        types[record.typeId] = record.typeName;
      }
      plans[record.effectivePlan.id] = record.effectivePlan.label;
      if (record.state.isNotEmpty) {
        stateOptions[record.state] = record.state;
      }
      if (states.contains(record.state) && record.city.isNotEmpty) {
        cityOptions[record.city] = record.city;
      }
      if (states.contains(record.state) &&
          cities.contains(record.city) &&
          record.district.isNotEmpty) {
        districtOptions[record.district] = record.district;
      }
    }
    List<UnitFilterOption> options(Map<String, String> source) =>
        source.entries.map((entry) => UnitFilterOption(entry.key, entry.value)).toList()
          ..sort((first, second) => first.label.compareTo(second.label));
    return UnitDirectoryFilterOptions(
      institutions: options(institutions),
      types: options(types),
      plans: options(plans),
      states: options(stateOptions),
      cities: options(cityOptions),
      districts: options(districtOptions),
    );
  }
}

int _compareRecords(UnitRecord first, UnitRecord second, UnitDirectorySortColumn column) {
  final comparison = switch (column) {
    UnitDirectorySortColumn.name => first.name.compareTo(second.name),
    UnitDirectorySortColumn.institutionName => first.institutionName.compareTo(
      second.institutionName,
    ),
    UnitDirectorySortColumn.institutionTypeName => first.institution.typeName.compareTo(
      second.institution.typeName,
    ),
    UnitDirectorySortColumn.typeName => first.typeName.compareTo(second.typeName),
    UnitDirectorySortColumn.groupsCount => first.groupsCount.compareTo(second.groupsCount),
    UnitDirectorySortColumn.activitiesCount => first.activitiesCount.compareTo(
      second.activitiesCount,
    ),
    UnitDirectorySortColumn.planName => first.effectivePlan.label.compareTo(
      second.effectivePlan.label,
    ),
    UnitDirectorySortColumn.status => first.status.label.compareTo(second.status.label),
    UnitDirectorySortColumn.contactEmail => first.contactEmail.compareTo(second.contactEmail),
    UnitDirectorySortColumn.contactPhone => first.contactPhone.compareTo(second.contactPhone),
    UnitDirectorySortColumn.contactMobilePhone => first.contactMobilePhone.compareTo(
      second.contactMobilePhone,
    ),
    UnitDirectorySortColumn.street => first.street.compareTo(second.street),
    UnitDirectorySortColumn.addressNumber => first.addressNumber.compareTo(second.addressNumber),
    UnitDirectorySortColumn.complement => first.complement.compareTo(second.complement),
    UnitDirectorySortColumn.district => first.district.compareTo(second.district),
    UnitDirectorySortColumn.postalCode => first.postalCode.compareTo(second.postalCode),
    UnitDirectorySortColumn.city => first.city.compareTo(second.city),
    UnitDirectorySortColumn.state => first.state.compareTo(second.state),
  };
  return comparison != 0 ? comparison : first.id.compareTo(second.id);
}
