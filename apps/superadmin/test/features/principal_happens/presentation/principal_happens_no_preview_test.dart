// Acontece: nao existe previa (decisao D3 do Owner, 10/09/2026).
//
// A tela avisava "estara disponivel na experiencia completa" e "indisponivel
// nesta previa" quando o host nao passava um destino. O Owner respondeu que as
// telas do Principal sao o produto: cada acao liga ponta a ponta e nenhuma
// mensagem de previa permanece.
//
// A regra que substitui o aviso: acao sem destino real fica visivel e inerte.
// Na rota real o composition root fornece os destinos, entao um controle
// desabilitado denuncia composicao incompleta, que e o que precisa aparecer
// para quem monta a tela.
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpFeed(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage(
          feedRepository: _SinglePostRepository(),
          feedScope: const PrincipalHappensFeedScope(institutionId: 'institution-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nenhuma acao do feed anuncia previa ou experiencia completa', (tester) async {
    await pumpFeed(tester);

    // Toca em tudo que antes abria o aviso: comentar, compartilhar e o menu da
    // publicacao sem autorizacao de retirada.
    for (final tooltip in ['Comentar', 'Compartilhar', 'Mais opções da publicação']) {
      final control = find.byTooltip(tooltip);
      if (control.evaluate().isEmpty) continue;
      await tester.tap(control, warnIfMissed: false);
      await tester.pump();
    }

    expect(find.textContaining('prévia'), findsNothing);
    expect(find.textContaining('experiência completa'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('acao sem destino fica inerte, e nao anunciada', (tester) async {
    await pumpFeed(tester);

    // Comentar e compartilhar nao existem no servidor: nenhuma migration cria
    // tabela de comentario ou de compartilhamento. O controle existe e esta
    // desabilitado.
    final comment = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .firstWhere((button) => button.tooltip == 'Comentar');
    expect(comment.onPressed, isNull);

    final share = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .firstWhere((button) => button.tooltip == 'Compartilhar');
    expect(share.onPressed, isNull);
  });
}

final class _SinglePostRepository implements PrincipalHappensFeedRepository {
  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(
    PrincipalHappensFeedScope scope,
  ) async => [
    PrincipalPostPreviewItem(
      author: 'Equipe',
      context: 'Contexto',
      time: 'Agora',
      initials: 'EQ',
      body: 'Registro unico',
      postId: 'post-0',
      publishedAt: DateTime.utc(2026, 9, 10, 12),
    ),
  ];

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async =>
      throw const PrincipalHappensFeedUnavailable();
}
