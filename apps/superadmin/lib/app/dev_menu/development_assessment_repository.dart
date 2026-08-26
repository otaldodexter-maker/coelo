import '../../features/assessments/assessment.dart';

final class DevelopmentAssessmentRepository implements AssessmentRepository {
  DevelopmentAssessmentRepository()
    : _configuration = const AssessmentConfiguration(
        id: 'dev-assessment-config-1',
        activityId: 'activity-1',
        institutionId: 'institution-1',
        periodicity: 'bimonthly',
        scaleKind: AssessmentScaleKind.numeric0To10,
        version: 1,
        status: 'active',
        instruments: [
          AssessmentInstrument(id: 'oral', name: 'Prova oral', weight: 40, sortOrder: 0),
          AssessmentInstrument(id: 'project', name: 'Projeto', weight: 35, sortOrder: 1),
          AssessmentInstrument(id: 'participation', name: 'Participação', weight: 25, sortOrder: 2),
        ],
        competencies: [
          AssessmentCompetency(id: 'speaking', name: 'Expressão oral', category: 'Inglês'),
        ],
      ) {
    _gradebook = AssessmentGradebook(
      id: 'dev-gradebook-1',
      version: 1,
      status: AssessmentGradebookStatus.draft,
      context: const AssessmentContext.sample(),
      configuration: _configuration,
      students: const [
        AssessmentStudentEntry(
          id: 'student-1',
          childContextId: 'child-1',
          name: 'Ana Clara',
          state: AssessmentStudentState.complete,
          suggestedScore: 8.5,
          finalNumericValue: 8.5,
        ),
        AssessmentStudentEntry(id: 'student-2', childContextId: 'child-2', name: 'Bruno Lima'),
      ],
    );
  }

  late AssessmentGradebook _gradebook;
  AssessmentConfiguration _configuration;

  @override
  Future<AssessmentContextOptions> fetchContextOptions() async => const AssessmentContextOptions(
    assignments: [AssessmentContext.sample()],
    periods: [AssessmentPeriodOption(id: 'period-1', name: '2º bimestre de 2027', status: 'open')],
  );

  @override
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId}) async =>
      _configuration;

  @override
  Future<AssessmentGradebook> createOrResumeGradebook(
    AssessmentContext context,
    AssessmentConfiguration configuration,
  ) async => _gradebook;

  @override
  Future<AssessmentGradebook?> fetchGradebook(String id) async =>
      id == _gradebook.id ? _gradebook : null;

  @override
  Future<List<AssessmentClosingItem>> fetchClosingQueue() async => [
    AssessmentClosingItem(
      id: _gradebook.id,
      status: _gradebook.status,
      version: _gradebook.version,
      institutionName: _gradebook.context.institutionName,
      unitName: _gradebook.context.unitName,
      groupName: _gradebook.context.groupName,
      activityName: _gradebook.context.activityName,
      periodName: _gradebook.context.periodName,
      pendingCount: _gradebook.students.where((student) => !student.isResolved).length,
    ),
  ];

  @override
  Future<AssessmentConfiguration> saveConfiguration(AssessmentConfiguration value) async =>
      _configuration = value.copyWith(version: value.version + 1);

  @override
  Future<AssessmentConfiguration> activateConfiguration(AssessmentConfiguration value) async =>
      _configuration = value.copyWith(status: 'active');

  @override
  Future<AssessmentGradebook> saveGradebook(AssessmentGradebook value, {String? reason}) async =>
      _gradebook = value.copyWith(version: value.version + 1);

  @override
  Future<AssessmentGradebook> submitGradebook(AssessmentGradebook value) async => _gradebook = value
      .copyWith(status: AssessmentGradebookStatus.submitted, version: value.version + 1);

  @override
  Future<AssessmentGradebook> transitionGradebook(
    AssessmentGradebook value,
    AssessmentClosingAction action,
    String reason,
  ) async {
    final status = switch (action) {
      AssessmentClosingAction.review => AssessmentGradebookStatus.reviewed,
      AssessmentClosingAction.returnToTeacher => AssessmentGradebookStatus.draft,
      AssessmentClosingAction.publish => AssessmentGradebookStatus.published,
    };
    return _gradebook = value.copyWith(status: status, version: value.version + 1);
  }

  @override
  Future<AssessmentGradebook> schedulePublication(
    AssessmentGradebook value,
    DateTime publishAt,
    String reason,
  ) async => _gradebook = value.copyWith(
    status: AssessmentGradebookStatus.reviewed,
    version: value.version + 1,
  );
}
