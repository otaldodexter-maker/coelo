import 'dart:async';

import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final changeChild in [false, true]) {
    testWidgets('reloads on isolated ${changeChild ? 'child context' : 'circular ID'} change', (
      tester,
    ) async {
      final repository = _Repository(checkChild: false);
      final responses = _ResponseRepository();
      Widget page({String circularId = 'circular-1', String child = 'child-1'}) => MaterialApp(
        home: PrincipalCircularDetailPage(
          circularId: circularId,
          childContextId: child,
          repository: repository,
          responseRepository: responses,
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        changeChild ? page(child: 'child-2') : page(circularId: 'circular-2'),
      );
      await tester.pumpAndSettle();
      expect(repository.reads, [
        ('circular-1', 'child-1'),
        (changeChild ? 'circular-1' : 'circular-2', changeChild ? 'child-2' : 'child-1'),
      ]);
    });
  }

  testWidgets('late read denial cannot hide the newly authorized detail', (tester) async {
    final pending = Completer<CircularDetail>();
    final responses = _ResponseRepository();
    Widget page(_Repository repository) => MaterialApp(
      home: PrincipalCircularDetailPage(
        circularId: 'circular-1',
        childContextId: 'child-1',
        repository: repository,
        responseRepository: responses,
      ),
    );
    await tester.pumpWidget(page(_Repository(pendingLoad: pending)));
    await tester.pumpWidget(page(_Repository(title: 'Circular B')));
    await tester.pump();
    pending.completeError(const CircularUnauthorized());
    await tester.pumpAndSettle();
    expect(find.text('Circular B'), findsOneWidget);
    expect(find.text('Você não tem acesso a esta Circular.'), findsNothing);
  });

  testWidgets('late submit cannot change the new response version', (tester) async {
    final pending = Completer<CircularResponseSaveResult>();
    final first = _ResponseRepository(pendingSubmit: pending);
    final second = _ResponseRepository();
    final repository = _Repository();
    Widget page(_ResponseRepository responses) => MaterialApp(
      home: PrincipalCircularDetailPage(
        circularId: 'circular-1',
        childContextId: 'child-1',
        repository: repository,
        responseRepository: responses,
      ),
    );
    await tester.pumpWidget(page(first));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('circular-submit-responses')));
    await tester.pump();
    expect(first.submittedExpectedVersion, 5);
    await tester.pumpWidget(page(second));
    await tester.pump();
    pending.complete(
      const CircularResponseSaveResult(
        sessionId: 'session-1',
        version: 99,
        state: CircularResponseState.answered,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Respostas enviadas'), findsNothing);
    await tester.tap(find.byKey(const Key('circular-submit-responses')));
    await tester.pumpAndSettle();
    expect(second.savedExpectedVersion, 4);
  });

  for (final dispose in [false, true]) {
    testWidgets(
      'pending response does not submit after ${dispose ? 'dispose' : 'repository swap'}',
      (tester) async {
        final pending = Completer<CircularResponseSaveResult>();
        final first = _ResponseRepository(pendingSave: pending);
        final second = _ResponseRepository();
        final repository = _Repository();
        Widget page(_ResponseRepository responses) => MaterialApp(
          home: PrincipalCircularDetailPage(
            circularId: 'circular-1',
            childContextId: 'child-1',
            repository: repository,
            responseRepository: responses,
          ),
        );
        await tester.pumpWidget(page(first));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('circular-submit-responses')));
        await tester.pump();
        await tester.pumpWidget(dispose ? const SizedBox() : page(second));
        await tester.pump();
        pending.complete(
          const CircularResponseSaveResult(
            sessionId: 'session-1',
            version: 5,
            state: CircularResponseState.partial,
          ),
        );
        await tester.pumpAndSettle();
        expect(first.submittedExpectedVersion, isNull);
        expect(second.submittedExpectedVersion, isNull);
        expect(find.text('Respostas enviadas'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('late detail cannot replace the newly selected context', (tester) async {
    final firstLoad = Completer<CircularDetail>();
    final first = _Repository(pendingLoad: firstLoad);
    final second = _Repository(title: 'Circular B');
    final responses = _ResponseRepository();
    Widget page(_Repository repository) => MaterialApp(
      home: PrincipalCircularDetailPage(
        circularId: 'circular-1',
        childContextId: 'child-1',
        repository: repository,
        responseRepository: responses,
      ),
    );
    await tester.pumpWidget(page(first));
    await tester.pumpWidget(page(second));
    await tester.pump();
    expect(find.text('Circular B'), findsOneWidget);
    firstLoad.complete(await _Repository().getVisible('circular-1', childContextId: 'child-1'));
    await tester.pumpAndSettle();
    expect(find.text('Circular B'), findsOneWidget);
    expect(find.text('Renovação'), findsNothing);
  });

  testWidgets('compact reader uses only the contextual Circular return', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalCircularDetailPage(
          circularId: 'circular-1',
          childContextId: 'child-1',
          repository: _Repository(),
          responseRepository: _ResponseRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-circular-contextual-return')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Circular'), findsOneWidget);
  });

  testWidgets('loads and updates the current versioned response', (tester) async {
    final responses = _ResponseRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalCircularDetailPage(
          circularId: 'circular-1',
          childContextId: 'child-1',
          repository: _Repository(),
          responseRepository: responses,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selected = tester.widget<Icon>(find.byIcon(Icons.radio_button_checked_rounded));
    expect(selected.color, isNotNull);
    await tester.tap(find.byKey(const Key('circular-submit-responses')));
    await tester.pumpAndSettle();

    expect(responses.savedExpectedVersion, 4);
    expect(responses.submittedExpectedVersion, 5);
    expect(responses.answers['question-1'], ['yes']);
    expect(find.text('Respostas enviadas'), findsOneWidget);
  });

  testWidgets('keeps unauthorized distinct from unavailable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalCircularDetailPage(
          circularId: 'foreign-circular',
          repository: _Repository(unauthorized: true),
          responseRepository: _ResponseRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Você não tem acesso a esta Circular.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('shows a distinct not-yet-available state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalCircularDetailPage(
          circularId: 'scheduled-circular',
          repository: _Repository(notAvailable: true),
          responseRepository: _ResponseRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Esta Circular ainda não está disponível.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });
}

final class _Repository implements CircularRepository {
  _Repository({
    this.unauthorized = false,
    this.notAvailable = false,
    this.pendingLoad,
    this.title = 'Renovação',
    this.checkChild = true,
  });
  final bool unauthorized;
  final bool notAvailable;
  final Completer<CircularDetail>? pendingLoad;
  final String title;
  final bool checkChild;
  final reads = <(String, String?)>[];

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async {
    reads.add((circularId, childContextId));
    if (pendingLoad case final pending?) return pending.future;
    if (unauthorized) throw const CircularUnauthorized();
    if (notAvailable) throw const CircularNotAvailable();
    if (checkChild) expect(childContextId, 'child-1');
    return CircularDetail(
      id: 'circular-1',
      revisionId: 'revision-1',
      title: title,
      authorName: 'Colégio Coelo',
      contextLabel: 'Turma A',
      publishedAt: DateTime.utc(2026, 8, 21),
      status: CircularStatus.published,
      responseState: CircularResponseState.partial,
      responseSessionId: 'session-1',
      responseVersion: 4,
      initialAnswers: const {
        'question-1': ['yes'],
      },
      blocks: const [
        CircularQuestionBlock(
          id: 'question-1',
          prompt: 'A matrícula será renovada?',
          kind: CircularQuestionKind.singleChoice,
          required: true,
          options: [
            CircularQuestionOption(id: 'yes', label: 'Sim'),
            CircularQuestionOption(id: 'no', label: 'Não'),
          ],
        ),
      ],
    );
  }

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();
  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}

final class _ResponseRepository implements CircularResponseRepository {
  _ResponseRepository({this.pendingSave, this.pendingSubmit});
  final Completer<CircularResponseSaveResult>? pendingSave;
  final Completer<CircularResponseSaveResult>? pendingSubmit;
  int? savedExpectedVersion;
  int? submittedExpectedVersion;
  Map<String, List<String>> answers = const {};

  @override
  Future<CircularResponseSaveResult> saveDraft({
    required String requestId,
    required String revisionId,
    required String? childContextId,
    required Map<String, List<String>> answers,
    required int expectedVersion,
  }) async {
    savedExpectedVersion = expectedVersion;
    this.answers = answers;
    if (pendingSave case final pending?) return pending.future;
    return const CircularResponseSaveResult(
      sessionId: 'session-1',
      version: 5,
      state: CircularResponseState.partial,
    );
  }

  @override
  Future<CircularResponseSaveResult> submit({
    required String requestId,
    required String sessionId,
    required int expectedVersion,
  }) async {
    submittedExpectedVersion = expectedVersion;
    if (pendingSubmit case final pending?) return pending.future;
    return const CircularResponseSaveResult(
      sessionId: 'session-1',
      version: 6,
      state: CircularResponseState.answered,
    );
  }
}
