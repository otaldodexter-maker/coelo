import 'institution_directory_item.dart';

enum InstitutionDirectorySortColumn {
  publicName('public_name'),
  typeName('type_name'),
  unitsCount('units_count'),
  groupsCount('groups_count'),
  planName('plan_name'),
  status('status'),
  contactEmail('contact_email'),
  contactPhone('contact_phone'),
  contactMobilePhone('contact_mobile_phone'),
  primaryDomain('primary_domain'),
  street('street'),
  postalCode('postal_code'),
  addressNumber('number'),
  complement('complement'),
  district('district'),
  city('city'),
  state('state');

  const InstitutionDirectorySortColumn(this.databaseColumn);

  final String databaseColumn;
}

final class InstitutionDirectoryQuery {
  InstitutionDirectoryQuery({
    this.search = '',
    Set<InstitutionStatus> statuses = const {},
    this.planId,
    Set<String> states = const {},
    Set<String> cities = const {},
    Set<String> districts = const {},
    Set<String> typeIds = const {},
    this.page = 0,
    this.pageSize = 11,
    this.sortColumn = InstitutionDirectorySortColumn.publicName,
    this.sortAscending = true,
  }) : assert(page >= 0),
       assert(pageSize > 0),
       statuses = Set.unmodifiable(statuses),
       states = Set.unmodifiable(states),
       cities = Set.unmodifiable(cities),
       districts = Set.unmodifiable(districts),
       typeIds = Set.unmodifiable(typeIds);

  final String search;
  final Set<InstitutionStatus> statuses;
  final String? planId;
  final Set<String> states;
  final Set<String> cities;
  final Set<String> districts;
  final Set<String> typeIds;
  final int page;
  final int pageSize;
  final InstitutionDirectorySortColumn sortColumn;
  final bool sortAscending;

  int get offset => page * pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      planId != null ||
      states.isNotEmpty ||
      cities.isNotEmpty ||
      districts.isNotEmpty ||
      typeIds.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is InstitutionDirectoryQuery &&
        other.search == search &&
        _setsEqual(other.statuses, statuses) &&
        other.planId == planId &&
        _setsEqual(other.states, states) &&
        _setsEqual(other.cities, cities) &&
        _setsEqual(other.districts, districts) &&
        _setsEqual(other.typeIds, typeIds) &&
        other.page == page &&
        other.pageSize == pageSize &&
        other.sortColumn == sortColumn &&
        other.sortAscending == sortAscending;
  }

  @override
  int get hashCode => Object.hash(
    search,
    Object.hashAllUnordered(statuses),
    planId,
    Object.hashAllUnordered(states),
    Object.hashAllUnordered(cities),
    Object.hashAllUnordered(districts),
    Object.hashAllUnordered(typeIds),
    page,
    pageSize,
    sortColumn,
    sortAscending,
  );
}

bool _setsEqual<T>(Set<T> first, Set<T> second) {
  return first.length == second.length && first.containsAll(second);
}
