import 'institution_directory_item.dart';

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
    this.pageSize = defaultPageSize,
  }) : assert(page >= 0),
       assert(allowedPageSizes.contains(pageSize)),
       statuses = Set.unmodifiable(statuses),
       states = Set.unmodifiable(states),
       cities = Set.unmodifiable(cities),
       districts = Set.unmodifiable(districts),
       typeIds = Set.unmodifiable(typeIds);

  static const defaultPageSize = 10;
  static const allowedPageSizes = <int>[10, 50, 100, 500];

  final String search;
  final Set<InstitutionStatus> statuses;
  final String? planId;
  final Set<String> states;
  final Set<String> cities;
  final Set<String> districts;
  final Set<String> typeIds;
  final int page;
  final int pageSize;

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
        other.pageSize == pageSize;
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
  );
}

bool _setsEqual<T>(Set<T> first, Set<T> second) {
  return first.length == second.length && first.containsAll(second);
}
