import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_recipient_picker.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects one recipient and restores review focus after cancellation', (tester) async {
    await _pumpPicker(tester);

    final group = find.widgetWithText(CheckboxListTile, 'Turma Girassol');
    expect(tester.getSize(group).height, greaterThanOrEqualTo(CoeloSize.touchMin));

    await tester.tap(group);
    await tester.pump();
    expect(find.text('1 destinatário selecionado'), findsOne);

    await tester.tap(find.text('Revisar envio'));
    await tester.pumpAndSettle();

    expect(find.text('Demonstração local'), findsOne);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
    expect(dialog.surfaceTintColor, Colors.transparent);
    final closeButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close_rounded),
    );
    expect(
      tester.getSize(find.widgetWithIcon(IconButton, Icons.close_rounded)).width,
      greaterThanOrEqualTo(CoeloSize.touchMin),
    );
    expect(
      closeButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.errorContainer,
    );
    expect(closeButton.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Demonstração local'), findsNothing);
    expect(find.text('1 destinatário selecionado'), findsOne);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Revisar envio'))
          .focusNode
          ?.hasPrimaryFocus,
      isTrue,
    );

    await tester.tap(find.text('Revisar envio'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Demonstração local'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Revisar envio'))
          .focusNode
          ?.hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('selects all recipients, reviews the quantity and confirms a local result', (
    tester,
  ) async {
    List<CoeloAdminContextOption>? confirmed;
    await _pumpPicker(tester, onConfirmed: (selection) => confirmed = selection);

    await tester.tap(find.text('Selecionar todos'));
    await tester.pump();

    expect(find.text('4 destinatários selecionados'), findsOne);
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((tile) => tile.value == true),
      isTrue,
    );

    await tester.tap(find.text('Revisar envio'));
    await tester.pumpAndSettle();

    expect(find.text('Demonstração local'), findsOne);
    expect(find.text('4 destinatários selecionados'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar demonstração'));
    await tester.pumpAndSettle();

    expect(confirmed, isNotNull);
    expect(confirmed, hasLength(4));
    expect(confirmed!.map((option) => option.id), [
      'centro-horizonte',
      'cambui',
      'girassol',
      'natacao',
    ]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('stays usable at 200 percent text in ${brightness.name} theme', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpPicker(
        tester,
        theme: brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark,
        textScaler: const TextScaler.linear(2),
      );

      await tester.tap(find.text('Selecionar todos'));
      await tester.pump();
      await tester.tap(find.text('Revisar envio'));
      await tester.pumpAndSettle();

      expect(find.text('Demonstração local'), findsOne);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  ValueChanged<List<CoeloAdminContextOption>>? onConfirmed,
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 620,
          height: 720,
          child: SuperadminChatRecipientPicker(
            options: superadminChatContextOptions,
            onConfirmed: onConfirmed ?? (_) {},
          ),
        ),
      ),
    ),
  );
}
