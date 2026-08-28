import 'dart:async';

import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:coelo_superadmin/features/student_tracking/presentation/student_tracking_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads children then selects the first context and period', () async {
    final repository = _FakeRepository(snapshot: _snapshot());
    final viewModel = StudentTrackingViewModel(repository);

    await viewModel.load();

    expect(viewModel.state, isA<StudentTrackingReady>());
    expect(viewModel.selectedChild?.id, 'child-1');
    expect(viewModel.selectedContext?.id, 'activity-school');
    expect(viewModel.selectedPeriod?.id, 'period-1');
    expect(repository.snapshotCalls, 3);
  });

  test('models no linked children explicitly', () async {
    final viewModel = StudentTrackingViewModel(_FakeRepository(children: const []));
    await viewModel.load();
    expect(viewModel.state, isA<StudentTrackingNoChildren>());
  });

  test('models a linked child without authorized contexts explicitly', () async {
    final viewModel = StudentTrackingViewModel(
      _FakeRepository(snapshot: _snapshot(contexts: const [])),
    );
    await viewModel.load();
    expect(viewModel.state, isA<StudentTrackingNoContext>());
  });

  test('clears sensitive selections when access is revoked', () async {
    final repository = _FakeRepository(snapshot: _snapshot());
    final viewModel = StudentTrackingViewModel(repository);
    await viewModel.load();
    repository.error = const StudentTrackingRevokedException();

    await viewModel.reload();

    expect(viewModel.state, isA<StudentTrackingRevoked>());
    expect(viewModel.snapshot, isNull);
    expect(viewModel.selectedChild, isNull);
  });

  test('maps connectivity failure to offline state and supports retry', () async {
    final repository = _FakeRepository(error: const StudentTrackingOfflineException());
    final viewModel = StudentTrackingViewModel(repository);
    await viewModel.load();
    expect(viewModel.state, isA<StudentTrackingOffline>());
    repository.error = null;
    await viewModel.retry();
    expect(viewModel.state, isA<StudentTrackingReady>());
  });

  test('clears the loaded snapshot when the repository is unavailable', () async {
    final repository = _FakeRepository(snapshot: _snapshot());
    final viewModel = StudentTrackingViewModel(repository);
    await viewModel.load();
    expect(viewModel.snapshot, isNotNull);
    repository.error = const StudentTrackingUnavailableException();

    await viewModel.reload();

    expect(viewModel.state, isA<StudentTrackingUnavailable>());
    expect(viewModel.snapshot, isNull);
    expect(viewModel.children, isEmpty);
    expect(viewModel.selectedChild, isNull);
    expect(viewModel.selectedContext, isNull);
    expect(viewModel.selectedPeriod, isNull);
  });

  test('clears every sensitive selection when a reload is denied', () async {
    final repository = _FakeRepository(snapshot: _snapshot());
    final viewModel = StudentTrackingViewModel(repository);
    await viewModel.load();
    repository.error = const StudentTrackingDeniedException();

    await viewModel.reload();

    expect(viewModel.state, isA<StudentTrackingDenied>());
    expect(viewModel.snapshot, isNull);
    expect(viewModel.children, isEmpty);
    expect(viewModel.selectedChild, isNull);
    expect(viewModel.selectedContext, isNull);
    expect(viewModel.selectedPeriod, isNull);
  });

  test('a late context A response cannot replace the latest context B', () async {
    final repository = _OrderedRepository();
    final viewModel = StudentTrackingViewModel(repository);
    await viewModel.load();
    repository.deferSelections = true;
    const contextA = StudentTrackingContext(id: 'context-a', name: 'Contexto A');
    const contextB = StudentTrackingContext(id: 'context-b', name: 'Contexto B');

    final selectingA = viewModel.selectContext(contextA);
    final selectingB = viewModel.selectContext(contextB);
    repository.contextB.complete(
      _snapshot(
        child: const StudentTrackingChild(
          id: 'child-b',
          name: 'Criança B',
          institutionName: 'Colégio B',
        ),
        contexts: const [contextB],
        periods: const [],
      ),
    );
    await selectingB;
    repository.contextA.complete(
      _snapshot(
        child: const StudentTrackingChild(
          id: 'child-a',
          name: 'Criança A',
          institutionName: 'Colégio A',
        ),
        contexts: const [contextA],
        periods: const [],
      ),
    );
    await selectingA;

    expect(viewModel.state, isA<StudentTrackingReady>());
    expect(viewModel.selectedContext?.id, 'context-b');
    expect(viewModel.snapshot?.child.name, 'Criança B');
  });

  test('dispose invalidates a pending load without notifying', () async {
    final repository = _PendingChildrenRepository();
    final viewModel = StudentTrackingViewModel(repository);
    var notifications = 0;
    viewModel.addListener(() => notifications += 1);

    final loading = viewModel.load();
    expect(notifications, 1);
    viewModel.dispose();
    repository.children.complete(
      StudentTrackingChildPage(
        items: const [
          StudentTrackingChild(
            id: 'late',
            name: 'Criança tardia',
            institutionName: 'Colégio tardio',
          ),
        ],
      ),
    );

    await loading;
    expect(notifications, 1);
  });

  test('dispose clears every loaded sensitive value without notifying', () async {
    final repository = _FakeRepository(snapshot: _snapshot());
    final viewModel = StudentTrackingViewModel(repository);
    var notifications = 0;
    viewModel.addListener(() => notifications += 1);
    await viewModel.load();
    final notificationsBeforeDispose = notifications;

    expect(viewModel.snapshot, isNotNull);
    expect(viewModel.children, isNotEmpty);
    expect(viewModel.selectedChild, isNotNull);
    expect(viewModel.selectedContext, isNotNull);
    expect(viewModel.selectedPeriod, isNotNull);

    viewModel.dispose();

    expect(viewModel.snapshot, isNull);
    expect(viewModel.children, isEmpty);
    expect(viewModel.selectedChild, isNull);
    expect(viewModel.selectedContext, isNull);
    expect(viewModel.selectedPeriod, isNull);
    expect(notifications, notificationsBeforeDispose);
  });
}

