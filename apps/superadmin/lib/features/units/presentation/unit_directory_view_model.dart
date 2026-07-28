import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/unit_directory.dart';

enum UnitDirectoryLoadState { initial, loading, success, empty, noResults, failure, unauthorized }

final class UnitDirectoryViewModel extends ChangeNotifier {
  UnitDirectoryViewModel(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 300),
  });

  final UnitDirectoryRepository _repository;
  final Duration searchDebounce;
  UnitDirectoryQuery _query = UnitDirectoryQuery();
  UnitDirectoryPage _page = const UnitDirectoryPage(items: [], totalCount: 0, page: 0);
  UnitDirectoryFilterOptions _filterOptions = const UnitDirectoryFilterOptions();
  UnitDirectoryLoadState _state = UnitDirectoryLoadState.initial;
  Timer? _searchTimer;
  int _requestVersion = 0;

  UnitDirectoryQuery get query => _query;
  UnitDirectoryPage get page => _page;
  UnitDirectoryFilterOptions get filterOptions => _filterOptions;
  UnitDirectoryLoadState get state => _state;
  bool get isLoading => _state == UnitDirectoryLoadState.loading;

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);
  Future<void> clearFilters() => _replace(UnitDirectoryQuery());

  void setSearch(String value) {
    _query = _copy(search: value);
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    notifyListeners();
  }

  Future<void> setInstitutions(Set<String> value) => _replace(_copy(institutionIds: value));
  Future<void> setTypes(Set<String> value) => _replace(_copy(typeIds: value));
  Future<void> setStatuses(Set<UnitStatus> value) => _replace(_copy(statuses: value));
  Future<void> setPlans(Set<String> value) => _replace(_copy(planIds: value));
  Future<void> setStates(Set<String> value) =>
      _replace(_copy(states: value, cities: const {}, districts: const {}));
  Future<void> setCities(Set<String> value) => _replace(_copy(cities: value, districts: const {}));
  Future<void> setDistricts(Set<String> value) => _replace(_copy(districts: value));
  Future<void> goToPage(int value) => value < 0 ? Future.value() : _replace(_copy(page: value));

  UnitDirectoryQuery _copy({
    String? search,
    Set<String>? institutionIds,
    Set<String>? typeIds,
    Set<UnitStatus>? statuses,
    Set<String>? planIds,
    Set<String>? states,
    Set<String>? cities,
    Set<String>? districts,
    int page = 0,
  }) {
    return UnitDirectoryQuery(
      search: search ?? _query.search,
      institutionIds: institutionIds ?? _query.institutionIds,
      typeIds: typeIds ?? _query.typeIds,
      statuses: statuses ?? _query.statuses,
      planIds: planIds ?? _query.planIds,
      states: states ?? _query.states,
      cities: cities ?? _query.cities,
      districts: districts ?? _query.districts,
      page: page,
    );
  }

  Future<void> _replace(UnitDirectoryQuery value) {
    _searchTimer?.cancel();
    _query = value;
    return _load(value);
  }

  Future<void> _load(UnitDirectoryQuery value) async {
    final version = ++_requestVersion;
    _state = UnitDirectoryLoadState.loading;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.fetchPage(value),
        _repository.fetchFilterOptions(states: value.states, cities: value.cities),
      ]);
      if (version != _requestVersion) return;
      _page = results[0] as UnitDirectoryPage;
      _filterOptions = results[1] as UnitDirectoryFilterOptions;
      _state = _page.items.isNotEmpty
          ? UnitDirectoryLoadState.success
          : value.hasActiveFilters
          ? UnitDirectoryLoadState.noResults
          : UnitDirectoryLoadState.empty;
    } on UnitDirectoryUnauthorizedException {
      if (version == _requestVersion) {
        _state = UnitDirectoryLoadState.unauthorized;
      }
    } on Exception {
      if (version == _requestVersion) {
        _state = UnitDirectoryLoadState.failure;
      }
    }
    if (version == _requestVersion) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
