import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/institution_directory_item.dart';
import '../../domain/institution_directory_page.dart';
import '../../domain/institution_directory_query.dart';
import '../../domain/institution_directory_repository.dart';

enum InstitutionDirectoryLoadState {
  initial,
  loading,
  success,
  empty,
  noResults,
  failure,
  unauthorized,
}

final class InstitutionDirectoryViewModel extends ChangeNotifier {
  InstitutionDirectoryViewModel({
    required InstitutionDirectoryRepository repository,
    this.searchDebounce = const Duration(milliseconds: 300),
  }) : _repository = repository;

  static const genericErrorMessage = 'Não foi possível carregar as instituições. Tente novamente.';
  static const unauthorizedMessage = 'Você não tem permissão para ver as instituições.';

  final InstitutionDirectoryRepository _repository;
  final Duration searchDebounce;

  InstitutionDirectoryQuery _query = InstitutionDirectoryQuery();
  InstitutionDirectoryPage _page = const InstitutionDirectoryPage(
    items: [],
    totalCount: 0,
    page: 0,
  );
  InstitutionDirectoryFilterOptions _filterOptions = InstitutionDirectoryFilterOptions.empty;
  InstitutionDirectoryLoadState _state = InstitutionDirectoryLoadState.initial;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isDisposed = false;
  int _requestVersion = 0;
  Timer? _searchTimer;

  InstitutionDirectoryQuery get query => _query;
  InstitutionDirectoryPage get page => _page;
  InstitutionDirectoryFilterOptions get filterOptions => _filterOptions;
  InstitutionDirectoryLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> load() => _load(_query);

  Future<void> retry() => _load(_query);

  Future<void> clearFilters() => _replaceAndLoad(InstitutionDirectoryQuery());

  void setSearch(String value) {
    _query = _queryWith(search: value);
    _requestVersion += 1;
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    _notifyIfActive();
  }

  Future<void> setStatuses(Set<InstitutionStatus> values) {
    return _replaceAndLoad(_queryWith(statuses: values));
  }

  Future<void> setPlan(String? value) {
    return _replaceAndLoad(_queryWith(planId: value));
  }

  Future<void> setStates(Set<String> values) {
    return _replaceAndLoad(_queryWith(states: values, cities: const {}, districts: const {}));
  }

  Future<void> setCities(Set<String> values) {
    return _replaceAndLoad(_queryWith(cities: values, districts: const {}));
  }

  Future<void> setDistricts(Set<String> values) {
    return _replaceAndLoad(_queryWith(districts: values));
  }

  Future<void> setTypes(Set<String> values) {
    return _replaceAndLoad(_queryWith(typeIds: values));
  }

  Future<void> goToPage(int value) {
    if (value < 0) {
      return Future<void>.value();
    }
    return _replaceAndLoad(_queryWith(page: value));
  }

  InstitutionDirectoryQuery _queryWith({
    String? search,
    Set<InstitutionStatus>? statuses,
    Object? planId = _unchangedQueryValue,
    Set<String>? states,
    Set<String>? cities,
    Set<String>? districts,
    Set<String>? typeIds,
    int page = 0,
  }) {
    return InstitutionDirectoryQuery(
      search: search ?? _query.search,
      statuses: statuses ?? _query.statuses,
      planId: identical(planId, _unchangedQueryValue) ? _query.planId : planId as String?,
      states: states ?? _query.states,
      cities: cities ?? _query.cities,
      districts: districts ?? _query.districts,
      typeIds: typeIds ?? _query.typeIds,
      page: page,
    );
  }

  Future<void> _replaceAndLoad(InstitutionDirectoryQuery value) {
    _searchTimer?.cancel();
    _query = value;
    return _load(value);
  }

  Future<void> _load(InstitutionDirectoryQuery value) async {
    final requestVersion = ++_requestVersion;
    _isLoading = true;
    _errorMessage = null;
    _state = InstitutionDirectoryLoadState.loading;
    _notifyIfActive();

    try {
      final results = await Future.wait<Object>([
        _repository.fetchPage(value),
        _repository.fetchFilterOptions(states: value.states, cities: value.cities),
      ]);
      if (requestVersion != _requestVersion) {
        return;
      }

      _page = results[0] as InstitutionDirectoryPage;
      _filterOptions = results[1] as InstitutionDirectoryFilterOptions;
      if (_page.items.isNotEmpty) {
        _state = InstitutionDirectoryLoadState.success;
      } else if (value.hasActiveFilters) {
        _state = InstitutionDirectoryLoadState.noResults;
      } else {
        _state = InstitutionDirectoryLoadState.empty;
      }
    } on InstitutionDirectoryUnauthorizedException {
      if (requestVersion == _requestVersion) {
        _state = InstitutionDirectoryLoadState.unauthorized;
        _errorMessage = unauthorizedMessage;
      }
    } on Exception {
      if (requestVersion == _requestVersion) {
        _state = InstitutionDirectoryLoadState.failure;
        _errorMessage = genericErrorMessage;
      }
    } finally {
      if (requestVersion == _requestVersion) {
        _isLoading = false;
        _notifyIfActive();
      }
    }
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchTimer?.cancel();
    super.dispose();
  }
}

const _unchangedQueryValue = Object();
