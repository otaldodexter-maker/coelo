import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:coelo_superadmin/features/student_tracking/presentation/student_tracking_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// `on Exception` does not catch an `Error`.
///
/// This view model caught `Exception` in all five of its load paths. A decoding
/// `TypeError` is an `Error`, so it escaped every one of them: the state never
/// left loading, the screen sat on its skeleton forever, and there was no retry
/// to press. A screen that hangs is worse than one that fails, because failing
/// is the only state a person can act on.
///
/// Four sibling directory view models had the same defect and were fixed in
/// c3ce3127. This file was missed there. Reported by C07 through C06, verified
/// here against the five catch sites before changing them.
final class _ThrowingRepository implements StudentTrackingRepository {
  _ThrowingRepository(this.failure);

  final Object failure;
  var childCalls = 0;

  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) async {
    childCalls++;
    throw failure;
  }

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) async => throw failure;
}

void main() {
  for (final failure in <(String, Object)>[
    // The one that actually escaped: a decoder meeting a shape it did not
    // expect throws an Error, not an Exception.
    ('a decoding TypeError', TypeError()),
    ('a StateError', StateError('bad state')),
    ('a plain Exception', Exception('offline')),
    ('a typed unavailability', const StudentTrackingUnavailableException()),
  ]) {
    test('${failure.$1} leaves a state a person can act on', () async {
      final repository = _ThrowingRepository(failure.$2);
      final viewModel = StudentTrackingViewModel(repository);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(
        viewModel.state,
        isNot(isA<StudentTrackingLoading>()),
        reason: 'staying in loading is the hang this test exists to forbid',
      );
      expect(viewModel.state, isNot(isA<StudentTrackingInitial>()));
    });
  }

  test('an Error is reported as a failure, which is the state that offers retry', () async {
    final repository = _ThrowingRepository(TypeError());
    final viewModel = StudentTrackingViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    expect(viewModel.state, isA<StudentTrackingFailure>());

    // And the retry the failure panel offers reaches the repository, rather
    // than repainting the same dead screen.
    final before = repository.childCalls;
    await viewModel.retry();
    expect(repository.childCalls, before + 1);
  });

  test('a typed unavailability keeps its own state instead of collapsing to failure', () async {
    // Widening the catch must not flatten the vocabulary: the states that carry
    // a specific meaning still carry it.
    final viewModel = StudentTrackingViewModel(
      _ThrowingRepository(const StudentTrackingRevokedException()),
    );
    addTearDown(viewModel.dispose);
    await viewModel.load();
    expect(viewModel.state, isA<StudentTrackingRevoked>());
  });
}
