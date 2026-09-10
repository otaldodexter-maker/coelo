import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envio de resposta de Circular quando o servidor recusa.
///
/// Antes desta correcao qualquer recusa virava "Nao foi possivel enviar. Tente
/// novamente." — inclusive conflito de versao e circular encerrada, em que
/// tentar de novo repete um envio que nunca vai passar. Agora cada recusa diz
/// o que aconteceu, e o conflito releitura o detalhe autorizado.
void main() {
  testWidgets('conflito de versao explica a atualizacao e releitura o detalhe', (tester) async {
    final repository = _ReaderRepository();
    await _pumpReader(tester, repository, _ResponseRepository(const CircularVersionConflict()));

    expect(repository.reads, 1);
    await _answerAndSubmit(tester);

    expect(find.textContaining('foi atualizada enquanto você respondia'), findsOneWidget);
    expect(find.textContaining('Tente novamente'), findsNothing);
    expect(repository.reads, 2, reason: 'o conflito precisa releiturar o detalhe autorizado');
  });

  testWidgets('conflito numa circular ja encerrada diz que fecharam, nao que responda de novo', (
    tester,
  ) async {
    final repository = _ReaderRepository()..closed = false;
    await _pumpReader(tester, repository, _ResponseRepository(const CircularVersionConflict()));
    repository.closed = true;

    await _answerAndSubmit(tester);

    expect(find.textContaining('foram encerradas enquanto você respondia'), findsOneWidget);
    expect(find.textContaining('responda novamente'), findsNothing);
  });

  testWidgets('circular encerrada diz que as respostas fecharam', (tester) async {
    final repository = _ReaderRepository();
    await _pumpReader(tester, repository, _ResponseRepository(const CircularNotAvailable()));

    await _answerAndSubmit(tester);

    expect(find.text('As respostas desta circular foram encerradas.'), findsOneWidget);
    expect(repository.reads, 1, reason: 'encerramento nao pede releitura');
  });

  testWidgets('o aviso do conflito e anunciado, nao so desenhado', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpReader(tester, _ReaderRepository(), _ResponseRepository(const CircularVersionConflict()));

    await _answerAndSubmit(tester);

    expect(
      tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.byKey(const Key('circular-response-conflict-notice')),
              matching: find.byType(Semantics),
            ),
          )
          .any((widget) => widget.properties.liveRegion ?? false),
      isTrue,
      reason: 'quem usa leitor de tela precisa ser avisado quando a recusa aparece',
    );
    handle.dispose();
  });

  testWidgets('indisponibilidade transitoria continua convidando a tentar de novo', (
    tester,
  ) async {
    final repository = _ReaderRepository();
    await _pumpReader(tester, repository, _ResponseRepository(const CircularUnavailable()));

    await _answerAndSubmit(tester);

    expect(find.text('Não foi possível enviar. Tente novamente.'), findsOneWidget);
  });
}

Future<void> _answerAndSubmit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('circular-option-question-1-yes')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('circular-submit-responses')));
  await tester.pumpAndSettle();
}

Future<void> _pumpReader(
  WidgetTester tester,
  _ReaderRepository repository,
  _ResponseRepository responses,
) async {
  await tester.binding.setSurfaceSize(const Size(1024, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalCircularDetailPage(
        circularId: 'circular-1',
        repository: repository,
        responseRepository: responses,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _ReaderRepository implements CircularRepository {
  var reads = 0;
  var closed = false;

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async {
    reads += 1;
    return CircularDetail(
      id: circularId,
      revisionId: 'revision-$reads',
      title: 'Renovacao de matricula 2027',
      authorName: 'Equipe Coelo',
      contextLabel: 'Turma Girassol',
      publishedAt: DateTime.utc(2026, 9, 1),
      blocks: const [
        CircularTextBlock(id: 'block-1', text: 'Confirme a renovacao ate 30 de setembro.'),
        CircularQuestionBlock(
          id: 'question-1',
          prompt: 'Confirma a renovacao?',
          kind: CircularQuestionKind.singleChoice,
          required: true,
          options: [
            CircularQuestionOption(id: 'yes', label: 'Sim'),
            CircularQuestionOption(id: 'no', label: 'Nao'),
          ],
        ),
      ],
      status: closed ? CircularStatus.closed : CircularStatus.published,
      responseState: CircularResponseState.unanswered,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ResponseRepository implements CircularResponseRepository {
  _ResponseRepository(this.failure);

  final CircularFailure failure;

  @override
  Future<CircularResponseSaveResult> saveDraft({
    required String requestId,
    required String revisionId,
    required String? childContextId,
    required Map<String, List<String>> answers,
    required int expectedVersion,
  }) => Future.error(failure);

  @override
  Future<CircularResponseSaveResult> submit({
    required String requestId,
    required String sessionId,
    required int expectedVersion,
  }) => Future.error(failure);
}
