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
  });
}

StudentTrackingSnapshot _snapshot({
  List<StudentTrackingContext> contexts = const [
    StudentTrackingContext(id: 'activity-school', name: 'Escola'),
  ],
}) => StudentTrackingSnapshot(
  child: const StudentTrackingChild(id: 'child-1', name: 'Lia', institutionName: 'Colégio'),
  contexts: contexts,
  periods: const [StudentTrackingPeriod(id: 'period-1', label: '3º bimestre')],
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
