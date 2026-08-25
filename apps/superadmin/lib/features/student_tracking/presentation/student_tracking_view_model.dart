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

  Future<void> load() async {
    _setState(const StudentTrackingLoading());
    try {
      final page = await _repository.fetchChildren();
      _children = page.items;
      if (_children.isEmpty) {
        _setState(const StudentTrackingNoChildren());
        return;
      }
      selectedChild = _children.first;
      await _loadSelection(autoSelect: true);
    } on Exception catch (error) {
      _handleFailure(error);
    }
  }

  Future<void> selectChild(StudentTrackingChild child) async {
    selectedChild = child;
    selectedContext = null;
    selectedPeriod = null;
    snapshot = null;
    _setState(const StudentTrackingLoading());
    try {
      await _loadSelection(autoSelect: true);
    } on Exception catch (error) {
      _handleFailure(error);
    }
  }

  Future<void> selectContext(StudentTrackingContext context) async {
    selectedContext = context;
    selectedPeriod = null;
    _setState(const StudentTrackingLoading());
    try {
      await _loadSelection(autoSelect: true);
    } on Exception catch (error) {
      _handleFailure(error);
    }
  }

  Future<void> selectPeriod(StudentTrackingPeriod period) async {
    selectedPeriod = period;
    _setState(const StudentTrackingLoading());
    try {
      await _loadSelection();
    } on Exception catch (error) {
      _handleFailure(error);
    }
  }

  Future<void> reload() async {
    if (selectedChild == null) {
      await load();
      return;
    }
    _setState(const StudentTrackingLoading());
    try {
      await _loadSelection();
    } on Exception catch (error) {
      _handleFailure(error);
    }
  }

  Future<void> retry() => load();

  Future<void> _loadSelection({bool autoSelect = false}) async {
    final child = selectedChild;
    if (child == null) return;
    var next = await _repository.fetchSnapshot(
      childContextId: child.id,
      activityId: selectedContext?.id,
      periodId: selectedPeriod?.id,
    );
    if (autoSelect && selectedContext == null) {
      if (next.contexts.isEmpty) {
        snapshot = next;
        _setState(const StudentTrackingNoContext());
        return;
      }
      selectedContext = next.contexts.first;
      next = await _repository.fetchSnapshot(
        childContextId: child.id,
        activityId: selectedContext!.id,
      );
    }
    if (autoSelect && selectedPeriod == null && next.periods.isNotEmpty) {
      selectedPeriod = next.periods.first;
      next = await _repository.fetchSnapshot(
        childContextId: child.id,
        activityId: selectedContext?.id,
        periodId: selectedPeriod!.id,
      );
    }
    snapshot = next;
    _setState(const StudentTrackingReady());
  }

  void _handleFailure(Exception error) {
    switch (error) {
      case StudentTrackingRevokedException():
        snapshot = null;
        selectedChild = null;
        selectedContext = null;
        selectedPeriod = null;
        _children = const [];
        _setState(const StudentTrackingRevoked());
      case StudentTrackingUnavailableException():
        snapshot = null;
        _setState(const StudentTrackingUnavailable());
      case StudentTrackingOfflineException():
        _setState(const StudentTrackingOffline());
      case StudentTrackingDeniedException():
        _setState(const StudentTrackingDenied());
      default:
        _setState(const StudentTrackingFailure());
    }
  }

  void _setState(StudentTrackingState value) {
    _state = value;
    notifyListeners();
  }
}
