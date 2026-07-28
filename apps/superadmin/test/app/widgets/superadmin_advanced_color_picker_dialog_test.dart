import 'package:coelo_superadmin/app/widgets/superadmin_advanced_color_picker_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('exposes saturation-value and hue controls to focus, semantics and keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSuperadminAdvancedColorPicker(
                context,
                initialColor: const Color(0xFFD63C00),
                title: 'Cor da sigla',
              ),
              child: const Text('Abrir seletor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir seletor'));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();

    final area = find.byKey(const Key('advanced-color-picker-area'));
    final hue = find.byKey(const Key('advanced-color-picker-hue'));
    expect(area, findsOneWidget);
    expect(hue, findsOneWidget);
    expect(tester.getSize(area).width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(tester.getSize(area).height, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(tester.getSize(hue).height, greaterThanOrEqualTo(CoeloSize.touchMin));

    final saturationValueSemantics = find.bySemanticsLabel(RegExp('SaturaÃ§Ã£o e valor'));
    final hueSemantics = find.bySemanticsLabel(RegExp('Matiz'));
    expect(saturationValueSemantics, findsOneWidget);
    expect(hueSemantics, findsOneWidget);
    expect(
      tester.getSemantics(saturationValueSemantics),
      isSemantics(
        label: 'SaturaÃ§Ã£o e valor',
        hasEnabledState: true,
        isEnabled: true,
        isSlider: true,
        hasFocusAction: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    expect(
      tester.getSemantics(hueSemantics),
      isSemantics(
        label: 'Matiz',
        hasEnabledState: true,
        isEnabled: true,
        isSlider: true,
        hasFocusAction: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );

    expect(_focusRing(tester, 'advanced-color-picker-area-focus-ring').color, Colors.transparent);
    expect(_focusRing(tester, 'advanced-color-picker-hue-focus-ring').color, Colors.transparent);

    await tester.tap(area);
    await tester.pump();
    expect(tester.widget<Focus>(area).focusNode!.hasFocus, isTrue);
    expect(
      _focusRing(tester, 'advanced-color-picker-area-focus-ring'),
      BorderSide(color: Theme.of(tester.element(area)).colorScheme.primary, width: 2),
    );
    final areaHex = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isNot(areaHex));

    await tester.ensureVisible(hue);
    await tester.tap(hue);
    await tester.pump();
    expect(tester.widget<Focus>(hue).focusNode!.hasFocus, isTrue);
    expect(_focusRing(tester, 'advanced-color-picker-area-focus-ring').color, Colors.transparent);
    expect(
      _focusRing(tester, 'advanced-color-picker-hue-focus-ring'),
      BorderSide(color: Theme.of(tester.element(hue)).colorScheme.primary, width: 2),
    );
    final hueHex = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isNot(hueHex));

    final semanticHueHex = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    tester.semantics.increase(find.semantics.byLabel('Matiz'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isNot(semanticHueHex),
    );
    semantics.dispose();
  });
}

BorderSide _focusRing(WidgetTester tester, String key) {
  final decoration = tester.widget<DecoratedBox>(find.byKey(Key(key))).decoration as BoxDecoration;
  return (decoration.border! as Border).top;
}
