import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fails closed as unavailable without response API or success state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormResponsePage()));

    expect(find.byType(CoeloStatePanel), findsOneWidget);
    expect(find.text('Resposta de formulário indisponível'), findsOneWidget);
    expect(find.text('O envio de respostas está temporariamente indisponível.'), findsOneWidget);
    expect(find.byType(Form), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.textContaining('segredo'), findsNothing);
    expect(find.textContaining('sucesso'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
