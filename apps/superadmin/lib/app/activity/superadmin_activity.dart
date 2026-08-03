import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

enum SuperadminActivityKind {
  import,
  export,
  announcement,
  emailApproval,
  attendanceNotice,
  routineUpdate,
}

enum SuperadminActivityStatus { inProgress, succeeded, partial, failed }

enum SuperadminActivityActionStatus { pending, approved, rejected }

enum SuperadminExportFormat { csv, xlsx }

@immutable
class SuperadminActivity {
  const SuperadminActivity({
    required this.id,
    required this.kind,
    required this.status,
    required this.subject,
    required this.summary,
    required this.createdAt,
    this.fileName,
    this.progress,
    this.isRead = false,
    this.actionStatus,
    this.requestedEmail,
    this.destination,
  });

  factory SuperadminActivity.announcement({
    required String id,
    required String subject,
    required String summary,
    DateTime? createdAt,
    bool isRead = false,
  }) {
    return SuperadminActivity(
      id: id,
      kind: SuperadminActivityKind.announcement,
      status: SuperadminActivityStatus.succeeded,
      subject: subject,
      summary: summary,
      createdAt: createdAt ?? DateTime.now(),
      isRead: isRead,
    );
  }

  factory SuperadminActivity.attendanceNotice({
    required String id,
    required String subject,
    required String summary,
    required String destination,
    DateTime? createdAt,
  }) => SuperadminActivity(
    id: id,
    kind: SuperadminActivityKind.attendanceNotice,
    status: SuperadminActivityStatus.succeeded,
    subject: subject,
    summary: summary,
    destination: destination,
    createdAt: createdAt ?? DateTime.now(),
  );

  factory SuperadminActivity.routineUpdate({
    required String id,
    required String subject,
    required String summary,
    required String destination,
    DateTime? createdAt,
  }) => SuperadminActivity(
    id: id,
    kind: SuperadminActivityKind.routineUpdate,
    status: SuperadminActivityStatus.succeeded,
    subject: subject,
    summary: summary,
    destination: destination,
    createdAt: createdAt ?? DateTime.now(),
  );

  final String id;
  final SuperadminActivityKind kind;
  final SuperadminActivityStatus status;
  final String subject;
  final String summary;
  final DateTime createdAt;
  final String? fileName;
  final int? progress;
  final bool isRead;
  final SuperadminActivityActionStatus? actionStatus;
  final String? requestedEmail;
  final String? destination;

  bool get isComplete => status != SuperadminActivityStatus.inProgress;

  SuperadminActivity copyWith({
    SuperadminActivityStatus? status,
    String? summary,
    int? progress,
    bool? isRead,
    SuperadminActivityActionStatus? actionStatus,
  }) {
    return SuperadminActivity(
      id: id,
      kind: kind,
      status: status ?? this.status,
      subject: subject,
      summary: summary ?? this.summary,
      createdAt: createdAt,
      fileName: fileName,
      progress: progress ?? this.progress,
      isRead: isRead ?? this.isRead,
      actionStatus: actionStatus ?? this.actionStatus,
      requestedEmail: requestedEmail,
      destination: destination,
    );
  }
}

