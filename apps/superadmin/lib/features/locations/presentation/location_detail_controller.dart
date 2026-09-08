import 'package:coelo_domain/locations.dart';
import 'package:flutter/foundation.dart';
import '../domain/location_catalog_reader.dart';

final class LocationDetailController extends ChangeNotifier {
  LocationDetailController({
    LocationCatalogReader reader = const UnavailableLocationCatalogReader(),
    required String id,
    required LocationScope scope,
    bool sessionAvailable = false,
    int contextRevision = 0,
  }) : _reader = reader,
       _id = id,
       _scope = scope,
       _sessionAvailable = sessionAvailable,
       _contextRevision = contextRevision;
  LocationCatalogReader _reader;
  String _id;
  LocationScope _scope;
  bool _sessionAvailable;
  int _contextRevision;
  int _epoch = 0;
  bool _disposed = false;
  LocationReadState _state = LocationReadState.unavailable;
  LocationCatalogEntry? _data;
  LocationReadState get state => _state;
  LocationCatalogEntry? get data => _data;

  Future<void> load({
    LocationCatalogReader? reader,
    String? id,
    LocationScope? scope,
    bool? sessionAvailable,
    int? contextRevision,
  }) async {
    if (_disposed) return;
    _reader = reader ?? _reader;
    _id = id ?? _id;
    _scope = scope ?? _scope;
    _sessionAvailable = sessionAvailable ?? _sessionAvailable;
    _contextRevision = contextRevision ?? _contextRevision;
    final epoch = ++_epoch;
    final currentReader = _reader;
    final requestedId = _id;
    final requestedScope = _scope;
    _data = null;
    _state = _sessionAvailable && validLocationId(requestedId) && validLocationScope(requestedScope)
        ? LocationReadState.loading
        : LocationReadState.denied;
    notifyListeners();
    if (!_current(epoch) || _state != LocationReadState.loading) return;
    try {
      final result = await currentReader.fetchDetail(requestedId);
      if (!_current(epoch)) return;
      if (result.id != requestedId || !sameLocationScope(result.scope, requestedScope)) {
        throw const FormatException('Invalid location detail');
      }
      _data = result;
      _state = LocationReadState.ready;
    } on LocationCatalogAccessDeniedException {
      if (!_current(epoch)) return;
      _state = LocationReadState.denied;
    } catch (_) {
      if (!_current(epoch)) return;
      _state = LocationReadState.unavailable;
    }
    if (_current(epoch)) notifyListeners();
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
