import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_superadmin/features/support/presentation/widgets/support_message_bubble.dart';
import 'package:coelo_superadmin/features/support/presentation/widgets/support_reply_composer.dart';

void main() {
  testWidgets('support reply composer sends with Enter and preserves Shift Enter', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final sent = <String>[];

    await tester.pumpWidget(
      _app(
        SupportReplyComposer(
          controller: controller,
          onSend: () {
            sent.add(controller.text);
            controller.clear();
          },
        ),
      ),
    );

    final sendButton = find.widgetWithIcon(IconButton, Icons.send_rounded);
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Primeira linha');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.enterText(find.byType(TextField), 'Primeira linha\nSegunda linha');
    expect(controller.text, contains('\n'));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sent, ['Primeira linha\nSegunda linha']);
    expect(controller.text, isEmpty);
  });

  testWidgets('support message bubble exposes author and delivery semantics', (tester) async {
    final message = SupportMessage(
      id: 'message-1',
      author: SupportMessageAuthor.requester,
      text: 'Precisamos de ajuda.',
      sentAt: DateTime(2026, 7, 28, 10, 32),
      deliveryState: SupportMessageDeliveryState.read,
    );

    await tester.pumpWidget(
      _app(SupportMessageBubble(message: message, requesterName: 'Marina Alves')),
    );

    final semantics = tester.getSemantics(find.byType(SupportMessageBubble));
    expect(semantics.label, contains('Marina Alves'));
    expect(semantics.label, contains('Precisamos de ajuda.'));
    expect(semantics.label, contains('Lida'));
    expect(
      tester.getSize(find.byKey(const Key('support-message-bubble-surface'))).width,
      lessThanOrEqualTo(CoeloSize.touchMin * 11),
    );
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}
