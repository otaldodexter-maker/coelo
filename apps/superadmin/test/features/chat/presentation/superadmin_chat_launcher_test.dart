import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop launcher keeps the stable orange capsule and server count', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app(unreadCount: 10));

    final surface = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final material = tester.widget<Material>(surface);
    final size = tester.getSize(surface);

    expect(find.text('Mens.'), findsOneWidget);
    expect(find.text('9+'), findsOneWidget);
    expect(material.color, CoeloTheme.light.colorScheme.primary);
    expect(material.shape, isA<StadiumBorder>());
    expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(size.height, CoeloSize.touchMin);
    expect(find.bySemanticsLabel('Abrir conversas, 10 mensagens nao lidas'), findsOneWidget);
  });

  testWidgets('loads the authorised unread total and caps the visual badge at 9+', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app(loadUnreadCount: () async => 10));
    await tester.pump();

    expect(find.text('9+'), findsOneWidget);
    expect(find.bySemanticsLabel('Abrir conversas, 10 mensagens nao lidas'), findsOneWidget);
  });

  testWidgets('routes directly to the authorised conversations surface', (tester) async {
    _viewport(tester, 1024);
    var openCount = 0;
    await tester.pumpWidget(_app(onOpen: () => openCount += 1));

    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();

    expect(openCount, 1);
    expect(find.byKey(const Key('superadmin-chat-launcher-panel')), findsNothing);
  });

  testWidgets('mobile launcher is a 48px circle and has no synthetic badge', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app());

    final surface = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final material = tester.widget<Material>(surface);
    expect(find.text('Mens.'), findsNothing);
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(material.shape, isA<CircleBorder>());
    expect(tester.getSize(surface), const Size(CoeloSize.touchMin, CoeloSize.touchMin));
    expect(find.bySemanticsLabel('Abrir conversas, nenhuma mensagem nao lida'), findsOneWidget);
  });

  testWidgets('drag and Alt arrows never move the safe-area anchored launcher', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final initial = tester.getTopLeft(launcher);

    await tester.drag(launcher, const Offset(-180, -120));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(launcher), initial);
  });
}

Widget _app({VoidCallback? onOpen, int unreadCount = 0, Future<int> Function()? loadUnreadCount}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomRight,
        child: SuperadminChatLauncher(
          unreadCount: unreadCount,
          loadUnreadCount: loadUnreadCount,
          onOpenConversations: onOpen ?? () {},
        ),
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
