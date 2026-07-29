import 'dart:ui';

import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collapsed launcher shows badge, avatars and keyboard focus', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());

    expect(find.text('Mensagens'), findsOne);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOne);
    expect(find.byType(CircleAvatar), findsNWidgets(7));
    expect(find.text('3'), findsOne);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final size = tester.getSize(find.byKey(const Key('superadmin-chat-launcher-surface')));
    expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin));
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