StudentTrackingSnapshot _snapshot({
  StudentTrackingChild child = const StudentTrackingChild(
    id: 'child-1',
    name: 'Lia',
    institutionName: 'Colégio',
  ),
  List<StudentTrackingContext> contexts = const [
    StudentTrackingContext(id: 'activity-school', name: 'Escola'),
  ],
  List<StudentTrackingPeriod> periods = const [
    StudentTrackingPeriod(id: 'period-1', label: '3º bimestre'),
  ],
}) => StudentTrackingSnapshot(
  child: child,
  contexts: contexts,
  periods: periods,
  assessments: const [],
  competencies: const [],
  categoryScores: const [],
  development: const [],
  attendance: const StudentTrackingAttendance(
    total: 0,
    present: 0,
    justifiedAbsences: 0,
    unjustifiedAbsences: 0,
    late: 0,
    percentage: 0,
  ),
  agenda: const [],
  pendingNotices: 0,
);

final class _FakeRepository implements StudentTrackingRepository {
  _FakeRepository({
    this.children = const [
      StudentTrackingChild(id: 'child-1', name: 'Lia', institutionName: 'Colégio'),
    ],
    StudentTrackingSnapshot? snapshot,
    this.error,
  }) : snapshot = snapshot ?? _snapshot();

  final List<StudentTrackingChild> children;
  final StudentTrackingSnapshot snapshot;
  Object? error;
  int snapshotCalls = 0;

  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) async {
    if (error case final failure?) throw failure;
    return StudentTrackingChildPage(items: children);
  }

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) async {
    snapshotCalls++;
    if (error case final failure?) throw failure;
    return snapshot;
  }
}

final class _OrderedRepository implements StudentTrackingRepository {
  bool deferSelections = false;
  final contextA = Completer<StudentTrackingSnapshot>();
  final contextB = Completer<StudentTrackingSnapshot>();

  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) async => StudentTrackingChildPage(
    items: const [StudentTrackingChild(id: 'child-1', name: 'Lia', institutionName: 'Colégio')],
  );

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) {
    if (deferSelections && activityId == 'context-a') return contextA.future;
    if (deferSelections && activityId == 'context-b') return contextB.future;
    return Future.value(
      _snapshot(
        contexts: const [
          StudentTrackingContext(id: 'context-a', name: 'Contexto A'),
          StudentTrackingContext(id: 'context-b', name: 'Contexto B'),
        ],
      ),
    );
  }
}

final class _PendingChildrenRepository implements StudentTrackingRepository {
  final children = Completer<StudentTrackingChildPage>();

  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) => children.future;

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) => throw UnimplementedError();
}
