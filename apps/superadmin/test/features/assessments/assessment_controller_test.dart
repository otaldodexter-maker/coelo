import 'package:coelo_superadmin/features/assessments/assessment.dart';
import 'package:coelo_superadmin/features/assessments/assessment_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks progress without turning absence into zero', () {
    final gradebook = AssessmentGradebook(
      id: 'book-1',
      version: 1,
      status: AssessmentGradebookStatus.draft,
      context: const AssessmentContext.sample(),
      students: [
        AssessmentStudentEntry(
          id: 'one',
          childContextId: 'child-1',
          name: 'Ana',
          state: AssessmentStudentState.complete,
          suggestedScore: 8.5,
        ),
        AssessmentStudentEntry(
          id: 'two',
          childContextId: 'child-2',
          name: 'Bia',
          state: AssessmentStudentState.absent,
        ),
        AssessmentStudentEntry(id: 'three', childContextId: 'child-3', name: 'Caio'),
      ],
    );

    expect(gradebook.resolvedCount, 2);
    expect(gradebook.students[1].suggestedScore, isNull);
    expect(gradebook.hasPending, isTrue);
  });

  test('controller recovers a draft and advances the selected student', () async {
    final repository = _AssessmentRepositoryStub();
    final controller = AssessmentController(repository);

    await controller.loadGradebook('book-1');
    expect(controller.state, isA<AssessmentReady>());
    expect(controller.recoveredDraft, isTrue);

    controller.nextStudent();
    expect(controller.selectedStudentIndex, 1);
  });

  test('version conflict is exposed as a dedicated state', () async {
    final controller = AssessmentController(_AssessmentRepositoryStub(conflict: true));
    await controller.loadGradebook('book-1');

    await expectLater(controller.saveDraft(), throwsA(isA<AssessmentVersionConflictException>()));
    expect(controller.state, isA<AssessmentConflict>());
  });

  test('offline save keeps the edited draft in memory for retry', () async {
    final repository = _AssessmentRepositoryStub(offlineOnce: true);
    final controller = AssessmentController(repository);
    addTearDown(controller.dispose);
    await controller.loadGradebook('book-1');
    controller.updateStudent(
      controller.selectedStudent!.copyWith(familyComment: 'Evoluiu na expressão oral.'),
    );

    await expectLater(controller.saveDraft(), throwsA(isA<AssessmentOfflineException>()));
    expect(controller.state, isA<AssessmentOffline>());
    expect(controller.gradebook!.students.first.familyComment, 'Evoluiu na expressão oral.');

    await controller.saveDraft();
    expect(controller.state, isA<AssessmentReady>());
  });

  test('schedules publication with date time and mandatory reason', () async {
    final repository = _AssessmentRepositoryStub();
    final controller = AssessmentController(repository);
    addTearDown(controller.dispose);
    await controller.loadGradebook('book-1');
    final publishAt = DateTime(2027, 7, 10, 8, 30);

    await controller.schedulePublication(publishAt, 'Liberação aprovada.');

    expect(repository.publishAt, publishAt);
    expect(repository.publicationReason, 'Liberação aprovada.');
    expect(() => controller.schedulePublication(publishAt, ' '), throwsArgumentError);
  });
}

final class _AssessmentRepositoryStub implements AssessmentRepository {
  _AssessmentRepositoryStub({this.conflict = false, this.offlineOnce = false});
  final bool conflict;
  bool offlineOnce;
  DateTime? publishAt;
  String? publicationReason;

  AssessmentGradebook get book => AssessmentGradebook(
    id: 'book-1',
    version: 2,
    status: AssessmentGradebookStatus.draft,
    context: const AssessmentContext.sample(),
    students: [
      AssessmentStudentEntry(id: 'one', childContextId: 'child-1', name: 'Ana'),
      AssessmentStudentEntry(id: 'two', childContextId: 'child-2', name: 'Bia'),
    ],
  );

  @override
  Future<AssessmentContextOptions> fetchContextOptions() async =>
      const AssessmentContextOptions(assignments: [], periods: []);
  @override
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId}) async =>
      null;
  @override
  Future<AssessmentGradebook> createOrResumeGradebook(
    AssessmentContext context,
    AssessmentConfiguration configuration,
  ) async => book;
  @override
  Future<AssessmentGradebook?> fetchGradebook(String id) async => book;
  @override
  Future<List<AssessmentClosingItem>> fetchClosingQueue() async => const [];
  @override
  Future<AssessmentGradebook> saveGradebook(AssessmentGradebook value, {String? reason}) async {
    if (conflict) throw const AssessmentVersionConflictException();
    if (offlineOnce) {
      offlineOnce = false;
      throw const AssessmentOfflineException();
    }
    return value.copyWith(version: value.version + 1);
  }

  @override
  Future<AssessmentGradebook> submitGradebook(AssessmentGradebook value) async => value;
  @override
  Future<AssessmentGradebook> transitionGradebook(
    AssessmentGradebook value,
    AssessmentClosingAction action,
    String reason,
  ) async => value;
  @override
  Future<AssessmentGradebook> schedulePublication(
    AssessmentGradebook value,
    DateTime scheduledAt,
    String reason,
  ) async {
    publishAt = scheduledAt;
    publicationReason = reason;
    return value;
  }

  @override
  Future<AssessmentConfiguration> saveConfiguration(AssessmentConfiguration value) async => value;
  @override
  Future<AssessmentConfiguration> activateConfiguration(AssessmentConfiguration value) async =>
      value;
}
