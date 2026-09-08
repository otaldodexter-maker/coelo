import 'package:coelo_domain/locations.dart';
import 'package:flutter/foundation.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_selection_source.dart';

/// Drives a consumer's choice of location for one owner scope.
///
/// It holds options and the current choice, never authority: the server
/// re-authorizes every read, and saving the choice belongs to the consumer's
/// own write. A stored catalogued choice is re-resolved on load, because the
/// location may have been renamed or deactivated since it was picked.
final class LocationSelectionController extends ChangeNotifier {
  LocationSelectionController({
    LocationSelectionSource source = const UnavailableLocationSelectionSource(),
    required LocationScope scope,
    bool sessionAvailable = false,
    int contextRevision = 0,
    LocationSelection? initial,
  }) : _source = source,
       _scope = scope,
       _sessionAvailable = sessionAvailable,
       _contextRevision = contextRevision,
       _selection = initial;

  LocationSelectionSource _source;
  LocationScope _scope;
  bool _sessionAvailable;
  int _contextRevision;
  LocationSelection? _selection;
  List<LocationReferenceSnapshot> _options = const [];
  String _search = '';
  bool _truncated = false;
  bool _selectionStale = false;
  int _epoch = 0;
  bool _disposed = false;
  LocationReadState _state = LocationReadState.unavailable;

  LocationReadState get state => _state;
  List<LocationReferenceSnapshot> get options => _options;
  bool get truncated => _truncated;
  String get search => _search;
  LocationSelection? get selection => _selection;

  /// The stored catalogued choice is readable but no longer offerable.
  ///
  /// The consumer keeps showing it as a historical reference and must not
  /// silently drop the record's location because the catalog changed.
  bool get selectionStale => _selectionStale;

  Future<void> load({
    LocationSelectionSource? source,
    LocationScope? scope,
    bool? sessionAvailable,
    int? contextRevision,
  }) async {
    if (_disposed) return;
    final changed =
        source != null && !identical(source, _source) ||
        scope != null && !sameLocationScope(scope, _scope) ||
        sessionAvailable != null && sessionAvailable != _sessionAvailable ||
        contextRevision != null && contextRevision != _contextRevision;
    _source = source ?? _source;
    _sessionAvailable = sessionAvailable ?? _sessionAvailable;
    _contextRevision = contextRevision ?? _contextRevision;
    if (scope != null && !sameLocationScope(scope, _scope)) {
      // Another owner means another catalog: a choice made in the previous one
      // is not valid here and is dropped rather than carried over.
      _scope = scope;
      _selection = null;
      _selectionStale = false;
    }
    if (changed) _search = '';

    final epoch = ++_epoch;
    final source0 = _source;
    final scope0 = _scope;
    final stored = _selection;
    _options = const [];
    _truncated = false;
    _state = _sessionAvailable && validLocationScope(scope0)
        ? LocationReadState.loading
        : LocationReadState.denied;
    notifyListeners();
    if (!_current(epoch) || _state != LocationReadState.loading) return;

    try {
      final result = await source0.fetchOptions(
        LocationSelectionRequest(scope: scope0, search: _search.isEmpty ? null : _search),
      );
      if (!_current(epoch)) return;
      _options = result.options;
      _truncated = result.truncated;
      _state = result.options.isNotEmpty
          ? LocationReadState.ready
          : _search.isEmpty
          ? LocationReadState.empty
          : LocationReadState.noResults;
    } on LocationCatalogAccessDeniedException {
      if (!_current(epoch)) return;
      _state = LocationReadState.denied;
    } on Object {
      if (!_current(epoch)) return;
      _state = LocationReadState.unavailable;
    }
    if (!_current(epoch)) return;

    if (stored is CataloguedLocationSelection && _state != LocationReadState.denied) {
      await _resolveStored(epoch, source0, scope0, stored);
      if (!_current(epoch)) return;
    }
    notifyListeners();
  }

  Future<void> _resolveStored(
    int epoch,
    LocationSelectionSource source,
    LocationScope scope,
    CataloguedLocationSelection stored,
  ) async {
    try {
      final resolved = await source.resolveSnapshot(id: stored.snapshot.id, scope: scope);
      if (!_current(epoch)) return;
      _selection = LocationSelection.catalogued(resolved.snapshot);
      _selectionStale = resolved.resolution == LocationSnapshotResolution.notSelectable;
    } on Object {
      if (!_current(epoch)) return;
      // The stored reference is kept as it was: failing to re-read is not
      // evidence that the record's location is wrong.
      _selectionStale = true;
    }
  }

  Future<void> setSearch(String value) {
    if (_disposed) return Future.value();
    final trimmed = value.replaceAll(RegExp(r'^ +| +$'), '');
    if (trimmed == _search) return Future.value();
    _search = trimmed;
    return _reload();
  }

  Future<void> retry() {
    if (_disposed) return Future.value();
    return _reload();
  }

  Future<void> _reload() async {
    final epoch = ++_epoch;
    final source = _source;
    final scope = _scope;
    _options = const [];
    _truncated = false;
    _state = _sessionAvailable && validLocationScope(scope)
        ? LocationReadState.loading
        : LocationReadState.denied;
    notifyListeners();
    if (!_current(epoch) || _state != LocationReadState.loading) return;
    try {
      final result = await source.fetchOptions(
        LocationSelectionRequest(scope: scope, search: _search.isEmpty ? null : _search),
      );
      if (!_current(epoch)) return;
      _options = result.options;
      _truncated = result.truncated;
      _state = result.options.isNotEmpty
          ? LocationReadState.ready
          : _search.isEmpty
          ? LocationReadState.empty
          : LocationReadState.noResults;
    } on LocationCatalogAccessDeniedException {
      if (!_current(epoch)) return;
      _state = LocationReadState.denied;
    } on Object {
      if (!_current(epoch)) return;
      _state = LocationReadState.unavailable;
    }
    if (_current(epoch)) notifyListeners();
  }

  void selectCatalogued(LocationReferenceSnapshot snapshot) {
    if (_disposed || !_options.any((option) => option.id == snapshot.id)) return;
    _selection = LocationSelection.catalogued(snapshot);
    _selectionStale = false;
    notifyListeners();
  }

  /// A one-off stays text; it never receives a fabricated catalog id.
  void setOneOff(String text) {
    if (_disposed) return;
    final trimmed = text.replaceAll(RegExp(r'^ +| +$'), '');
    _selection = trimmed.isEmpty ? null : LocationSelection.oneOff(trimmed);
    _selectionStale = false;
    notifyListeners();
  }

  void clear() {
    if (_disposed) return;
    _selection = null;
    _selectionStale = false;
    notifyListeners();
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _options = const [];
    super.dispose();
  }
}
