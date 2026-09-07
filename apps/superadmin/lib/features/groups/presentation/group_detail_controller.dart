import 'package:flutter/foundation.dart';
import '../domain/group_detail.dart';

enum GroupDetailState { loading, ready, denied, unavailable }

final class GroupDetailController extends ChangeNotifier {
  GroupDetailController({required GroupDetailRepository repository, required String id})
    : _repository = repository,
      _id = id;

  GroupDetailRepository _repository;
  String _id;
  var _generation = 0;
  var _disposed = false;
  GroupDetailState _state = GroupDetailState.loading;
  GroupDetail? _detail;
  GroupDetailState get state => _state;
  GroupDetail? get detail => _detail;

  Future<void> load({String? id, GroupDetailRepository? repository}) async {
    if (_disposed) return;
    if (id != null) _id = id;
    if (repository != null) _repository = repository;
    final generation = ++_generation;
    _detail = null;
    _state = GroupDetailState.loading;
    notifyListeners();
    try {
      final detail = await _repository.fetchById(_id);
      if (_disposed || generation != _generation) return;
      _detail = detail;
      _state = GroupDetailState.ready;
    } on GroupDetailException catch (error) {
      if (_disposed || generation != _generation) return;
      _state = error.failure == GroupDetailFailure.unavailable
          ? GroupDetailState.unavailable
          : GroupDetailState.denied;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _state = GroupDetailState.unavailable;
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
