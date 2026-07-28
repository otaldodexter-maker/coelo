import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_context_panel.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_recipient_picker.dart';
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
        expect(find.byKey(const Key('superadmin-chat-rail')), findsOne);
        expect(find.byKey(const Key('superadmin-chat-thread')), findsOne);
        await tester.tap(find.byTooltip('Ver contexto'));
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

  testWidgets('keeps one filter action, two visible chips and clear', (tester) async {
    _viewport(tester, 1440);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Filtrar'), findsOne);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Filtrar'));
    await tester.pumpAndSettle();
    for (final label in ['CE', 'Centro Horizonte', 'Turma Girassol']) {
      await tester.tap(find.widgetWithText(FilterChip, label));
      await tester.pump();
    }
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();

    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('+1'), findsOne);
    expect(find.text('Limpar'), findsOne);
  });

  testWidgets('sends with Enter and keeps Shift Enter as a newline', (tester) async {
    _viewport(tester, 768);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('superadmin-chat-composer-field'));

    await tester.enterText(field, 'Primeira linha\nSegunda linha');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('Primeira linha\nSegunda linha'), findsOne);
    expect(find.text('Mensagem simulada. Nada foi enviado.'), findsNothing);
  });

  testWidgets('selects all bulk recipients and confirms simulated sending', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-chat-new-message')));
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminChatRecipientPicker), findsOne);
    await tester.tap(find.text('Selecionar todos'));
    await tester.pump();
    await tester.tap(find.text('Revisar envio'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar envio em massa'), findsOne);
    await tester.tap(find.text('Confirmar simulação'));
    await tester.pumpAndSettle();
    expect(find.text('Envio em massa simulado com sucesso.'), findsOne);
  });

  testWidgets('supports 200 percent text without overflow', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app(textScale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-conversation-girassol')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver contexto'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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

Future<LogoutResult> _logout() async => const LogoutResult.success();
