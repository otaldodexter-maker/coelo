import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows label, error and picks a single date through the Coelo picker', (
    tester,
  ) async {
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CoeloDateField(
              labelText: 'Data de início',
              value: picked,
              errorText: picked == null ? 'Informe a data.' : null,
              onChanged: (value) => setState(() => picked = value),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Data de início'), findsOneWidget);
    expect(find.text('Informe a data.'), findsOneWidget);
    expect(find.text('Selecionar data'), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloDateRangePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.tap(find.text('${DateTime.now().day}').first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coelo-date-range-apply')));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.hour, 0);
    expect(find.text('Informe a data.'), findsNothing);
    expect(find.text(CoeloDateField.format(picked!)), findsOneWidget);
  });
}
