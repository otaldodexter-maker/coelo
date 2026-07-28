import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders continuous options with semantic selected styling', (tester) async {
    var value = 'Rascunho';
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: CoeloAdminSingleSelectField<String>(
              label: 'Status',
              value: value,
              options: const ['Rascunho', 'Ativa'],
              optionLabel: (option) => option,
              onChanged: (option) => setState(() => value = option),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rascunho'));
    await tester.pumpAndSettle();
    final selected = tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Rascunho'));
    final triggerWidth = tester.getSize(find.byType(InputDecorator)).width;
    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    expect(anchor.crossAxisUnconstrained, isFalse);
    expect(anchor.alignmentOffset, const Offset(0, CoeloSpacing.space1));
    expect(anchor.style!.minimumSize!.resolve({})!.width, triggerWidth);
    expect(anchor.style!.maximumSize!.resolve({})!.width, triggerWidth);
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, 'Rascunho'),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
    expect(
      selected.style!.backgroundColor!.resolve({}),
      CoeloTheme.light.colorScheme.primaryContainer,
    );

    await tester.tap(find.text('Ativa'));
    await tester.pumpAndSettle();
    expect(value, 'Ativa');
  });

  testWidgets('associates an error message with the trigger field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(
          body: CoeloAdminSingleSelectField<String>(
            label: 'Município',
            value: '',
            options: ['', 'Campinas'],
            optionLabel: _identity,
            onChanged: _ignore,
            errorText: 'Não foi possível carregar os municípios.',
          ),
        ),
      ),
    );

    final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.decoration.errorText, 'Não foi possível carregar os municípios.');
    expect(find.text('Não foi possível carregar os municípios.'), findsOneWidget);
  });

  testWidgets('disabled and loading states cannot change the selection', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              CoeloAdminSingleSelectField<String>(
                label: 'Desabilitado',
                value: 'A',
                options: const ['A', 'B'],
                optionLabel: _identity,
                onChanged: (_) => changes += 1,
                enabled: false,
              ),
              CoeloAdminSingleSelectField<String>(
                label: 'Carregando',
                value: 'A',
                options: const ['A', 'B'],
                optionLabel: _identity,
                onChanged: (_) => changes += 1,
                isLoading: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('A').first);
    await tester.tap(find.text('A').last);
    await tester.pump();
    expect(changes, 0);
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('offers internal search automatically for long option lists', (tester) async {
    final options = List.generate(27, (index) => 'UF ${index.toString().padLeft(2, '0')}');
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminSingleSelectField<String>(
            label: 'UF',
            value: options.first,
            options: options,
            optionLabel: _identity,
            onChanged: _ignore,
          ),
        ),
      ),
    );

    await tester.tap(find.text(options.first));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'UF 26');
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, 'UF 26'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'UF 00'), findsNothing);
  });

  testWidgets('opens from keyboard focus and returns selection focus to trigger', (tester) async {
    var value = 'Rascunho';
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: CoeloAdminSingleSelectField<String>(
              label: 'Status',
              value: value,
              options: const ['Rascunho', 'Ativa'],
              optionLabel: _identity,
              onChanged: (option) => setState(() => value = option),
            ),
          ),
        ),
      ),
    );

    final trigger = tester.widget<InkWell>(find.byType(InkWell));
    trigger.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Ativa'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, 'Ativa');
    expect(trigger.focusNode!.hasFocus, isTrue);
  });
}

String _identity(String value) => value;

void _ignore(String _) {}
