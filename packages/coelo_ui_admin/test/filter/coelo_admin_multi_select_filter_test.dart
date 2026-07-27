import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('searches, selects multiple values, clears and applies a copy', (tester) async {
    final selected = <String>{'SP'};
    Set<String>? result;
    await _pumpFilter(tester, selected: selected, onChanged: (value) => result = value);

    await tester.tap(find.text('SP — São Paulo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rio');
    await tester.pump();

    expect(find.text('RJ — Rio de Janeiro'), findsOneWidget);
    expect(find.text('AC — Acre'), findsNothing);
    await tester.tap(find.text('RJ — Rio de Janeiro'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Aplicar')).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Limpar')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('SP — São Paulo').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Aplicar')).onPressed,
      isNull,
    );
    await tester.tap(find.text('AC — Acre'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Aplicar')).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(selected, {'SP'});
    expect(result, {'SP', 'AC'});
    expect(identical(result, selected), isFalse);
  });

  testWidgets('Escape closes the menu and restores focus to the trigger', (tester) async {
    await _pumpFilter(tester);
    final trigger = find.text('Todas as UFs');

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Aplicar'), findsNothing);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(of: trigger, matching: find.byType(OutlinedButton)),
    );
    expect(button.focusNode?.hasFocus, isTrue);
  });

  testWidgets('uses canonical open colors and border for the trigger', (tester) async {
    final triggerKey = GlobalKey();
    await _pumpFilter(tester, key: triggerKey);

    await tester.tap(find.text('Todas as UFs'));
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.descendant(of: find.byKey(triggerKey), matching: find.byType(OutlinedButton)),
    );
    final colors = CoeloTheme.light.colorScheme;
    const openStates = <WidgetState>{};

    expect(button.style?.backgroundColor?.resolve(openStates), colors.primaryContainer);
    expect(button.style?.foregroundColor?.resolve(openStates), colors.primary);
    expect(button.style?.side?.resolve(openStates)?.width, 2);
  });

  testWidgets('uses approved hover and focus colors for options', (tester) async {
    await _pumpFilter(tester);
    await tester.tap(find.text('Todas as UFs'));
    await tester.pumpAndSettle();

    final option = find.widgetWithText(MenuItemButton, 'AC — Acre');
    final button = tester.widget<MenuItemButton>(option);
    final colors = CoeloTheme.light.colorScheme;

    expect(button.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(button.style?.foregroundColor?.resolve({WidgetState.focused}), colors.primary);
  });

  testWidgets('preserves approved menu elevation, search icon and autofocus', (tester) async {
    await _pumpFilter(tester);
    await tester.tap(find.text('Todas as UFs'));
    await tester.pumpAndSettle();

    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    final field = tester.widget<TextField>(find.byType(TextField));

    expect(anchor.style?.elevation?.resolve({}), 6);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('omits internal search when no search hint is supplied', (tester) async {
    await _pumpFilter(tester, searchHintText: null);

    await tester.tap(find.text('Todas as UFs'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('AC — Acre'), findsOneWidget);
  });
}

Future<void> _pumpFilter(
  WidgetTester tester, {
  Key? key,
  Set<String> selected = const {},
  ValueChanged<Set<String>>? onChanged,
  String? searchHintText = 'Buscar UF',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 180,
            child: CoeloAdminMultiSelectFilter<String>(
              key: key,
              label: 'Todas as UFs',
              options: const ['SP', 'RJ', 'AC'],
              selectedValues: selected,
              optionLabel: (value) => switch (value) {
                'SP' => 'SP — São Paulo',
                'RJ' => 'RJ — Rio de Janeiro',
                _ => 'AC — Acre',
              },
              onChanged: onChanged ?? (_) {},
              searchHintText: searchHintText,
            ),
          ),
        ),
      ),
    ),
  );
}
