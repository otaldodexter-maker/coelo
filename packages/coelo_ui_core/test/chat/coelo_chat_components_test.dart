import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat avatar distinguishes Now from profile activation', (tester) async {
    var profileOpens = 0;
    var nowOpens = 0;

    await tester.pumpWidget(
      _app(
        CoeloChatAvatar(
          label: 'Turma Girassol',
          initials: 'TG',
          nowState: CoeloNowState.unseen,
          presence: CoeloChatPresence.available,
          presenceLabel: 'Equipe disponível',
          onProfilePressed: () => profileOpens++,
          onNowPressed: () => nowOpens++,
        ),
      ),
    );

    expect(find.bySemanticsLabel('Turma Girassol. Now não visto. Equipe disponível'), findsOne);
    expect(
      tester.getSize(find.byKey(const Key('coelo-chat-avatar-presence'))),
      const Size.square(14),
    );
    expect(find.byKey(const Key('coelo-chat-avatar-now-ring')), findsOne);
    await tester.tap(find.byType(CoeloChatAvatar));
    expect(nowOpens, 1);
    expect(profileOpens, 0);
  });

  testWidgets('conversation tile announces unread messages and opens the thread', (tester) async {
    var opens = 0;

    await tester.pumpWidget(
      _app(
        CoeloConversationTile(
          avatar: const CoeloChatAvatar(label: 'Centro Horizonte', initials: 'CH'),
          title: 'Centro Horizonte',
          preview: 'A equipe enviou uma mensagem.',
          timestamp: '2 min',
          unreadCount: 3,
          onPressed: () => opens++,
        ),
      ),
    );

    expect(find.bySemanticsLabel(RegExp('3 mensagens não lidas')), findsOne);
    await tester.tap(find.text('Centro Horizonte'));
    expect(opens, 1);
  });

  testWidgets('conversation header separates profile and enabled actions', (tester) async {
    var profileOpens = 0;
    var infoOpens = 0;

    await tester.pumpWidget(
      _app(
        CoeloConversationHeader(
          avatar: const CoeloChatAvatar(label: 'Turma Girassol', initials: 'TG'),
          title: 'Turma Girassol',
          subtitle: 'Centro Horizonte · Unidade Cambuí',
          onProfilePressed: () => profileOpens++,
          actions: [
            IconButton(
              tooltip: 'Ver vínculos',
              onPressed: () => infoOpens++,
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Turma Girassol'));
    await tester.tap(find.byTooltip('Ver vínculos'));
    expect(profileOpens, 1);
    expect(infoOpens, 1);
  });

  testWidgets('message bubble exposes context, children and delivery as text', (tester) async {
    await tester.pumpWidget(
      _app(
        const CoeloMessageBubble(
          direction: CoeloMessageDirection.sent,
          body: 'A retirada será às 17h.',
          timestamp: '16:42',
          authorLabel: 'Owner Coelo · Suporte',
          contextLabel: 'Turma Girassol',
          childLabels: ['Lia'],
          deliveryState: CoeloMessageDeliveryState.read,
        ),
      ),
    );

    expect(find.text('Turma Girassol · Lia'), findsOne);
    expect(find.text('Lida'), findsOne);
    expect(find.bySemanticsLabel(RegExp('Mensagem enviada')), findsOne);
  });

  testWidgets('composer exposes enabled media and audio actions when callbacks are supplied', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;
    var audioOpens = 0;
    var mediaOpens = 0;

    await tester.pumpWidget(
      _app(
        CoeloChatComposer(
          controller: controller,
          onSend: () => sends++,
          showMediaAction: true,
          showAudioAction: true,
          onAudioPressed: () => audioOpens++,
          onMediaPressed: () => mediaOpens++,
        ),
      ),
    );

    expect(find.byTooltip('Enviar mensagem'), findsOne);
    expect(find.byTooltip('Adicionar mídia'), findsOne);
    expect(find.byTooltip('Gravar áudio'), findsOne);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded)).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.image_outlined)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Gravar áudio'));
    await tester.tap(find.byTooltip('Adicionar mídia'));
    expect(audioOpens, 1);
    expect(mediaOpens, 1);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.mic_none_outlined)).onPressed,
      isNotNull,
    );

    await tester.enterText(find.byType(TextField), 'Olá');
    await tester.pump();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send_rounded));
    expect(sends, 1);
  });

  testWidgets('composer sends a non-empty message when Enter is pressed', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;

    await tester.pumpWidget(_app(CoeloChatComposer(controller: controller, onSend: () => sends++)));

    await tester.enterText(find.byType(TextField), 'Olá');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

    expect(sends, 1);
  });

  testWidgets('composer keeps Enter available for a newline while Shift is pressed', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;

    await tester.pumpWidget(_app(CoeloChatComposer(controller: controller, onSend: () => sends++)));

    await tester.enterText(find.byType(TextField), 'Olá');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(sends, 0);
    expect(controller.text, 'Olá\n');
  });

  testWidgets('composer exposes context and styles an enabled send action', (tester) async {
    final controller = TextEditingController(text: 'Olá');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        CoeloChatComposer(controller: controller, onSend: () {}, contextLabel: 'Turma Girassol'),
      ),
    );

    final colors = Theme.of(tester.element(find.byType(CoeloChatComposer))).colorScheme;
    final sendButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send_rounded),
    );

    expect(find.text('Turma Girassol'), findsOne);
    expect(sendButton.onPressed, isNotNull);
    expect(sendButton.style?.backgroundColor?.resolve(<WidgetState>{}), colors.primary);
  });

  testWidgets('composer enables the optional emoji action when supplied', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var emojiOpens = 0;

    await tester.pumpWidget(
      _app(
        CoeloChatComposer(
          controller: controller,
          onSend: () {},
          onEmojiPressed: () => emojiOpens++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Adicionar emoji'));

    expect(emojiOpens, 1);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}
