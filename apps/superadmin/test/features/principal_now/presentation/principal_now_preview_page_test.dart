import 'dart:ui';

import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpNow(
    WidgetTester tester, {
    Size size = const Size(375, 900),
    VoidCallback? onClose,
    VoidCallback? onOpenHappens,
    VoidCallback? onCreate,
    bool disableAnimations = false,
    double textScale = 1,
    ThemeData? theme,
    ValueChanged<String>? onReply,
    VoidCallback? onShare,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? CoeloTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
            padding: padding,
            viewPadding: padding,
          ),
          child: child!,
        ),
        home: PrincipalNowPreviewPage(
          onClose: onClose,
          onOpenHappens: onOpenHappens,
          onCreate: onCreate,
          onReply: onReply,
          onShare: onShare,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the canonical mobile story anatomy', (tester) async {
    await pumpNow(tester);

    expect(find.byKey(const Key('principal-now-story')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-progress')), findsOneWidget);
    expect(find.text('Riverside School'), findsOneWidget);
    expect(find.byKey(const Key('principal-now-reply-field')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-close')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-desktop-shell')), findsNothing);
    expect(find.byKey(const Key('principal-now-previous-preview')), findsNothing);
    expect(find.byKey(const Key('principal-now-back')), findsOneWidget);
    expect(find.byTooltip('Voltar para Acontece'), findsOneWidget);
    expect(find.byKey(const Key('principal-global-dock')), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps mobile media edge-to-edge while controls respect safe insets', (tester) async {
    const safePadding = EdgeInsets.only(top: 32, bottom: 24);
    await pumpNow(tester, padding: safePadding);

    final storyRect = tester.getRect(find.byKey(const Key('principal-now-story')));
    expect(storyRect.top, 0);
    expect(storyRect.bottom, 900);
    expect(tester.getTopLeft(find.byKey(const Key('principal-now-close'))).dy, greaterThan(32));
    expect(
      tester.getBottomRight(find.byKey(const Key('principal-now-reply-field'))).dy,
      lessThan(900 - 24),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes accessible controls with minimum touch targets', (tester) async {
    await pumpNow(tester);

    expect(find.bySemanticsLabel('Agora anterior'), findsOneWidget);
    expect(find.bySemanticsLabel('Próximo Agora'), findsOneWidget);
    expect(find.byTooltip('Opções do Agora'), findsOneWidget);
    expect(find.byTooltip('Voltar para Acontece'), findsOneWidget);
    expect(find.byTooltip('Desativar áudio'), findsOneWidget);
    expect(find.byTooltip('Reagir a este Agora'), findsOneWidget);
    expect(find.byTooltip('Compartilhar este Agora'), findsOneWidget);
    expect(find.byTooltip('Enviar resposta privada'), findsOneWidget);
    final audience = find.byKey(const Key('principal-now-audience'));
    expect(audience, findsOneWidget);
    expect(tester.widget<Semantics>(audience).properties.label, 'Audiência do Agora');

    for (final key in const [
      Key('principal-now-options'),
      Key('principal-now-close'),
      Key('principal-now-like'),
      Key('principal-now-share'),
      Key('principal-now-send-reply'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin));
      expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin));
    }
  });

  testWidgets('gives the immersive private reply an explicit hover state', (tester) async {
    await pumpNow(tester);
    final fieldFinder = find.byKey(const Key('principal-now-reply-field'));
    expect(find.bySemanticsLabel('Resposta privada ao Agora'), findsOneWidget);

    final before = tester.widget<TextField>(fieldFinder);
    final beforeBorder = before.decoration!.enabledBorder! as OutlineInputBorder;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(fieldFinder));
    await tester.pump();

    final after = tester.widget<TextField>(fieldFinder);
    final afterBorder = after.decoration!.enabledBorder! as OutlineInputBorder;
    expect(afterBorder.borderSide.color, isNot(beforeBorder.borderSide.color));
  });

  testWidgets('renders centered story and neighboring previews on desktop', (tester) async {
    await pumpNow(tester, size: const Size(1440, 1000));

    expect(find.byKey(const Key('principal-now-desktop-shell')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-previous-preview')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-next-preview')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-back')), findsOneWidget);
    expect(find.byTooltip('Voltar para Acontece'), findsOneWidget);
    expect(find.byKey(const Key('principal-now-reply-field')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-audience')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps 1024 tablet in a centered safe frame without web previews', (tester) async {
    await pumpNow(tester, size: const Size(1024, 900));

    expect(find.byKey(const Key('principal-now-desktop-shell')), findsNothing);
    expect(find.byKey(const Key('principal-now-previous-preview')), findsNothing);
    expect(find.byKey(const Key('principal-now-next-preview')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('principal-now-story'))).width,
      lessThanOrEqualTo(430),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers the publication entry from options and pauses the story', (tester) async {
    var createRequested = false;
    await pumpNow(tester, onCreate: () => createRequested = true);

    await tester.tap(find.byKey(const Key('principal-now-options')));
    await tester.pumpAndSettle();
    expect(find.text('Publicar no Agora'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Explorando reações na aula de ciências'), findsOneWidget);

    await tester.tap(find.text('Publicar no Agora'));
    await tester.pump();
    expect(createRequested, isTrue);
  });

  testWidgets('keeps autoplay paused while the story is held', (tester) async {
    await pumpNow(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('principal-now-next-zone'))),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Explorando reações na aula de ciências'), findsOneWidget);
    await gesture.cancel();
  });

  testWidgets('advances automatically and closes after the final story', (tester) async {
    var closed = false;
    await pumpNow(tester, onClose: () => closed = true);

    expect(find.text('Explorando reações na aula de ciências'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pump();
    expect(find.text('Conversas que aproximam escola e família'), findsOneWidget);

    for (var index = 0; index < 4; index += 1) {
      await tester.pump(const Duration(milliseconds: 5100));
      await tester.pump();
    }
    expect(closed, isTrue);
  });

  testWidgets('supports manual navigation with tap zones and keyboard', (tester) async {
    await pumpNow(tester, size: const Size(1440, 1000));

    await tester.tap(find.byKey(const Key('principal-now-next-zone')));
    await tester.pump();
    expect(find.text('Conversas que aproximam escola e família'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Explorando reações na aula de ciências'), findsWidgets);

    await tester.tap(find.byKey(const Key('principal-now-next-preview')));
    await tester.pump();
    expect(find.text('Conversas que aproximam escola e família'), findsOneWidget);
  });

  testWidgets('pauses with space and while the private reply has focus', (tester) async {
    await pumpNow(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Explorando reações na aula de ciências'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.tap(find.byKey(const Key('principal-now-reply-field')));
    await tester.enterText(
      find.byKey(const Key('principal-now-reply-field')),
      'Obrigado pelo registro',
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Explorando reações na aula de ciências'), findsOneWidget);

    await tester.tap(find.byKey(const Key('principal-now-send-reply')));
    await tester.pump();
    expect(find.text('Resposta indisponível nesta prévia.'), findsOneWidget);
    expect(find.text('Obrigado pelo registro'), findsOneWidget);
  });

  testWidgets('dispatches reply and share only through injected integrations', (tester) async {
    String? reply;
    var shares = 0;
    await pumpNow(tester, onReply: (value) => reply = value, onShare: () => shares += 1);
    await tester.enterText(find.byKey(const Key('principal-now-reply-field')), 'Mensagem privada');
    await tester.tap(find.byKey(const Key('principal-now-send-reply')));
    await tester.tap(find.byKey(const Key('principal-now-share')));
    await tester.pump();

    expect(reply, 'Mensagem privada');
    expect(shares, 1);
    expect(find.text('Mensagem privada'), findsNothing);
    expect(find.textContaining('indisponível'), findsNothing);
  });

  testWidgets('toggles audio, reaction, options and close controls', (tester) async {
    var closed = false;
    await pumpNow(tester, size: const Size(1440, 1000), onClose: () => closed = true);

    await tester.tap(find.byKey(const Key('principal-now-audio')));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('principal-now-options')));
    await tester.pump();
    expect(find.text('Opções deste Agora'), findsOneWidget);
    await tester.tapAt(const Offset(40, 40));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('principal-now-close')));
    expect(closed, isTrue);
  });

  for (final testCase in [
    (name: '375 light', size: const Size(375, 900), theme: CoeloTheme.light),
    (name: '375 dark', size: const Size(375, 900), theme: CoeloTheme.dark),
    (name: '768 light', size: const Size(768, 1024), theme: CoeloTheme.light),
    (name: '768 dark', size: const Size(768, 1024), theme: CoeloTheme.dark),
    (name: '1024 light', size: const Size(1024, 900), theme: CoeloTheme.light),
    (name: '1024 dark', size: const Size(1024, 900), theme: CoeloTheme.dark),
    (name: '1440 light', size: const Size(1440, 1000), theme: CoeloTheme.light),
    (name: '1440 dark', size: const Size(1440, 1000), theme: CoeloTheme.dark),
  ]) {
    testWidgets('has no overflow at ${testCase.name}', (tester) async {
      await pumpNow(tester, size: testCase.size, theme: testCase.theme);
      expect(find.byKey(const Key('principal-now-story')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(375, 900), const Size(768, 1024), const Size(1024, 900)]) {
    testWidgets('supports 200 percent text at ${size.width.toInt()} px', (tester) async {
      await pumpNow(tester, size: size, textScale: 2, disableAnimations: true);
      await tester.pump(const Duration(seconds: 6));

      expect(find.byKey(const Key('principal-now-story')), findsOneWidget);
      expect(find.text('Explorando reações na aula de ciências'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