class SuperadminActivityController extends ChangeNotifier {
  SuperadminActivityController({
    this.tickInterval = const Duration(milliseconds: 600),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  SuperadminActivityController.seeded(
    Iterable<SuperadminActivity> activities, {
    this.tickInterval = const Duration(milliseconds: 600),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _activities.addAll(activities);
  }

  final Duration tickInterval;
  final DateTime Function() _now;
  final List<SuperadminActivity> _activities = [];
  final List<Timer> _timers = [];
  Future<void> Function(String id, {required bool approved})? onEmailApprovalDecision;
  var _nextId = 0;
  var _centerOpen = false;
  var _disposed = false;

  UnmodifiableListView<SuperadminActivity> get activities => UnmodifiableListView(_activities);

  int get unreadCount =>
      _activities.where((activity) => activity.isComplete && !activity.isRead).length;

  void addActivity(SuperadminActivity activity) {
    _activities.insert(0, activity.copyWith(isRead: _centerOpen));
    notifyListeners();
  }

  String addEmailApproval({required String requestedEmail}) {
    final id = 'email-approval-${_nextId++}';
    _activities.insert(
      0,
      SuperadminActivity(
        id: id,
        kind: SuperadminActivityKind.emailApproval,
        status: SuperadminActivityStatus.succeeded,
        subject: 'Alteração de e-mail',
        summary: 'Aprovação solicitada para $requestedEmail',
        requestedEmail: requestedEmail,
        actionStatus: SuperadminActivityActionStatus.pending,
        createdAt: _now(),
        isRead: _centerOpen,
      ),
    );
    notifyListeners();
    return id;
  }

  void resolveEmailApproval(String id, {required bool approved}) {
    final index = _activities.indexWhere((activity) => activity.id == id);
    if (index < 0) return;
    final activity = _activities[index];
    _activities[index] = activity.copyWith(
      actionStatus: approved
          ? SuperadminActivityActionStatus.approved
          : SuperadminActivityActionStatus.rejected,
      summary: approved ? 'Alteração de e-mail aprovada' : 'Alteração de e-mail recusada',
      isRead: _centerOpen,
    );
    notifyListeners();
  }

  Future<void> decideEmailApproval(String id, {required bool approved}) async {
    await onEmailApprovalDecision?.call(id, approved: approved);
  }

  void removeActivity(String id) {
    final previousLength = _activities.length;
    _activities.removeWhere((activity) => activity.id == id);
    if (_activities.length != previousLength) {
      notifyListeners();
    }
  }

  void startDemoImport({
    String subject = 'Instituições',
    String fileName = 'instituicoes-julho.xlsx',
    String progressSummary = 'Importando instituições',
    String completedSummary = '24 importadas, 2 rejeitadas',
  }) {
    final id = 'demo-import-${_nextId++}';
    _activities.insert(
      0,
      SuperadminActivity(
        id: id,
        kind: SuperadminActivityKind.import,
        status: SuperadminActivityStatus.inProgress,
        subject: subject,
        summary: 'Preparando importação',
        createdAt: _now(),
        fileName: fileName,
        progress: 0,
        isRead: true,
      ),
    );
    notifyListeners();

    const steps = [25, 55, 80, 100];
    var index = 0;
    late final Timer timer;
    timer = Timer.periodic(tickInterval, (_) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final progress = steps[index++];
      final activityIndex = _activities.indexWhere((activity) => activity.id == id);
      if (activityIndex < 0) {
        timer.cancel();
        return;
      }
      final completed = progress == 100;
      _activities[activityIndex] = _activities[activityIndex].copyWith(
        progress: progress,
        status: completed ? SuperadminActivityStatus.partial : SuperadminActivityStatus.inProgress,
        summary: completed ? completedSummary : progressSummary,
        isRead: completed ? _centerOpen : true,
      );
      if (completed) {
        timer.cancel();
        _timers.remove(timer);
      }
      notifyListeners();
    });
    _timers.add(timer);
  }

  void completeDemoExport(
    SuperadminExportFormat format, {
    String subject = 'Instituições',
    String fileBaseName = 'instituicoes',
  }) {
    _activities.insert(
      0,
      SuperadminActivity(
        id: 'demo-export-${_nextId++}',
        kind: SuperadminActivityKind.export,
        status: SuperadminActivityStatus.succeeded,
        subject: subject,
        summary: 'Exportação preparada para demonstração',
        createdAt: _now(),
        fileName: '$fileBaseName.${format.name}',
        progress: 100,
        isRead: _centerOpen,
      ),
    );
    notifyListeners();
  }

  void setCenterOpen(bool open) {
    _centerOpen = open;
    if (!open) {
      return;
    }
    var changed = false;
    for (var index = 0; index < _activities.length; index += 1) {
      final activity = _activities[index];
      if (activity.isComplete && !activity.isRead) {
        _activities[index] = activity.copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
