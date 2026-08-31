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

  testWidgets('autosave exposes one real state and reacts to editing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormResponsePage.development()));

    expect(find.text('Inicial'), findsOneWidget);
    expect(find.text('Alterado'), findsNothing);
    expect(find.text('Salvando'), findsNothing);
    expect(find.text('Salvo'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Resposta local');
    await tester.pump();
    expect(find.text('Alterado'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Salvando'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Salvo'), findsOneWidget);
  });

  testWidgets('development response preserves the selected form context', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FormResponsePage.development(formId: 'form-dev-02')),
    );

    expect(find.text('Enquete rápida sobre transporte'), findsOneWidget);
  });

  testWidgets('cancelar upload preserva a resposta e encerra o progresso local', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormResponsePage.development()));
    await tester.enterText(find.byType(TextFormField), 'Não perder');

    await tester.tap(find.text('Cancelar upload'));
    await tester.pump();

    expect(find.text('Upload cancelado'), findsOneWidget);
    expect(find.byKey(const Key('form-response-upload-progress')), findsNothing);
    expect(find.text('Não perder'), findsOneWidget);
  });
}
