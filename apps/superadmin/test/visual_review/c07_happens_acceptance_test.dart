import 'dart:math' as math;
import 'dart:ui' show Canvas, PointerDeviceKind;

import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aceitacao comportamental (sem golden) da entrada `Publicar agora`.
///
/// Contrato literal, `specs/050-principal-ui-ux-closure.md`, secao "Entrada
/// Publicar agora":
///
/// > "contorno tracejado arredondado, acao circular central, icone vetorial e
/// > rotulo curto. O estado normal usa superficie neutra e icone laranja;
/// > hover, foco e pressionado reforcam borda e acao em laranja sem depender
/// > somente de cor."
///
/// Por que este arquivo existe: o golden `principal_happens_now_hover_light_1440`
/// prova quase nada. Ele passa com 79 px de diferenca entre hover e repouso e
/// delta maximo de 32/255, concentrados em antialiasing, porque o `ClipRRect`
/// do cartao de Agora cobre a borda do `TextButton`. Aqui cada estado e medido
/// por propriedade observavel — cor efetivamente desenhada, preenchimento
/// resolvido, geometria renderizada — e toda mudanca precisa superar o teto de
/// antialiasing de 32/255 para contar como mudanca de estado.
///
/// Ja coberto em `test/features/principal_happens/presentation/` e NAO repetido
/// aqui: presenca das chaves `principal-happens-publish-now-card`,
/// `-dashed-border` e `-action`; cor da acao igual a `primary` depois do hover;
/// cor da acao igual a `primary` com `WidgetState.pressed` injetado a mao no
/// `statesController`; semantica de botao habilitado; disparo de `onPublishNow`
/// no toque; e a borda do cartao vizinho de Agora (`_NowCard`, outro widget).
///
/// Lacunas cobertas por este arquivo: a linha de base de repouso (contorno em
/// `outlineVariant`, superficie neutra, icone laranja) que ninguem media; a cor
/// realmente desenhada pelo contorno tracejado, medida no `drawPath` do painter
/// e nao inferida da existencia do `CustomPaint`; o reforco da BORDA alem da
/// acao, exigido pela spec; o foco sozinho, sem mouse, produzindo o mesmo
/// reforco; o pressionado por gesto real em vez de estado injetado; a guarda de
/// antialiasing; e a verificacao do segundo sinal alem de cor.
void main() {
  const cardKey = Key('principal-happens-publish-now-card');
  const borderKey = Key('principal-happens-publish-now-dashed-border');
  const actionKey = Key('principal-happens-publish-now-action');

  /// Teto de antialiasing. O golden fraco muda no maximo 32/255 por canal entre
  /// repouso e hover; uma mudanca de estado real precisa superar esse teto.
  const antialiasCeiling = 32;

  /// Espessura declarada no `_DashedRoundedBorderPainter`. E ancora de medicao,
  /// nao contrato: o contrato e "reforcam borda ... sem depender somente de cor".
  const dashStrokeWidth = 1.5;

  final card = find.byKey(cardKey);
  final border = find.byKey(borderKey);
  final action = find.byKey(actionKey);
  final button = find.descendant(of: card, matching: find.byType(TextButton));
  final actionIcon = find.descendant(of: action, matching: find.byType(Icon));
  final cardLabel = find.descendant(of: border, matching: find.text('Publicar\nagora'));

  final themes = [(name: 'claro', data: CoeloTheme.light), (name: 'escuro', data: CoeloTheme.dark)];

  Future<void> pumpHappens(
    WidgetTester tester, {
    required ThemeData theme,
    Size size = const Size(1440, 1000),
    VoidCallback? onPublishNow,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: PrincipalHappensPreviewPage.demo(onPublishNow: onPublishNow),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Delta maximo por canal, em 0-255, entre duas cores.
  int maxChannelDelta(Color a, Color b) => <int>[
    ((a.r - b.r).abs() * 255).round(),
    ((a.g - b.g).abs() * 255).round(),
    ((a.b - b.b).abs() * 255).round(),
    ((a.a - b.a).abs() * 255).round(),
  ].reduce(math.max);

  /// Falha quando a diferenca entre dois valores medidos cabe dentro do teto de
  /// antialiasing, isto e, quando o "estado" nao mudou nada perceptivel.
  void expectPerceptible(String signal, String label, Color rest, Color active) {
    final delta = maxChannelDelta(rest, active);
    expect(
      delta > antialiasCeiling,
      isTrue,
      reason:
          '[$label] $signal foi de $rest para $active; delta maximo $delta/255 '
          'nao supera o teto de antialiasing $antialiasCeiling/255 medido no '
          'golden principal_happens_now_hover_light_1440',
    );
  }

  /// Executa o painter do contorno num canvas gravado.
  ///
  /// `_DashedRoundedBorderPainter` e privado, entao a cor nao vem de reflexao
  /// nem de pixel: o `drawPath` real e gravado e comparado. A ancora de medicao
  /// e a chave `principal-happens-publish-now-dashed-border`; o que se afirma e
  /// a cor efetivamente desenhada.
  void Function(Canvas) dashedBorderPainting(WidgetTester tester, String label) {
    final painter = tester.widget<CustomPaint>(border).painter;
    expect(painter, isNotNull, reason: '[$label] CustomPaint em $borderKey sem painter');
    final size = tester.getSize(border);
    void paintOnce(Canvas canvas) => painter!.paint(canvas, size);
    return paintOnce;
  }

  /// Afirma a cor efetivamente tracada pelo contorno. Em caso de falha o
  /// matcher `paints` imprime a display list real, com a cor medida.
  void expectDashedBorder(WidgetTester tester, Color expected, String label) {
    expect(
      dashedBorderPainting(tester, label),
      paints..path(color: expected, strokeWidth: dashStrokeWidth, style: PaintingStyle.stroke),
      reason:
          '[$label] o contorno tracejado nao desenha $expected em '
          '$dashStrokeWidth px; a display list real vem na descricao acima',
    );
  }

  /// Espessura efetiva do traco, descoberta casando candidatas contra o
  /// `drawPath` gravado. `null` significa nenhuma candidata casada.
  double? dashedBorderStroke(WidgetTester tester, String label) {
    final painting = dashedBorderPainting(tester, label);
    for (final width in const <double>[0.5, 1, 1.5, 2, 2.5, 3, 4, 6]) {
      final matcher = (paints..path(strokeWidth: width, style: PaintingStyle.stroke)) as Matcher;
      if (matcher.matches(painting, <dynamic, dynamic>{})) {
        return width;
      }
    }
    return null;
  }

  /// Preenchimento resolvido da acao circular central.
  Color actionFill(WidgetTester tester, String label) {
    final decoration = tester.widget<DecoratedBox>(action).decoration;
    expect(decoration, isA<BoxDecoration>(), reason: '[$label] acao sem BoxDecoration');
    final color = (decoration as BoxDecoration).color;
    expect(color, isNotNull, reason: '[$label] acao sem cor de preenchimento');
    return color!;
  }

  /// Cor resolvida do icone vetorial da acao.
  Color actionIconColor(WidgetTester tester, String label) {
    final color = tester.widget<Icon>(actionIcon).color;
    expect(color, isNotNull, reason: '[$label] icone da acao sem cor explicita');
    return color!;
  }

  /// Estados do cartao, sempre como copia.
  ///
  /// `WidgetStatesController.update` faz `value.add(state)` / `value.remove(state)`
  /// e nunca troca o `Set`. Devolver `statesController.value` cru entregaria uma
  /// referencia viva: guardar os estados durante o toque e soltar o gesto depois
  /// esvaziaria o conjunto ja capturado antes de a assercao rodar, acusando o
  /// produto por um efeito do proprio teste.
  Set<WidgetState> cardStates(WidgetTester tester) => <WidgetState>{
    ...?tester.widget<TextButton>(button).statesController?.value,
  };

  FocusNode cardFocusNode(WidgetTester tester) {
    final node = tester.widget<TextButton>(button).focusNode;
    expect(node, isNotNull, reason: 'TextButton do cartao sem focusNode; foco nao e alcancavel');
    return node!;
  }

  /// Foca sem mouse e deixa a arvore efetivamente reconstruida.
  ///
  /// `FocusNode.requestFocus` apenas agenda o microtask `_applyFocusChange`; nao
  /// agenda frame. `AutomatedTestWidgetsFlutterBinding.pump` constroi frame so
  /// dentro de `if (hasScheduledFrame)` e flusha os microtasks restantes DEPOIS
  /// desse bloco. Com a arvore ja assentada nao ha frame pendente, entao o
  /// primeiro `pump` so aplica o foco e agenda o frame que o `setState` do cartao
  /// pediu. Um unico `pump` deixaria o `statesController` com `focused` e a
  /// arvore ainda em repouso, e a medicao do painter leria a cor de repouso.
  Future<FocusNode> focusCard(WidgetTester tester) async {
    final node = cardFocusNode(tester);
    node.requestFocus();
    await tester.pump();
    await tester.pumpAndSettle();
    return node;
  }

  Future<void> hoverCard(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump();
  }

  /// Pressiona de verdade e deixa a arvore reconstruida.
  ///
  /// O cartao vive num `ListView` horizontal, entao o reconhecedor de toque
  /// divide a arena com o de arrasto e nao vence enquanto o dedo esta parado.
  /// Nao precisa vencer: `BaseTapGestureRecognizer` nasce com
  /// `deadline: kPressTimeout` (100 ms) e `didExceedDeadline` chama `_checkDown`,
  /// que emite `onTapDown` sozinho; o `InkResponse` responde com
  /// `statesController.update(WidgetState.pressed, true)`. Os 200 ms cobrem esse
  /// prazo, e como o `elapse` do `pump` acontece antes do frame o `setState`
  /// resultante ja e construido no mesmo `pump`.
  Future<TestGesture> pressCard(WidgetTester tester) async {
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 200));
    return gesture;
  }

  /// Sinais visuais que NAO sao cor. Geometria renderizada, glifo do icone e
  /// tipografia do rotulo. A flag semantica de foco fica fora de proposito: ela
  /// nao e sinal visual e nao atende "sem depender somente de cor" para quem
  /// enxerga a tela.
  Map<String, Object?> nonColorSignals(WidgetTester tester, String label) => <String, Object?>{
    'espessura do contorno': dashedBorderStroke(tester, label),
    'tamanho do cartao': tester.getSize(card),
    'tamanho da acao circular': tester.getSize(action),
    'tamanho do icone': tester.getSize(actionIcon),
    'glifo do icone': tester.widget<Icon>(actionIcon).icon,
    'tamanho do rotulo': tester.getSize(cardLabel),
    'peso do rotulo': tester.widget<Text>(cardLabel).style?.fontWeight,
    'corpo do rotulo': tester.widget<Text>(cardLabel).style?.fontSize,
  };

  for (final theme in themes) {
    final colors = theme.data.colorScheme;

    testWidgets('repouso mantem contorno tracejado, superficie neutra e icone '
        'laranja no tema ${theme.name}', (tester) async {
      await pumpHappens(tester, theme: theme.data);
      final label = 'repouso ${theme.name}';

      expect(card, findsOneWidget, reason: '[$label] cartao Publicar agora ausente');
      expect(cardStates(tester), isEmpty, reason: '[$label] estado sujo: ${cardStates(tester)}');

      expectDashedBorder(tester, colors.outlineVariant, label);
      expect(
        actionFill(tester, label),
        colors.surface,
        reason:
            '[$label] a acao central deveria usar superficie neutra '
            '(${colors.surface}) e usa ${actionFill(tester, label)}',
      );
      expect(
        actionIconColor(tester, label),
        colors.primary,
        reason:
            '[$label] o icone deveria ser laranja (${colors.primary}) e e '
            '${actionIconColor(tester, label)}',
      );
      expect(
        tester.widget<Icon>(actionIcon).icon,
        Icons.add_rounded,
        reason: '[$label] icone vetorial trocado',
      );
      expect(
        cardLabel,
        findsOneWidget,
        reason: '[$label] rotulo curto Publicar agora ausente do cartao',
      );
      expect(tester.takeException(), isNull, reason: label);
    });

    testWidgets('hover reforca borda e acao em laranja no tema ${theme.name}', (tester) async {
      await pumpHappens(tester, theme: theme.data);
      final label = 'hover ${theme.name}';

      expect(
        colors.outlineVariant,
        isNot(colors.primary),
        reason: '[$label] tokens indistinguiveis tornariam a medicao vazia',
      );

      final restFill = actionFill(tester, label);
      final restIcon = actionIconColor(tester, label);
      expectDashedBorder(tester, colors.outlineVariant, 'antes do hover, $label');

      await hoverCard(tester);

      expect(
        cardStates(tester),
        contains(WidgetState.hovered),
        reason: '[$label] o ponteiro nao produziu hover: ${cardStates(tester)}',
      );
      expect(
        cardStates(tester).contains(WidgetState.focused),
        isFalse,
        reason: '[$label] hover so vale como prova de hover se o foco nao ajudar',
      );

      final hoverFill = actionFill(tester, label);
      final hoverIcon = actionIconColor(tester, label);

      expectDashedBorder(tester, colors.primary, 'depois do hover, $label');
      expectPerceptible('a borda', label, colors.outlineVariant, colors.primary);

      expect(
        hoverFill,
        colors.primary,
        reason: '[$label] a acao foi de $restFill para $hoverFill, esperado ${colors.primary}',
      );
      expectPerceptible('a acao', label, restFill, hoverFill);

      expect(
        hoverIcon,
        colors.onPrimary,
        reason: '[$label] o icone foi de $restIcon para $hoverIcon, esperado ${colors.onPrimary}',
      );
      expectPerceptible('o icone', label, restIcon, hoverIcon);
      expect(tester.takeException(), isNull, reason: label);
    });

    testWidgets('foco sozinho, sem mouse, reforca borda e acao no tema ${theme.name}', (
      tester,
    ) async {
      await pumpHappens(tester, theme: theme.data);
      final label = 'foco ${theme.name}';

      final restFill = actionFill(tester, label);
      final restIcon = actionIconColor(tester, label);
      expectDashedBorder(tester, colors.outlineVariant, 'antes do foco, $label');

      final node = await focusCard(tester);

      expect(
        node.hasPrimaryFocus,
        isTrue,
        reason:
            '[$label] foco primario ficou em '
            '${FocusManager.instance.primaryFocus?.debugLabel ?? 'nenhum'}',
      );
      expect(
        cardStates(tester),
        contains(WidgetState.focused),
        reason: '[$label] foco real nao virou WidgetState.focused: ${cardStates(tester)}',
      );
      expect(
        cardStates(tester).contains(WidgetState.hovered),
        isFalse,
        reason:
            '[$label] nenhum ponteiro foi adicionado; hover presente invalidaria '
            'a prova de que o foco sozinho reforca',
      );

      final focusFill = actionFill(tester, label);
      final focusIcon = actionIconColor(tester, label);

      expectDashedBorder(tester, colors.primary, 'depois do foco, $label');
      expectPerceptible('a borda', label, colors.outlineVariant, colors.primary);

      expect(
        focusFill,
        colors.primary,
        reason: '[$label] a acao foi de $restFill para $focusFill, esperado ${colors.primary}',
      );
      expectPerceptible('a acao', label, restFill, focusFill);

      expect(
        focusIcon,
        colors.onPrimary,
        reason: '[$label] o icone foi de $restIcon para $focusIcon, esperado ${colors.onPrimary}',
      );
      expectPerceptible('o icone', label, restIcon, focusIcon);
      expect(tester.takeException(), isNull, reason: label);
    });

    testWidgets('pressionado por gesto real reforca borda e acao no tema ${theme.name}', (
      tester,
    ) async {
      var published = false;
      await pumpHappens(tester, theme: theme.data, onPublishNow: () => published = true);
      final label = 'pressionado ${theme.name}';

      final restFill = actionFill(tester, label);
      final restIcon = actionIconColor(tester, label);
      expectDashedBorder(tester, colors.outlineVariant, 'antes do toque, $label');

      final gesture = await pressCard(tester);

      // `cardStates` devolve copia: sem ela o `Set` do `statesController` seria
      // esvaziado pelo `gesture.up()` abaixo antes das assercoes.
      final states = cardStates(tester);
      final pressedFill = actionFill(tester, label);
      final pressedIcon = actionIconColor(tester, label);
      final pressedBorder = dashedBorderStroke(tester, label);
      // O painter e imutavel: guardar a chamada de pintura preserva o estado
      // pressionado e permite soltar o gesto antes das assercoes.
      final pressedBorderPainting = dashedBorderPainting(tester, label);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        states,
        contains(WidgetState.pressed),
        reason: '[$label] o gesto real nao produziu pressed: $states',
      );
      expect(
        pressedFill,
        colors.primary,
        reason: '[$label] a acao foi de $restFill para $pressedFill, esperado ${colors.primary}',
      );
      expectPerceptible('a acao', label, restFill, pressedFill);
      expect(
        pressedIcon,
        colors.onPrimary,
        reason: '[$label] o icone foi de $restIcon para $pressedIcon, esperado ${colors.onPrimary}',
      );
      expectPerceptible('o icone', label, restIcon, pressedIcon);
      expect(
        pressedBorder,
        dashStrokeWidth,
        reason: '[$label] contorno tracejado sumiu durante o toque: $pressedBorder',
      );
      expect(
        pressedBorderPainting,
        paints
          ..path(color: colors.primary, strokeWidth: dashStrokeWidth, style: PaintingStyle.stroke),
        reason:
            '[$label] o contorno tracejado nao foi reforcado em '
            '${colors.primary} durante o toque; saiu de ${colors.outlineVariant} '
            'e a display list real vem na descricao acima',
      );
      expectPerceptible('a borda', label, colors.outlineVariant, colors.primary);
      expect(published, isTrue, reason: '[$label] o toque real nao publicou');
      expect(tester.takeException(), isNull, reason: label);
    });
  }

  testWidgets('o foco medido e foco de teclado: Enter aciona Publicar agora', (tester) async {
    var published = false;
    await pumpHappens(tester, theme: CoeloTheme.light, onPublishNow: () => published = true);

    await focusCard(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      published,
      isTrue,
      reason:
          'Enter no cartao focado nao publicou; o foco medido nos casos acima '
          'nao seria foco de teclado acionavel',
    );
    expect(tester.takeException(), isNull);
  });

  for (final state in const ['hover', 'foco', 'pressionado']) {
    testWidgets('$state reforca algum sinal alem de cor no cartao Publicar agora', (tester) async {
      await pumpHappens(tester, theme: CoeloTheme.light, onPublishNow: () {});
      final label = '$state claro';

      final rest = nonColorSignals(tester, 'repouso claro');
      TestGesture? gesture;
      switch (state) {
        case 'hover':
          await hoverCard(tester);
        case 'foco':
          await focusCard(tester);
        default:
          gesture = await pressCard(tester);
      }
      final active = nonColorSignals(tester, label);

      final changed = rest.keys.where((signal) => rest[signal] != active[signal]).toList();

      await gesture?.up();
      await tester.pumpAndSettle();

      expect(
        changed,
        isNotEmpty,
        reason:
            '[$label] a spec 050 exige reforco "sem depender somente de cor" e '
            'nenhum sinal visual alem de cor mudou. Repouso: $rest. '
            'Estado $state: $active. O cartao troca apenas as tres cores '
            '(contorno, preenchimento da acao e icone); espessura, geometria, '
            'glifo e tipografia sao identicas',
      );
      expect(tester.takeException(), isNull, reason: label);
    });
  }
}
