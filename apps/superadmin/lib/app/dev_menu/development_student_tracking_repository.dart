import '../../features/student_tracking/domain/student_tracking.dart';

final class DevelopmentStudentTrackingRepository implements StudentTrackingRepository {
  const DevelopmentStudentTrackingRepository();

  static const _children = [
    StudentTrackingChild(
      id: 'lia-context',
      name: 'Lia Martins',
      institutionName: 'Instituto Horizonte',
      institutionId: 'institution-1',
    ),
    StudentTrackingChild(
      id: 'caio-context',
      name: 'Caio Martins',
      institutionName: 'Instituto Horizonte',
      institutionId: 'institution-1',
    ),
  ];

  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) async {
    final normalized = query?.trim().toLowerCase() ?? '';
    final items = _children
        .where(
          (child) =>
              normalized.isEmpty ||
              child.name.toLowerCase().contains(normalized) ||
              child.institutionName.toLowerCase().contains(normalized),
        )
        .take(limit)
        .toList(growable: false);
    return StudentTrackingChildPage(items: items);
  }

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) async {
    final child = _children.where((item) => item.id == childContextId).firstOrNull;
    if (child == null) throw const StudentTrackingDeniedException();
    return StudentTrackingSnapshot(
      child: child,
      contexts: const [
        StudentTrackingContext(id: 'school', name: 'Escola'),
        StudentTrackingContext(id: 'music', name: 'Musicalização'),
      ],
      periods: const [
        StudentTrackingPeriod(id: 'period-3', label: '3º bimestre'),
        StudentTrackingPeriod(id: 'period-4', label: '4º bimestre'),
      ],
      assessments: const [
        StudentTrackingAssessment(
          id: 'assessment-math',
          title: 'Matemática',
          value: '8,5',
          normalized: .85,
          observation: 'Boa evolução na resolução de problemas.',
        ),
        StudentTrackingAssessment(
          id: 'assessment-reading',
          title: 'Leitura',
          value: 'Muito bom',
          normalized: .9,
        ),
      ],
      competencies: const [
        StudentTrackingCompetency(
          id: 'competency-empathy',
          category: 'Socioemocional',
          name: 'Empatia',
          normalized: .84,
        ),
        StudentTrackingCompetency(
          id: 'competency-autonomy',
          category: 'Autonomia',
          name: 'Organização',
          normalized: .76,
        ),
      ],
      categoryScores: const [
        StudentTrackingCategoryScore(name: 'Socioemocional', normalized: .84),
        StudentTrackingCategoryScore(name: 'Comunicação', normalized: .78),
        StudentTrackingCategoryScore(name: 'Autonomia', normalized: .76),
      ],
      development: const [
        StudentDevelopmentScore(
          id: 'participation',
          kind: StudentDevelopmentKind.participation,
          name: 'Participação',
          normalized: .82,
        ),
        StudentDevelopmentScore(
          id: 'behavior',
          kind: StudentDevelopmentKind.behavior,
          name: 'Convivência',
          normalized: .9,
        ),
      ],
      attendance: const StudentTrackingAttendance(
        total: 20,
        present: 18,
        justifiedAbsences: 1,
        unjustifiedAbsences: 1,
        late: 2,
        percentage: 90,
      ),
      agenda: [
        StudentAgendaEvent(
          id: 'math-test',
          kind: 'assessment',
          title: 'Prova de Matemática',
          startsAt: DateTime(2026, 8, 25, 9),
          description: 'Revisar as atividades do caderno.',
        ),
        StudentAgendaEvent(
          id: 'reading-circle',
          kind: 'activity',
          title: 'Roda de leitura',
          startsAt: DateTime(2026, 8, 27, 14),
        ),
      ].take(agendaLimit).toList(growable: false),
      reportCard: StudentReportCard(
        id: 'report-period-3',
        title: 'Boletim do 3º bimestre',
        summary: 'Exemplo local para conferência visual.',
        publishedAt: DateTime(2026, 8, 20),
      ),
      recommendation: StudentTeacherRecommendation(
        id: 'recommendation-reading',
        text: 'Continue incentivando a leitura em família.',
        publishedAt: DateTime(2026, 8, 21),
      ),
      pendingNotices: 1,
    );
  }
}
