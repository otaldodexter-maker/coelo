import 'package:flutter/foundation.dart';

import '../domain/access_profile.dart';

enum AccessProfileLoadState {
  initial,
  loading,
  success,
  empty,
  noResults,
  failure,
  unauthorized,
  conflict,
}

final class AccessProfileViewModel extends ChangeNotifier {
  AccessProfileViewModel(this._repository);

  final AccessProfileRepository _repository;

  AccessProfileQuery query = const AccessProfileQuery();
  AccessProfilePage page = const AccessProfilePage.empty();
  List<PrincipalCapability> capabilities = const [];
  AccessProfileLoadState state = AccessProfileLoadState.initial;
  String? errorMessage;
  int _requestGeneration = 0;
  int _searchGeneration = 0;
  bool _disposed = false;

  bool get isDemo => _repository.isDemo;

  List<PrincipalCapability> get visibleCapabilities {
    final normalizedSearch = query.search.trim().toLowerCase();
    if (normalizedSearch.isEmpty) return capabilities;
    return capabilities
        .where(
          (item) =>
              item.name.toLowerCase().contains(normalizedSearch) ||
              item.code.toLowerCase().contains(normalizedSearch) ||
              item.description.toLowerCase().contains(normalizedSearch),
        )
        .toList(growable: false);
  }

  Future<void> load() async {
    final requestGeneration = ++_requestGeneration;
    state = AccessProfileLoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      if (query.domain == AccessProfileDomain.principal) {
        final loadedCapabilities = await _repository.fetchPrincipalCapabilities();
        if (!_isCurrent(requestGeneration)) return;
        capabilities = loadedCapabilities;
        state = capabilities.isEmpty
            ? AccessProfileLoadState.empty
            : AccessProfileLoadState.success;
      } else {
        final loadedPage = await _repository.fetchProfiles(query);
        if (!_isCurrent(requestGeneration)) return;
        page = loadedPage;
        state = page.items.isNotEmpty
            ? AccessProfileLoadState.success
            : query.hasFilters
            ? AccessProfileLoadState.noResults
            : AccessProfileLoadState.empty;
      }
    } on AccessProfileUnauthorizedException catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      errorMessage = error.message;
      state = AccessProfileLoadState.unauthorized;
    } on AccessProfileConflictException catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      errorMessage = error.message;
      state = AccessProfileLoadState.conflict;
    } on AccessProfileException catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      errorMessage = error.message;
      state = AccessProfileLoadState.failure;
    } on Object {
      if (!_isCurrent(requestGeneration)) return;
      errorMessage = 'Tente novamente em instantes.';
      state = AccessProfileLoadState.failure;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setDomain(AccessProfileDomain value) async {
    query = query.copyWith(domain: value, clearStatuses: true, clearScopes: true, resetPage: true);
    await load();
  }

  Future<void> setSearch(String value) async {
    query = query.copyWith(search: value, resetPage: true);
    if (query.domain == AccessProfileDomain.principal) {
      state = visibleCapabilities.isEmpty
          ? AccessProfileLoadState.noResults
          : AccessProfileLoadState.success;
      if (!_disposed) notifyListeners();
      return;
    }
    final searchGeneration = ++_searchGeneration;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_disposed || searchGeneration != _searchGeneration) return;
    await load();
  }

  Future<void> setStatuses(Set<AccessProfileStatus> values) async {
    query = query.copyWith(statuses: values, resetPage: true);
    await load();
  }

  Future<void> setScopes(Set<AccessProfileScope> values) async {
    query = query.copyWith(scopes: values, resetPage: true);
    await load();
  }

  Future<void> setLayout(AccessProfileLayout value) async {
    final pageSize = value == AccessProfileLayout.cards ? 11 : 8;
    query = query.copyWith(layout: value, pageSize: pageSize, resetPage: true);
    await load();
  }

  Future<void> goToPage(int value) async {
    query = query.copyWith(page: value);
    await load();
  }

  Future<void> setPageSize(int value) async {
    query = query.copyWith(pageSize: value, resetPage: true);
    await load();
  }

  Future<void> clearFilters() async {
    query = AccessProfileQuery(
      domain: query.domain,
      layout: query.layout,
      pageSize: query.pageSize,
    );
    await load();
  }

  bool _isCurrent(int requestGeneration) => !_disposed && requestGeneration == _requestGeneration;

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    _searchGeneration++;
    super.dispose();
  }
}
