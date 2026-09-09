import 'dart:async';

import 'package:coelo_superadmin/features/assessments/assessment.dart';
import 'package:coelo_superadmin/features/assessments/assessment_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closing decision inherits local dark theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Theme(
          data: CoeloTheme.dark,
          child: AssessmentClosingDetailPage(
            repository: _PageAssessmentRepository.immediate(
              _pageBook('book-a', 'Aluno A', status: AssessmentGradebookStatus.submitted),
            ),
            gradebookId: 'book-a',
            logout: unavailableSuperadminLogout,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('assessment-closing-reason')))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('closing actions follow the backend state machine', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final expectation in const [
      (
        status: AssessmentGradebookStatus.draft,
        canReturn: false,
        canReview: false,
        canPublish: false,
      ),
      (
        status: AssessmentGradebookStatus.submitted,
        canReturn: true,
        canReview: true,
        canPublish: false,
      ),
      (
        status: AssessmentGradebookStatus.reviewed,
        canReturn: true,
        canReview: false,
        canPublish: true,
      ),
      (
        status: AssessmentGradebookStatus.published,
        canReturn: false,
        canReview: false,
        canPublish: false,
      ),
    ]) {
      final status = expectation.status;
      await tester.pumpWidget(
        _app(
          ValueKey(status),
          _PageAssessmentRepository.immediate(
            _pageBook(
              'book-${status.name}',
              'Aluno',
              status: status,
              studentState: AssessmentStudentState.complete,
            ),
          ),
          'book-${status.name}',
          closing: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Devolver')).onPressed !=
            null,
        expectation.canReturn,
        reason: '${status.name} return',
      );
      expect(
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Revisar')).onPressed !=
            null,
        expectation.canReview,
        reason: '${status.name} review',
      );
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publicar')).onPressed !=
            null,
        expectation.canPublish,
        reason: '${status.name} publish',
      );
    }
  });

  testWidgets('closing detail reloads when only gradebook ID changes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    final repository = _PageAssessmentRepository.pending();
    await tester.pumpWidget(_app(key, repository, 'book-a', closing: true));
    repository.complete('book-a', _pageBook('book-a', 'Aluno A'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(key, repository, 'book-b', closing: true));
    expect(repository.gradebookRequests, ['book-a', 'book-b']);
    expect(find.text('Aluno A'), findsNothing);
    repository.complete('book-b', _pageBook('book-b', 'Aluno B'));
    await tester.pumpAndSettle();
    expect(find.text('Aluno B'), findsWidgets);
  });

  for (final lateFailure in [false, true]) {
    testWidgets('closing command from A cannot notify or replace B (failure=$lateFailure)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      final a = _PageAssessmentRepository.immediate(
        _pageBook('book-a', 'Aluno A', status: AssessmentGradebookStatus.submitted),
      );
      a.pendingTransition = Completer<AssessmentGradebook>();
      final b = _PageAssessmentRepository.immediate(_pageBook('book-b', 'Aluno B'));
      await tester.pumpWidget(_app(key, a, 'book-a', closing: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('assessment-closing-reason')), 'Revisão A');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(a.transitions, ['book-a']);
      await tester.pumpWidget(_app(key, b, 'book-b', closing: true));
      await tester.pumpAndSettle();
      if (lateFailure) {
        a.pendingTransition!.completeError(Exception('old command'));
      } else {
        a.pendingTransition!.complete(_pageBook('book-a', 'Aluno A'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Aluno B'), findsWidgets);
      expect(find.text('Aluno A'), findsNothing);
      expect(find.text('Fechamento atualizado.'), findsNothing);
      expect(b.transitions, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final lateFailure in [false, true]) {
    testWidgets('closing queue swaps context and ignores late A (failure=$lateFailure)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      final a = _PendingClosingRepository();
      final b = _PendingClosingRepository();
      Widget app(AssessmentRepository repository) => MaterialApp(
        theme: CoeloTheme.light,
        home: AssessmentClosingPage(
          key: key,
          repository: repository,
          logout: unavailableSuperadminLogout,
          onOpen: (_) {},
        ),
      );
      await tester.pumpWidget(app(a));
      await tester.pumpWidget(app(b));
      expect(b.requests, 1);
      final rows = await const _ClosingAssessmentRepository().fetchClosingQueue();
      b.result.complete([rows.last]);
      await tester.pumpAndSettle();
      expect(find.text('Expressão musical'), findsWidgets);
      if (lateFailure) {
        a.result.completeError(Exception('old context'));
      } else {
        a.result.complete([rows.first]);
      }
      await tester.pumpAndSettle();
      expect(find.text('Expressão musical'), findsWidgets);
      expect(find.text('Robótica'), findsNothing);
      expect(find.text('Não foi possível carregar'), findsNothing);
    });
  }

  testWidgets('closing queue maps decoding Errors to a retryable failure', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AssessmentClosingPage(
          repository: const _ClosingDecodingErrorRepository(),
          logout: unavailableSuperadminLogout,
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('closing detail swaps repository and discards late gradebook A', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    final a = _PageAssessmentRepository.pending();
    final b = _PageAssessmentRepository.pending();
    await tester.pumpWidget(_app(key, a, 'book-a', closing: true));
    await tester.pumpWidget(_app(key, b, 'book-b', closing: true));
    expect(b.gradebookRequests, ['book-b']);
    b.complete('book-b', _pageBook('book-b', 'Aluno B'));
    await tester.pumpAndSettle();
    a.complete('book-a', _pageBook('book-a', 'Aluno A'));
    await tester.pumpAndSettle();
    expect(find.text('Aluno B'), findsWidgets);
    expect(find.text('Aluno A'), findsNothing);
  });

  testWidgets('closing decision is dismissed when its context changes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    final a = _PageAssessmentRepository.immediate(
      _pageBook('book-a', 'Aluno A', status: AssessmentGradebookStatus.submitted),
    );
    final b = _PageAssessmentRepository.immediate(_pageBook('book-b', 'Aluno B'));
    await tester.pumpWidget(_app(key, a, 'book-a', closing: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar diário'), findsOneWidget);
    await tester.pumpWidget(_app(key, b, 'book-b', closing: true));
    await tester.pumpAndSettle();
    expect(find.text('Revisar diário'), findsNothing);
    expect(find.text('Aluno B'), findsWidgets);
    expect(a.transitions, isEmpty);
    expect(b.transitions, isEmpty);
  });

  testWidgets('assessment file actions stay visible and fail closed', (tester) async {
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

    expect(find.byType(CoeloAdminFileActions), findsOneWidget);
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);

    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Indisponível nesta etapa'), findsOneWidget);
    expect(find.textContaining('exportado'), findsNothing);
  });

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
  bool closing = false,
}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: closing
      ? AssessmentClosingDetailPage(
          key: pageKey,
          repository: repository,
          logout: unavailableSuperadminLogout,
          onBack: () {},
          gradebookId: gradebookId,
        )
      : AssessmentEntryPage(
          key: pageKey,
          repository: repository,
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          gradebookId: gradebookId,
        ),
);

AssessmentGradebook _pageBook(
  String id,
  String studentName, {
  AssessmentGradebookStatus status = AssessmentGradebookStatus.draft,
  AssessmentStudentState studentState = AssessmentStudentState.notStarted,
}) => AssessmentGradebook(
  id: id,
  version: 1,
  status: status,
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
    AssessmentStudentEntry(
      id: 'student-$id',
      childContextId: 'child-$id',
      name: studentName,
      state: studentState,
    ),
  ],
);

final class _PageAssessmentRepository implements AssessmentRepository {
  _PageAssessmentRepository.pending() : _immediate = null;
  _PageAssessmentRepository.immediate(this._immediate);

  final AssessmentGradebook? _immediate;
  final _loads = <String, Completer<AssessmentGradebook?>>{};
  final gradebookRequests = <String>[];
  final transitions = <String>[];
  Completer<AssessmentGradebook>? pendingTransition;

  @override
  Future<AssessmentGradebook> transitionGradebook(
    AssessmentGradebook book,
    AssessmentClosingAction action,
    String reason,
  ) async {
    transitions.add(book.id);
    return pendingTransition?.future ?? Future.value(book);
  }

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

final class _PendingClosingRepository implements AssessmentRepository {
  final result = Completer<List<AssessmentClosingItem>>();
  int requests = 0;
  @override
  Future<List<AssessmentClosingItem>> fetchClosingQueue() {
    requests++;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ClosingDecodingErrorRepository implements AssessmentRepository {
  const _ClosingDecodingErrorRepository();

  @override
  Future<List<AssessmentClosingItem>> fetchClosingQueue() async {
    final row = <String, Object?>{'items': 42};
    return row['items']! as List<AssessmentClosingItem>;
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
