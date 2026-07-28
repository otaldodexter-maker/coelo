import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launcher is keyboard reachable and opens the anchored compact panel', (
    tester,
  ) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('superadmin-chat-launcher-surface')),
    );
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.focused}),
      CoeloTheme.light.colorScheme.primary,
    );
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-launcher-panel')), findsOne);
    expect(find.text('Conversas'), findsOne);
  });

  testWidgets('launcher uses a compact sheet below expanded', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app());

    expect(find.text('Mensagens'), findsNothing);
    expect(find.byTooltip('Abrir conversas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOne);
    expect(find.text('Conversas'), findsOne);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
  });
}

Widget _app() {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomRight,
        child: SuperadminChatLauncher(onOpenConversations: () {}),
      ),
    ),
  );
}

void _viewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 720);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
