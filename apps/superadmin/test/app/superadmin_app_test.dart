import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on the bootstrap route with Coelo themes', (tester) async {
    await tester.pumpWidget(const SuperadminApp());
    await tester.pumpAndSettle();

    expect(find.text('Superadmin Coelo'), findsOneWidget);
    expect(find.text('Operacao interna'), findsOneWidget);
    expect(find.text('Base inicial pronta'), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, CoeloPalette.orange500);
    expect(app.darkTheme?.colorScheme.primary, CoeloPalette.orange300);
    expect(app.themeMode, ThemeMode.system);
  });
}
