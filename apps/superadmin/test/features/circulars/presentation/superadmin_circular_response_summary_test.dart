import 'package:coelo_superadmin/features/circulars/domain/superadmin_circular_repository.dart';
import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_detail_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resumo de respostas no leitor administrativo de Circular.
///
/// O aceite da acao declara conteudo, contexto E resumo de respostas.
/// superadmin_circular_response_summary_v2 existia no gateway, o repositorio
/// tinha o metodo e havia teste de dados — mas NENHUMA tela chamava, entao o
/// resumo nunca aparecia. O leitor tambem recebia o repositorio pelo tipo mais
/// estreito, o que impedia a chamada mesmo com a instancia certa injetada.
void main() {
  Future<void> pump(WidgetTester tester, {SuperadminCircularRepository? source}) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SuperadminCircularDetailPage(
            circularId: 'circular-1',
            repository: _DetailRepository(),
            responseSummarySource: source,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sem fonte de resumo o leitor nao inventa numero nenhum', (tester) async {
    await pump(tester);

    expect(find.text('Renovacao de matricula 2027'), findsOneWidget);
    expect(find.byKey(const Key('circular-detail-response-summary')), findsNothing);
  });

  testWidgets('com fonte o leitor mostra enviadas, parciais e total', (tester) async {
    await pump(
      tester,
      source: _SummaryRepository(
        const SuperadminCircularResponseSummary(
          responseCount: 12,
          submittedCount: 7,
          partialCount: 5,
          closed: false,
        ),
      ),
    );

    expect(
      find.text('7 enviadas · 5 parciais · 12 no total'),
      findsOneWidget,
    );
  });

  testWidgets('encerrada diz que as respostas fecharam', (tester) async {
    await pump(
      tester,
      source: _SummaryRepository(
        const SuperadminCircularResponseSummary(
          responseCount: 3,
          submittedCount: 3,
          partialCount: 0,
          closed: true,
        ),
      ),
    );

    expect(find.textContaining('Respostas encerradas'), findsOneWidget);
  });

  testWidgets('falha no resumo nao derruba a leitura da Circular', (tester) async {
    await pump(tester, source: _FailingSummaryRepository());

    expect(find.text('Renovacao de matricula 2027'), findsOneWidget);
    expect(find.byKey(const Key('circular-detail-response-summary')), findsNothing);
    expect(find.text('Nao foi possivel carregar'), findsNothing);
  });
}

final class _DetailRepository implements CircularRepository {
  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async =>
      CircularDetail(
        id: circularId,
        revisionId: 'revision-1',
        title: 'Renovacao de matricula 2027',
        authorName: 'Equipe Coelo',
        contextLabel: 'Colegio Horizonte',
        publishedAt: DateTime.utc(2026, 9, 1),
        blocks: const [CircularTextBlock(id: 'block-1', text: 'Confirme ate 30 de setembro.')],
        status: CircularStatus.published,
        responseState: CircularResponseState.unanswered,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SummaryRepository implements SuperadminCircularRepository {
  _SummaryRepository(this.summary);

  final SuperadminCircularResponseSummary summary;

  @override
  Future<SuperadminCircularResponseSummary> fetchResponseSummary(String circularId) async =>
      summary;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FailingSummaryRepository implements SuperadminCircularRepository {
  @override
  Future<SuperadminCircularResponseSummary> fetchResponseSummary(String circularId) =>
      Future.error(const CircularUnavailable());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
