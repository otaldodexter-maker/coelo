import 'dart:ui' show PointerDeviceKind;
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_context_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [1440.0, 1024.0, 768.0, 375.0]) {
    testWidgets('uses approved responsive composition at ${width.toInt()}px', (tester) async {
      _viewport(tester, width);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
      if (width == 1440) {
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
        expect(find.byType(SuperadminChatContextPanel), findsOne);
      } else if (width == 1024) {
        expect(find.byKey(const Key('superadmin-chat-rail')), findsNothing);
        expect(find.byTooltip('Voltar para conversas'), findsOne);
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
        await tester.tap(find.byTooltip('Ver informações do perfil'));
        await tester.pumpAndSettle();
        expect(find.byType(SuperadminChatContextPanel), findsOne);
      } else if (width == 768) {
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
        await tester.tap(find.byTooltip('Voltar para conversas'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
      } else {
        expect(find.byKey(const Key('superadmin-chat-inbox')), findsOne);
        await tester.tap(find.byKey(const Key('superadmin-chat-conversation-girassol')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('uses three audiences and a separate action strip', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-search')), findsOne);
    for (final label in ['Todos', 'Institucional', 'Pessoas']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byKey(const Key('superadmin-chat-action-create-group')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-action-new-message')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-action-filter')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-new-message')), findsNothing);
    expect(find.text('Envio em massa'), findsNothing);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('lays out quick inbox filters without horizontal scrolling at ${width.toInt()}px', (
      tester,
    ) async {
      _viewport(tester, width);
      await tester.pumpWidget(_app(textScale: 2));
      await tester.pumpAndSettle();

      if (width == 768 || width == 1024) {
        await tester.tap(find.byTooltip('Voltar para conversas'));
        await tester.pumpAndSettle();
      }

      final filters = find.byKey(const Key('superadmin-chat-quick-filters'));
      expect(filters, findsOneWidget);
      expect(find.descendant(of: filters, matching: find.byType(Wrap)), findsOneWidget);
      expect(
        find.descendant(of: filters, matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps filter choices as a draft until applying', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-chat-action-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Filtros institucionais'), findsOne);
    expect(find.byKey(const Key('superadmin-chat-hierarchy-search')), findsOne);
    expect(find.text('Selecionar todos'), findsOne);
    final dialog = find.byKey(const Key('superadmin-chat-dialog-frame'));
    expect(find.descendant(of: dialog, matching: find.text('Instituições')), findsOne);
    expect(find.descendant(of: dialog, matching: find.text('Unidades')), findsOne);
    expect(find.descendant(of: dialog, matching: find.text('Turmas')), findsOne);
    expect(find.descendant(of: dialog, matching: find.text('Atividades')), findsOne);
    expect(find.descendant(of: dialog, matching: find.text('Pessoas')), findsOne);
    await tester.tap(find.descendant(of: dialog, matching: find.text('Centro Horizonte')).last);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Centro Horizonte'), findsOne);
  });

  testWidgets('Shift Enter does not send and Enter sends the multiline composer value', (
    tester,
  ) async {
    _viewport(tester, 768);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('superadmin-chat-composer-field'));

    await tester.enterText(field, 'Primeira linha');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(find.text('Mensagem simulada. Nada foi enviado.'), findsNothing);
    expect(tester.widget<TextField>(field).controller!.text, 'Primeira linha');

    // The test text input represents the newline inserted by the platform after
    // the composer leaves Shift+Enter unhandled.
    await tester.enterText(field, 'Primeira linha\nSegunda linha');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('Primeira linha\nSegunda linha'), findsOne);
    expect(find.text('Mensagem simulada. Nada foi enviado.'), findsNothing);
  });

  testWidgets('writes, selects and reviews private bulk deliveries', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-chat-action-new-message')));
    await tester.pumpAndSettle();
    expect(find.text('Nova mensagem'), findsWidgets);
    expect(find.text('Escolha com quem quer falar'), findsOne);
    await tester.tap(find.text('Envio em massa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Escreva antes'), findsOne);
    await tester.enterText(
      find.byKey(const Key('superadmin-chat-flow-message')),
      'Comunicado local',
    );
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar todos'));
    await tester.pump();
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar envio privado'), findsOne);
    await tester.tap(find.text('Simular envio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('entregas privadas simuladas'), findsOne);
  });

  testWidgets('pins a conversation in the current audience', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ações de Turma Girassol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixar'));
    await tester.pumpAndSettle();

    expect(find.text('Fixados'), findsOne);
  });

  testWidgets('keeps academic conversation actions explicit in the local demo', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ações de Turma Girassol'));
    await tester.pumpAndSettle();

    expect(find.text('Fixar'), findsOneWidget);
    expect(find.text('Excluir conversa'), findsOne);
    expect(find.text('Excluir grupo'), findsNothing);
  });

  testWidgets('uses the neutral rounded action menu and canonical delete dialog', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ações da conversa'));
    await tester.pumpAndSettle();
    expect(find.text('Fixar'), findsWidgets);
    expect(find.text('Excluir conversa'), findsOne);

    await tester.tap(find.text('Excluir conversa'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-dialog-frame')), findsOne);
    expect(find.byTooltip('Fechar'), findsOne);
    expect(find.byKey(const Key('superadmin-chat-dialog-footer-divider')), findsNothing);
    final deleteWidth = tester.getSize(find.widgetWithText(FilledButton, 'Excluir conversa')).width;
    final cancelWidth = tester.getSize(find.widgetWithText(TextButton, 'Cancelar')).width;
    expect(deleteWidth, closeTo(cancelWidth, 0.01));
    expect(deleteWidth, greaterThan(190));
  });

  testWidgets('cancelling deletion preserves a locally created group', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _createLocalGroup(tester, 'Grupo para cancelar');
    expect(find.text('Grupo para cancelar'), findsWidgets);

    await tester.tap(find.byTooltip('Ações da conversa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir grupo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Grupo para cancelar'), findsWidgets);
  });

  testWidgets('confirming deletion removes only the locally created group', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _createLocalGroup(tester, 'Grupo para excluir');
    expect(find.text('Turma Girassol'), findsWidgets);

    await tester.tap(find.byTooltip('Ações da conversa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir grupo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir grupo'));
    await tester.pumpAndSettle();

    expect(find.text('Grupo para excluir'), findsNothing);
    expect(find.text('Turma Girassol'), findsWidgets);
  });

  testWidgets('creates a reviewed cross-tenant group only in local state', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-chat-action-create-group')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-dialog-frame')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-hierarchy-search')), findsOne);
    expect(find.text('Selecionar todos'), findsOne);
    expect(find.byKey(const Key('superadmin-chat-dialog-footer-divider')), findsNothing);
    expect(find.byKey(const Key('superadmin-chat-dialog-header-divider')), findsNothing);
    await tester.enterText(find.byKey(const Key('superadmin-chat-group-name')), 'Equipe integrada');
    await tester.tap(find.byKey(const Key('superadmin-chat-hierarchy-centro-horizonte')));
    await tester.tap(find.byKey(const Key('superadmin-chat-hierarchy-instituto-aurora')));
    await tester.pump();
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar grupo'), findsOne);
    expect(find.textContaining('múltiplas origens'), findsOne);
    await tester.tap(find.text('Criar grupo local'));
    await tester.pumpAndSettle();

    expect(find.text('Equipe integrada'), findsWidgets);
    expect(find.text('Grupos'), findsOne);
  });

  testWidgets('uses one profile toggle and the canonical red close action', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ver informações do perfil'), findsOne);
    expect(find.byTooltip('Mostrar contexto'), findsNothing);
    final closeButton = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('Fechar contexto'), matching: find.byType(IconButton)),
    );
    expect(closeButton.color, CoeloTheme.light.colorScheme.error);
  });

  testWidgets('wraps the chat workspace in the canonical outlined surface', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const Key('superadmin-chat-workspace-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.lg));
  });

  testWidgets('supports 200 percent text without overflow', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app(textScale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-conversation-girassol')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver informações do perfil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers equivalent flag selection by touch, keyboard and mouse', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final flag = find.byKey(const Key('superadmin-chat-flag-girassol'));
    await tester.tap(flag);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Urgente'), findsOneWidget);
    expect(find.textContaining('Vermelho'), findsNothing);
    expect(find.bySemanticsLabel('Bandeira vermelha: Urgente'), findsOneWidget);
    final urgentItem = find.widgetWithText(MenuItemButton, 'Urgente');
    final urgentIcon = tester.widget<Icon>(
      find.descendant(of: urgentItem, matching: find.byType(Icon)),
    );
    expect(urgentIcon.color, CoeloTheme.light.colorScheme.error);

    await tester.tap(find.text('Aguardando retorno'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip?.startsWith('Aguardando retorno em Turma Girassol') == true,
      ),
      findsOneWidget,
    );

    final flagButton = find.descendant(of: flag, matching: find.byType(IconButton));
    Focus.of(tester.element(flagButton)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Aguardando retorno'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(flag));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Aguardando retorno'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await mouse.moveTo(const Offset(8, 8));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(flag));
    await mouse.down(tester.getCenter(flag));
    await mouse.up();
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip?.startsWith('Sens\u00edvel em') == true,
      ),
      findsOneWidget,
    );
  });
}

Widget _app({double textScale = 1}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const SuperadminChatPage(logout: _logout),
  );
}

void _viewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _createLocalGroup(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('superadmin-chat-action-create-group')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('superadmin-chat-group-name')), name);
  await tester.tap(find.byKey(const Key('superadmin-chat-hierarchy-centro-horizonte')));
  await tester.pump();
  await tester.tap(find.text('Revisar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Criar grupo local'));
  await tester.pumpAndSettle();
}

Future<LogoutResult> _logout() async => const LogoutResult.success();
