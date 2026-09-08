import 'package:coelo_api/children.dart';
import 'package:flutter/foundation.dart';

typedef ChildDirectoryRead = Future<ChildDirectoryPage> Function(ChildDirectoryRequest request);

enum ChildDirectoryState { loading, ready, empty, denied, unavailable }

/// Default read for any composition without an authorized session.
///
/// It fails instead of returning an empty page, so a missing wiring can never
/// be mistaken for "this actor has no children".
Future<ChildDirectoryPage> unavailableChildDirectoryRead(ChildDirectoryRequest _) =>
    Future.error(StateError('Child directory unavailable'));

/// Holds one page, never authority. The server must authorize every request.
final class ChildDirectoryController extends ChangeNotifier {
  ChildDirectoryController({
    ChildDirectoryRead read = unavailableChildDirectoryRead,
    bool sessionAvailable = false,
    String? institutionId,
    int revision = 0,
  }) : _read = read,
       _sessionAvailable = sessionAvailable,
       _institutionId = institutionId,
       _revision = revision;
  ChildDirectoryRead _read;
  bool _sessionAvailable;
  String? _institutionId;
  int _revision;
  int _generation = 0;
  bool _disposed = false;
  ChildDirectoryPage? _page;
  ChildDirectoryState _state = ChildDirectoryState.unavailable;
  ChildDirectoryPage? get page => _page;
  ChildDirectoryState get state => _state;

  Future<void> setContext({
    required bool sessionAvailable,
    required String? institutionId,
    required int revision,
    ChildDirectoryRead? read,
  }) {
    if (_disposed) return Future.value();
    final changed =
        sessionAvailable != _sessionAvailable ||
        institutionId != _institutionId ||
        revision != _revision ||
        read != null && !identical(read, _read);
    if (!changed) return Future.value();
    _sessionAvailable = sessionAvailable;
    _institutionId = institutionId;
    _revision = revision;
    _read = read ?? _read;
    return reload();
  }

  Future<void> reload() => _load(null);
  Future<void> nextPage() {
    if (_disposed ||
        !_sessionAvailable ||
        _state != ChildDirectoryState.ready ||
        _page?.nextCursor == null) {
      return Future.value();
    }
    return _load(_page!.nextCursor);
  }

  Future<void> _load(ChildDirectoryCursor? after) async {
    if (_disposed) return;
    final generation = ++_generation;
    final read = _read;
    final request = ChildDirectoryRequest(institutionId: _institutionId, after: after);
    _page = null;
    _state = _sessionAvailable ? ChildDirectoryState.loading : ChildDirectoryState.denied;
    notifyListeners();
    if (!_current(generation) || _state != ChildDirectoryState.loading) return;
    try {
      final params = request.toRpcParams();
      final result = await read(request);
      if (!_current(generation)) return;
      if (result.items.length > request.limit ||
          result.items.map((item) => item.contextId).toSet().length != result.items.length ||
          params['p_institution_id'] != null &&
              result.items.any((item) => item.institutionId != params['p_institution_id'])) {
        throw const FormatException('Invalid child directory page');
      }
      _page = result;
      _state = result.items.isEmpty ? ChildDirectoryState.empty : ChildDirectoryState.ready;
    } on ChildDirectoryDeniedException {
      if (!_current(generation)) return;
      _state = ChildDirectoryState.denied;
    } catch (_) {
      if (!_current(generation)) return;
      _state = ChildDirectoryState.unavailable;
    }
    if (_current(generation)) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _page = null;
    super.dispose();
  }
}
