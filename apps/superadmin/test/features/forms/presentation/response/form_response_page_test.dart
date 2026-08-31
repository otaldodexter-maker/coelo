import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('production preserves response composition with neutral disabled controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FormResponsePage()));

    expect(find.byKey(const Key('form-response-unavailable')), findsOneWidget);
    expect(find.text('Formulário sem dados disponíveis'), findsOneWidget);
    expect(find.text('Pesquisa das famílias'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).enabled, isFalse);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Revisar resposta')).onPressed,
      isNull,
    );
    expect(find.textContaining('segredo'), findsNothing);
    expect(find.textContaining('sucesso'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
