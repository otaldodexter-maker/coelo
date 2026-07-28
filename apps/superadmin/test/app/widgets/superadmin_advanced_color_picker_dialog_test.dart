import 'package:coelo_superadmin/app/widgets/superadmin_advanced_color_picker_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows equal footer actions and discards a changed color when cancelled', (
    tester,
  ) async {
    Color? result;
    late BuildContext buttonContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              buttonContext = context;
              return TextButton(
                onPressed: () async {
                  result = await showSuperadminAdvancedColorPicker(
                    buttonContext,
                    initialColor: const Color(0xFFD63C00),
                    title: 'Cor principal da marca',
                  );
                },
                child: const Text('Abrir seletor'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir seletor'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('advanced-color-picker-dialog')), findsOneWidget);
    expect(find.byKey(const Key('advanced-color-picker-cancel')), findsOneWidget);
    expect(find.byKey(const Key('advanced-color-picker-apply')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('advanced-color-picker-cancel'))).width,
      tester.getSize(find.byKey(const Key('advanced-color-picker-apply'))).width,
    );

    await tester.enterText(find.byType(TextField), '#123456');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '#123456');

    await tester.tap(find.byKey(const Key('advanced-color-picker-cancel')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
