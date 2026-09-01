import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/child_safety.dart';
import '../domain/child_safety_contract.dart';

final class ChildSafetyController extends ChangeNotifier {
  ChildSafetyController(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 300),
  });

  final ChildSafetyRepository _repository;
  final Duration searchDebounce;
  ChildSafetyDirectoryQuery _query = ChildSafetyDirectoryQuery();
  List<ChildSafetyRecord> _records = const [];
  ChildSafetySegmentCounts _segmentCounts = const ChildSafetySegmentCounts();
  ChildSafetyLoadState _state = ChildSafetyLoadState.loading;
  int _totalCount = 0;
  bool _canCreate = false;
  bool _saving = false;
  String? _errorMessage;
  Timer? _searchTimer;
  int _requestVersion = 0;
  int _dataVersion = 0;
  bool _disposed = false;
  final Map<int, String?> _pageCursors = {0: null};

  ChildSafetyLoadState get state => _state;
  List<ChildSafetyRecord> get records => List.unmodifiable(_records);
  int get totalCount => _totalCount;
  ChildSafetyDirectoryQuery get query => _query;
  bool get canCreate => _canCreate;
  String? get errorMessage => _errorMessage;
  ChildSafetySegmentCounts get segmentCounts => _segmentCounts;
  int get currentPage => _query.pageIndex;
  int get pageSize => _query.pageSize;
  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / _query.pageSize).ceil();
  bool get isSaving => _saving;
  int get dataVersion => _dataVersion;

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);

  void setSearch(String value) {
    _searchTimer?.cancel();
    _resetCursors();
    _query = _replaceQuery(search: value);
    _notify();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
  }

  Future<void> setInstitutions(Set<String> value) =>
      _replaceAndLoad(_replaceQuery(institutionIds: value));
  Future<void> setUnits(Set<String> value) => _replaceAndLoad(_replaceQuery(unitIds: value));
  Future<void> setStatusSegment(ChildSafetyDirectorySegment value) =>
      _replaceAndLoad(_replaceQuery(segment: value));

  Future<void> setView(ChildSafetyDirectoryView value) {
    final size = value == ChildSafetyDirectoryView.cards ? 11 : 8;
    return _replaceAndLoad(_replaceQuery(view: value, pageSize: size));
  }

  Future<void> goToPage(int zeroBased) {
    if (zeroBased < 0 || zeroBased >= totalPages) return Future.value();
    final cursor = _pageCursors[zeroBased];
    if (zeroBased != 0 && cursor == null) return Future.value();
    return _replaceAndLoad(_replaceQuery(cursor: cursor, pageIndex: zeroBased, keepCursor: true));
  }

  Future<void> setPageSize(int value) {
    final allowed = _query.view == ChildSafetyDirectoryView.cards
        ? ChildSafetyDirectoryQuery.cardPageSizes
        : ChildSafetyDirectoryQuery.tablePageSizes;
    if (!allowed.contains(value)) return Future.value();
    return _replaceAndLoad(_replaceQuery(pageSize: value));
  }

  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) {
    final normalized = query.trim();
    if (normalized.length < 2 || limit < 1 || limit > 50) return Future.value(const []);
    return _repository.searchChildren(normalized, limit: limit);
  }

  Future<ChildSafetyRecord?> fetchChild(String id) => _repository.fetchChild(id);
  Future<bool> saveAuthorization(SavePickupAuthorizationCommand command) =>
      _runCommand(() => _repository.saveAuthorization(command));
  Future<bool> transitionAuthorization(TransitionPickupAuthorizationCommand command) =>
      _runCommand(() => _repository.transitionAuthorization(command));
  Future<bool> suspendAuthorization(SuspendPickupAuthorizationCommand command) =>
      _runCommand(() => _repository.suspendAuthorization(command));
  Future<bool> requestExport(ChildSafetyExportCommand command) =>
      _runCommand(() => _repository.requestExport(command), refresh: false);

  ChildSafetyDirectoryQuery _replaceQuery({
    String? search,
    Set<String>? institutionIds,
    Set<String>? unitIds,
    ChildSafetyDirectorySegment? segment,
    ChildSafetyDirectoryView? view,
    String? cursor,
    int? pageIndex,
    int? pageSize,
    bool keepCursor = false,
  }) => ChildSafetyDirectoryQuery(
    search: search ?? _query.search,
    institutionIds: institutionIds ?? _query.institutionIds,
    unitIds: unitIds ?? _query.unitIds,
    segment: segment ?? _query.segment,
    view: view ?? _query.view,
    cursor: keepCursor ? cursor : null,
    pageIndex: keepCursor ? pageIndex ?? _query.pageIndex : 0,
    pageSize: pageSize ?? _query.pageSize,
  );

  Future<void> _replaceAndLoad(ChildSafetyDirectoryQuery query) {
    _searchTimer?.cancel();
    if (query.pageIndex == 0) {
      _resetCursors();
    }
    _query = query;
    return _load(query);
  }

  Future<void> _load(ChildSafetyDirectoryQuery query) async {
    final version = ++_requestVersion;
    _state = ChildSafetyLoadState.loading;
    _errorMessage = null;
    _notify();
    try {
      final page = await _repository.fetchDirectory(query);
      if (version != _requestVersion) return;
      _records = List.unmodifiable(page.records);
      _totalCount = page.totalCount;
      _segmentCounts = page.segmentCounts;
      _canCreate = page.canCreate;
      if (page.nextCursor != null) _pageCursors[query.pageIndex + 1] = page.nextCursor;
      if (page.previousCursor != null && query.pageIndex > 0) {
        _pageCursors[query.pageIndex - 1] = page.previousCursor;
      }
      _state = ChildSafetyLoadState.ready;
      _dataVersion++;
    } on ChildSafetyUnauthorizedException {
      if (version == _requestVersion) _failClosed(ChildSafetyLoadState.unauthorized);
    } on Exception {
      if (version == _requestVersion) {
        _failClosed(ChildSafetyLoadState.error);
        _errorMessage = 'Não foi possível carregar a segurança da criança.';
      }
    }
    if (version == _requestVersion) _notify();
  }

  void _failClosed(ChildSafetyLoadState state) {
    _records = const [];
    _totalCount = 0;
    _segmentCounts = const ChildSafetySegmentCounts();
    _canCreate = false;
    _state = state;
  }

  Future<bool> _runCommand(Future<void> Function() command, {bool refresh = true}) async {
    if (_saving || _disposed) return false;
    _saving = true;
    _errorMessage = null;
    _notify();
    try {
      await command();
      if (_disposed) return false;
      if (refresh) await _load(_query);
      return !_disposed && _state == ChildSafetyLoadState.ready;
    } on ChildSafetyUnauthorizedException {
      _failClosed(ChildSafetyLoadState.unauthorized);
      return false;
    } on ChildSafetyValidationException {
      _errorMessage = 'Revise os dados da autorização.';
      return false;
    } on ChildSafetyConflictException {
      _errorMessage = 'A autorização mudou. Recarregue e tente novamente.';
      return false;
    } on Exception {
      _errorMessage = 'Não foi possível concluir a ação.';
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  void _resetCursors() {
    _pageCursors
      ..clear()
      ..[0] = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _searchTimer?.cancel();
    super.dispose();
  }
}
