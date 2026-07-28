import 'dart:ui';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_recipient_picker.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_scope_filters.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_thread_body.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [1440.0, 1024.0, 768.0, 375.0]) {
    testWidgets('uses the approved chat composition at ${width.toInt()}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_app(SuperadminChatPage(key: ValueKey(width), logout: _logout)));
      await tester.pumpAndSettle();

      if (width == 1440) {
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-context-panel')), findsOne);
        expect(find.byKey(const Key('chat-context-metric')), findsNWidgets(4));
      } else if (width >= CoeloBreakpoints.medium.minWidth) {
        expect(find.byKey(const Key('superadmin-chat-rail')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-context-panel-collapsed')), findsOne);
        await tester.tap(find.byTooltip('Mostrar detalhes do contexto'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-chat-context-panel')), findsOne);
        expect(find.text('Professores'), findsOne);
      } else {
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
        await tester.tap(find.text('Turma Girassol').first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-context-panel-collapsed')), findsOne);
        await tester.tap(find.byTooltip('Mostrar detalhes do contexto'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-chat-context-panel')), findsOne);
        expect(find.text('Professores'), findsOne);
        await tester.tap(find.byTooltip('Voltar para a conversa'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Voltar para conversas'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
      }
      expect(tester.takeException(), isNull, reason: '$width');
    });
  }

  for (final width in [1024.0, 768.0, 375.0]) {
    testWidgets('transfers context panel focus at ${width.toInt()}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
      await tester.pumpAndSettle();

      if (width == 375) {
        await tester.tap(find.text('Turma Girassol').first);
        await tester.pumpAndSettle();
      }

      final collapsedButton = tester.widget<IconButton>(
        find.byKey(const Key('superadmin-chat-context-toggle-collapsed')),
      );
      expect(collapsedButton.focusNode, isNotNull);
      collapsedButton.focusNode!.requestFocus();
      await tester.pump();
      expect(collapsedButton.focusNode!.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final expandedButton = tester.widget<IconButton>(
        find.byKey(const Key('superadmin-chat-context-toggle-expanded')),
      );
      expect(expandedButton.focusNode, isNotNull);
      expect(expandedButton.focusNode!.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final restoredButton = tester.widget<IconButton>(
        find.byKey(const Key('superadmin-chat-context-toggle-collapsed')),
      );
      expect(restoredButton.focusNode, same(collapsedButton.focusNode));
      expect(restoredButton.focusNode!.hasPrimaryFocus, isTrue);
    });
  }

  testWidgets('updates contextual metrics when the selected granularity changes', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('superadmin-chat-context-panel'));
    expect(find.descendant(of: panel, matching: find.text('Professores')), findsOne);
    expect(find.descendant(of: panel, matching: find.text('Funcionários')), findsNothing);

    await tester.tap(find.byKey(const Key('superadmin-chat-conversation-cambui')));
    await tester.pumpAndSettle();

    expect(find.descendant(of: panel, matching: find.text('Funcionários')), findsOne);
    expect(find.descendant(of: panel, matching: find.text('Professores')), findsNothing);
  });

  testWidgets('groups the desktop inbox and preserves the thread while collapsing it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();

    final inbox = find.byKey(const Key('superadmin-chat-inbox'));
    expect(find.descendant(of: inbox, matching: find.text('Grupos')), findsOne);
    expect(find.descendant(of: inbox, matching: find.text('Pessoas')), findsOne);
    await tester.tap(find.descendant(of: inbox, matching: find.text('Grupos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-conversation-girassol')), findsNothing);
    await tester.tap(find.descendant(of: inbox, matching: find.text('Unidade Cambuí')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Recolher conversas'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-inbox-rail')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right))
          .focusNode
          ?.hasPrimaryFocus,
      isTrue,
    );
    final selectedRailConversation = find.byKey(
      const Key('superadmin-chat-rail-conversation-cambui'),
    );
    expect(selectedRailConversation, findsOne);
    expect(
      tester.getSemantics(selectedRailConversation).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const Key('superadmin-chat-rail-conversation-cambui-surface')),
                  )
                  .decoration!
              as BoxDecoration)
          .color,
      CoeloTheme.light.colorScheme.primaryContainer,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-chat-thread')),
        matching: find.text('Unidade Cambuí'),
      ),
      findsWidgets,
    );

    await tester.tap(find.byTooltip('Expandir conversas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-conversation-girassol')), findsNothing);
    semantics.dispose();
  });

  testWidgets('opens contextual profile and hierarchical recipient selection', (tester) async {
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
    expect(find.byType(SuperadminChatRecipientPicker), findsOne);
    expect(find.text('Pesquisar pessoa · Acesso auditado'), findsOne);
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      CoeloTheme.light.colorScheme.surface,
    );
    final closeButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close_rounded),
    );
    expect(
      closeButton.style?.backgroundColor?.resolve({WidgetState.focused}),
      CoeloTheme.light.colorScheme.errorContainer,
    );
    expect(closeButton.style?.overlayColor?.resolve({WidgetState.focused}), Colors.transparent);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Centro Horizonte'));
    await tester.pump();
    expect(find.text('1 destinatário selecionado'), findsOne);

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

  testWidgets('confirms a bulk local demonstration and restores focus to its launcher', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();

    final launcher = find.descendant(
      of: find.byKey(const Key('superadmin-chat-inbox')),
      matching: find.widgetWithIcon(IconButton, Icons.edit_outlined),
    );
    final launcherButton = tester.widget<IconButton>(launcher);
    expect(launcherButton.focusNode, isNotNull);
    launcherButton.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selecionar todos'));
    await tester.pump();
    expect(find.text('4 destinatários selecionados'), findsOne);
    await tester.tap(find.text('Revisar envio'));
    await tester.pumpAndSettle();
    expect(find.text('Demonstração local'), findsOne);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar demonstração'));
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminChatRecipientPicker), findsNothing);
    expect(find.text('Envio em massa · 4 destinatários'), findsOne);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Demonstração local · nenhum envio real foi realizado.'),
      ),
      findsOne,
    );
    expect(launcherButton.focusNode!.hasPrimaryFocus, isTrue);

    await _selectScopeOption(tester, filterId: 'state', option: 'CE');
    await _selectScopeOption(tester, filterId: 'institution', option: 'Centro Horizonte');
    expect(find.byKey(const Key('superadmin-chat-conversation-bulk-local-1')), findsOne);
    await tester.tap(find.byKey(const Key('superadmin-chat-conversation-bulk-local-1')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-chat-thread')),
        matching: find.text('Centro Horizonte · 4 destinatários · Demonstração local'),
      ),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape cancels recipient selection and restores launcher focus', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();

    final launcher = find.descendant(
      of: find.byKey(const Key('superadmin-chat-inbox')),
      matching: find.widgetWithIcon(IconButton, Icons.edit_outlined),
    );
    final launcherButton = tester.widget<IconButton>(launcher);
    launcherButton.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminChatRecipientPicker), findsOne);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminChatRecipientPicker), findsNothing);
    expect(find.byKey(const Key('superadmin-chat-conversation-bulk-local-1')), findsNothing);
    expect(launcherButton.focusNode!.hasPrimaryFocus, isTrue);
  });

  testWidgets('opens a local activity conversation with its own unread-free message', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();
    await _createLocalActivityConversation(tester);

    await tester.tap(find.byKey(const Key('superadmin-chat-conversation-bulk-local-1')));
    await tester.pumpAndSettle();

    final thread = find.byKey(const Key('superadmin-chat-thread'));
    final bubbles = find.descendant(of: thread, matching: find.byType(CoeloMessageBubble));
    expect(bubbles, findsOne);
    final bubble = tester.widget<CoeloMessageBubble>(bubbles);
    expect(
      bubble.body,
      'Demonstração local · mensagem preparada para Natação; nenhum envio real foi realizado.',
    );
    expect(bubble.direction, CoeloMessageDirection.sent);
    expect(bubble.contextLabel, 'Demonstração local');
    expect(bubble.authorLabel, isNull);
    expect(bubble.childLabels, isEmpty);
    expect(bubble.deliveryState, CoeloMessageDeliveryState.none);
    expect(find.descendant(of: thread, matching: find.text('Marina · Professora')), findsNothing);
    expect(find.descendant(of: thread, matching: find.text('Turma Girassol')), findsNothing);

    await tester.enterText(
      find.descendant(of: thread, matching: find.byType(TextField)),
      'Outra nota local',
    );
    await tester.pump();
    await tester.tap(find.descendant(of: thread, matching: find.byTooltip('Enviar mensagem')));
    await tester.pump(const Duration(milliseconds: 1400));

    final updatedBubbles = tester.widgetList<CoeloMessageBubble>(
      find.descendant(of: thread, matching: find.byType(CoeloMessageBubble)),
    );
    expect(updatedBubbles, hasLength(2));
    expect(
      updatedBubbles.every((message) => message.deliveryState == CoeloMessageDeliveryState.none),
      isTrue,
    );
    expect(find.descendant(of: thread, matching: find.text('Marina · Professora')), findsNothing);
  });

  testWidgets('keeps a local activity visible under compatible ancestor filters', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();
    await _createLocalActivityConversation(tester);

    const localConversation = Key('superadmin-chat-conversation-bulk-local-1');
    expect(find.byKey(localConversation), findsOne);
    for (final (filterId, option) in [
      ('concept', 'Atividades'),
      ('state', 'CE'),
      ('institution', 'Centro Horizonte'),
      ('unit', 'Unidade Cambuí'),
      ('group', 'Turma Girassol'),
      ('activity', 'Natação'),
    ]) {
      await _selectScopeOption(tester, filterId: filterId, option: option);
      expect(find.byKey(localConversation), findsOne, reason: '$filterId: $option');
    }
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
      CoeloTheme.light.colorScheme.primary,
    );
    expect(
      tester.widget<Text>(find.text('Mensagens')).style?.color,
      CoeloTheme.light.colorScheme.onPrimary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.send_outlined)).color,
      CoeloTheme.light.colorScheme.onPrimary,
    );

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    tester
        .widget<InkWell>(find.descendant(of: launcherSurface, matching: find.byType(InkWell)))
        .focusNode!
        .requestFocus();
    await tester.pump();
    await mouse.moveTo(tester.getCenter(launcherSurface));
    await tester.pump();
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(
      (tester.widget<Container>(launcherSurface).decoration as BoxDecoration).color,
      CoeloTheme.light.colorScheme.primary,
    );
    expect(
      tester.widget<Text>(find.text('Mensagens')).style?.color,
      CoeloTheme.light.colorScheme.onPrimary,
    );

    await tester.tap(find.text('Mensagens'));
    await tester.pumpAndSettle();
    expect(find.text('Conversas'), findsOne);
    final launcherHeader = find.byKey(const Key('superadmin-chat-launcher-header'));
    expect(tester.getSize(launcherHeader).height, greaterThanOrEqualTo(72));
    final launcherInbox = find.byKey(const Key('superadmin-chat-launcher-inbox'));
    expect(
      find.descendant(of: launcherInbox, matching: find.widgetWithText(ExpansionTile, 'Grupos')),
      findsOne,
    );
    expect(
      find.descendant(of: launcherInbox, matching: find.widgetWithText(ExpansionTile, 'Pessoas')),
      findsOne,
    );
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

    expect(
      tester.getBottomLeft(find.text('Voltar à tela anterior')).dy,
      lessThanOrEqualTo(900 - CoeloSize.touchMin - CoeloSpacing.space8),
    );
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
    expect(item.style?.foregroundColor?.resolve({WidgetState.hovered}), colors.primary);
  });

  testWidgets('shows the closed scope filter focus with a primary two-pixel border', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(const SuperadminChatPage(logout: _logout)));
    await tester.pumpAndSettle();

    final filter = find.byKey(const Key('superadmin-chat-filter-state'));
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'CE'), findsNothing);

    final materials = tester
        .widgetList<Material>(
          find.ancestor(
            of: find.descendant(of: filter, matching: find.byType(InkWell)),
            matching: find.byType(Material),
          ),
        )
        .where((material) => material.shape is StadiumBorder)
        .toList(growable: false);
    expect(materials, hasLength(1));
    final material = materials.single;
    final side = (material.shape! as StadiumBorder).side;
    expect(side.color, CoeloTheme.light.colorScheme.primary);
    expect(side.width, 2);
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

  testWidgets('adds local-demo audio immediately without sending or delivery state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Scaffold(body: SuperadminChatThreadBody(conversation: _localDemoConversation))),
    );

    await tester.tap(find.byTooltip('Gravar áudio'));
    await tester.pump();

    expect(find.text('Demonstração local · mensagem de áudio · 0:08'), findsOne);
    expect(find.textContaining('Enviando'), findsNothing);
    expect(find.text('Gravando áudio…'), findsNothing);
    final bubbles = tester.widgetList<CoeloMessageBubble>(find.byType(CoeloMessageBubble)).toList();
    expect(bubbles, hasLength(2));
    expect(bubbles.last.deliveryState, CoeloMessageDeliveryState.none);
    expect(bubbles.last.authorLabel, isNull);

    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.byType(CoeloMessageBubble), findsNWidgets(2));
    expect(find.text('Marina · Professora'), findsNothing);
  });

  testWidgets('adds local-demo media immediately without sending or delivery state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Scaffold(body: SuperadminChatThreadBody(conversation: _localDemoConversation))),
    );

    await tester.tap(find.byTooltip('Adicionar mídia'));
    await tester.pump();

    expect(find.text('Demonstração local · imagem anexada'), findsOne);
    expect(find.textContaining('Enviando'), findsNothing);
    expect(find.text('Carregando mídia… 48%'), findsNothing);
    final bubbles = tester.widgetList<CoeloMessageBubble>(find.byType(CoeloMessageBubble)).toList();
    expect(bubbles, hasLength(2));
    expect(bubbles.last.deliveryState, CoeloMessageDeliveryState.none);
    expect(bubbles.last.authorLabel, isNull);

    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.byType(CoeloMessageBubble), findsNWidgets(2));
    expect(find.text('Marina · Professora'), findsNothing);
  });

  testWidgets('keeps approved viewports usable at 200 percent text', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [1440.0, 1024.0, 768.0, 375.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(width),
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SuperadminChatPage(logout: _logout),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Turma Girassol'), findsWidgets);
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

const _localDemoConversation = SuperadminChatConversation(
  id: 'local-demo',
  title: 'Natação',
  initials: 'NA',
  preview: 'Demonstração local',
  timestamp: 'Agora',
  context: 'Centro Horizonte · Demonstração local',
  institution: 'Centro Horizonte',
  targetKind: CoeloAdminContextKind.activity,
  metrics: [SuperadminChatMetric('Mensagens', 1)],
  localInitialMessage: 'Demonstração local · nenhum envio real foi realizado.',
);

Widget _app(Widget child) {
  return MaterialApp(theme: CoeloTheme.light, home: child);
}

Future<void> _createLocalActivityConversation(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Nova conversa'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile, 'Natação'));
  await tester.pump();
  await tester.tap(find.text('Revisar envio'));
  await tester.pumpAndSettle();
  expect(find.text('Centro Horizonte / Unidade Cambuí / Turma Girassol / Natação'), findsOne);
  await tester.tap(find.widgetWithText(FilledButton, 'Confirmar demonstração'));
  await tester.pumpAndSettle();
}

Future<void> _selectScopeOption(
  WidgetTester tester, {
  required String filterId,
  required String option,
}) async {
  await tester.tap(find.byKey(Key('superadmin-chat-filter-$filterId')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MenuItemButton, option));
  await tester.pumpAndSettle();
}
