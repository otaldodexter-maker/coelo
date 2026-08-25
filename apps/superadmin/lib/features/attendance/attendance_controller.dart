import 'package:flutter/foundation.dart';

import 'attendance.dart';

sealed class AttendanceState {
  const AttendanceState();
}

final class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

final class AttendanceLoading extends AttendanceState {
  const AttendanceLoading();
}

final class AttendanceReady extends AttendanceState {
  const AttendanceReady(this.overview);
  final AttendanceOverview overview;
}

final class AttendanceEmpty extends AttendanceState {
  const AttendanceEmpty();
}

final class AttendanceUnauthorized extends AttendanceState {
  const AttendanceUnauthorized();
}

final class AttendanceConflict extends AttendanceState {
  const AttendanceConflict();
}

final class AttendanceFailure extends AttendanceState {
  const AttendanceFailure(this.error);
  final Object error;
}

final class AttendanceController extends ChangeNotifier {
  AttendanceController({required this.repository, required this.permissions});

  final AttendanceRepository repository;
  final AttendancePermissions permissions;
  AttendanceState _state = const AttendanceInitial();
  AttendanceBulkReceipt? _lastBulkReceipt;

  AttendanceState get state => _state;
  AttendanceBulkReceipt? get lastBulkReceipt => _lastBulkReceipt;

  Future<void> load({DateTime? date}) async {
    _emit(const AttendanceLoading());
    try {
      final overview = await repository.fetchOverview(date: date);
      _emit(overview.calls.isEmpty ? const AttendanceEmpty() : AttendanceReady(overview));
    } on AttendanceUnauthorizedException {
      _emit(const AttendanceUnauthorized());
    } catch (error) {
      _emit(AttendanceFailure(error));
    }
  }

  bool canOperate(AttendanceCall call) => permissions.canOperate(call);

  Future<AttendanceCall> createCall(AttendanceCallDraft draft) =>
      _runCall(() => repository.createCall(draft));

  Future<AttendanceCall> setParticipantState(
    AttendanceCall call,
    String participantId,
    AttendancePresenceState participantState,
  ) {
    _requireWrite(call);
    return _runCall(
      () => repository.setParticipantState(
        call.id,
        participantId,
        participantState,
        expectedVersion: call.version,
      ),
    );
  }

  Future<AttendanceBulkResult> markRemainingPresent(AttendanceCall call) async {
    _requireWrite(call);
    final result = await _run(
      () => repository.markRemainingPresent(call.id, expectedVersion: call.version),
    );
    _lastBulkReceipt = result.receipt;
    notifyListeners();
    return result;
  }

  Future<AttendanceBulkResult> clearPresenceMarks(AttendanceCall call) async {
    _requireWrite(call);
    final result = await _run(
      () => repository.clearPresenceMarks(call.id, expectedVersion: call.version),
    );
    _lastBulkReceipt = result.receipt;
    notifyListeners();
    return result;
  }

  Future<AttendanceCall> undoLastBulk() async {
    final receipt = _lastBulkReceipt;
    if (receipt == null) throw StateError('Nenhuma operação em lote pode ser desfeita.');
    final call = await _runCall(() => repository.undoBulk(receipt));
    _lastBulkReceipt = null;
    notifyListeners();
    return call;
  }

  Future<AttendanceCall> complete(AttendanceCall call) {
    _requireWrite(call);
    return _runCall(() => repository.completeCall(call.id, expectedVersion: call.version));
  }

  Future<AttendanceCall> reopen(AttendanceCall call, String reason) {
    _requireWrite(call);
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason');
    return _runCall(
      () => repository.reopenCall(call.id, expectedVersion: call.version, reason: reason.trim()),
    );
  }

  Future<AttendanceCall> _runCall(Future<AttendanceCall> Function() operation) => _run(operation);

  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AttendanceVersionConflictException {
      _emit(const AttendanceConflict());
      rethrow;
    } on AttendanceUnauthorizedException {
      _emit(const AttendanceUnauthorized());
      rethrow;
    }
  }

  void _requireWrite(AttendanceCall call) {
    if (!canOperate(call)) throw StateError('Ação não permitida neste vínculo.');
  }

  void _emit(AttendanceState value) {
    _state = value;
    notifyListeners();
  }
}
