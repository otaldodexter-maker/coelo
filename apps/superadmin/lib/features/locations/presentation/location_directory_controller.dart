import 'dart:math' as math;
import 'package:coelo_domain/locations.dart';
import 'package:flutter/foundation.dart';
import '../domain/location_catalog_reader.dart';

final class LocationDirectoryController extends ChangeNotifier {
  LocationDirectoryController({
    LocationCatalogReader reader = const UnavailableLocationCatalogReader(),
    required LocationScope scope,
    bool sessionAvailable = false,
    int contextRevision = 0,
  }) : _reader = reader,
       _scope = scope,
       _sessionAvailable = sessionAvailable,
       _contextRevision = contextRevision;
  LocationCatalogReader _reader;
  LocationScope _scope;
  bool _sessionAvailable;
  int _contextRevision;
  int _epoch = 0;
  bool _disposed = false;
  String _search = '';
  int _page = 0;
  int _pageSize = 11;
  LocationReadState _state = LocationReadState.unavailable;
  LocationDirectoryResult? _data;
  LocationReadState get state => _state;
  LocationDirectoryResult? get data => _data;

  /// Snapshot used by rendered callbacks, including when a reader reuses objects.
  int get readGeneration => _epoch;
  int get page => _page;
  int get pageSize => _pageSize;
  String get search => _search;
  int get totalPages =>
      math.max(1, math.min(((_data?.totalCount ?? 0) / _pageSize).ceil(), 10000 ~/ _pageSize + 1));
  bool get windowLimited => ((_data?.totalCount ?? 0) / _pageSize).ceil() > 10000 ~/ _pageSize + 1;

  Future<void> load({
    LocationCatalogReader? reader,
    LocationScope? scope,
    bool? sessionAvailable,
    int? contextRevision,
  }) async {
    if (_disposed) return;
    final changed =
        reader != null && !identical(reader, _reader) ||
        scope != null && !sameLocationScope(scope, _scope) ||
        sessionAvailable != null && sessionAvailable != _sessionAvailable ||
        contextRevision != null && contextRevision != _contextRevision;
    _reader = reader ?? _reader;
    _scope = scope ?? _scope;
    _sessionAvailable = sessionAvailable ?? _sessionAvailable;
    _contextRevision = contextRevision ?? _contextRevision;
    if (changed) {
      _page = 0;
      _search = '';
    }
    final epoch = ++_epoch;
    final currentReader = _reader;
    var request = LocationDirectoryRequest(
      scope: _scope,
      search: _search.isEmpty ? null : _search,
      limit: _pageSize,
      offset: _page * _pageSize,
    );
    _data = null;
    _state = !_sessionAvailable || !validLocationScope(request.scope)
        ? LocationReadState.denied
        : _search.runes.length > 120
        ? LocationReadState.unavailable
        : LocationReadState.loading;
    notifyListeners();
    if (!_current(epoch) || _state != LocationReadState.loading) return;
    try {
      var result = await currentReader.fetchDirectory(request);
      if (!_current(epoch)) return;
      if (request.offset > 0 && request.offset >= result.totalCount && result.totalCount >= 0) {
        _page = 0;
        request = LocationDirectoryRequest(
          scope: request.scope,
          search: request.search,
          limit: request.limit,
        );
        // One recovery only. Concurrent deletions cannot create an unbounded loop.
        result = await currentReader.fetchDirectory(request);
      }
      if (!_current(epoch)) return;
      if (result.totalCount < result.items.length ||
          result.items.length > request.limit ||
          result.items.map((item) => item.id).toSet().length != result.items.length ||
          result.items.any(
            (item) => !validLocationId(item.id) || !sameLocationScope(item.scope, request.scope),
          )) {
        throw const FormatException('Invalid location page');
      }
      _data = result;
      _state = result.items.isNotEmpty
          ? LocationReadState.ready
          : request.search == null
          ? LocationReadState.empty
          : LocationReadState.noResults;
    } on LocationCatalogAccessDeniedException {
      if (!_current(epoch)) return;
      _state = LocationReadState.denied;
    } catch (_) {
      if (!_current(epoch)) return;
      _state = LocationReadState.unavailable;
    }
    if (_current(epoch)) notifyListeners();
  }

  Future<void> setSearch(String value) {
    if (_disposed) return Future.value();
    _search = value.replaceAll(RegExp(r'^ +| +$'), '');
    _page = 0;
    return load();
  }

  Future<void> goToPage(int value) {
    if (_disposed || value < 0 || value >= totalPages || value == _page) return Future.value();
    _page = value;
    return load();
  }

  Future<void> setPageSize(int value) {
    if (_disposed || !const [8, 11, 20, 50, 100].contains(value) || value == _pageSize) {
      return Future.value();
    }
    _pageSize = value;
    _page = 0;
    return load();
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;
  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _data = null;
    super.dispose();
  }
}
