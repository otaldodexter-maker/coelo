import 'dart:async';

import 'package:coelo_superadmin/features/assessments/assessment.dart';
import 'package:coelo_superadmin/features/assessments/assessment_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closing search filters the fake queue across its visible context', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AssessmentClosingPage(
          repository: const _ClosingAssessmentRepository(),
          logout: unavailableSuperadminLogout,
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Robótica'), findsWidgets);
    expect(find.text('Expressão musical'), findsWidgets);
    await tester.enterText(find.byKey(const Key('assessment-closing-search')), 'unidade norte');
    await tester.pump();

    expect(find.text('Robótica'), findsNothing);
    expect(find.text('Expressão musical'), findsWidgets);
  });

  testWidgets('repository and gradebook swap loads only B and discards late A', (tester) async {
    final pageKey = GlobalKey();
    final repositoryA = _PageAssessmentRepository.pending();
    final repositoryB = _PageAssessmentRepository.pending();

    await tester.pumpWidget(_app(pageKey, repositoryA, 'book-a'));
    await tester.pump();
    expect(repositoryA.gradebookRequests, ['book-a']);

    await tester.pumpWidget(_app(pageKey, repositoryB, 'book-b'));
    await tester.pump();
    expect(repositoryB.gradebookRequests, ['book-b']);

    repositoryB.complete('book-b', _pageBook('book-b', 'Aluno B'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Aluno B'), findsWidgets);

    repositoryA.complete('book-a', _pageBook('book-a', 'Aluno A'));
    await tester.pump();
    expect(find.text('Aluno B'), findsWidgets);
    expect(find.text('Aluno A'), findsNothing);
  });

  testWidgets('repository swap clears the student search before loading B', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    final pageKey = GlobalKey();
    final repositoryA = _PageAssessmentRepository.immediate(_pageBook('book-a', 'Aluno A'));
    final repositoryB = _PageAssessmentRepository.immediate(_pageBook('book-b', 'Aluno B'));

    await tester.pumpWidget(_app(pageKey, repositoryA, 'book-a'));
    await tester.pumpAndSettle();
    final search = find.descendant(
      of: find.byKey(const Key('assessment-student-search')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(search, 'Aluno A');
    await tester.pump();
    expect(tester.widget<EditableText>(search).controller.text, 'Aluno A');

    await tester.pumpWidget(_app(pageKey, repositoryB, 'book-b'));
    await tester.pumpAndSettle();

    expect(repositoryB.gradebookRequests, ['book-b']);
    final searchB = find.descendant(
      of: find.byKey(const Key('assessment-student-search')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(searchB).controller.text, isEmpty);
    expect(find.text('Aluno B'), findsWidgets);
    expect(find.text('Aluno A'), findsNothing);
  });

  testWidgets('entry remains stable across the responsive matrix', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      for (final scale in const [1.0, 2.0]) {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        await tester.pumpWidget(
          _app(
            GlobalKey(),
            _PageAssessmentRepository.immediate(_pageBook('book-$width-$scale', 'Aluno')),
            'book-$width-$scale',
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width at ${scale}x');
      }
    }
  });
}

Widget _app(
  Key pageKey,
  AssessmentRepository repository,
  String gradebookId, {
  double textScale = 1,
}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: AssessmentEntryPage(
    key: pageKey,
    repository: repository,
    logout: unavailableSuperadminLogout,
    onCancel: () {},
    gradebookId: gradebookId,
  ),
);

AssessmentGradebook _pageBook(String id, String studentName) => AssessmentGradebook(
  id: id,
  version: 1,
  status: AssessmentGradebookStatus.draft,
  context: const AssessmentContext.sample(),
  configuration: const AssessmentConfiguration(
    id: 'configuration-1',
    activityId: 'activity-1',
    institutionId: 'institution-1',
    periodicity: 'bimester',
    scaleKind: AssessmentScaleKind.numeric0To10,
    version: 1,
    status: 'active',
    instruments: [],
    competencies: [],
  ),
  students: [
    AssessmentStudentEntry(id: 'student-$id', childContextId: 'child-$id', name: studentName),
  ],
);

final class _PageAssessmentRepository implements AssessmentRepository {
  _PageAssessmentRepository.pending() : _immediate = null;
  _PageAssessmentRepository.immediate(this._immediate);

  final AssessmentGradebook? _immediate;
  final _loads = <String, Completer<AssessmentGradebook?>>{};
  final gradebookRequests = <String>[];

  void complete(String id, AssessmentGradebook value) => _loads[id]!.complete(value);

  @override
  Future<AssessmentGradebook?> fetchGradebook(String id) {
    gradebookRequests.add(id);
    if (_immediate case final value?) return Future.value(value);
    return (_loads[id] ??= Completer<AssessmentGradebook?>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ClosingAssessmentRepository implements AssessmentRepository {
  const _ClosingAssessmentRepository();

  @override
  Future<List<AssessmentClosingItem>> fetchClosingQueue() async => const [
    AssessmentClosingItem(
      id: 'closing-1',
      status: AssessmentGradebookStatus.draft,
      version: 1,
      institutionName: 'Instituto Aurora',
      unitName: 'Unidade Centro',
      groupName: 'Turma Girassol',
      activityName: 'Robótica',
      periodName: '1º bimestre',
      pendingCount: 2,
    ),
    AssessmentClosingItem(
      id: 'closing-2',
      status: AssessmentGradebookStatus.submitted,
      version: 1,
      institutionName: 'Casa Nuvem',
      unitName: 'Unidade Norte',
      groupName: 'Turma Azul',
      activityName: 'Expressão musical',
      periodName: '2º bimestre',
      pendingCount: 1,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
