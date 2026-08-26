import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_composer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inserts a selected emoji at the cursor without sending a fake message', (
    tester,
  ) async {
    const emoji = '\u{1F60A}';
    final controller = TextEditingController(text: 'Ola ')
      ..selection = const TextSelection.collapsed(offset: 4);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SuperadminChatComposer(
            controller: controller,
            onSend: () {},
            onEmoji: () {},
            onAudio: () {},
            onImage: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Adicionar emoji'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Inserir :)'), findsOneWidget);
    await tester.tap(find.text(emoji));
    await tester.pumpAndSettle();

    expect(controller.text, 'Ola $emoji');
    expect(find.byKey(const Key('superadmin-chat-emoji-picker')), findsNothing);
    expect(tester.getSize(find.byTooltip('Adicionar emoji')).shortestSide, CoeloSize.touchMin);
  });
}
