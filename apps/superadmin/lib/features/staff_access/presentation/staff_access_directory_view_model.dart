import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/staff_access.dart';

enum StaffAccessLoadState { initial, loading, success, empty, noResults, failure, unauthorized }

final class StaffAccessDirectoryViewModel extends ChangeNotifier {
  StaffAccessDirectoryViewModel(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 300),
    int initialPageSize = 11,
  }) : _query = StaffAccessQuery(pageSize: initialPageSize);

  final StaffAccessRepository _repository;
  final Duration searchDebounce;
  StaffAccessQuery _query;
  StaffAccessPage _page = const StaffAccessPage(items: [], totalCount: 0, page: 0);
  StaffAccessLoadState _state = StaffAccessLoadState.initial;
  Timer? _searchTimer;
  int _requestVersion = 0;

  StaffAccessQuery get query => _query;
  StaffAccessPage get page => _page;
  StaffAccessFilterOptions get filterOptions => _page.filterOptions;
  StaffAccessLoadState get state => _state;
  bool get isLoading => _state == StaffAccessLoadState.loading;

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);
  Future<void> clearFilters() => _replace(StaffAccessQuery(pageSize: _query.pageSize));

  void setSearch(String value) {
    _query = _query.copyWith(search: value, page: 0);
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    notifyListeners();
  }

  Future<void> setInstitution(String? value) =>
      _replace(_query.copyWith(institutionId: () => value, unitId: () => null, page: 0));
  Future<void> setUnit(String? value) => _replace(_query.copyWith(unitId: () => value, page: 0));
  Future<void> setStates(Set<StaffAccessState> value) =>
      _replace(_query.copyWith(states: value, page: 0));
  Future<void> setSources(Set<StaffAccessSource> value) =>
      _replace(_query.copyWith(sources: value, page: 0));
  Future<void> goToPage(int value) =>
      value < 0 ? Future.value() : _replace(_query.copyWith(page: value));
  Future<void> setPageSize(int value) => _replace(_query.copyWith(pageSize: value, page: 0));

  Future<void> _replace(StaffAccessQuery value) {
    _searchTimer?.cancel();
    _query = value;
    return _load(value);
  }

  Future<void> _load(StaffAccessQuery value) async {
    final version = ++_requestVersion;
    _state = StaffAccessLoadState.loading;
    notifyListeners();
    try {
      final result = await _repository.fetchPage(value);
      if (version != _requestVersion) return;
      _page = result;
      _state = result.items.isNotEmpty
          ? StaffAccessLoadState.success
          : value.hasActiveFilters
          ? StaffAccessLoadState.noResults
          : StaffAccessLoadState.empty;
    } on StaffAccessUnauthorizedException {
      if (version == _requestVersion) _state = StaffAccessLoadState.unauthorized;
    } on Object {
      if (version == _requestVersion) _state = StaffAccessLoadState.failure;
    }
    if (version == _requestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _requestVersion++;
    _searchTimer?.cancel();
    super.dispose();
  }
}

final class StaffLeaveDirectoryViewModel extends ChangeNotifier {
  StaffLeaveDirectoryViewModel(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 300),
    int initialPageSize = 11,
  }) : _query = StaffLeaveQuery(pageSize: initialPageSize);

  final StaffAccessRepository _repository;
  final Duration searchDebounce;
  StaffLeaveQuery _query;
  StaffLeavePage _page = const StaffLeavePage(items: [], totalCount: 0, page: 0);
  StaffAccessFilterOptions _filterOptions = const StaffAccessFilterOptions();
  StaffAccessLoadState _state = StaffAccessLoadState.initial;
  Timer? _searchTimer;
  int _requestVersion = 0;

  StaffLeaveQuery get query => _query;
  StaffLeavePage get page => _page;
  StaffAccessFilterOptions get filterOptions => _filterOptions;
  StaffAccessLoadState get state => _state;
  bool get isLoading => _state == StaffAccessLoadState.loading;

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);
  Future<void> clearFilters() => _replace(StaffLeaveQuery(pageSize: _query.pageSize));

  void setSearch(String value) {
    _query = _query.copyWith(search: value, page: 0);
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    notifyListeners();
  }

  Future<void> setInstitution(String? value) =>
      _replace(_query.copyWith(institutionId: () => value, unitId: () => null, page: 0));
  Future<void> setUnit(String? value) => _replace(_query.copyWith(unitId: () => value, page: 0));
  Future<void> setPeriod(StaffLeavePeriod? value) =>
      _replace(_query.copyWith(period: () => value, page: 0));
  Future<void> goToPage(int value) =>
      value < 0 ? Future.value() : _replace(_query.copyWith(page: value));
  Future<void> setPageSize(int value) => _replace(_query.copyWith(pageSize: value, page: 0));

  Future<void> _replace(StaffLeaveQuery value) {
    _searchTimer?.cancel();
    _query = value;
    return _load(value);
  }

  Future<void> _load(StaffLeaveQuery value) async {
    final version = ++_requestVersion;
    _state = StaffAccessLoadState.loading;
    notifyListeners();
    try {
      // As opções de filtro (instituições/unidades sob a hierarquia) vêm do
      // diretório de vínculos, que as projeta uma vez.
      final results = await Future.wait<Object>([
        _repository.fetchLeaves(value),
        _repository.fetchPage(const StaffAccessQuery(pageSize: 1)),
      ]);
      if (version != _requestVersion) return;
      _page = results[0] as StaffLeavePage;
      _filterOptions = (results[1] as StaffAccessPage).filterOptions;
      _state = _page.items.isNotEmpty
          ? StaffAccessLoadState.success
          : value.hasActiveFilters
          ? StaffAccessLoadState.noResults
          : StaffAccessLoadState.empty;
    } on StaffAccessUnauthorizedException {
      if (version == _requestVersion) _state = StaffAccessLoadState.unauthorized;
    } on Object {
      if (version == _requestVersion) _state = StaffAccessLoadState.failure;
    }
    if (version == _requestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _requestVersion++;
    _searchTimer?.cancel();
    super.dispose();
  }
}
