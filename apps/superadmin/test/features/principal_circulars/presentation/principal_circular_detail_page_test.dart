import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  _Repository({this.unauthorized = false, this.notAvailable = false});
  final bool unauthorized;
  final bool notAvailable;

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async {
    if (unauthorized) throw const CircularUnauthorized();
    if (notAvailable) throw const CircularNotAvailable();
    expect(childContextId, 'child-1');
    return CircularDetail(
      id: 'circular-1',
      revisionId: 'revision-1',
      title: 'Renovação',
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
    return const CircularResponseSaveResult(
      sessionId: 'session-1',
      version: 6,
      state: CircularResponseState.answered,
    );
  }
}
