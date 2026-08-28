import 'package:flutter/foundation.dart';

import '../domain/student_tracking.dart';

sealed class StudentTrackingState {
  const StudentTrackingState();
}

final class StudentTrackingInitial extends StudentTrackingState {
  const StudentTrackingInitial();
}

final class StudentTrackingLoading extends StudentTrackingState {
  const StudentTrackingLoading();
}

final class StudentTrackingReady extends StudentTrackingState {
  const StudentTrackingReady();
}

final class StudentTrackingNoChildren extends StudentTrackingState {
  const StudentTrackingNoChildren();
}

final class StudentTrackingNoContext extends StudentTrackingState {
  const StudentTrackingNoContext();
}

final class StudentTrackingOffline extends StudentTrackingState {
  const StudentTrackingOffline();
}

final class StudentTrackingUnavailable extends StudentTrackingState {
  const StudentTrackingUnavailable();
}

final class StudentTrackingDenied extends StudentTrackingState {
  const StudentTrackingDenied();
}

final class StudentTrackingRevoked extends StudentTrackingState {
  const StudentTrackingRevoked();
}

final class StudentTrackingFailure extends StudentTrackingState {
  const StudentTrackingFailure();
}

final class StudentTrackingViewModel extends ChangeNotifier {
  StudentTrackingViewModel(this._repository);
  final StudentTrackingRepository _repository;

  StudentTrackingState _state = const StudentTrackingInitial();
  StudentTrackingState get state => _state;
  List<StudentTrackingChild> _children = const [];
  List<StudentTrackingChild> get children => List.unmodifiable(_children);
  StudentTrackingChild? selectedChild;
  StudentTrackingContext? selectedContext;
  StudentTrackingPeriod? selectedPeriod;
  StudentTrackingSnapshot? snapshot;
  var _generation = 0;
  var _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    _clearSensitiveState();
    _setState(const StudentTrackingLoading(), generation);
    try {
      final page = await _repository.fetchChildren();
      if (!_isCurrent(generation)) return;
      _children = page.items;
      if (_children.isEmpty) {
        _setState(const StudentTrackingNoChildren(), generation);
        return;
      }
      selectedChild = _children.first;
      await _loadSelection(generation, autoSelect: true);
    } on Exception catch (error) {
      _handleFailure(error, generation);
    }
  }

  Future<void> selectChild(StudentTrackingChild child) async {
    final generation = ++_generation;
    selectedChild = child;
    selectedContext = null;
    selectedPeriod = null;
    snapshot = null;
    _setState(const StudentTrackingLoading(), generation);
    try {
      await _loadSelection(generation, autoSelect: true);
    } on Exception catch (error) {
      _handleFailure(error, generation);
    }
  }

  Future<void> selectContext(StudentTrackingContext context) async {
    final generation = ++_generation;
    selectedContext = context;
    selectedPeriod = null;
    snapshot = null;
    _setState(const StudentTrackingLoading(), generation);
    try {
      await _loadSelection(generation, autoSelect: true);
    } on Exception catch (error) {
      _handleFailure(error, generation);
    }
  }

  Future<void> selectPeriod(StudentTrackingPeriod period) async {
    final generation = ++_generation;
    selectedPeriod = period;
    snapshot = null;
    _setState(const StudentTrackingLoading(), generation);
    try {
      await _loadSelection(generation);
    } on Exception catch (error) {
      _handleFailure(error, generation);
    }
  }

  Future<void> reload() async {
    if (selectedChild == null) {
      await load();
      return;
    }
    final generation = ++_generation;
    snapshot = null;
    _setState(const StudentTrackingLoading(), generation);
    try {
      await _loadSelection(generation);
    } on Exception catch (error) {
      _handleFailure(error, generation);
    }
  }

  Future<void> retry() => load();

  Future<void> _loadSelection(int generation, {bool autoSelect = false}) async {
    if (!_isCurrent(generation)) return;
    final child = selectedChild;
    if (child == null) return;
    var next = await _repository.fetchSnapshot(
      childContextId: child.id,
      activityId: selectedContext?.id,
      periodId: selectedPeriod?.id,
    );
    if (!_isCurrent(generation)) return;
    if (autoSelect && selectedContext == null) {
      if (next.contexts.isEmpty) {
        snapshot = next;
        _setState(const StudentTrackingNoContext(), generation);
        return;
      }
      selectedContext = next.contexts.first;
      next = await _repository.fetchSnapshot(
        childContextId: child.id,
        activityId: selectedContext!.id,
      );
      if (!_isCurrent(generation)) return;
    }
    if (autoSelect && selectedPeriod == null && next.periods.isNotEmpty) {
      selectedPeriod = next.periods.first;
      next = await _repository.fetchSnapshot(
        childContextId: child.id,
        activityId: selectedContext?.id,
        periodId: selectedPeriod!.id,
      );
      if (!_isCurrent(generation)) return;
    }
    snapshot = next;
    _setState(const StudentTrackingReady(), generation);
  }

  void _handleFailure(Exception error, int generation) {
    if (!_isCurrent(generation)) return;
    _clearSensitiveState();
    switch (error) {
      case StudentTrackingRevokedException():
        _setState(const StudentTrackingRevoked(), generation);
      case StudentTrackingUnavailableException():
        _setState(const StudentTrackingUnavailable(), generation);
      case StudentTrackingOfflineException():
        _setState(const StudentTrackingOffline(), generation);
      case StudentTrackingDeniedException():
        _setState(const StudentTrackingDenied(), generation);
      default:
        _setState(const StudentTrackingFailure(), generation);
    }
  }

  void _clearSensitiveState() {
    snapshot = null;
    selectedChild = null;
    selectedContext = null;
    selectedPeriod = null;
    _children = const [];
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _setState(StudentTrackingState value, int generation) {
    if (!_isCurrent(generation)) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _clearSensitiveState();
    super.dispose();
  }
}
