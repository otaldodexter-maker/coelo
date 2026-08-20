import 'package:coelo_superadmin/features/forms/presentation/response/form_response_route_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens through the device secret store and keeps a missing API fail closed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormResponseRoutePage(api: null, occurrenceId: 'occurrence-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('O serviço de Formulários não está disponível.'), findsOneWidget);
  });
}
