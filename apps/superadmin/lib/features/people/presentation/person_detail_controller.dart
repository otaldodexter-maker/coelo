import 'package:flutter/foundation.dart';
import '../domain/person_detail_reader.dart';
import '../domain/person_directory.dart';

enum PersonDetailState { loading, ready, denied, unavailable }

final class PersonDetailController extends ChangeNotifier {
  PersonDetailController({required PersonDetailReader reader, required String id})
    : _reader = reader,
      _id = id;

  PersonDetailReader _reader;
  String _id;
  var _generation = 0;
  var _disposed = false;
  var _state = PersonDetailState.loading;
  PersonDirectoryItem? _detail;
  PersonDetailState get state => _state;
  PersonDirectoryItem? get detail => _detail;

  Future<void> load({String? id, PersonDetailReader? reader}) async {
    if (_disposed) return;
    if (id != null) _id = id;
    if (reader != null) _reader = reader;
    final requestedId = _id;
    final requestedReader = _reader;
    final generation = ++_generation;
    _detail = null;
    _state = PersonDetailState.loading;
    notifyListeners();
    // A listener may replace the target or invalidate this request synchronously.
    if (_disposed || generation != _generation) return;
    if (!isPersonDetailId(requestedId)) {
      _state = PersonDetailState.denied;
      notifyListeners();
      return;
    }
    try {
      final detail = await requestedReader.fetchDetail(requestedId);
      if (_disposed || generation != _generation) return;
      if (detail.id.toLowerCase() != requestedId.toLowerCase()) {
        throw const PersonDirectoryUnavailableException();
      }
      _detail = detail;
      _state = PersonDetailState.ready;
    } on PersonDirectoryUnauthorizedException {
      if (_disposed || generation != _generation) return;
      _state = PersonDetailState.denied;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _state = PersonDetailState.unavailable;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _detail = null;
    super.dispose();
  }
}
