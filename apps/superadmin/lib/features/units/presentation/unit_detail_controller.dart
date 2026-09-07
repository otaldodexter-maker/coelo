import 'package:flutter/foundation.dart';
import '../domain/unit_detail.dart';

enum UnitDetailState { loading, ready, denied, unavailable }

final class UnitDetailController extends ChangeNotifier {
  UnitDetailController({required UnitDetailRepository repository, required String id})
    : _repository = repository,
      _id = id;

  UnitDetailRepository _repository;
  String _id;
  var _generation = 0;
  var _disposed = false;
  UnitDetailState _state = UnitDetailState.loading;
  UnitDetail? _detail;
  UnitDetailState get state => _state;
  UnitDetail? get detail => _detail;

  Future<void> load({String? id, UnitDetailRepository? repository}) async {
    if (_disposed) return;
    if (id != null) _id = id;
    if (repository != null) _repository = repository;
    final generation = ++_generation;
    _detail = null;
    _state = UnitDetailState.loading;
    notifyListeners();
    try {
      final detail = await _repository.fetchById(_id);
      if (_disposed || generation != _generation) return;
      _detail = detail;
      _state = UnitDetailState.ready;
    } on UnitDetailException catch (error) {
      if (_disposed || generation != _generation) return;
      _state = error.failure == UnitDetailFailure.unavailable
          ? UnitDetailState.unavailable
          : UnitDetailState.denied;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _state = UnitDetailState.unavailable;
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
