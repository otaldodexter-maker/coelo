import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_superadmin/features/daily_routine/widgets/daily_routine_field_configuration_editor.dart';
import 'package:coelo_superadmin/features/daily_routine/widgets/daily_routine_inheritance_summary.dart';
import 'package:coelo_superadmin/features/daily_routine/widgets/daily_routine_option_list_editor.dart';
import 'package:coelo_superadmin/features/daily_routine/widgets/daily_routine_ordered_editor.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child, {double textScale = 1}) => MaterialApp(
    theme: CoeloTheme.light,
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: inner!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  const options = [
    RoutineFieldOption(id: 'yes', label: 'Sim', sortOrder: 0),
    RoutineFieldOption(id: 'no', label: 'Não', sortOrder: 1),
  ];

  const fields = [
    RoutineField(
      id: 'first-field',
      label: 'Primeiro campo',
      kind: RoutineFieldKind.shortText,
      sortOrder: 0,
    ),
    RoutineField(
      id: 'second-field',
      label: 'Segundo campo',
      kind: RoutineFieldKind.longText,
      sortOrder: 1,
    ),
  ];

  const sections = [
    RoutineSection(id: 'first', name: 'Primeira', sortOrder: 0, fields: fields),
    RoutineSection(id: 'second', name: 'Segunda', sortOrder: 1, fields: []),
  ];

  testWidgets('choice options are separate stable ordered items with 48px actions', (tester) async {
    (int, int)? reorder;
    await tester.pumpWidget(
      app(
        DailyRoutineOptionListEditor(
          options: options,
          enabled: true,
          onAdd: () {},
          onLabelChanged: (_, _) {},
          onRemove: (_) {},
          onReorder: (oldIndex, newIndex) => reorder = (oldIndex, newIndex),
        ),
      ),
    );

    expect(find.byKey(const Key('daily-routine-option-list')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-option-0')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-option-1')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-field-options')), findsNothing);

    final moveUp = find.byKey(const Key('daily-routine-option-1-move-up'));
    expect(tester.getSize(moveUp), const Size(48, 48));
    expect(tester.getSemantics(moveUp).tooltip, 'Mover opcao para cima');
    await tester.tap(moveUp);
    expect(reorder, (1, 0));
  });

  testWidgets('number editor emits typed initial value and numeric limits', (tester) async {
    var changed = const RoutineField(
      id: 'temperature',
      label: 'Temperatura',
      kind: RoutineFieldKind.number,
      sortOrder: 0,
    );
    await tester.pumpWidget(
      app(
        DailyRoutineFieldConfigurationEditor(
          field: changed,
          availableParents: const [],
          enabled: true,
          onChanged: (value) => changed = value,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('daily-routine-field-initial-value')), '36,5');
    await tester.enterText(find.byKey(const Key('daily-routine-number-min')), '35');
    await tester.enterText(find.byKey(const Key('daily-routine-number-max')), '42');

    expect(changed.initialValue, 36.5);
    expect(changed.minimumValue, 35);
    expect(changed.maximumValue, 42);
    expect(changed.validate, returnsNormally);
  });

  testWidgets('section and field move actions preserve stable ids and callbacks', (tester) async {
    (int, int)? sectionMove;
    (String, int, int)? fieldMove;
    await tester.pumpWidget(
      app(
        DailyRoutineOrderedEditor(
          sections: sections,
          enabled: true,
          onAddSection: () {},
          onEditSection: (_) {},
          onDuplicateSection: (_) {},
          onRemoveSection: (_) {},
          onReorderSections: (oldIndex, newIndex) => sectionMove = (oldIndex, newIndex),
          onAddField: (_) {},
          onEditField: (_, _) {},
          onDuplicateField: (_, _) {},
          onRemoveField: (_, _) {},
          onReorderFields: (section, oldIndex, newIndex) =>
              fieldMove = (section.id, oldIndex, newIndex),
          onAddChildField: (_, _) {},
        ),
      ),
    );

    final sectionUp = find.byKey(const Key('daily-routine-section-second-move-up'));
    await tester.ensureVisible(sectionUp);
    expect(tester.getSize(sectionUp), const Size(48, 48));
    await tester.tap(sectionUp);
    expect(sectionMove, (1, 0));

    final fieldUp = find.byKey(const Key('daily-routine-field-second-field-move-up'));
    await tester.ensureVisible(fieldUp);
    expect(tester.getSize(fieldUp), const Size(48, 48));
    await tester.tap(fieldUp);
    expect(fieldMove, ('first', 1, 0));

    expect(
      tester.getSemantics(find.byKey(const Key('daily-routine-section-first-drag-handle'))).label,
      contains('Reordenar secao'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('daily-routine-field-first-field-drag-handle')))
          .label,
      contains('Reordenar campo'),
    );
  });

  testWidgets('inheritance exposes origin inherited effective and reversible customization', (
    tester,
  ) async {
    RoutineInheritanceMode? mode;
    var reverted = false;
    await tester.pumpWidget(
      app(
        DailyRoutineInheritanceSummary(
          application: RoutineApplication(
            id: 'application',
            modelVersionId: 'model-version',
            institutionId: 'institution',
            unitId: 'unit',
            status: RoutineApplicationStatus.active,
            inheritanceMode: RoutineInheritanceMode.customized,
            effectiveVersion: 2,
            expectedVersion: 2,
          ),
          originLabel: 'Instituição Aurora',
          inheritedLabel: 'Modelo institucional v2',
          effectiveLabel: 'Personalização da Unidade Centro',
          enabled: true,
          onModeChanged: (value) => mode = value,
          onRevert: () => reverted = true,
        ),
      ),
    );

    final summary = find.byKey(const Key('daily-routine-inheritance-summary'));
    expect(tester.getSemantics(summary).label, contains('Heranca da rotina'));
    expect(find.text('Origem'), findsOneWidget);
    expect(find.text('Herdado'), findsOneWidget);
    expect(find.text('Efetivo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily-routine-inheritance-toggle')));
    expect(mode, RoutineInheritanceMode.inherited);
    await tester.tap(find.byKey(const Key('daily-routine-inheritance-reset')));
    expect(reverted, isTrue);
  });

  testWidgets('field editor remains usable at 200 percent across responsive widths', (
    tester,
  ) async {
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1200);
      await tester.pumpWidget(
        app(
          DailyRoutineFieldConfigurationEditor(
            field: const RoutineField(
              id: 'number',
              label: 'Número',
              kind: RoutineFieldKind.number,
              sortOrder: 0,
            ),
            availableParents: const [],
            enabled: true,
            onChanged: (_) {},
          ),
          textScale: 2,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'width=$width textScale=2');
      for (final key in const [
        'daily-routine-field-initial-value',
        'daily-routine-number-min',
        'daily-routine-number-max',
        'daily-routine-field-required',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: 'width=$width key=$key');
      }
    }
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
