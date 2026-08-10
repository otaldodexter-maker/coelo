import 'dart:ui';

import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop launcher keeps its orange capsule geometry on hover', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());

    expect(find.text('Mensagens'), findsOne);
    expect(find.byTooltip('Abrir conversas'), findsNothing);
    expect(find.text('3'), findsOne);
    expect(
      tester
          .widget<Material>(find.byKey(const Key('superadmin-chat-launcher-surface')))
          .clipBehavior,
      Clip.none,
    );

    final idleSize = tester.getSize(find.byKey(const Key('superadmin-chat-launcher-surface')));
    final idleMaterial = tester.widget<Material>(
      find.byKey(const Key('superadmin-chat-launcher-surface')),
    );
    expect(idleMaterial.color, CoeloTheme.light.colorScheme.primary);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byKey(const Key('superadmin-chat-launcher-surface'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mensagens'), findsOne);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOne);
    expect(find.byType(CircleAvatar), findsNWidgets(7));

    expect(tester.getSize(find.byKey(const Key('superadmin-chat-launcher-surface'))), idleSize);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(idleSize.width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(idleSize.height, greaterThanOrEqualTo(CoeloSize.touchMin));
  });

  testWidgets('outside click closes the panel without keeping the launcher orange', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());

    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-launcher-panel')), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-launcher-panel')), findsNothing);
    final surface = tester.widget<Material>(
      find.byKey(const Key('superadmin-chat-launcher-surface')),
    );
    expect(surface.color, CoeloTheme.light.colorScheme.primary);
    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('Launcher de conversas'));
  });

  testWidgets('Alt arrows move the launcher and Home resets it', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final initial = tester.getTopLeft(launcher);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    final moved = tester.getTopLeft(launcher);
    expect(moved.dx, lessThan(initial.dx));

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    final resetRect = tester.getRect(launcher);
    expect(resetRect.right, 1024 - CoeloSpacing.space2);
    expect(resetRect.bottom, 720 - CoeloSpacing.space2);
  });

  testWidgets('keeps the dragged position when a routed page recreates the launcher', (
    tester,
  ) async {
    _viewport(tester, 1024);
    final secondPage = ValueNotifier(false);
    final position = SuperadminChatLauncherPositionController();
    addTearDown(secondPage.dispose);
    addTearDown(position.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: secondPage,
            builder: (context, value, _) => Align(
              alignment: Alignment.bottomRight,
              child: SuperadminChatLauncher(
                key: ValueKey(value),
                positionController: position,
                onOpenConversations: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final initial = tester.getTopLeft(launcher);
    await tester.drag(launcher, const Offset(-180, -120));
    await tester.pumpAndSettle();
    final moved = tester.getTopLeft(launcher);
    expect(moved.dx, lessThan(initial.dx));

    secondPage.value = true;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(launcher), moved);
  });

  testWidgets('opens compact inbox with canonical search and three audience tabs', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());

    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-launcher-panel')), findsOne);
    expect(find.text('Conversas'), findsOne);
    expect(find.byKey(const Key('superadmin-chat-launcher-header')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-launcher-search')), findsOne);
    for (final label in ['Todos', 'Institucional', 'Pessoas']) {
      expect(find.text(label), findsOne, reason: label);
    }
    expect(find.text('Criar grupo'), findsNothing);
    expect(find.text('Nova mensagem'), findsNothing);
    expect(find.text('Filtrar'), findsNothing);
  });

  testWidgets('keeps the anchored panel inside the viewport with a subtle elevation', (
    tester,
  ) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                right: CoeloSpacing.space3,
                bottom: CoeloSize.touchMin * 2,
                child: SuperadminChatLauncher(onOpenConversations: () {}),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('superadmin-chat-launcher-panel'));
    final rect = tester.getRect(panel);
    expect(rect.top, greaterThanOrEqualTo(CoeloSpacing.space2));
    expect(rect.bottom, lessThanOrEqualTo(720 - CoeloSpacing.space2));
    final material = tester.widget<Material>(panel);
    expect(material.elevation, lessThanOrEqualTo(2));
  });

  testWidgets('uses rounded orange hover for compact conversation rows', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());
    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('superadmin-chat-launcher-conversation-girassol'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(row));
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find.descendant(of: row, matching: find.byType(Material)).first,
    );
    expect(material.color, CoeloTheme.light.colorScheme.primaryContainer);
    expect(material.borderRadius, BorderRadius.circular(CoeloRadius.md));
  });

  testWidgets('closes with Escape and restores focus to the launcher', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());

    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-launcher-panel')), findsOne);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-launcher-panel')), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Launcher de conversas');
  });

  testWidgets('keeps back and emoji interactions free of layout assertions', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());
    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-conversation-girassol')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Adicionar emoji'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Voltar para conversas'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-launcher-search')), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact launcher is a surface circle with the real unread count', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app());

    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final material = tester.widget<Material>(launcher);
    final size = tester.getSize(launcher);

    expect(find.text('Mensagens'), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(material.color, CoeloTheme.light.colorScheme.surface);
    expect(material.shape, isA<CircleBorder>());
    expect(material.elevation, greaterThan(0));
    expect(size, const Size(CoeloSize.touchMin, CoeloSize.touchMin));
    expect(find.byTooltip('Abrir conversas'), findsNothing);
    expect(find.bySemanticsLabel('Abrir conversas, 3 mensagens não lidas'), findsOneWidget);

    await tester.tap(launcher);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOne);
    expect(find.text('Conversas'), findsOne);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
  });

  testWidgets('compact launcher uses the semantic dark surface', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app(theme: CoeloTheme.dark));

    final material = tester.widget<Material>(
      find.byKey(const Key('superadmin-chat-launcher-surface')),
    );
    expect(material.color, CoeloTheme.dark.colorScheme.surface);
    expect(material.shape, isA<CircleBorder>());
  });

  testWidgets('medium launcher preserves the orange capsule anatomy', (tester) async {
    _viewport(tester, 768);
    await tester.pumpWidget(_app());

    final material = tester.widget<Material>(
      find.byKey(const Key('superadmin-chat-launcher-surface')),
    );
    expect(find.text('Mensagens'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(7));
    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    expect(material.color, CoeloTheme.light.colorScheme.primary);
    expect(material.shape, isA<StadiumBorder>());
  });

  testWidgets('clamps safely when the reserved footer consumes the viewport', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: SuperadminChatLauncher(bottomClearance: 900, onOpenConversations: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const Key('superadmin-chat-launcher-surface'))).dy,
      greaterThanOrEqualTo(CoeloSpacing.space2),
    );
  });
}

Widget _app({ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? CoeloTheme.light,
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
