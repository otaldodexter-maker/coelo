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

  InstitutionDirectoryQuery _query = const InstitutionDirectoryQuery();
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

  Future<void> clearFilters() => _replaceAndLoad(const InstitutionDirectoryQuery());

  void setSearch(String value) {
    _query = InstitutionDirectoryQuery(
      search: value,
      status: _query.status,
      planId: _query.planId,
      state: _query.state,
      city: _query.city,
      district: _query.district,
      typeId: _query.typeId,
    );
    _requestVersion += 1;
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    _notifyIfActive();
  }

  Future<void> setStatus(InstitutionStatus? value) {
    return _replaceAndLoad(
      InstitutionDirectoryQuery(
        search: _query.search,
        status: value,
        planId: _query.planId,
        state: _query.state,
        city: _query.city,
        district: _query.district,
        typeId: _query.typeId,
      ),
    );
  }

  Future<void> setPlan(String? value) {
    return _replaceAndLoad(
      InstitutionDirectoryQuery(
        search: _query.search,
        status: _query.status,
        planId: value,
        state: _query.state,
        city: _query.city,
        district: _query.district,
        typeId: _query.typeId,
      ),
    );
  }

  Future<void> setState(String? value) {
    return _replaceAndLoad(
      InstitutionDirectoryQuery(
        search: _query.search,
        status: _query.status,
        planId: _query.planId,
        state: value,
        city: null,
        district: null,
        typeId: _query.typeId,
      ),
    );
  }

  Future<void> setCity(String? value) {
    return _replaceAndLoad(
      InstitutionDirectoryQuery(
        search: _query.search,
        status: _query.status,
        planId: _query.planId,
        state: _query.state,
        city: value,
        district: null,
        typeId: _query.typeId,
      ),
    );
  }

  Future<void> setDistrict(String? value) {
    return _replaceAndLoad(
      InstitutionDirectoryQuery(
        search: _query.search,
        status: _query.status,
        planId: _query.planId,
        state: _query.state,
        city: _query.city,
        district: value,
        typeId: _query.typeId,
      ),
    );
  }

  Future<void> setType(String? value) {
    return _replaceAndLoad(
      InstitutionDirectoryQuery(
        search: _query.search,
        status: _query.status,
        planId: _query.planId,
        state: _query.state,
        city: _query.city,
        district: _query.district,
        typeId: value,
      ),
    );
  }

  Future<void> goToPage(int value) {
    if (value < 0) {
      return Future<void>.value();
    }
    return _replaceAndLoad(
      InstitutionDirectoryQuery(
        search: _query.search,
        status: _query.status,
        planId: _query.planId,
        state: _query.state,
        city: _query.city,
        district: _query.district,
        typeId: _query.typeId,
        page: value,
      ),
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
        _repository.fetchFilterOptions(state: value.state, city: value.city),
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
