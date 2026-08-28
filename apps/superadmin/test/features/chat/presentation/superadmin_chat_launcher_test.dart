import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop launcher uses the canonical orange capsule and server count', (
    tester,
  ) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app(unreadCount: 10));

    final surface = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final material = tester.widget<Material>(surface);
    final size = tester.getSize(surface);

    expect(find.text('Mens.'), findsOneWidget);
    expect(find.text('9+'), findsOneWidget);
    expect(material.color, CoeloTheme.light.colorScheme.primary);
    expect(material.shape, isA<StadiumBorder>());
    expect(size.height, CoeloSize.touchMin);
    expect(size.width, greaterThan(CoeloSize.touchMin));
    expect(
      find.bySemanticsLabel(RegExp('Abrir conversas, 10 mensagens nao lidas')),
      findsOneWidget,
    );
  });

  testWidgets('loads the authorised unread total and caps the visual badge at 9+', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app(loadUnreadCount: () async => 10));
    await tester.pump();

    expect(find.text('9+'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Abrir conversas, 10 mensagens nao lidas')),
      findsOneWidget,
    );
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

  testWidgets('mobile launcher is the same 48px circular FAB without synthetic badge', (
    tester,
  ) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app());

    final surface = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final material = tester.widget<Material>(surface);
    expect(find.text('Mens.'), findsNothing);
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(material.color, CoeloTheme.light.colorScheme.primary);
    expect(material.shape, isA<CircleBorder>());
    expect(tester.getSize(surface), const Size(CoeloSize.touchMin, CoeloSize.touchMin));
    expect(
      find.bySemanticsLabel(RegExp('Abrir conversas, nenhuma mensagem nao lida')),
      findsOneWidget,
    );
  });

  testWidgets('adapts at the medium breakpoint without clipping at 200 percent text', (
    tester,
  ) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      _viewport(tester, width);
      await tester.pumpWidget(_app(key: ValueKey(width), textScaler: const TextScaler.linear(2)));
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('superadmin-chat-launcher-surface'));
      final material = tester.widget<Material>(surface);
      final size = tester.getSize(surface);
      final compact = width < CoeloBreakpoints.medium.minWidth;

      expect(size.height, CoeloSize.touchMin, reason: 'width $width');
      expect(
        size.width,
        compact ? CoeloSize.touchMin : greaterThan(CoeloSize.touchMin),
        reason: 'width $width',
      );
      expect(material.shape, compact ? isA<CircleBorder>() : isA<StadiumBorder>());
      expect(find.text('Mens.'), compact ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width at 200% text');
    }
  });
  testWidgets('drag, Alt arrows and Home reposition and reset within the safe area', (
    tester,
  ) async {
    _viewport(tester, 1024);
    final controller = SuperadminChatLauncherPositionController();
    addTearDown(controller.dispose);
    var openCount = 0;
    await tester.pumpWidget(_app(positionController: controller, onOpen: () => openCount += 1));
    await tester.pumpAndSettle();
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final initial = tester.getTopLeft(launcher);

    await tester.drag(launcher, const Offset(-180, -120));
    await tester.pumpAndSettle();
    final dragged = tester.getTopLeft(launcher);

    expect(dragged.dx, lessThan(initial.dx));
    expect(dragged.dy, lessThan(initial.dy));
    expect(controller.value, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    final keyboardMoved = tester.getTopLeft(launcher);

    expect(keyboardMoved.dx, lessThan(dragged.dx));

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(launcher), initial);
    expect(controller.value, isNull);

    await tester.tap(launcher);
    await tester.pumpAndSettle();
    expect(openCount, 1);
  });
}

Widget _app({
  Key? key,
  VoidCallback? onOpen,
  int unreadCount = 0,
  Future<int> Function()? loadUnreadCount,
  SuperadminChatLauncherPositionController? positionController,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    key: key,
    theme: CoeloTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: SuperadminChatLauncher(
              unreadCount: unreadCount,
              loadUnreadCount: loadUnreadCount,
              positionController: positionController,
              onOpenConversations: onOpen ?? () {},
            ),
          ),
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
