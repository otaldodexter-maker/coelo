import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/forms_editor_context.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in [FormItemKind.singleChoice, FormItemKind.multipleChoice]) {
    testWidgets('choice branch explicit trigger survives save and reload $kind', (tester) async {
      final api = _EditorApi(firstItems: [_branchChoice(kind)]);
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      tester
          .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
          .singleWhere((field) => field.label == 'Desdobrar por resposta')
          .onChanged!(true);
      await tester.pumpAndSettle();
      final selector = find.byKey(const ValueKey('forms-branch-option-parent'));
      expect(selector, findsOneWidget);
      expect(tester.widget<CoeloAdminSingleSelectField<String?>>(selector).value, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Adicionar pergunta ao ramo'),
            )
            .onPressed,
        isNull,
      );
      tester.widget<CoeloAdminSingleSelectField<String?>>(selector).onChanged('opaque-b');
      await tester.pumpAndSettle();
      final add = find.text('Adicionar pergunta ao ramo');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final sent = api.savedCommands.single.payload.sections.first.items;
      expect(sent, hasLength(2));
      expect(sent.last.conditions.single.sourceItemId, 'parent');
      expect(sent.last.conditions.single.optionIds, {'opaque-b'});
      final reloaded = _EditorApi(firstItems: sent);
      await tester.pumpWidget(_app(reloaded, 'form-1'));
      await tester.pumpAndSettle();
      expect(find.text('Se “Segunda opção”'), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final second = reloaded.savedCommands.single.payload.sections.first.items;
      expect(second.map((item) => item.id), sent.map((item) => item.id));
      expect(second.last.conditions.single.optionIds, {'opaque-b'});
      expect(tester.takeException(), isNull);
    });
  }

  for (final action in [
    'toggle',
    'reorder-options',
    'duplicate-parent',
    'duplicate-section',
    'next-trigger',
  ]) {
    testWidgets('choice branch retains opaque triggers after $action', (tester) async {
      final api = _EditorApi(firstItems: [_branchChoice(FormItemKind.multipleChoice)]);
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      tester
          .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
          .singleWhere((field) => field.label == 'Desdobrar por resposta')
          .onChanged!(true);
      await tester.pumpAndSettle();
      await _addChoiceBranch(tester, 'opaque-b');
      if (action == 'toggle') {
        tester
            .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
            .singleWhere((field) => field.label == 'Desdobrar por resposta')
            .onChanged!(false);
      } else if (action == 'reorder-options') {
        tester
            .widget<ReorderableListView>(find.byKey(const ValueKey('forms-editor-options-parent')))
            .onReorderItem!(0, 1);
        await tester.pumpAndSettle();
        final text = find.byWidgetPredicate(
          (widget) => widget is TextFormField && widget.controller?.text == 'Segunda opção',
        );
        await tester.enterText(text, 'Opção renomeada');
      } else if (action.startsWith('duplicate')) {
        final button = find
            .byTooltip(action == 'duplicate-parent' ? 'Duplicar pergunta' : 'Duplicar seção')
            .first;
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
      } else {
        await _addChoiceBranch(tester, 'opaque-a');
      }
      await tester.pumpAndSettle();
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final definition = api.savedCommands.single.payload;
      final items = definition.sections.expand((section) => section.items).toList();
      final children = items.where((item) => item.conditions.isNotEmpty).toList();
      expect(
        children,
        hasLength(action.startsWith('duplicate') || action == 'next-trigger' ? 2 : 1),
      );
      for (final child in children) {
        final parent = items.singleWhere((item) => item.id == child.conditions.single.sourceItemId);
        expect(
          parent.options.map((option) => option.id),
          contains(child.conditions.single.optionIds.single),
        );
        if (parent.id == 'parent') {
          expect(
            child.conditions.single.optionIds,
            child == children.first ? {'opaque-b'} : {'opaque-a'},
          );
        } else {
          expect(child.conditions.single.optionIds, isNot(contains('opaque-b')));
        }
      }
      expect(items.map((item) => item.id).toSet(), hasLength(items.length));
      expect(const FormDefinitionValidator().validate(definition), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('choice branch retained add cannot run after its trigger is cleared', (tester) async {
    final api = _EditorApi(firstItems: [_branchChoice(FormItemKind.singleChoice)]);
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    tester
        .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
        .singleWhere((field) => field.label == 'Desdobrar por resposta')
        .onChanged!(true);
    await tester.pumpAndSettle();
    final selector = find.byKey(const ValueKey('forms-branch-option-parent'));
    tester.widget<CoeloAdminSingleSelectField<String?>>(selector).onChanged('opaque-b');
    await tester.pumpAndSettle();
    final retained = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Adicionar pergunta ao ramo'))
        .onPressed!;
    tester.widget<CoeloAdminSingleSelectField<String?>>(selector).onChanged(null);
    await tester.pumpAndSettle();
    expect(retained, returnsNormally);
    await tester.pumpAndSettle();
    expect(find.text('Pergunta do ramo 1'), findsNothing);
  });

  for (final invalid in ['cycle', 'unknown-option', 'unknown-source']) {
    testWidgets('choice branch rejects $invalid without destructive hydration', (tester) async {
      final source = _branchChoice(FormItemKind.singleChoice);
      final api = _EditorApi(
        firstItems: [
          FormItem(
            id: source.id,
            kind: source.kind,
            label: source.label,
            position: 0,
            options: source.options,
            conditions: invalid == 'cycle'
                ? [
                    const FormCondition.choice(sourceItemId: 'leaf', optionIds: {'leaf-a'}),
                  ]
                : const [],
          ),
          FormItem(
            id: 'leaf',
            kind: FormItemKind.singleChoice,
            label: 'Leaf',
            position: 1,
            options: const [
              FormOption(id: 'leaf-a', label: 'One', position: 0),
              FormOption(id: 'leaf-b', label: 'Two', position: 1),
            ],
            conditions: [
              FormCondition.choice(
                sourceItemId: invalid == 'unknown-source' ? 'missing' : 'parent',
                optionIds: {invalid == 'unknown-option' ? 'missing' : 'opaque-b'},
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.savedCommands, isEmpty);
      expect(
        find.text('Revise o título, a ordem e os campos obrigatórios antes de salvar.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('choice branch mixed hierarchy remains editable at 375 and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _branchChoice(FormItemKind.singleChoice);
    final api = _EditorApi(
      firstItems: [
        FormItem(id: 'root', kind: FormItemKind.yesNo, label: 'Root', position: 0),
        FormItem(
          id: source.id,
          kind: source.kind,
          label: source.label,
          options: source.options,
          position: 1,
          conditions: const [FormCondition.yesNo(sourceItemId: 'root', expected: true)],
        ),
        FormItem(
          id: 'leaf',
          kind: FormItemKind.shortText,
          label: 'Loaded leaf',
          position: 2,
          conditions: const [
            FormCondition.choice(sourceItemId: 'parent', optionIds: {'opaque-b'}),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: FormsEditorPage(api: api, formId: 'form-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('forms-question-card-leaf'));
    expect(card, findsOneWidget);
    final expand = find.descendant(of: card, matching: find.byTooltip('Editar pergunta')).first;
    await tester.ensureVisible(expand);
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (widget) => widget is TextFormField && widget.controller?.text == 'Loaded leaf',
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Edited leaf');
    await tester.pumpAndSettle();
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final items = api.savedCommands.single.payload.sections.first.items;
    expect(items.map((item) => item.id), ['root', 'parent', 'leaf']);
    expect(items.last.label, 'Edited leaf');
    expect(items.last.conditions.single.optionIds, {'opaque-b'});
    expect(tester.takeException(), isNull);
  });

  for (final depth in [4, 5]) {
    testWidgets('choice branch depth $depth keeps backend-independent client validation', (
      tester,
    ) async {
      final api = _EditorApi(
        firstItems: [
          _branchChoice(FormItemKind.singleChoice),
          for (var index = 1; index <= depth; index++)
            FormItem(
              id: 'level-$index',
              kind: FormItemKind.singleChoice,
              label: 'Level $index',
              position: index,
              options: [
                FormOption(id: 'option-$index', label: 'One', position: 0),
                FormOption(id: 'other-$index', label: 'Two', position: 1),
              ],
              conditions: [
                FormCondition.choice(
                  sourceItemId: index == 1 ? 'parent' : 'level-${index - 1}',
                  optionIds: {index == 1 ? 'opaque-b' : 'option-${index - 1}'},
                ),
              ],
            ),
        ],
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.savedCommands, hasLength(depth == 4 ? 1 : 0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('yes-no branch creation survives a new editor load and second save', (tester) async {
    final first = _EditorApi(itemKind: FormItemKind.yesNo);
    await tester.pumpWidget(_app(first, 'form-1'));
    await tester.pumpAndSettle();
    tester
        .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
        .singleWhere((field) => field.label == 'Desdobrar por resposta')
        .onChanged!(true);
    await tester.pumpAndSettle();
    final add = find.text('Adicionar pergunta ao ramo').first;
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final sent = first.savedCommands.single.payload.sections.first.items;
    final second = _EditorApi(firstItems: sent);
    await tester.pumpWidget(_app(second, 'form-1'));
    await tester.pumpAndSettle();
    expect(find.text('Se Sim'), findsOneWidget);
    expect(find.text('2 perguntas'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final saved = second.savedCommands.single.payload.sections.first.items;
    expect(saved.map((item) => item.id), sent.map((item) => item.id));
    expect(saved.map((item) => item.label), sent.map((item) => item.label));
    expect(saved.last.conditions.single.sourceItemId, sent.first.id);
    expect(saved.last.conditions.single.expectedYesNo, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yes-no branch cyclic loaded graph stays rejected without recursive UI failure', (
    tester,
  ) async {
    final api = _EditorApi(
      firstItems: [
        FormItem(
          id: 'parent',
          kind: FormItemKind.yesNo,
          label: 'Parent',
          position: 0,
          conditions: const [FormCondition.yesNo(sourceItemId: 'child', expected: true)],
        ),
        FormItem(
          id: 'child',
          kind: FormItemKind.yesNo,
          label: 'Child',
          position: 1,
          conditions: const [FormCondition.yesNo(sourceItemId: 'parent', expected: true)],
        ),
      ],
    );
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(api.savedCommands, isEmpty);
    expect(
      find.text('Revise o título, a ordem e os campos obrigatórios antes de salvar.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('yes-no branch loaded children remain present in preview', (tester) async {
    final api = _EditorApi(
      firstItems: [
        FormItem(id: 'parent', kind: FormItemKind.yesNo, label: 'Parent', position: 0),
        FormItem(
          id: 'child',
          kind: FormItemKind.shortText,
          label: 'Loaded child',
          position: 1,
          conditions: const [FormCondition.yesNo(sourceItemId: 'parent', expected: true)],
        ),
      ],
    );
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'preview');
    await tester.pumpAndSettle();
    final preview = find.byType(CoeloAdminDialogShell);
    expect(find.descendant(of: preview, matching: find.text('1. Parent')), findsOneWidget);
    expect(find.descendant(of: preview, matching: find.text('2. Loaded child')), findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.text('Pergunta condicionada')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('yes-no branch deep hierarchy remains editable at 375 pixels with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _EditorApi(
      firstItems: [
        for (var index = 0; index < 5; index++)
          FormItem(
            id: 'level-$index',
            kind: index == 4 ? FormItemKind.shortText : FormItemKind.yesNo,
            label: 'Level $index',
            position: index,
            conditions: index == 0
                ? const []
                : [FormCondition.yesNo(sourceItemId: 'level-${index - 1}', expected: true)],
          ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: FormsEditorPage(api: api, formId: 'form-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final edit = find.descendant(
      of: find.byKey(const ValueKey('forms-question-card-level-4')),
      matching: find.byTooltip('Editar pergunta'),
    );
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final field = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .singleWhere((field) => field.controller?.text == 'Level 4');
    await tester.enterText(find.byWidget(field), 'Edited deep child');
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.savedCommands.single.payload.sections.first.items.last.label, 'Edited deep child');
    expect(tester.takeException(), isNull);
  });

  for (final action in [
    'save',
    'hide',
    'duplicate-parent',
    'duplicate-section',
    'reorder-parent',
  ]) {
    testWidgets('yes-no branch retains child and condition after $action', (tester) async {
      final api = _EditorApi(
        itemKind: FormItemKind.yesNo,
        firstItems: [
          FormItem(id: 'parent', kind: FormItemKind.yesNo, label: 'Parent', position: 0),
          FormItem(id: 'other', kind: FormItemKind.shortText, label: 'Other', position: 1),
        ],
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      final toggle = tester
          .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
          .singleWhere((field) => field.label == 'Desdobrar por resposta');
      toggle.onChanged!(true);
      await tester.pumpAndSettle();
      final add = find.text('Adicionar pergunta ao ramo').first;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      if (action == 'hide') {
        tester
            .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
            .singleWhere((field) => field.label == 'Desdobrar por resposta')
            .onChanged!(false);
        await tester.pumpAndSettle();
      } else if (action == 'duplicate-parent' || action == 'duplicate-section') {
        final button = find
            .byTooltip(action == 'duplicate-parent' ? 'Duplicar pergunta' : 'Duplicar seção')
            .first;
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      } else if (action == 'reorder-parent') {
        final list = tester.widget<ReorderableListView>(
          find.byKey(const Key('forms-editor-question-reorder-list')),
        );
        list.onReorderItem!(0, 1);
        await tester.pumpAndSettle();
      }
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final definition = api.savedCommands.single.payload;
      final allItems = definition.sections.expand((section) => section.items).toList();
      final children = allItems.where((item) => item.label.startsWith('Pergunta do ramo')).toList();
      expect(children, hasLength(action.startsWith('duplicate') ? 2 : 1));
      for (final child in children) {
        final parent = allItems.singleWhere(
          (item) => item.id == child.conditions.single.sourceItemId,
        );
        expect(parent.kind, FormItemKind.yesNo);
        expect(child.conditions.single.expectedYesNo, isTrue);
        final section = definition.sections.singleWhere((section) => section.items.contains(child));
        expect(section.items.indexOf(child), section.items.indexOf(parent) + 1);
      }
      expect(allItems.map((item) => item.id).toSet(), hasLength(allItems.length));
      for (final section in definition.sections) {
        expect(
          section.items.map((item) => item.position),
          List.generate(section.items.length, (index) => index),
        );
      }
      expect(const FormDefinitionValidator().validate(definition), isEmpty);
      if (action.startsWith('duplicate')) {
        expect(children.map((item) => item.conditions.single.sourceItemId).toSet(), hasLength(2));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('yes-no branch reload preserves hierarchy, order and editable child', (tester) async {
    final api = _EditorApi(
      firstItems: [
        FormItem(id: 'parent', kind: FormItemKind.yesNo, label: 'Parent', position: 0),
        FormItem(
          id: 'child',
          kind: FormItemKind.shortText,
          label: 'Loaded child',
          position: 1,
          conditions: const [FormCondition.yesNo(sourceItemId: 'parent', expected: true)],
        ),
      ],
    );
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    expect(find.text('Se Sim'), findsOneWidget);
    final edit = find.byTooltip('Editar pergunta').first;
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final childField = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .singleWhere((field) => field.controller?.text == 'Loaded child');
    await tester.enterText(find.byWidget(childField), 'Changed child');
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final items = api.savedCommands.single.payload.sections.first.items;
    expect(items.map((item) => item.id), ['parent', 'child']);
    expect(items.last.label, 'Changed child');
    expect(items.last.conditions.single.sourceItemId, 'parent');
    expect(items.last.conditions.single.expectedYesNo, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final sourceAfter in [false, true]) {
    testWidgets('yes-no branch preserves noncontiguous loaded order sourceAfter=$sourceAfter', (
      tester,
    ) async {
      final order = sourceAfter ? ['child', 'other', 'parent'] : ['parent', 'other', 'child'];
      final api = _EditorApi(
        firstItems: [
          for (var index = 0; index < order.length; index++)
            FormItem(
              id: order[index],
              kind: order[index] == 'parent' ? FormItemKind.yesNo : FormItemKind.shortText,
              label: order[index],
              position: index,
              conditions: order[index] == 'child'
                  ? const [FormCondition.yesNo(sourceItemId: 'parent', expected: true)]
                  : const [],
            ),
        ],
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byWidget(_title(tester)), 'Changed title only');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      final items = api.savedCommands.single.payload.sections.first.items;
      expect(items.map((item) => item.id), order);
      expect(
        items.singleWhere((item) => item.id == 'child').conditions.single.sourceItemId,
        'parent',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('yes-no branch deleting and adding children retains distinct stable IDs', (
    tester,
  ) async {
    final api = _EditorApi(itemKind: FormItemKind.yesNo);
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    tester
        .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
        .singleWhere((field) => field.label == 'Desdobrar por resposta')
        .onChanged!(true);
    await tester.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      final add = find.text('Adicionar pergunta ao ramo').first;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
    }
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final before = api.savedCommands.single.payload.sections.first.items;
    expect(before, hasLength(3));
    final delete = find.descendant(
      of: find.byKey(ValueKey('forms-question-card-${before[1].id}')),
      matching: find.byTooltip('Excluir pergunta'),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir pergunta'));
    await tester.pumpAndSettle();
    final add = find.text('Adicionar pergunta ao ramo').first;
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final after = api.savedCommands.last.payload.sections.first.items;
    expect(after.map((item) => item.id).toSet(), hasLength(3));
    expect(after[1].id, before[2].id);
    expect(after[2].id, isNot(isIn(before.map((item) => item.id))));
    expect(const FormDefinitionValidator().validate(api.savedCommands.last.payload), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'yes-no branch nested copy remaps the complete subtree and keeps descendant editable',
    (tester) async {
      final api = _EditorApi(
        firstItems: [
          FormItem(id: 'parent', kind: FormItemKind.yesNo, label: 'Parent', position: 0),
          FormItem(
            id: 'child',
            kind: FormItemKind.yesNo,
            label: 'Child',
            position: 1,
            conditions: const [FormCondition.yesNo(sourceItemId: 'parent', expected: true)],
          ),
          FormItem(
            id: 'grandchild',
            kind: FormItemKind.shortText,
            label: 'Grandchild',
            position: 2,
            conditions: const [FormCondition.yesNo(sourceItemId: 'child', expected: true)],
          ),
        ],
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      final grandchild = find.byKey(const ValueKey('forms-question-card-grandchild'));
      final edit = find.descendant(of: grandchild, matching: find.byTooltip('Editar pergunta'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Se Sim'), findsNWidgets(2));
      final field = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .singleWhere((field) => field.controller?.text == 'Grandchild');
      await tester.enterText(find.byWidget(field), 'Edited grandchild');
      final duplicate = find.byTooltip('Duplicar pergunta').first;
      await tester.ensureVisible(duplicate);
      await tester.tap(duplicate);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final items = api.savedCommands.single.payload.sections.first.items;
      expect(items, hasLength(6));
      expect(items[4].conditions.single.sourceItemId, items[3].id);
      expect(items[5].conditions.single.sourceItemId, items[4].id);
      expect(items[5].label, contains('Edited grandchild'));
      expect(items.map((item) => item.id).toSet(), hasLength(6));
      expect(const FormDefinitionValidator().validate(api.savedCommands.single.payload), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final incomplete in [
    'missing-intent',
    'blank-intent',
    'long-intent',
    'no-question',
    'information',
    'two-questions',
  ]) {
    testWidgets('incomplete quick poll $incomplete saves draft but cannot publish', (tester) async {
      final api = _EditorApi(
        formKind: FormKind.quickPoll,
        description: switch (incomplete) {
          'missing-intent' => null,
          'blank-intent' => '   ',
          'long-intent' => 'x' * 281,
          _ => 'Approved intention',
        },
        firstItems: switch (incomplete) {
          'no-question' => const [],
          'information' => [
            FormItem(id: 'info', kind: FormItemKind.information, label: 'Information', position: 0),
          ],
          'two-questions' => [
            FormItem(id: 'one', kind: FormItemKind.shortText, label: 'First', position: 0),
            FormItem(id: 'two', kind: FormItemKind.shortText, label: 'Second', position: 1),
          ],
          _ => null,
        },
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      expect(api.savedCommands, hasLength(1));
      expect(api.savedCommands.single.payload.kind, FormKind.quickPoll);
      expect(api.savedCommands.single.payload.description, api.description);
      expect(find.text('Rascunho salvo.'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Publicar ou agendar'));
      await tester.pumpAndSettle();
      expect(api.publishCommands, isEmpty);
      expect(find.byType(CoeloAdminDialogShell), findsNothing);
      expect(
        find.text('Revise o título, a ordem e os campos obrigatórios antes de publicar.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final structural in ['empty-title', 'invalid-condition']) {
    testWidgets('incomplete quick poll still rejects $structural on draft save', (tester) async {
      final api = _EditorApi(
        formKind: FormKind.quickPoll,
        title: structural == 'empty-title' ? '   ' : 'Quick poll',
        firstItems: structural == 'invalid-condition'
            ? [
                FormItem(
                  id: 'one',
                  kind: FormItemKind.shortText,
                  label: 'Question',
                  position: 0,
                  conditions: const [FormCondition.yesNo(sourceItemId: 'missing', expected: true)],
                ),
              ]
            : null,
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      expect(api.savedCommands, isEmpty);
      expect(
        find.text('Revise o título, a ordem e os campos obrigatórios antes de salvar.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in FormKind.values) {
    for (final discard in [false, true]) {
      testWidgets('loaded metadata survives $kind title edit discard=$discard', (tester) async {
        final api = _EditorApi(
          formKind: kind,
          identityMode: FormIdentityMode.anonymous,
          responseUnit: FormResponseUnit.childFamilyContext,
          description: 'Approved intention',
          status: FormStatus.published,
        );
        await tester.pumpWidget(_app(api, 'form-1'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byWidget(_title(tester)), 'Changed title');
        if (discard) await _discard(tester);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
        await tester.pumpAndSettle();
        final command = api.savedCommands.single;
        expect(command.payload.kind, kind);
        expect(command.payload.identityMode, FormIdentityMode.anonymous);
        expect(command.payload.responseUnit, FormResponseUnit.childFamilyContext);
        expect(command.payload.description, 'Approved intention');
        expect(command.payload.status, FormStatus.published);
        expect(command.payload.managementVersion, command.expectedVersion);
        expect(const FormDefinitionValidator().validate(command.payload), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'incomplete quick poll rejected by API retains edits and confirmed discard baseline',
    (tester) async {
      final gate = Completer<void>();
      final api = _EditorApi(
        formKind: FormKind.quickPoll,
        title: 'Confirmed title',
        saveGate: gate.future,
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byWidget(_title(tester)), 'Unsaved title');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pump();
      expect(api.savedCommands, hasLength(1));
      gate.completeError(
        const FormApiException(FormApiFailureKind.validation, 'Draft rejected by server'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Draft rejected by server'), findsOneWidget);
      expect(find.text('Rascunho salvo.'), findsNothing);
      expect(_title(tester).controller!.text, 'Unsaved title');
      await _discard(tester);
      expect(_title(tester).controller!.text, 'Confirmed title');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('complete quick poll retains publish confirmation', (tester) async {
    final api = _EditorApi(formKind: FormKind.quickPoll, description: 'Approved intention');
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Publicar ou agendar'));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    expect(api.publishCommands, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final kind in [FormItemKind.scale, FormItemKind.decimal, FormItemKind.money]) {
    testWidgets('loaded $kind noneditable configuration survives title edit', (tester) async {
      final config = kind == FormItemKind.scale
          ? const FormItemConfig(
              scaleMin: 1,
              scaleMax: 5,
              scaleMinLabel: 'Low',
              scaleMaxLabel: 'High',
            )
          : FormItemConfig(
              minValue: 0,
              maxValue: 10,
              decimalPlaces: 2,
              currency: kind == FormItemKind.money ? 'BRL' : null,
            );
      final api = _EditorApi(itemKind: kind, itemConfig: config);
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byWidget(_title(tester)), 'Changed title');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      final saved = api.savedCommands.single.payload.sections.first.items.single.config;
      expect(saved.scaleMin, config.scaleMin);
      expect(saved.scaleMax, config.scaleMax);
      expect(saved.scaleMinLabel, config.scaleMinLabel);
      expect(saved.scaleMaxLabel, config.scaleMaxLabel);
      expect(saved.decimalPlaces, config.decimalPlaces);
      expect(saved.currency, config.currency);
      expect(saved.minValue, config.minValue);
      expect(saved.maxValue, config.maxValue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final action in [
    'title',
    'discard',
    'reorder',
    'duplicate-question',
    'duplicate-section',
    'reorder-duplicate-section',
    'duplicate-dependent',
  ]) {
    testWidgets('loaded branching survives $action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _EditorApi(firstItems: _branchingItems());
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byWidget(_title(tester)), 'Edited title');
      if (action == 'discard') await _discard(tester);
      if (action.startsWith('reorder')) {
        final list = tester.widget<ReorderableListView>(
          find.byKey(const ValueKey('forms-editor-options-choice-source')),
        );
        list.onReorderItem!(0, 2);
        await tester.pumpAndSettle();
      }
      if (action == 'duplicate-question') {
        await tester.tap(find.byTooltip('Duplicar pergunta').first);
        await tester.pumpAndSettle();
      }
      if (action == 'duplicate-dependent') {
        await tester.ensureVisible(find.byTooltip('Duplicar pergunta').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Duplicar pergunta').last);
        await tester.pumpAndSettle();
      }
      if (action.endsWith('duplicate-section')) {
        await tester.tap(find.byTooltip('Duplicar seção'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      final payload = api.savedCommands.single.payload;
      final original = payload.sections.first.items;
      final choice = original.firstWhere((item) => item.id == 'choice-source');
      expect(
        choice.options.map((option) => option.id),
        action.startsWith('reorder')
            ? ['opaque-b', 'opaque-c', 'opaque-a']
            : ['opaque-a', 'opaque-b', 'opaque-c'],
      );
      expect(
        choice.options.map((option) => option.label),
        action.startsWith('reorder') ? ['B', 'C', 'A'] : ['A', 'B', 'C'],
      );
      expect(choice.options.map((option) => option.position), [0, 1, 2]);
      final target = original.firstWhere((item) => item.id == 'dependent');
      expect(target.conditions, hasLength(2));
      expect(target.conditions[0].kind, FormConditionKind.choice);
      expect(target.conditions[0].sourceItemId, 'choice-source');
      expect(target.conditions[0].optionIds, {'opaque-b', 'opaque-c'});
      expect(target.conditions[1].kind, FormConditionKind.yesNo);
      expect(target.conditions[1].sourceItemId, 'yes-source');
      expect(target.conditions[1].expectedYesNo, isFalse);
      if (action == 'duplicate-question') {
        final copy = original[1];
        expect(copy.options.map((option) => option.label), ['A', 'B', 'C']);
        expect(
          copy.options
              .map((option) => option.id)
              .toSet()
              .intersection(choice.options.map((option) => option.id).toSet()),
          isEmpty,
        );
      }
      if (action == 'duplicate-dependent') {
        final copied = original.last;
        expect(copied.id, isNot(target.id));
        expect(copied.conditions[0].sourceItemId, 'choice-source');
        expect(copied.conditions[0].optionIds, {'opaque-b', 'opaque-c'});
        expect(copied.conditions[1].sourceItemId, 'yes-source');
        expect(copied.conditions[1].expectedYesNo, isFalse);
      }
      if (action.endsWith('duplicate-section')) {
        final copied = payload.sections[1].items;
        expect(copied, hasLength(3));
        expect(copied[2].conditions[0].sourceItemId, copied[0].id);
        expect(
          copied[2].conditions[0].optionIds,
          copied[0].options
              .where((option) => option.label != 'A')
              .map((option) => option.id)
              .toSet(),
        );
        expect(copied[2].conditions[1].sourceItemId, copied[1].id);
      }
      expect(const FormDefinitionValidator().validate(payload), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in [FormItemKind.photo, FormItemKind.gallery]) {
    testWidgets('$kind duplication preserves loaded image settings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _EditorApi(
        itemKind: kind,
        itemConfig: const FormItemConfig(allowCamera: true, allowExisting: false, maxImages: 1),
      );
      await tester.pumpWidget(_app(api, 'form-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Duplicar pergunta').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      final items = api.savedCommands.single.payload.sections.first.items;
      expect(items, hasLength(2));
      expect(items[0].id, isNot(items[1].id));
      for (final item in items) {
        expect(item.kind, kind);
        expect(item.config.allowCamera, isTrue);
        expect(item.config.allowExisting, isFalse);
        expect(item.config.maxImages, 1);
      }
      expect(tester.takeException(), isNull);
    });

    for (final discard in [false, true]) {
      testWidgets('$kind image settings survive title edit and discard=$discard', (tester) async {
        final api = _EditorApi(
          itemKind: kind,
          itemConfig: const FormItemConfig(allowCamera: false, allowExisting: true, maxImages: 2),
        );
        await tester.pumpWidget(_app(api, 'form-1'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byWidget(_title(tester)), 'Edited title');
        if (discard) await _discard(tester);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
        await tester.pumpAndSettle();
        final item = api.savedCommands.single.payload.sections.first.items.single;
        expect(item.kind, kind);
        expect(item.config.allowCamera, isFalse);
        expect(item.config.allowExisting, isTrue);
        expect(item.config.maxImages, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('production discard confirmation describes the confirmed baseline', (tester) async {
    await tester.pumpWidget(_app(_EditorApi(), 'form-1'));
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'cancel');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'O editor voltará ao último conteúdo confirmado. Em um formulário novo, os campos voltarão ao estado inicial.',
      ),
      findsOneWidget,
    );
    expect(find.text('A prévia voltará ao conteúdo inicial desta sessão.'), findsNothing);
  });

  testWidgets('production discard restores removed questions and clears local context', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _EditorApi();
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    final contextField = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((field) => field.decoration?.labelText == 'Contexto');
    await tester.enterText(find.byWidget(contextField), 'Unsaved context');
    await _openOverlay(tester, 'delete-question');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir pergunta'));
    await tester.pumpAndSettle();
    await _discard(tester);
    expect(contextField.controller!.text, isEmpty);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(api.savedCommands.single.payload.sections.first.items.single.id, 'item-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('production discard restores the latest publication receipt', (tester) async {
    final api = _EditorApi(title: 'Loaded', publishedTitle: 'Published baseline');
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'publish');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-confirm-publish')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidget(_title(tester)), 'Unsaved edit');
    await _discard(tester);
    expect(_title(tester).controller!.text, 'Published baseline');
    expect(api.publishCommands, hasLength(1));
    expect(api.savedCommands, isEmpty);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(api.savedCommands.single.expectedVersion, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production discard restores the authorized loaded definition', (tester) async {
    final api = _EditorApi(title: 'Authorized form');
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidget(_title(tester)), 'Unsaved');
    await _discard(tester);
    expect(_title(tester).controller!.text, 'Authorized form');
    expect(api.savedCommands, isEmpty);
    expect(api.publishCommands, isEmpty);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    final command = api.savedCommands.single;
    expect(command.payload.id, 'form-1');
    expect(command.expectedVersion, 1);
    expect(command.payload.sections.map((value) => value.id), ['section-1', 'section-2']);
    expect(command.payload.sections.expand((value) => value.items).map((value) => value.id), [
      'item-1',
      'item-2',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production discard keeps edits when confirmation is cancelled', (tester) async {
    final api = _EditorApi();
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidget(_title(tester)), 'Unsaved');
    await _openOverlay(tester, 'cancel');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Continuar editando'));
    await tester.pumpAndSettle();
    expect(_title(tester).controller!.text, 'Unsaved');
    expect(api.savedCommands, isEmpty);
    expect(api.publishCommands, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production discard restores the latest successful save receipt', (tester) async {
    final api = _EditorApi(title: 'Loaded', savedTitle: 'Confirmed save');
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidget(_title(tester)), 'Submitted');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidget(_title(tester)), 'Unsaved after save');
    await _discard(tester);
    expect(_title(tester).controller!.text, 'Confirmed save');
    expect(api.savedCommands, hasLength(1));
    expect(api.requestedForms, ['form-1']);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(api.savedCommands.last.expectedVersion, 2);
    expect(api.savedCommands.last.payload.title, 'Confirmed save');
    expect(tester.takeException(), isNull);
  });

  testWidgets('discarding a new production form restores its neutral authorized draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _EditorApi();
    await tester.pumpWidget(_app(api, null));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidget(_title(tester)), 'Unsaved new form');
    await _openOverlay(tester, 'catalog');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('forms-editor-catalog-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-catalog-date')));
    await tester.pumpAndSettle();
    await _discard(tester);
    expect(_title(tester).controller!.text, isEmpty);
    expect(_save(tester).onPressed, isNotNull);
    expect(api.requestedForms, isEmpty);
    expect(api.savedCommands, isEmpty);
    await tester.enterText(find.byWidget(_title(tester)), 'New form');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    final command = api.savedCommands.single;
    expect(command.payload.id, isEmpty);
    expect(command.expectedVersion, 0);
    expect(command.payload.institutionId, 'institution-1');
    expect(command.payload.sections, hasLength(1));
    expect(command.payload.sections.single.items, hasLength(1));
    expect(command.payload.sections.single.items.single.kind, FormItemKind.shortText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save does not replace the production discard baseline', (tester) async {
    final pending = Completer<void>();
    final api = _EditorApi(title: 'Authorized form', saveGate: pending.future);
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidget(_title(tester)), 'Rejected edit');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pump();
    pending.completeError(const FormApiException(FormApiFailureKind.conflict, 'Rejected save'));
    await tester.pumpAndSettle();
    expect(find.text('Rejected save'), findsOneWidget);
    await _discard(tester);
    expect(_title(tester).controller!.text, 'Authorized form');
    expect(find.text('Rejected save'), findsNothing);
    expect(api.savedCommands, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('owned editor dialog preserves the theme below its navigator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Theme(
            data: CoeloTheme.dark,
            child: FormsEditorPage(api: _EditorApi(), formId: 'form-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'cancel');
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(CoeloAdminDialogShell))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('context replacement removes only editor overlays and preserves an external route', (
    tester,
  ) async {
    final first = _EditorApi();
    final second = _EditorApi(title: 'Form B');
    await tester.pumpWidget(_app(first, 'form-1'));
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'preview');
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push<void>(
        DialogRoute<void>(
          context: navigator.context,
          builder: (_) => const Center(child: Text('External route')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(second, 'form-2'));
    await tester.pumpAndSettle();
    expect(find.text('External route'), findsOneWidget);
    expect(find.text('Prévia do formulário', skipOffstage: false), findsNothing);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(_title(tester).controller!.text, 'Form B');
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the editor removes its own open dialog', (tester) async {
    final api = _EditorApi();
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'catalog');
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-editor-question-catalog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an obsolete save cannot release the next editor save', (tester) async {
    final pendingA = Completer<void>();
    final pendingB = Completer<void>();
    final first = _EditorApi(saveGate: pendingA.future);
    final second = _EditorApi(saveGate: pendingB.future);
    await tester.pumpWidget(_app(first, 'form-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pump();
    await tester.pumpWidget(_app(second, 'form-2'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pump();
    pendingA.complete();
    await tester.pumpAndSettle();
    expect(_save(tester).onPressed, isNull);
    pendingB.complete();
    await tester.pumpAndSettle();
    expect(_save(tester).onPressed, isNotNull);
    expect(second.savedCommands, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('publication confirmed in an old context cannot publish the replacement form', (
    tester,
  ) async {
    final first = _EditorApi();
    final second = _EditorApi();
    await tester.pumpWidget(_app(first, 'form-1'));
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'publish');
    await tester.pumpAndSettle();
    tester.widget<FilledButton>(find.byKey(const Key('forms-editor-confirm-publish'))).onPressed!();
    await tester.pumpWidget(_app(second, 'form-2'));
    await tester.pumpAndSettle();
    expect(first.publishCommands, isEmpty);
    expect(second.publishCommands, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old publication receipt cannot replace the new editor definition', (tester) async {
    final pending = Completer<void>();
    final first = _EditorApi(publishGate: pending.future);
    final second = _EditorApi();
    await tester.pumpWidget(_app(first, 'form-1'));
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'publish');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-confirm-publish')));
    await tester.pumpAndSettle();
    expect(first.publishCommands, hasLength(1));
    await tester.pumpWidget(_app(second, 'form-2'));
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(second.savedCommands.single.payload.id, 'form-2');
    expect(second.savedCommands.single.expectedVersion, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old catalog callback cannot mutate the replacement editor', (tester) async {
    final first = _EditorApi();
    final second = _EditorApi();
    await tester.pumpWidget(_app(first, 'form-1'));
    await tester.pumpAndSettle();
    await _openOverlay(tester, 'catalog');
    await tester.pumpAndSettle();
    final dynamic item = tester.widget(find.byKey(const Key('forms-editor-catalog-date')));
    final callback = item.onPressed as VoidCallback;
    await tester.pumpWidget(_app(second, 'form-2'));
    await tester.pumpAndSettle();
    callback();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(second.savedCommands.single.payload.sections.first.items, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final overlay in [
    'preview',
    'catalog',
    'delete-section',
    'delete-question',
    'move',
    'publish',
    'cancel',
  ]) {
    testWidgets('context replacement dismisses its $overlay route before its first build', (
      tester,
    ) async {
      final first = _EditorApi(title: 'Form A');
      final second = _EditorApi(title: 'Form B');
      await tester.pumpWidget(_app(first, 'form-1'));
      await tester.pumpAndSettle();
      await _openOverlay(tester, overlay);
      await tester.pumpWidget(_app(second, 'form-2'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CoeloAdminDialogShell),
          matching: find.text(_overlayTitle(overlay)),
        ),
        findsNothing,
      );
      expect(_title(tester).controller!.text, 'Form B');
      expect(second.savedCommands, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fails in [false, true]) {
    testWidgets('stale editor save ${fails ? 'error' : 'receipt'} cannot alter the current form', (
      tester,
    ) async {
      final pending = Completer<void>();
      final first = _EditorApi(title: 'Form A', saveGate: pending.future);
      final second = _EditorApi(title: 'Form B');
      await tester.pumpWidget(_app(first, 'form-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pump();
      await tester.pumpWidget(_app(second, 'form-2'));
      await tester.pumpAndSettle();
      if (fails) {
        pending.completeError(
          const FormApiException(FormApiFailureKind.conflict, 'Old save failure'),
        );
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(find.text('Old save failure'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      expect(second.savedCommands.single.payload.id, 'form-2');
      expect(second.savedCommands.single.expectedVersion, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('API replacement clears prior editor data and capabilities immediately', (
    tester,
  ) async {
    final pending = Completer<void>();
    final first = _EditorApi(title: 'Form A');
    final second = _EditorApi(title: 'Form B', projectionGate: pending.future, canPublish: false);
    await tester.pumpWidget(_app(first, 'form-1'));
    await tester.pumpAndSettle();
    expect(_title(tester).controller!.text, 'Form A');
    await tester.pumpWidget(_app(second, 'form-1'));
    expect(_title(tester).controller!.text, isEmpty);
    expect(_save(tester).onPressed, isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(_title(tester).controller!.text, 'Form B');
    expect(second.requestedForms, ['form-1']);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Publicar ou agendar'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('form ID replacement loads the new definition through the same API', (tester) async {
    final api = _EditorApi();
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(api, 'form-2'));
    await tester.pumpAndSettle();
    expect(api.requestedForms, ['form-1', 'form-2']);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(api.savedCommands.single.payload.id, 'form-2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unchanged editor identity preserves unsaved edits without refetching', (
    tester,
  ) async {
    final api = _EditorApi();
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    final field = find.byWidget(_title(tester));
    await tester.enterText(field, 'Local edit');
    await tester.pumpWidget(_app(api, 'form-1'));
    await tester.pumpAndSettle();
    expect(_title(tester).controller!.text, 'Local edit');
    expect(api.requestedForms, ['form-1']);
  });

  for (final dispose in [false, true]) {
    testWidgets(
      'obsolete editor context cannot fetch a form after ${dispose ? 'dispose' : 'replacement'}',
      (tester) async {
        final pending = Completer<void>();
        final first = _EditorApi(contextGate: pending.future);
        final second = _EditorApi(title: 'Form B');
        await tester.pumpWidget(_app(first, 'form-1'));
        await tester.pump();
        await tester.pumpWidget(dispose ? const SizedBox.shrink() : _app(second, 'form-2'));
        await tester.pump();
        pending.complete();
        await tester.pumpAndSettle();
        expect(first.requestedForms, isEmpty);
        if (!dispose) expect(_title(tester).controller!.text, 'Form B');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(FormsApi api, String? formId) => _host(FormsEditorPage(api: api, formId: formId));

Future<void> _discard(WidgetTester tester) async {
  await _openOverlay(tester, 'cancel');
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
  await tester.pumpAndSettle();
}

Widget _host(Widget editor) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(body: editor),
);

TextFormField _title(WidgetTester tester) => tester
    .widgetList<TextFormField>(find.byType(TextFormField))
    .firstWhere((field) => field.controller != null);
OutlinedButton _save(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));

Future<void> _openOverlay(WidgetTester tester, String overlay) async {
  final finder = switch (overlay) {
    'preview' => find.byKey(const Key('forms-editor-toggle-preview')),
    'catalog' => find.byKey(const Key('forms-editor-add-question')),
    'delete-section' => find.byTooltip('Excluir seção'),
    'delete-question' => find.byTooltip('Excluir pergunta').first,
    'move' => find.byTooltip('Mover pergunta para outra seção').first,
    'publish' => find.widgetWithText(OutlinedButton, 'Publicar ou agendar'),
    _ => find.widgetWithText(TextButton, 'Cancelar'),
  };
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

String _overlayTitle(String overlay) => switch (overlay) {
  'preview' => 'Prévia do formulário',
  'catalog' => 'Adicionar pergunta',
  'delete-section' => 'Excluir seção?',
  'delete-question' => 'Excluir pergunta?',
  'move' => 'Mover pergunta para seção',
  'publish' => 'Publicar formulário',
  _ => 'Descartar alterações locais?',
};

List<FormItem> _branchingItems() => [
  FormItem(
    id: 'choice-source',
    kind: FormItemKind.singleChoice,
    label: 'Choice',
    position: 0,
    options: const [
      FormOption(id: 'opaque-a', label: 'A', position: 0),
      FormOption(id: 'opaque-b', label: 'B', position: 1),
      FormOption(id: 'opaque-c', label: 'C', position: 2),
    ],
  ),
  FormItem(id: 'yes-source', kind: FormItemKind.yesNo, label: 'Yes or no', position: 1),
  FormItem(
    id: 'dependent',
    kind: FormItemKind.shortText,
    label: 'Dependent',
    position: 2,
    conditions: const [
      FormCondition.choice(sourceItemId: 'choice-source', optionIds: {'opaque-b', 'opaque-c'}),
      FormCondition.yesNo(sourceItemId: 'yes-source', expected: false),
    ],
  ),
];

FormItem _branchChoice(FormItemKind kind) => FormItem(
  id: 'parent',
  kind: kind,
  label: 'Escolha',
  position: 0,
  options: const [
    FormOption(id: 'opaque-a', label: 'Primeira opção', position: 0),
    FormOption(id: 'opaque-b', label: 'Segunda opção', position: 1),
  ],
);

Future<void> _addChoiceBranch(WidgetTester tester, String optionId) async {
  tester
      .widget<CoeloAdminSingleSelectField<String?>>(
        find.byKey(const ValueKey('forms-branch-option-parent')),
      )
      .onChanged(optionId);
  await tester.pumpAndSettle();
  tester
      .widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Adicionar pergunta ao ramo').first,
      )
      .onPressed!();
  await tester.pumpAndSettle();
}

final class _EditorApi implements FormsApi, FormsEditorContextApi {
  _EditorApi({
    this.title = 'Form title',
    this.savedTitle,
    this.publishedTitle,
    this.contextGate,
    this.projectionGate,
    this.saveGate,
    this.publishGate,
    this.canPublish = true,
    this.itemKind = FormItemKind.shortText,
    this.itemConfig = const FormItemConfig(),
    this.firstItems,
    this.formKind = FormKind.form,
    this.identityMode = FormIdentityMode.identified,
    this.responseUnit = FormResponseUnit.person,
    this.description,
    this.status = FormStatus.draft,
  });
  final String title;
  final String? savedTitle;
  final String? publishedTitle;
  final Future<void>? contextGate;
  final Future<void>? projectionGate;
  final Future<void>? saveGate;
  final Future<void>? publishGate;
  final publishCommands = <FormCommand<FormIdPayload>>[];
  final bool canPublish;
  final FormItemKind itemKind;
  final FormItemConfig itemConfig;
  final List<FormItem>? firstItems;
  final FormKind formKind;
  final FormIdentityMode identityMode;
  final FormResponseUnit responseUnit;
  final String? description;
  final FormStatus status;
  final requestedForms = <String>[];
  final savedCommands = <FormCommand<FormDefinition>>[];

  @override
  Future<FormsEditorContext> getEditorContext() async {
    if (contextGate != null) await contextGate;
    return FormsEditorContext(
      institutions: [
        FormsEditorInstitution(
          id: 'institution-1',
          name: 'Synthetic institution',
          canManageForms: true,
          canPublishForms: canPublish,
        ),
      ],
    );
  }

  @override
  Future<FormEditorProjection> getEditor(String formId) async {
    requestedForms.add(formId);
    if (projectionGate != null) await projectionGate;
    return FormEditorProjection(definition: definition(formId));
  }

  FormDefinition definition(String id, {int version = 1, String? confirmedTitle}) => FormDefinition(
    id: id,
    institutionId: 'institution-1',
    title: confirmedTitle ?? title,
    kind: formKind,
    identityMode: identityMode,
    responseUnit: responseUnit,
    description: description,
    status: status,
    managementVersion: version,
    sections: [
      FormSection(
        id: 'section-1',
        title: 'Section',
        position: 0,
        items:
            firstItems ??
            [
              FormItem(
                id: 'item-1',
                kind: itemKind,
                label: 'Question',
                position: 0,
                config: itemConfig,
              ),
            ],
      ),
      if (formKind != FormKind.quickPoll)
        FormSection(
          id: 'section-2',
          title: 'Section B',
          position: 1,
          items: [
            FormItem(id: 'item-2', kind: FormItemKind.shortText, label: 'Question B', position: 0),
          ],
        ),
    ],
  );

  @override
  Future<FormDefinition> saveDraft(FormCommand<FormDefinition> command) async {
    savedCommands.add(command);
    if (saveGate != null) await saveGate;
    return definition(
      command.payload.id,
      version: command.expectedVersion + 1,
      confirmedTitle: savedTitle,
    );
  }

  @override
  Future<FormDefinition> publish(FormCommand<FormIdPayload> command) async {
    publishCommands.add(command);
    if (publishGate != null) await publishGate;
    return definition(
      requestedForms.last,
      version: command.expectedVersion + 1,
      confirmedTitle: publishedTitle,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
