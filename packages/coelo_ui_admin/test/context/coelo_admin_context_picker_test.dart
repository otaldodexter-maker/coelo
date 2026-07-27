import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects an institution without forcing navigation to its last descendant', (
    tester,
  ) async {
    List<CoeloAdminContextOption>? selectedPath;

    await tester.pumpWidget(
      _app(CoeloAdminContextPicker(options: _options, onSelected: (path) => selectedPath = path)),
    );

    await tester.tap(find.byKey(const Key('coelo-context-select-institution')));
    await tester.pump();

    expect(find.text('Centro Horizonte'), findsWidgets);
    expect(find.text('Centro Horizonte / Unidade Cambuí'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Selecionar contexto'), findsOne);

    await tester.tap(find.widgetWithText(FilledButton, 'Selecionar contexto'));
    expect(selectedPath?.map((item) => item.label), ['Centro Horizonte']);
  });

  testWidgets('navigates the hierarchy and confirms the complete context path', (tester) async {
    List<CoeloAdminContextOption>? selectedPath;

    await tester.pumpWidget(
      _app(CoeloAdminContextPicker(options: _options, onSelected: (path) => selectedPath = path)),
    );

    expect(find.textContaining('2 unidades'), findsOne);
    await tester.tap(find.byKey(const Key('coelo-context-open-institution')));
    await tester.pump();
    expect(find.text('Centro Horizonte', skipOffstage: false), findsWidgets);
    expect(find.textContaining('2 grupos'), findsOne);

    await tester.tap(find.byKey(const Key('coelo-context-open-unit-cambui')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('coelo-context-open-group-girassol')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('coelo-context-select-activity-swim')));
    await tester.pump();

    expect(find.text('Centro Horizonte / Unidade Cambuí / Turma Girassol / Natação'), findsOne);
    await tester.tap(find.widgetWithText(FilledButton, 'Selecionar contexto'));

    expect(selectedPath?.map((item) => item.label), [
      'Centro Horizonte',
      'Unidade Cambuí',
      'Turma Girassol',
      'Natação',
    ]);
  });

  testWidgets('filters only the options at the current hierarchy level', (tester) async {
    await tester.pumpWidget(_app(CoeloAdminContextPicker(options: _options, onSelected: (_) {})));

    await tester.tap(find.byKey(const Key('coelo-context-open-institution')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Taquaral');
    await tester.pump();

    expect(find.text('Unidade Taquaral'), findsOne);
    expect(find.text('Unidade Cambuí'), findsNothing);
    expect(find.text('Centro Horizonte'), findsWidgets);
  });
}

const _options = [
  CoeloAdminContextOption(
    id: 'institution',
    label: 'Centro Horizonte',
    kind: CoeloAdminContextKind.institution,
    children: [
      CoeloAdminContextOption(
        id: 'unit-cambui',
        label: 'Unidade Cambuí',
        kind: CoeloAdminContextKind.unit,
        children: [
          CoeloAdminContextOption(
            id: 'group-girassol',
            label: 'Turma Girassol',
            kind: CoeloAdminContextKind.group,
            children: [
              CoeloAdminContextOption(
                id: 'activity-swim',
                label: 'Natação',
                subtitle: 'Terças e quintas',
                kind: CoeloAdminContextKind.activity,
              ),
            ],
          ),
          CoeloAdminContextOption(
            id: 'group-azul',
            label: 'Turma Azul',
            kind: CoeloAdminContextKind.group,
          ),
        ],
      ),
      CoeloAdminContextOption(
        id: 'unit-taquaral',
        label: 'Unidade Taquaral',
        kind: CoeloAdminContextKind.unit,
      ),
    ],
  ),
];

Widget _app(Widget child) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(body: SizedBox(width: 520, height: 720, child: child)),
  );
}
