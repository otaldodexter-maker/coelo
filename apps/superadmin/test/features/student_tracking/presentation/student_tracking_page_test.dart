import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:coelo_superadmin/features/student_tracking/presentation/student_tracking_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('renders without overflow at ${width.toInt()}', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(StudentTrackingPage(repository: _Repository(), logout: unavailableSuperadminLogout)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lia'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changes between linear tabs and exposes competency detail only once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(StudentTrackingPage(repository: _Repository(), logout: unavailableSuperadminLogout)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Competências').last);
    await tester.pump();
    expect(find.byKey(const Key('student-tracking-competency-radar')), findsOneWidget);
    expect(find.text('Empatia'), findsOneWidget);
  });

  testWidgets('renders access denied state with retry', (tester) async {
    await tester.pumpWidget(
      _app(
        StudentTrackingPage(
          repository: _Repository(error: const StudentTrackingDeniedException()),
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acesso negado'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('renders unavailable distinctly in ${brightness.name}', (tester) async {
      tester.view.physicalSize = Size(brightness == Brightness.light ? 375 : 1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: StudentTrackingPage(
              repository: const UnavailableStudentTrackingRepository(),
              logout: unavailableSuperadminLogout,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('student-tracking-unavailable')), findsOneWidget);
      expect(find.text('Acompanhamento indisponível'), findsOneWidget);
      expect(find.text('Conexão indisponível'), findsNothing);
      expect(find.text('Tentar novamente'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders an explicit context without published data state', (tester) async {
    await tester.pumpWidget(
      _app(
        StudentTrackingPage(
          repository: _Repository(noData: true),
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-tracking-no-data')), findsOneWidget);
    expect(find.text('Nenhum dado publicado'), findsOneWidget);
  });

  testWidgets('renders empty agenda, assessment period and unpublished report states', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        StudentTrackingPage(
          repository: _Repository(emptySections: true),
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum compromisso neste período.'), findsOneWidget);
    await tester.tap(find.text('Avaliações').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma avaliação publicada para este período.'), findsOneWidget);
    final reportCardsTab = find.text('Boletins');
    await tester.ensureVisible(reportCardsTab);
    await tester.pumpAndSettle();
    await tester.tap(reportCardsTab);
    await tester.pumpAndSettle();
    expect(find.text('O boletim ainda não foi publicado.'), findsOneWidget);
  });

  testWidgets('changes authorized context and period through canonical selectors', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      _app(StudentTrackingPage(repository: repository, logout: unavailableSuperadminLogout)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-context-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ballet').last);
    await tester.pumpAndSettle();
    expect(repository.lastActivityId, 'ballet');
    await tester.tap(find.byKey(const Key('student-period-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4º bimestre').last);
    await tester.pumpAndSettle();
    expect(repository.lastPeriodId, 'period-4');
  });

  testWidgets('changes between authorized children through the canonical selector', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      _app(StudentTrackingPage(repository: repository, logout: unavailableSuperadminLogout)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-child-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caio').last);
    await tester.pumpAndSettle();
    expect(repository.lastChildContextId, 'child-2');
    expect(find.text('Caio'), findsWidgets);
  });

  testWidgets('keeps the read-only page free of management and justification actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(StudentTrackingPage(repository: _Repository(), logout: unavailableSuperadminLogout)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gerenciar dados'), findsNothing);
    await tester.tap(find.text('Assiduidade').last);
    await tester.pump();
    expect(find.text('Justificar ausência'), findsNothing);
  });

  testWidgets('supports keyboard focus, 200 percent text and reduced motion', (tester) async {
    tester.view.physicalSize = const Size(375, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2), disableAnimations: true),
          child: StudentTrackingPage(
            repository: _Repository(),
            logout: unavailableSuperadminLogout,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(theme: CoeloTheme.light, home: child);

final class _Repository implements StudentTrackingRepository {
  String? lastActivityId;
  String? lastPeriodId;
  String? lastChildContextId;
  _Repository({this.error, this.noData = false, this.emptySections = false});
  final Object? error;
  final bool noData;
  final bool emptySections;
  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) async {
    if (error case final value?) throw value;
    return StudentTrackingChildPage(
      items: const [
        StudentTrackingChild(id: 'child', name: 'Lia', institutionName: 'Colégio'),
        StudentTrackingChild(id: 'child-2', name: 'Caio', institutionName: 'Colégio'),
      ],
    );
  }

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) async {
    lastChildContextId = childContextId;
    lastActivityId = activityId;
    lastPeriodId = periodId;
    final childName = childContextId == 'child-2' ? 'Caio' : 'Lia';
    if (noData) {
      return StudentTrackingSnapshot(
        child: StudentTrackingChild(
          id: childContextId,
          name: childName,
          institutionName: 'Colégio',
        ),
        contexts: const [StudentTrackingContext(id: 'school', name: 'Escola')],
        periods: const [StudentTrackingPeriod(id: 'period', label: '3º bimestre')],
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
    }
    if (emptySections) {
      return StudentTrackingSnapshot(
        child: StudentTrackingChild(
          id: childContextId,
          name: childName,
          institutionName: 'Colégio',
        ),
        contexts: const [StudentTrackingContext(id: 'school', name: 'Escola')],
        periods: const [StudentTrackingPeriod(id: 'period', label: '3º bimestre')],
        assessments: const [],
        competencies: const [],
        categoryScores: const [],
        development: const [],
        attendance: const StudentTrackingAttendance(
          total: 1,
          present: 1,
          justifiedAbsences: 0,
          unjustifiedAbsences: 0,
          late: 0,
          percentage: 100,
        ),
        agenda: const [],
        pendingNotices: 0,
      );
    }
    return StudentTrackingSnapshot(
      child: StudentTrackingChild(id: childContextId, name: childName, institutionName: 'Colégio'),
      contexts: const [
        StudentTrackingContext(id: 'school', name: 'Escola'),
        StudentTrackingContext(id: 'ballet', name: 'Ballet'),
      ],
      periods: const [
        StudentTrackingPeriod(id: 'period', label: '3º bimestre'),
        StudentTrackingPeriod(id: 'period-4', label: '4º bimestre'),
      ],
      assessments: const [
        StudentTrackingAssessment(id: 'a', title: 'Matemática', value: '8,5', normalized: .85),
      ],
      competencies: const [
        StudentTrackingCompetency(category: 'Socioemocional', name: 'Empatia', normalized: .84),
      ],
      categoryScores: const [
        StudentTrackingCategoryScore(name: 'Socioemocional', normalized: .84),
        StudentTrackingCategoryScore(name: 'Comunicação', normalized: .78),
        StudentTrackingCategoryScore(name: 'Autonomia', normalized: .72),
      ],
      development: const [
        StudentDevelopmentScore(
          kind: StudentDevelopmentKind.participation,
          name: 'Participação',
          normalized: .8,
        ),
        StudentDevelopmentScore(
          kind: StudentDevelopmentKind.behavior,
          name: 'Comportamento',
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
          id: 'event',
          kind: 'test',
          title: 'Prova de Matemática',
          startsAt: DateTime(2026, 8, 25),
        ),
      ],
      reportCard: StudentReportCard(
        id: 'report',
        title: 'Boletim do 3º bimestre',
        publishedAt: DateTime(2026, 8, 20),
      ),
      recommendation: StudentTeacherRecommendation(
        id: 'recommendation',
        text: 'Continue incentivando a leitura.',
        publishedAt: DateTime(2026, 8, 20),
      ),
      pendingNotices: 1,
    );
  }
}
