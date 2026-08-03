import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_flow_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('divides two dialog actions equally on wide constraints', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Center(
          child: SizedBox(
            width: 480,
            child: SuperadminChatDialogActions(
              actions: [
                TextButton(onPressed: () {}, child: const Text('Cancelar')),
                FilledButton(onPressed: () {}, child: const Text('Confirmar')),
              ],
            ),
          ),
        ),
      ),
    );

    final cancel = tester.getSize(find.widgetWithText(TextButton, 'Cancelar'));
    final confirm = tester.getSize(find.widgetWithText(FilledButton, 'Confirmar'));
    expect(cancel.width, closeTo(confirm.width, 1));
  });

  testWidgets('stacks every action at full width on compact constraints', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Center(
          child: SizedBox(
            width: 280,
            child: SuperadminChatDialogActions(
              actions: [
                TextButton(onPressed: () {}, child: const Text('Voltar')),
                OutlinedButton(onPressed: () {}, child: const Text('Revisar')),
                FilledButton(onPressed: () {}, child: const Text('Salvar')),
              ],
            ),
          ),
        ),
      ),
    );

    final widths = <double>[
      tester.getSize(find.widgetWithText(TextButton, 'Voltar')).width,
      tester.getSize(find.widgetWithText(OutlinedButton, 'Revisar')).width,
      tester.getSize(find.widgetWithText(FilledButton, 'Salvar')).width,
    ];
    expect(widths.every((width) => width > 270), isTrue);
    expect(
      tester.getTopLeft(find.text('Salvar')).dy,
      lessThan(tester.getTopLeft(find.text('Voltar')).dy),
    );
  });
}
