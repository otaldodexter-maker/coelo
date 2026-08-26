import 'package:coelo_superadmin/features/forms/presentation/response/forms_test_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('is a static unavailable surface without API or success state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormsTestPage()));

    expect(find.text('Teste de formulário indisponível'), findsOneWidget);
    expect(find.textContaining('temporariamente indisponível'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
