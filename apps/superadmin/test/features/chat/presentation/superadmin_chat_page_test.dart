import 'dart:ui';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_scope_filters.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_thread_body.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses inbox, rail and stacked navigation at approved breakpoints', (tester) async {
    for (final width in [1440.0, 768.0, 375.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
      await tester.pumpAndSettle();

      if (width >= CoeloBreakpoints.expanded.minWidth) {
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
      } else if (width >= CoeloBreakpoints.medium.minWidth) {
        expect(find.byKey(const Key('superadmin-chat-rail')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
      } else {
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
        await tester.tap(find.text('Turma Girassol').first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
        await tester.tap(find.byTooltip('Voltar para conversas'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
      }
      expect(tester.takeException(), isNull, reason: '$width');
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('opens contextual profile and hierarchical conversation creation', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turma Girassol').last);
    await tester.pumpAndSettle();
    expect(find.text('Vínculos autorizados'), findsOne);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nova conversa'));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminContextPicker), findsOne);
    expect(find.text('Pesquisar pessoa · Acesso auditado'), findsOne);
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      CoeloTheme.light.colorScheme.surface,
    );
    await tester.tap(find.byKey(const Key('coelo-context-select-centro-horizonte')));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Selecionar contexto'), findsOne);

    await tester.tap(find.text('Pesquisar pessoa · Acesso auditado'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Apoio solicitado pela instituição');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Marina Alves'), findsOne);
    await tester.tap(find.text('Marina Alves'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Iniciar conversa'), findsOne);
  });

  testWidgets('launcher opens compact inbox and expands through its callback', (tester) async {
    var expands = 0;
    await tester.pumpWidget(_app(SuperadminChatLauncher(onExpand: () => expands++)));

    final launcherSurface = find.byKey(const Key('superadmin-chat-launcher-surface'));
    expect(
      (tester.widget<Container>(launcherSurface).decoration as BoxDecoration).color,
      CoeloTheme.light.colorScheme.surface,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(launcherSurface));
    await tester.pump();
    expect(
      (tester.widget<Container>(launcherSurface).decoration as BoxDecoration).color,
      CoeloTheme.light.colorScheme.primaryContainer,
    );

    await tester.tap(find.text('Mensagens'));
    await tester.pumpAndSettle();
    expect(find.text('Conversas'), findsOne);
    for (final label in [
      'Todas',
      'Instituição',
      'Unidade',
      'Grupo/Turma',
      'Atividade',
      'Criança',
    ]) {
      expect(find.text(label), findsOne, reason: label);
    }
    expect(
      (tester.widget<ColoredBox>(find.byKey(const Key('superadmin-chat-launcher-header')))).color,
      CoeloTheme.light.colorScheme.primary,
    );

    await tester.tap(find.text('Turma Girassol'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-launcher-thread')), findsOne);
    expect(find.byIcon(Icons.call_outlined), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
    expect(find.byTooltip('Gravar áudio'), findsOne);
    expect(find.byTooltip('Adicionar mídia'), findsOne);
    expect(find.textContaining('Em breve'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Mensagem simulada');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Mensagem simulada'), findsOne);
    expect(find.text('Marina está digitando…'), findsOne);
    await tester.tap(find.byTooltip('Voltar para conversas'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Conversas'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Conversas'), findsOne);
    await tester.tap(find.byTooltip('Expandir conversas'));
    expect(expands, 1);
  });

  testWidgets('filters the full inbox by every contextual dimension', (tester) async {
    var backs = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(SuperadminChatPage(logout: _logout, onBack: () => backs++)));
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(find.text('Voltar à tela anterior')).dy, greaterThan(800));
    await tester.tap(find.text('Voltar à tela anterior'));
    expect(backs, 1);
    for (final id in ['concept', 'institution', 'unit', 'group', 'activity', 'child']) {
      expect(find.byKey(Key('superadmin-chat-filter-$id')), findsOne);
    }
    await tester.tap(find.byKey(const Key('superadmin-chat-filter-institution')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Instituto Aurora'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-conversation-aurora')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-conversation-girassol')), findsNothing);
    expect(find.byIcon(Icons.call_outlined), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
  });

  testWidgets('opens scope filters with a canonical menu surface and hover state', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<SuperadminChatScopeDomain>), findsOne);
    await tester.tap(find.byKey(const Key('superadmin-chat-filter-state')));
    await tester.pumpAndSettle();

    final colors = CoeloTheme.light.colorScheme;
    final menu = tester.widget<MenuAnchor>(find.byType(MenuAnchor).last);
    expect(menu.style?.backgroundColor?.resolve({}), colors.surface);

    final option = find.widgetWithText(MenuItemButton, 'CE');
    final item = tester.widget<MenuItemButton>(option);
    expect(tester.getSize(option).height, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(item.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
  });

  testWidgets('simulates audio recording and media loading locally', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(body: SuperadminChatThreadBody(conversation: superadminChatConversations.first)),
      ),
    );

    await tester.tap(find.byTooltip('Gravar áudio'));
    await tester.pump();
    expect(find.text('Gravando áudio…'), findsOne);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Enviando áudio…'), findsOne);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Mensagem de áudio · 0:08'), findsOne);

    await tester.tap(find.byTooltip('Adicionar mídia'));
    await tester.pump();
    expect(find.text('Carregando mídia… 48%'), findsOne);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Enviando mídia…'), findsOne);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Imagem anexada · demonstração local'), findsOne);
  });

  testWidgets('keeps the compact inbox usable at 200 percent text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const SuperadminChatPage(logout: _logout),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turma Girassol'), findsOne);
    expect(tester.takeException(), isNull);
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

Widget _app(Widget child) {
  return MaterialApp(theme: CoeloTheme.light, home: child);
}
