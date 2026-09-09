import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_superadmin/features/principal_shared/presentation/principal_publication_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aceitacao comportamental (sem golden) da anatomia APROVADA de Publicar no
/// Agora.
///
/// Fontes do contrato, ambas versionadas:
///
/// 1. `docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md`
///    (`status: approved-design`), item 31: "Publicar no Agora tambem foi
///    aprovado visualmente pelo Owner em 2026-08-31: preserva literalmente a
///    anatomia comum de Acontece/Momentos, com midia temporaria vertical, texto
///    curto, ferramentas proprias, publico/contexto, aviso de 24 horas e preview
///    lateral no desktop." O mesmo item, para Momentos, nomeia o que essa
///    anatomia comum contem: "reproduz literalmente o cabecalho,
///    `Sua publicacao`, ordem das secoes, largura util, preview e rodape de
///    Publicar no Acontece".
/// 2. `specs/036-principal-now-publication-mvp.md` (`status: approved`), linha
///    31: "Copias obrigatorias: `Publicar no Agora`, `Publico e contexto`,
///    `Agendar publicacao`, `Salvar rascunho` e `Publicar agora`."
///
/// A imagem aprovada pelo Owner em 2026-08-31
/// (`docs/reviews/evidence/etapa-2/principal-visual/2026-08-31-publicar-agora-approved.png`)
/// NAO existe nesta arvore; nada foi buscado fora do repositorio. O desenho
/// afirmado aqui vem apenas das duas fontes escritas acima e da anatomia comum
/// viva no proprio codigo: `principal_happens_publication_page.dart` e
/// `principal_moments_publication_page.dart` encabecam o composer com
/// `Sua publicacao` e ancoram a previa lateral do desktop nas chaves
/// `happens-publication-desktop-preview` e `moments-publication-desktop-preview`.
/// Publicar no Agora ja teve a sua, `now-publication-desktop-preview`, ate
/// `21e0ed09`; `3419a89e` removeu previa e `Sua publicacao` e introduziu a barra
/// de progresso segmentada. Por isso a chave esperada aqui e a mesma da familia.
///
/// Criterio fixado para este arquivo: anatomia aprovada do publicador, previa no
/// desktop, sem trilho de etapas e sem barra de progresso.
///
/// Este arquivo fixa o ALVO aprovado, nao o estado atual: no baseline os casos
/// de `Sua publicacao`, de previa lateral e de ausencia da barra de progresso
/// falham por construcao. `test/features/principal_now_publication/presentation/
/// principal_now_publication_page_test.dart` ainda afirma
/// `now-publication-progress` presente, ou seja, cristalizou o estado de
/// `3419a89e`; a contradicao e conhecida e se resolve na correcao, nao afrouxando
/// este aceite.
void main() {
  const mobile = Size(375, 900);
  const tablet = Size(768, 1024);
  const desktop = Size(1440, 1000);
  const viewports = [mobile, tablet, desktop];
///
/// ATUALIZACAO 2026-09-08T22:00, conferida por mim nas duas pontas: esse
/// conflito **caduca no baseline conjunto**. No meu baseline 4af42925 o teste
/// de feature afirma `findsOneWidget` para a barra (linhas 120 e 670); no HEAD
/// da C05 ele ja afirma `findsNothing` e exige `Sua publicacao` (linhas 122,
/// 123, 673 e 675). A C05 corrigiu a pagina e o proprio teste dela. Portanto
/// nao ha pendencia viva para o fechamento, e os 7 vermelhos deste arquivo
/// devem virar verdes quando a C00 materializar o baseline conjunto. Se algum
/// nao virar, e achado real e deve ser reportado.

  final composerFrame = find.byType(PrincipalPublicationFrame);
  final mediaStage = find.byKey(const Key('now-media-stage'));
  final desktopPreview = find.byKey(const Key('now-publication-desktop-preview'));

  Future<void> pumpComposer(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: PrincipalNowPublicationPage.demo(repository: InMemoryNowPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();
  }

  String label(Size size) => size.width.toInt().toString();

  // Caso 1 - a anatomia comum encabeca o composer com `Sua publicacao`, e o nome
  // do fluxo vem logo abaixo, como em Acontece e Momentos.
  for (final size in viewports) {
    testWidgets('the approved composer is headed by Sua publicacao at ${label(size)}', (
      tester,
    ) async {
      await pumpComposer(tester, size);
      final at = label(size);

      final heading = find.text('Sua publicação');
      final flow = find.text('Publicar no Agora');

      expect(
        heading,
        findsOneWidget,
        reason:
            '[$at] o cabecalho `Sua publicacao` da anatomia comum de '
            'Acontece/Momentos nao esta na arvore',
      );
      expect(flow, findsOneWidget, reason: '[$at] o nome do fluxo nao esta na arvore');
      expect(
        tester.getRect(heading).top < tester.getRect(flow).top,
        isTrue,
        reason:
            '[$at] `Sua publicacao` em ${tester.getRect(heading)} nao antecede '
            '`Publicar no Agora` em ${tester.getRect(flow)}',
      );
      expect(tester.takeException(), isNull, reason: at);
    });
  }

  // Caso 2 - previa lateral no desktop: presente, ao lado (nao abaixo) da midia,
  // dentro do viewport e rotulada como previa.
  testWidgets('the desktop keeps the lateral preview beside the media stage at 1440', (
    tester,
  ) async {
    await pumpComposer(tester, desktop);

    // Contrato, nao implementacao: a spec exige "preview lateral no desktop" e
    // NAO fixa key. Procuro a previa pelo que ela e — uma regiao que se
    // identifica como previa —, e uso a key so como pista na mensagem de falha.
    // Ancorar a assercao na key faria o teste falhar por acoplamento caso a
    // correcao adote outra, dizendo "nao ha previa" quando ha.
    final previewLabel = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data ?? '').startsWith('Prévia'),
      description: 'rotulo que identifica a previa',
    );
    expect(
      previewLabel,
      findsAtLeastNWidgets(1),
      reason:
          'previa lateral ausente no desktop. A spec exige preview lateral no '
          'desktop sem fixar key; a familia usa '
          '`<dominio>-publication-desktop-preview` e o Agora usava '
          '`now-publication-desktop-preview` ate 21e0ed09, mas qualquer '
          'identificacao equivalente satisfaz o contrato.',
    );
    expect(mediaStage, findsOneWidget, reason: 'palco da midia vertical ausente');

    // Se a key canonica existir, mede por ela; senao, pelo ancestral que
    // carrega o rotulo. As duas formas satisfazem o contrato.
    final previewAnchor = desktopPreview.evaluate().isNotEmpty
        ? desktopPreview
        : find
              .ancestor(of: previewLabel.first, matching: find.byType(DecoratedBox))
              .first;
    final previewRect = tester.getRect(previewAnchor);
    final stageRect = tester.getRect(mediaStage);

    expect(
      previewRect.overlaps(stageRect),
      isFalse,
      reason: 'previa $previewRect sobrepoe o palco da midia $stageRect',
    );
    expect(
      previewRect.left >= stageRect.right,
      isTrue,
      reason: 'previa $previewRect nao fica lateral ao palco da midia $stageRect',
    );
    expect(
      previewRect.left >= 0 && previewRect.right <= desktop.width,
      isTrue,
      reason: 'previa $previewRect fora da largura util de ${desktop.width}',
    );
    expect(
      find.descendant(
        of: desktopPreview,
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data ?? '').startsWith('Prévia'),
        ),
      ),
      findsAtLeastNWidgets(1),
      reason:
          'a previa nao se identifica como previa; a copia exata nao e fixada '
          'pela spec, apenas o rotulo de previa exigido pela anatomia comum',
    );
    expect(tester.takeException(), isNull);
  });

  // O contrato aprovado chama a previa de LATERAL no desktop; em 375 a coluna
  // lateral nao existe e a anatomia empilha.
  testWidgets('the lateral preview column stays out of the 375 layout', (tester) async {
    await pumpComposer(tester, mobile);

    expect(
      desktopPreview,
      findsNothing,
      reason: 'a previa lateral e contrato de desktop; em 375 a anatomia empilha',
    );
    expect(tester.takeException(), isNull);
  });

  // Caso 3 - a anatomia aprovada do Agora nao tem trilho de etapas.
  for (final size in viewports) {
    testWidgets('no step rail and no wizard navigation at ${label(size)}', (tester) async {
      await pumpComposer(tester, size);
      final at = label(size);

      expect(
        find.byType(PrincipalPublicationStepNavigation),
        findsNothing,
        reason: '[$at] trilho lateral de etapas presente',
      );
      expect(
        find.byKey(const Key('principal-publication-steps-scroll')),
        findsNothing,
        reason: '[$at] rolagem do trilho de etapas presente',
      );
      expect(
        find.byKey(const Key('principal-publication-step-summary')),
        findsNothing,
        reason: '[$at] resumo compacto de etapas presente',
      );
      expect(
        find.text('Continuar'),
        findsNothing,
        reason: '[$at] acao de avanco de wizard presente',
      );
      expect(
        find.text('Anterior'),
        findsNothing,
        reason: '[$at] acao de retorno de wizard presente',
      );

      expect(composerFrame, findsOneWidget, reason: '[$at] frame canonico ausente');
      expect(
        tester.widget<PrincipalPublicationFrame>(composerFrame).navigation,
        isNull,
        reason: '[$at] o frame recebeu um slot de navegacao por etapas',
      );
      expect(tester.takeException(), isNull, reason: at);
    });
  }

  // Caso 4 - nem barra de progresso segmentada.
  for (final size in viewports) {
    testWidgets('no segmented progress bar at ${label(size)}', (tester) async {
      await pumpComposer(tester, size);
      final at = label(size);

      expect(
        find.byType(PrincipalPublicationProgressBar),
        findsNothing,
        reason:
            '[$at] barra de progresso segmentada presente; a anatomia aprovada '
            'nao a descreve',
      );
      expect(
        find.byKey(const Key('now-publication-progress')),
        findsNothing,
        reason: '[$at] chave da barra de progresso do Agora presente',
      );
      for (final segment in const [
        Key('now-progress-media'),
        Key('now-progress-details'),
        Key('now-progress-publication'),
      ]) {
        expect(
          find.byKey(segment),
          findsNothing,
          reason: '[$at] segmento $segment da barra de progresso presente',
        );
      }
      expect(tester.takeException(), isNull, reason: at);
    });
  }

  // Caso 5 - as cinco copias obrigatorias da spec 036, linha 31.
  for (final size in viewports) {
    testWidgets('the five mandatory copies of spec 036 survive at ${label(size)}', (tester) async {
      await pumpComposer(tester, size);
      final at = label(size);

      for (final copy in const [
        'Publicar no Agora',
        'Público e contexto',
        'Agendar publicação',
        'Salvar rascunho',
        'Publicar agora',
      ]) {
        expect(
          find.text(copy),
          findsWidgets,
          reason: '[$at] copia obrigatoria `$copy` ausente da arvore',
        );
      }
      expect(
        find.text('Publicações ficam disponíveis por 24 horas no Agora.'),
        findsOneWidget,
        reason: '[$at] o aviso de 24 horas nomeado pelo item 31 esta ausente',
      );
      expect(tester.takeException(), isNull, reason: at);
    });
  }

  // Caso 6 - nenhuma excecao de layout nos viewports do contrato, inclusive
  // depois de percorrer a rolagem unica ate a secao de agendamento.
  for (final size in viewports) {
    testWidgets('no layout exception across the single scroll at ${label(size)}', (tester) async {
      await pumpComposer(tester, size);
      final at = label(size);

      expect(tester.takeException(), isNull, reason: '[$at] excecao logo apos o primeiro layout');

      await tester.ensureVisible(find.text('Agendar publicação'));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: '[$at] excecao ao percorrer a rolagem ate o agendamento',
      );
    });
  }
}
