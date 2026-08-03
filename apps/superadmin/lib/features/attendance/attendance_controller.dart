import 'package:flutter/foundation.dart';

import 'attendance.dart';

final class AttendanceController extends ChangeNotifier {
  AttendanceController({required this.repository, required this.permissions}) {
    if (repository case final ChangeNotifier notifier) {
      notifier.addListener(_forwardChange);
      _notifier = notifier;
    }
  }

  final AttendanceRepository repository;
  final AttendancePermissions permissions;
  ChangeNotifier? _notifier;

  bool canOperate(String callId) {
    final call = repository.callById(callId);
    return call != null && permissions.canOperate(call);
  }

  void markRemainingPresent(String callId) {
    if (!canOperate(callId)) throw StateError('Ação não permitida neste vínculo.');
    repository.markRemainingPresent(callId);
  }

  void complete(String callId) {
    if (!canOperate(callId)) throw StateError('Ação não permitida neste vínculo.');
    repository.completeCall(callId);
  }

  void _forwardChange() => notifyListeners();

  @override
  void dispose() {
    _notifier?.removeListener(_forwardChange);
    super.dispose();
  }
}
