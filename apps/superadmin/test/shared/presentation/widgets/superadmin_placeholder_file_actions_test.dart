import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_placeholder_file_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes import and export without pretending they already execute', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(body: SuperadminPlaceholderFileActions(resourceLabel: 'formulários')),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar arquivo'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);

    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Exportação CSV de formulários estará disponível em breve.'), findsOneWidget);
  });
}
