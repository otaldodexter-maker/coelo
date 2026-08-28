import 'dart:async';

import 'package:coelo_domain/coelo_domain.dart';
import 'package:flutter/foundation.dart';

sealed class AttendanceDashboardState {
  const AttendanceDashboardState();
}

final class AttendanceDashboardInitial extends AttendanceDashboardState {
  const AttendanceDashboardInitial();
}

final class AttendanceDashboardLoading extends AttendanceDashboardState {
  const AttendanceDashboardLoading(this.previous);

  final AttendanceDashboardSnapshot? previous;
}

final class AttendanceDashboardReady extends AttendanceDashboardState {
  const AttendanceDashboardReady(this.snapshot);

  final AttendanceDashboardSnapshot snapshot;
}

final class AttendanceDashboardEmpty extends AttendanceDashboardState {
  const AttendanceDashboardEmpty(this.snapshot);

  final AttendanceDashboardSnapshot snapshot;
}

final class AttendanceDashboardUnauthorizedState extends AttendanceDashboardState {
  const AttendanceDashboardUnauthorizedState();
}

final class AttendanceDashboardFailure extends AttendanceDashboardState {
  const AttendanceDashboardFailure(this.error, this.previous);

  final Object error;
  final AttendanceDashboardSnapshot? previous;
}

final class AttendanceDashboardController extends ChangeNotifier {
  AttendanceDashboardController({
    required this.repository,
    required AttendanceDashboardQuery initialQuery,
    this.searchDelay = const Duration(milliseconds: 350),
  }) : _query = initialQuery;

  final AttendanceDashboardRepository repository;
  final Duration searchDelay;
  AttendanceDashboardQuery _query;
  AttendanceDashboardAccess? _access;
  AttendanceDashboardState _state = const AttendanceDashboardInitial();
  Timer? _searchTimer;
  var _requestGeneration = 0;
  var _disposed = false;

  AttendanceDashboardState get state => _state;
  AttendanceDashboardQuery get query => _query;
  AttendanceDashboardAccess? get access => _access;

  Future<void> load() => _reload();

  Future<void> retry() => _reload();

  Future<void> selectInstitution(String? id) {
    _query = _query.selectInstitution(id);
    return _reload();
  }

  Future<void> selectUnit(String? id) {
    _query = _query.selectUnit(id);
    return _reload();
  }

  Future<void> selectGroup(String? id) {
    _query = _query.selectGroup(id);
    return _reload();
  }

  Future<void> selectActivity(String? id) {
    _query = _query.selectActivity(id);
    return _reload();
  }

  Future<void> selectChild(String? id) {
    _query = _query.selectChild(id);
    return _reload();
  }

  Future<void> changePeriod(DateTime start, DateTime end) {
    _query = _query.copyWith(periodStart: start, periodEnd: end, page: 1);
    return _reload();
  }

  Future<void> changeGranularity(AttendanceDashboardGranularity value) {
    _query = _query.copyWith(granularity: value, page: 1);
    return _reload();
  }

  Future<void> changePage(int page) {
    _query = _query.copyWith(page: page);
    return _reload();
  }

  Future<void> changePageSize(int pageSize) {
    _query = _query.copyWith(page: 1, pageSize: pageSize);
    return _reload();
  }

  Future<void> changeStatuses(Set<AttendanceDashboardCallStatus> values) {
    _query = _query.copyWith(statuses: values, page: 1);
    return _reload();
  }

  Future<void> changeSort(AttendanceDashboardCallSort value) {
    _query = _query.copyWith(sort: value, page: 1);
    return _reload();
  }

  Future<void> changeRankingDirection(AttendanceRankingDirection value) {
    _query = _query.copyWith(rankingDirection: value, page: 1);
    return _reload();
  }

  void changeSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDelay, () {
      _query = _query.copyWith(search: value.trim(), page: 1);
      _reload();
    });
  }

  Future<void> _reload() async {
    final generation = ++_requestGeneration;
    final previous = switch (_state) {
      AttendanceDashboardReady(:final snapshot) ||
      AttendanceDashboardEmpty(:final snapshot) => snapshot,
      AttendanceDashboardLoading(:final previous) ||
      AttendanceDashboardFailure(previous: final previous) => previous,
      _ => null,
    };
    _setState(AttendanceDashboardLoading(previous));
    try {
      final access = _access ?? await repository.fetchAccess();
      if (!_isCurrent(generation)) return;
      if (!access.canRead) throw const AttendanceDashboardUnauthorized();
      _access = access;
      final scopedQuery = _query.enforce(access);
      _query = scopedQuery;
      final snapshot = await repository.fetchDashboard(scopedQuery);
      if (!_isCurrent(generation)) return;
      _setState(
        snapshot.isEmpty ? AttendanceDashboardEmpty(snapshot) : AttendanceDashboardReady(snapshot),
      );
    } on AttendanceDashboardUnauthorized {
      if (_isCurrent(generation)) _setState(const AttendanceDashboardUnauthorizedState());
    } catch (error) {
      if (_isCurrent(generation)) _setState(AttendanceDashboardFailure(error, previous));
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _requestGeneration;

  void _setState(AttendanceDashboardState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    _searchTimer?.cancel();
    super.dispose();
  }
}
