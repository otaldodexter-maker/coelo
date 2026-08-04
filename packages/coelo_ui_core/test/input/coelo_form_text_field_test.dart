import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the Coelo form anatomy across idle, hover and focus', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloFormTextField(
            controller: controller,
            labelText: 'E-mail',
            hintText: 'seu.email@coelo.me',
            prefixIcon: Icons.mail_outline_rounded,
          ),
        ),
      ),
    );

    final decoration = tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
    expect(decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
    expect(decoration.prefixIcon, isNotNull);
    expect(decoration.hintText, 'seu.email@coelo.me');

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(tester.widget<InputDecorator>(find.byType(InputDecorator)).isFocused, isTrue);
  });

  testWidgets('top-aligns the prefix icon only for multiline fields', (tester) async {
    final singleLineController = TextEditingController(text: 'Linha única');
    final multilineController = TextEditingController(text: 'Primeira linha\nSegunda linha');
    addTearDown(singleLineController.dispose);
    addTearDown(multilineController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              CoeloFormTextField(
                controller: singleLineController,
                labelText: 'Assunto',
                prefixIcon: Icons.title_rounded,
              ),
              CoeloFormTextField(
                controller: multilineController,
                labelText: 'Descrição',
                prefixIcon: Icons.notes_rounded,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );

    final singleLineField = find.byType(TextFormField).first;
    final multilineField = find.byType(TextFormField).last;
    final singleLineEditable = find.descendant(
      of: singleLineField,
      matching: find.byType(EditableText),
    );
    final multilineEditable = find.descendant(
      of: multilineField,
      matching: find.byType(EditableText),
    );

    expect(
      tester.getCenter(find.byIcon(Icons.title_rounded)).dy,
      closeTo(tester.getCenter(singleLineEditable).dy, 1),
    );
    expect(
      tester.getTopLeft(find.byIcon(Icons.notes_rounded)).dy,
      closeTo(tester.getTopLeft(multilineEditable).dy, 1),
    );
    expect(
      tester
          .widget<TextField>(find.descendant(of: multilineField, matching: find.byType(TextField)))
          .textAlignVertical,
      TextAlignVertical.top,
    );
  });

  testWidgets('forwards input formatters and contains multiline content at 200 percent', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: 'Bio preenchida em duas linhas\nsem sair da caixa',
    );
    addTearDown(controller.dispose);
    final formatter = FilteringTextInputFormatter.digitsOnly;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SizedBox(
              width: 500,
              child: CoeloFormTextField(
                controller: controller,
                labelText: 'Bio',
                prefixIcon: Icons.notes_rounded,
                maxLines: 4,
                inputFormatters: [formatter],
              ),
            ),
          ),
        ),
      ),
    );

    final field = find.byType(TextFormField);
    final editable = find.descendant(of: field, matching: find.byType(EditableText));
    expect(
      tester
          .widget<TextField>(find.descendant(of: field, matching: find.byType(TextField)))
          .inputFormatters,
      contains(formatter),
    );
    expect(tester.getTopLeft(editable).dy, greaterThanOrEqualTo(tester.getTopLeft(field).dy));
    final icon = find.byIcon(Icons.notes_rounded);
    expect(tester.getBottomRight(editable).dy, lessThanOrEqualTo(tester.getBottomRight(field).dy));
    expect(tester.getRect(icon).right, lessThanOrEqualTo(tester.getRect(editable).left));
    expect(tester.getRect(editable).right, lessThanOrEqualTo(tester.getRect(field).right));
  });
}
