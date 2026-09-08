import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<FormSection> sections({bool branch = false}) => [
    FormSection(
      id: 'section-a',
      title: 'First section',
      position: 0,
      items: [
        FormItem(
          id: 'item-a',
          kind: branch ? FormItemKind.yesNo : FormItemKind.shortText,
          label: 'First answer',
          position: 0,
          isRequired: true,
        ),
      ],
    ),
    FormSection(
      id: 'section-b',
      title: 'Second section',
      position: 1,
      items: [
        FormItem(
          id: 'item-b',
          kind: FormItemKind.decimal,
          label: 'Second answer',
          position: 0,
          isRequired: true,
          conditions: branch
              ? const [FormCondition.yesNo(sourceItemId: 'item-a', expected: true)]
              : const [],
        ),
      ],
    ),
  ];
  Future<void> open(
    WidgetTester tester,
    _ResponseApi api, {
    String occurrence = 'occurrence-1',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormResponsePage(api: api, occurrenceId: occurrence),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('response presents one section and preserves numeric text across navigation', (
    tester,
  ) async {
    final api = _ResponseApi(sections: sections());
    await open(tester, api);
    expect(find.text('First section'), findsOneWidget);
    expect(find.text('Second section'), findsNothing);
    expect(find.text('Seção 1 de 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('form-response-next-section')));
    await tester.pump();
    expect(find.text('First section'), findsNothing);
    expect(find.text('Seção 2 de 2'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('form-response-item-item-b')), '-');
    await tester.tap(find.byKey(const Key('form-response-previous-section')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-next-section')));
    await tester.pump();
    expect(find.text('-'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(api.saveCalls, isEmpty);
    expect(api.submitCommand, isNull);
  });

  testWidgets('global response review navigates to the first missing section', (tester) async {
    final api = _ResponseApi(sections: sections());
    await open(tester, api);
    await tester.tap(find.byKey(const Key('form-response-next-section')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('form-response-item-item-b')), '12');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pump();
    expect(find.text('Seção 1 de 2'), findsOneWidget);
    expect(find.byKey(const Key('form-response-submit')), findsNothing);
    expect(api.submitCommand, isNull);
  });

  testWidgets('response section progress excludes a fully hidden conditional section', (
    tester,
  ) async {
    final api = _ResponseApi(sections: sections(branch: true));
    await open(tester, api);
    expect(find.text('Seção 1 de 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sim'));
    await tester.pump();
    expect(find.text('Seção 1 de 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('form-response-next-section')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('form-response-item-item-b')), '12');
    await tester.tap(find.byKey(const Key('form-response-previous-section')));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Não'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Seção 1 de 1'), findsOneWidget);
    expect(api.saveCalls.last.payload.answers.keys, ['item-a']);
  });

  testWidgets('global review chooses first section even when a later number is invalid', (
    tester,
  ) async {
    final api = _ResponseApi(sections: sections());
    await open(tester, api);
    await tester.tap(find.byKey(const Key('form-response-next-section')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('form-response-item-item-b')), '-');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pump();
    expect(find.text('Seção 1 de 2'), findsOneWidget);
  });

  testWidgets('navigation preserves pending autosave and focus stays in the active section', (
    tester,
  ) async {
    final api = _ResponseApi(sections: sections());
    await open(tester, api);
    await tester.enterText(find.byKey(const Key('form-response-item-item-a')), 'First value');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-next-section')));
    await tester.pump();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.widget is Focus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('form-response-item-item-b')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.focusNode.hasFocus, isTrue);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.saveCalls, hasLength(1));
    expect(api.saveCalls.single.payload.answers.keys, ['item-a']);
    expect(find.text('Seção 2 de 2'), findsOneWidget);
  });

  testWidgets('receipt hiding the active section chooses a visible destination', (tester) async {
    final gate = Completer<void>();
    final api = _ResponseApi(
      sections: sections(branch: true),
      saveGate: gate.future,
      receiptAnswers: {'item-a': FormAnswer.yesNo(itemId: 'item-a', value: false)},
    );
    await open(tester, api);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sim'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const Key('form-response-next-section')));
    await tester.pump();
    expect(find.text('Seção 2 de 2'), findsOneWidget);
    gate.complete();
    await tester.pump();
    expect(find.text('Seção 1 de 1'), findsOneWidget);
    expect(find.byKey(const Key('form-response-item-item-b')), findsNothing);
  });

  for (final replaceApi in [false, true]) {
    testWidgets('response section context and focus reset on API replacement=$replaceApi', (
      tester,
    ) async {
      final api = _ResponseApi(sections: sections());
      await open(tester, api);
      await tester.tap(find.byKey(const Key('form-response-next-section')));
      await open(
        tester,
        replaceApi ? _ResponseApi(sections: sections()) : api,
        occurrence: replaceApi ? 'occurrence-1' : 'occurrence-2',
      );
      expect(find.text('Seção 1 de 2'), findsOneWidget);
      expect(find.byKey(const Key('form-response-item-item-b')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('response review includes answers from every presented section', (tester) async {
    final api = _ResponseApi(sections: sections());
    await open(tester, api);
    await tester.enterText(find.byKey(const Key('form-response-item-item-a')), 'First value');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-next-section')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('form-response-item-item-b')), '12');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pump();
    expect(find.text('First answer: First value'), findsOneWidget);
    expect(find.text('Second answer: 12.0'), findsOneWidget);
    expect(api.submitCommand, isNull);
  });

  testWidgets('response section navigation fits 375px at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _ResponseApi(sections: sections());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final next = find.byKey(const Key('form-response-next-section'));
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pump();
    expect(find.text('Seção 2 de 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final previous = find.byKey(const Key('form-response-previous-section'));
    await tester.ensureVisible(previous);
    await tester.pumpAndSettle();
    await tester.tap(previous);
    await tester.pump();
    expect(find.text('Seção 1 de 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('response autosave debounces edits and does not save hydration', (tester) async {
    final api = _ResponseApi();
    await open(tester, api);
    await tester.pump(const Duration(seconds: 2));
    expect(api.saveCalls, isEmpty);
    final field = find.byKey(const Key('form-response-item-item-1'));
    await tester.enterText(field, 'First');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(field, 'Latest');
    await tester.pump(const Duration(milliseconds: 799));
    expect(api.saveCalls, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(api.saveCalls, hasLength(1));
    expect(
      api.saveCalls.single.payload.answers['item-1']!.value,
      isA<FormShortTextValue>().having((value) => value.value, 'answer', 'Latest'),
    );
    expect(find.text('Rascunho salvo.'), findsOneWidget);
  });

  testWidgets('response autosave saves incomplete draft without submitting', (tester) async {
    final api = _ResponseApi();
    await open(tester, api);
    final field = find.byKey(const Key('form-response-item-item-1'));
    await tester.enterText(field, 'Temporary');
    await tester.enterText(field, '');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.saveCalls, hasLength(1));
    expect(api.saveCalls.single.payload.answers, isEmpty);
    expect(api.submitCommand, isNull);
  });

  testWidgets('response autosave serializes local edits during receipt wait', (tester) async {
    final gate = Completer<void>();
    final api = _ResponseApi(saveGate: gate.future);
    await open(tester, api);
    final field = find.byKey(const Key('form-response-item-item-1'));
    await tester.enterText(field, 'First');
    await tester.pump(const Duration(milliseconds: 800));
    expect(api.saveCalls, hasLength(1));
    await tester.enterText(field, 'Later');
    await tester.pump(const Duration(seconds: 2));
    expect(api.saveCalls, hasLength(1));
    gate.complete();
    await tester.pump();
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.saveCalls, hasLength(2));
    expect(api.saveCalls.last.expectedVersion, 2);
    expect(find.text('Later'), findsOneWidget);
  });

  for (final replacement in ['api', 'occurrence', 'dispose']) {
    testWidgets('response autosave rejects retained callback after $replacement', (tester) async {
      final first = _ResponseApi();
      await open(tester, first);
      final field = find.byKey(const Key('form-response-item-item-1'));
      final retained = tester.widget<TextFormField>(field).onChanged!;
      await tester.enterText(field, 'Obsolete answer');
      final next = replacement == 'api' ? _ResponseApi() : first;
      if (replacement == 'dispose') {
        await tester.pumpWidget(const SizedBox());
      } else {
        await open(
          tester,
          next,
          occurrence: replacement == 'occurrence' ? 'occurrence-2' : 'occurrence-1',
        );
      }
      retained('Obsolete callback');
      await tester.pump(const Duration(seconds: 2));
      expect(first.saveCalls, isEmpty);
      expect(next.saveCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('response autosave is paused in review and submit stays explicit', (tester) async {
    final api = _ResponseApi();
    await open(tester, api);
    await tester.enterText(find.byKey(const Key('form-response-item-item-1')), 'Reviewed answer');
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(api.saveCalls, isEmpty);
    expect(api.submitCommand, isNull);
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(api.submitCommand, isNotNull);
    expect(api.saveCalls, isEmpty);
  });

  for (final failure in [FormApiFailureKind.conflict, FormApiFailureKind.unauthorized]) {
    testWidgets('response autosave pauses after $failure', (tester) async {
      final api = _ResponseApi()..saveFailure = failure;
      await open(tester, api);
      final field = find.byKey(const Key('form-response-item-item-1'));
      await tester.enterText(field, 'Unconfirmed answer');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      if (failure == FormApiFailureKind.conflict) {
        await tester.enterText(field, 'Later edit');
      } else {
        expect(field, findsNothing);
      }
      await tester.pump(const Duration(seconds: 3));
      expect(api.saveCalls, hasLength(1));
      expect(find.text('Rascunho salvo.'), findsNothing);
    });
  }

  testWidgets('response autosave lost confirmation requires manual replay before later save', (
    tester,
  ) async {
    final api = _ResponseApi(lostConfirmation: 'save');
    await open(tester, api);
    final field = find.byKey(const Key('form-response-item-item-1'));
    await tester.enterText(field, 'Committed answer');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.enterText(field, 'Later answer');
    await tester.pump(const Duration(seconds: 3));
    expect(api.saveCalls, hasLength(1));
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.tap(find.byKey(const Key('form-response-save-draft')));
    await tester.pump();
    expect(identical(api.saveCalls.first, api.saveCalls.last), isTrue);
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.saveCalls, hasLength(3));
    expect(api.saveCalls.last.expectedVersion, 2);
    expect(find.text('Rascunho salvo.'), findsOneWidget);
  });

  for (final raw in ['-', 'NaN', 'Infinity']) {
    testWidgets('response autosave preserves numeric draft while invalid input is $raw', (
      tester,
    ) async {
      final api = _ResponseApi(
        kind: FormItemKind.decimal,
        initialAnswers: {'item-1': FormAnswer.decimal(itemId: 'item-1', value: 12)},
      );
      await open(tester, api);
      final field = find.byKey(const Key('form-response-item-item-1'));
      await tester.enterText(field, raw);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(api.saveCalls, isEmpty);
      await tester.tap(find.byKey(const Key('form-response-save-draft')));
      await tester.pump();
      expect(api.saveCalls, isEmpty);
      await tester.enterText(field, '14,5');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(api.saveCalls, hasLength(1));
      expect(
        api.saveCalls.single.payload.answers['item-1']!.value,
        isA<FormDecimalValue>().having((value) => value.value, 'number', 14.5),
      );
    });
  }

  for (final replaceContext in [false, true]) {
    testWidgets('retained submit cannot bypass fresh review after context change=$replaceContext', (
      tester,
    ) async {
      final first = _ResponseApi();
      await open(tester, first);
      final field = find.byKey(const Key('form-response-item-item-1'));
      await tester.enterText(field, 'Reviewed A');
      await tester.pump();
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pump();
      final oldSubmit = tester
          .widget<FilledButton>(find.byKey(const Key('form-response-submit')))
          .onPressed!;
      final next = replaceContext ? _ResponseApi() : first;
      if (replaceContext) await open(tester, next, occurrence: 'occurrence-2');
      await tester.enterText(field, 'Unreviewed B');
      await tester.pump();
      oldSubmit();
      await tester.pump();
      expect(next.submitCommand, isNull);
      // A current explicit review followed by send remains available.
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('form-response-submit')));
      await tester.pump();
      expect(next.submitCommand, isNotNull);
    });
  }

  testWidgets('response autosave clears invalid numeric state when its branch is hidden', (
    tester,
  ) async {
    final api = _ResponseApi(
      items: [
        FormItem(id: 'root', kind: FormItemKind.yesNo, label: 'Root', position: 0),
        FormItem(
          id: 'number',
          kind: FormItemKind.integer,
          label: 'Number',
          position: 1,
          conditions: const [FormCondition.yesNo(sourceItemId: 'root', expected: true)],
        ),
      ],
    );
    await open(tester, api);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sim'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('form-response-item-number')), '1.5');
    await tester.pump(const Duration(seconds: 2));
    expect(api.saveCalls, isEmpty);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Não'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.saveCalls.single.payload.answers.keys, ['root']);
  });

  testWidgets('confirmed submission clears transient invalid numeric edit before reopening', (
    tester,
  ) async {
    final gate = Completer<void>();
    final api = _ResponseApi(kind: FormItemKind.decimal, submitGate: gate.future);
    await open(tester, api);
    final field = find.byKey(const Key('form-response-item-item-1'));
    await tester.enterText(field, '12');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pump();
    await tester.enterText(field, '-');
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada'), findsOneWidget);
    await tester.tap(find.text('Editar resposta'));
    await tester.pump();
    expect(api.editCommand, isNotNull);
  });

  testWidgets('response autosave feedback fits 375px at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _ResponseApi();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-response-item-item-1')), 'Synthetic answer');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.saveCalls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lost save replay preserves newer answers and the next intent uses the confirmed version',
    (tester) async {
      final api = _ResponseApi(lostConfirmation: 'save');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('form-response-item-item-1'));
      final save = find.byKey(const Key('form-response-save-draft'));
      await tester.enterText(field, 'Original answer');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('form-response-review'))).onPressed,
        isNull,
      );
      await tester.enterText(field, 'New local answer');
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      expect(find.text('New local answer'), findsOneWidget);
      expect(
        find.text('Salvamento anterior confirmado. Há alterações locais ainda não salvas.'),
        findsOneWidget,
      );
      expect(identical(api.confirmationCalls[0].$2, api.confirmationCalls[1].$2), isTrue);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.confirmationCalls.last.$2.expectedVersion, 2);
      expect(
        api.confirmationCalls.last.$2.requestId,
        isNot(api.confirmationCalls.first.$2.requestId),
      );
      expect(
        api.confirmationCalls.last.$2.payload.answers['item-1']?.value,
        isA<FormShortTextValue>().having((value) => value.value, 'new intent', 'New local answer'),
      );
    },
  );

  for (final operation in ['save', 'submit', 'edit']) {
    testWidgets('lost $operation confirmation retries the exact committed command', (tester) async {
      final api = _ResponseApi(lostConfirmation: operation);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('form-response-item-item-1')), 'Original answer');
      Future<void> invoke() async {
        if (operation == 'save') {
          await tester.tap(find.byKey(const Key('form-response-save-draft')));
        } else if (operation == 'submit') {
          await tester.tap(find.byKey(const Key('form-response-submit')));
        } else {
          await tester.tap(find.text('Editar resposta'));
        }
        await tester.pumpAndSettle();
      }

      if (operation != 'save') {
        await tester.tap(find.byKey(const Key('form-response-review')));
        await tester.pumpAndSettle();
        if (operation == 'edit') {
          await tester.tap(find.byKey(const Key('form-response-submit')));
          await tester.pumpAndSettle();
        }
      }
      await invoke();
      expect(find.text('Confirmation lost'), findsOneWidget);
      if (operation == 'submit') {
        expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('form-response-save-draft')))
              .onPressed,
          isNull,
        );
      }
      await invoke();
      final commands = api.confirmationCalls
          .where((call) => call.$1 == operation)
          .map((call) => call.$2)
          .toList();
      expect(commands.length, 2);
      expect(identical(commands[0], commands[1]), isTrue);
      expect(find.text('Conflict after duplicate request'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in [FormItemKind.shortText, FormItemKind.multipleChoice]) {
    testWidgets('empty loaded $kind does not satisfy a required answer', (tester) async {
      final api = _ResponseApi(
        items: [
          FormItem(id: 'required', kind: kind, label: 'Required', position: 0, isRequired: true),
        ],
        initialAnswers: {
          'required': kind == FormItemKind.shortText
              ? FormAnswer.shortText(itemId: 'required', value: '   ')
              : FormAnswer.multipleChoice(itemId: 'required', optionIds: const {}),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pumpAndSettle();
      expect(find.text('Revisão da resposta'), findsNothing);
      expect(api.submitCommand, isNull);
    });
  }

  for (final kind in [
    FormItemKind.yesNo,
    FormItemKind.singleChoice,
    FormItemKind.multipleChoice,
    FormItemKind.scale,
    FormItemKind.date,
  ]) {
    testWidgets('required $kind must be answered before review', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _ResponseApi(
        items: [
          FormItem(
            id: 'required',
            kind: kind,
            label: 'Required question',
            position: 0,
            isRequired: true,
            config: const FormItemConfig(scaleMin: 0, scaleMax: 2),
            options: kind == FormItemKind.singleChoice || kind == FormItemKind.multipleChoice
                ? const [
                    FormOption(id: 'a', label: 'A', position: 0),
                    FormOption(id: 'b', label: 'B', position: 1),
                  ]
                : const [],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pumpAndSettle();
      expect(find.text('Revisão da resposta'), findsNothing);
      expect(api.submitCommand, isNull);
      switch (kind) {
        case FormItemKind.yesNo:
          await tester.tap(find.widgetWithText(ChoiceChip, 'Não'));
        case FormItemKind.singleChoice:
          await tester.tap(find.widgetWithText(ChoiceChip, 'A'));
        case FormItemKind.multipleChoice:
          await tester.tap(find.widgetWithText(FilterChip, 'A'));
        case FormItemKind.scale:
          await tester.tap(find.widgetWithText(ChoiceChip, '0'));
        case FormItemKind.date:
          await tester.tap(find.text('Selecionar data'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('OK'));
        default:
          throw StateError('Unsupported test case');
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pumpAndSettle();
      expect(find.text('Revisão da resposta'), findsOneWidget);
      await tester.tap(find.byKey(const Key('form-response-submit')));
      await tester.pumpAndSettle();
      expect(api.submitCommand?.payload.answers['required'], isNotNull);
      expect(find.text('Resposta enviada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('submitted summary shows the confirmed receipt, not edits during submit', (
    tester,
  ) async {
    final pending = Completer<void>();
    final api = _ResponseApi(submitGate: pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-response-item-item-1')), 'Confirmed answer');
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('form-response-item-item-1')), 'Unconfirmed edit');
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada'), findsOneWidget);
    expect(find.textContaining('Confirmed answer'), findsOneWidget);
    expect(find.textContaining('Unconfirmed edit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final fromReceipt in [false, true]) {
    testWidgets('residual hidden answers are removed from ${fromReceipt ? 'receipt' : 'load'}', (
      tester,
    ) async {
      final residual = {
        'root': FormAnswer.yesNo(itemId: 'root', value: false),
        'leaf': FormAnswer.shortText(itemId: 'leaf', value: 'Residual hidden answer'),
      };
      final api = _ResponseApi(
        initialAnswers: fromReceipt ? {'root': residual['root']!} : residual,
        receiptAnswers: fromReceipt ? residual : null,
        items: [
          FormItem(
            id: 'leaf',
            kind: FormItemKind.shortText,
            label: 'Leaf',
            position: 0,
            conditions: const [FormCondition.yesNo(sourceItemId: 'root', expected: true)],
          ),
          FormItem(id: 'root', kind: FormItemKind.yesNo, label: 'Root', position: 1),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
        ),
      );
      await tester.pumpAndSettle();
      if (fromReceipt) {
        await tester.tap(find.byKey(const Key('form-response-save-draft')));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Residual hidden answer'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sim'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(find.byKey(const Key('form-response-item-leaf')));
      expect(field.initialValue, isEmpty);
      await tester.tap(find.byKey(const Key('form-response-save-draft')));
      await tester.pumpAndSettle();
      expect(api.saveCommand?.payload.answers.keys, ['root']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('late branch save receipt preserves newer hidden-branch intent', (tester) async {
    final pending = Completer<void>();
    final api = _ResponseApi(
      saveGate: pending.future,
      items: [
        FormItem(id: 'root', kind: FormItemKind.yesNo, label: 'Root', position: 0),
        FormItem(
          id: 'leaf',
          kind: FormItemKind.shortText,
          label: 'Leaf',
          position: 1,
          conditions: const [FormCondition.yesNo(sourceItemId: 'root', expected: true)],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sim'));
    // Keep this manual-save regression before the new autosave debounce.
    await tester.pump();
    await tester.enterText(find.byKey(const Key('form-response-item-leaf')), 'Obsolete branch');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-response-save-draft')));
    await tester.pump();
    expect(api.saveCommand?.payload.answers.keys, ['root', 'leaf']);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Não'));
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-response-item-leaf')), findsNothing);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Não')).selected, isTrue);
    await tester.tap(find.byKey(const Key('form-response-save-draft')));
    await tester.pumpAndSettle();
    expect(api.saveCommand?.expectedVersion, 2);
    expect(api.saveCommand?.payload.answers.keys, ['root']);
    expect(tester.takeException(), isNull);
  });

  for (final nested in [false, true]) {
    testWidgets('hidden branch values leave review and commands nested=$nested', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _ResponseApi(
        items: [
          FormItem(id: 'root', kind: FormItemKind.yesNo, label: 'Root', position: 0),
          if (nested)
            FormItem(
              id: 'middle',
              kind: FormItemKind.yesNo,
              label: 'Middle',
              position: 1,
              conditions: const [FormCondition.yesNo(sourceItemId: 'root', expected: true)],
            ),
          FormItem(
            id: 'leaf',
            kind: FormItemKind.shortText,
            label: 'Leaf',
            position: nested ? 2 : 1,
            conditions: [
              FormCondition.yesNo(sourceItemId: nested ? 'middle' : 'root', expected: true),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sim').first);
      await tester.pumpAndSettle();
      if (nested) {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Sim').last);
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byKey(const Key('form-response-item-leaf')),
        'Hidden sensitive answer',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Não').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form-response-item-leaf')), findsNothing);
      await tester.tap(find.byKey(const Key('form-response-save-draft')));
      await tester.pumpAndSettle();
      expect(api.saveCommand?.payload.answers.keys, ['root']);
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hidden sensitive answer'), findsNothing);
      await tester.tap(find.byKey(const Key('form-response-submit')));
      await tester.pumpAndSettle();
      expect(api.submitCommand?.payload.answers.keys, ['root']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('one matching branch condition is enough, consistent with the domain', (
    tester,
  ) async {
    final api = _ResponseApi(
      items: [
        FormItem(
          id: 'root',
          kind: FormItemKind.multipleChoice,
          label: 'Root',
          position: 0,
          options: const [
            FormOption(id: 'a', label: 'A', position: 0),
            FormOption(id: 'b', label: 'B', position: 1),
          ],
        ),
        FormItem(
          id: 'leaf',
          kind: FormItemKind.shortText,
          label: 'Leaf',
          position: 1,
          conditions: const [
            FormCondition.choice(sourceItemId: 'root', optionIds: {'a'}),
            FormCondition.choice(sourceItemId: 'root', optionIds: {'b'}),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'A'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-response-item-leaf')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final imageKind in [FormItemKind.photo, FormItemKind.gallery]) {
    for (final visible in [false, true]) {
      testWidgets('$imageKind required attachment follows visible=$visible', (tester) async {
        final api = _ResponseApi(kind: FormItemKind.yesNo, conditionalImageKind: imageKind);
        await tester.binding.setSurfaceSize(const Size(1000, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, visible ? 'Sim' : 'Não'));
        await tester.pumpAndSettle();
        expect(find.text('Anexo indisponível'), visible ? findsOneWidget : findsNothing);
        await tester.tap(find.byKey(const Key('form-response-review')));
        await tester.pumpAndSettle();
        expect(find.text('Revisão da resposta'), visible ? findsNothing : findsOneWidget);
        expect(
          find.text(
            'Este formulário exige anexo e o envio protegido ainda não está disponível nesta superfície.',
          ),
          visible ? findsOneWidget : findsNothing,
        );
        if (!visible) {
          await tester.tap(find.byKey(const Key('form-response-submit')));
          await tester.pumpAndSettle();
          expect(api.submitCommand?.payload.answers.keys, ['item-1']);
          expect(find.text('Resposta enviada'), findsOneWidget);
        } else {
          expect(api.submitCommand, isNull);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('date picker result from an old context cannot populate the new response', (
    tester,
  ) async {
    final first = _ResponseApi(kind: FormItemKind.date);
    final second = _ResponseApi(kind: FormItemKind.date);
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: first, occurrenceId: 'occurrence-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar data'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: second, occurrenceId: 'occurrence-2'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-save-draft')));
    await tester.pumpAndSettle();
    expect(second.saveCommand?.payload.answers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets('obsolete save ${fails ? 'failure' : 'receipt'} does not affect the next context', (
      tester,
    ) async {
      final pending = Completer<void>();
      final first = _ResponseApi(saveGate: pending.future);
      final second = _ResponseApi();
      await tester.pumpWidget(
        MaterialApp(
          home: FormResponsePage(api: first, occurrenceId: 'occurrence-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('form-response-item-item-1')),
        'Answer from context A',
      );
      await tester.tap(find.byKey(const Key('form-response-save-draft')));
      await tester.pump();
      expect(first.saveCommand, isNotNull);
      await tester.pumpWidget(
        MaterialApp(
          home: FormResponsePage(api: second, occurrenceId: 'occurrence-2'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('form-response-item-item-1')),
        'Answer from context B',
      );
      if (fails) {
        pending.completeError(
          const FormApiException(FormApiFailureKind.conflict, 'Obsolete save error'),
        );
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(find.text('Obsolete save error'), findsNothing);
      await tester.tap(find.byKey(const Key('form-response-save-draft')));
      await tester.pumpAndSettle();
      expect(second.saveCommand?.expectedVersion, 1);
      expect(second.saveCommand?.payload.occurrenceId, 'occurrence-2');
      expect(second.saveCommand?.payload.responseId, 'response-occurrence-2');
      expect(
        second.saveCommand?.payload.answers['item-1']?.value,
        isA<FormShortTextValue>().having((value) => value.value, 'answer', 'Answer from context B'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final replaceApi in [false, true]) {
    testWidgets('production clears answers when ${replaceApi ? 'API' : 'occurrence'} changes', (
      tester,
    ) async {
      final first = _ResponseApi();
      final second = replaceApi ? _ResponseApi() : first;
      await tester.pumpWidget(
        MaterialApp(
          home: FormResponsePage(api: first, occurrenceId: 'occurrence-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('form-response-item-item-1')),
        'Answer from context A',
      );

      final nextId = replaceApi ? 'occurrence-1' : 'occurrence-2';
      await tester.pumpWidget(
        MaterialApp(
          home: FormResponsePage(api: second, occurrenceId: nextId),
        ),
      );
      expect(find.text('Answer from context A'), findsNothing);
      await tester.pumpAndSettle();
      expect(
        second.requestedOccurrences,
        replaceApi ? ['occurrence-1'] : ['occurrence-1', 'occurrence-2'],
      );
      await tester.enterText(
        find.byKey(const Key('form-response-item-item-1')),
        'Answer from context B',
      );
      await tester.tap(find.byKey(const Key('form-response-save-draft')));
      await tester.pumpAndSettle();
      expect(second.saveCommand?.payload.occurrenceId, nextId);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('obsolete occurrence lookup cannot open a draft after context replacement', (
    tester,
  ) async {
    final pending = Completer<void>();
    final first = _ResponseApi(loadGate: pending.future, label: 'Old question');
    final second = _ResponseApi(label: 'New question');
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: first, occurrenceId: 'occurrence-1'),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: second, occurrenceId: 'occurrence-2'),
      ),
    );
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(first.openCalls, 0);
    expect(second.openCalls, 1);
    expect(find.text('Old question *'), findsNothing);
    expect(find.text('New question *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed occurrence lookup cannot open a response draft', (tester) async {
    final pending = Completer<void>();
    final api = _ResponseApi(loadGate: pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete();
    await tester.pumpAndSettle();
    expect(api.openCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production fails closed without an authorized occurrence', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormResponsePage()));

    expect(find.byKey(const Key('form-response-unavailable')), findsOneWidget);
    expect(find.textContaining('ocorrência autorizada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production opens, saves and submits the authorized response draft', (tester) async {
    final api = _ResponseApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(api: api, occurrenceId: 'occurrence-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.openCalls, 1);
    expect(find.text('Como foi o acolhimento? *'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('form-response-item-item-1')), 'Muito cuidadoso');
    await tester.tap(find.byKey(const Key('form-response-save-draft')));
    await tester.pumpAndSettle();
    expect(api.saveCommand?.expectedVersion, 1);
    expect(api.saveCommand?.payload.answers['item-1'], isA<FormAnswer>());
    expect(api.saveCommand?.requestId, matches(RegExp(r'^[0-9a-f-]{36}$')));

    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    expect(api.submitCommand?.expectedVersion, 2);
    expect(find.text('Resposta enviada'), findsOneWidget);
    await tester.tap(find.text('Editar resposta'));
    await tester.pumpAndSettle();
    expect(api.editCommand?.expectedVersion, 3);
    expect(find.byKey(const Key('form-response-save-draft')), findsOneWidget);
  });

  testWidgets('autosave exposes one real state and reacts to editing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormResponsePage.development()));

    expect(find.text('Inicial'), findsOneWidget);
    expect(find.text('Alterado'), findsNothing);
    expect(find.text('Salvando'), findsNothing);
    expect(find.text('Salvo'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Resposta local');
    await tester.pump();
    expect(find.text('Alterado'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Salvando'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Salvo'), findsOneWidget);
  });

  testWidgets('development response preserves the selected form context', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FormResponsePage.development(formId: 'form-dev-02')),
    );

    expect(find.text('Enquete rápida sobre transporte'), findsOneWidget);
  });

  testWidgets('cancelar upload preserva a resposta e encerra o progresso local', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormResponsePage.development()));
    await tester.enterText(find.byType(TextFormField), 'Não perder');

    await tester.tap(find.text('Cancelar upload'));
    await tester.pump();

    expect(find.text('Upload cancelado'), findsOneWidget);
    expect(find.byKey(const Key('form-response-upload-progress')), findsNothing);
    expect(find.text('Não perder'), findsOneWidget);
  });
}

final class _ResponseApi implements FormsApi {
  _ResponseApi({
    this.loadGate,
    this.saveGate,
    this.submitGate,
    this.label = 'Como foi o acolhimento?',
    this.kind = FormItemKind.shortText,
    this.conditionalImageKind,
    this.items,
    this.sections,
    this.initialAnswers = const {},
    this.receiptAnswers,
    this.lostConfirmation,
  });

  final Future<void>? loadGate;
  final Future<void>? saveGate;
  final Future<void>? submitGate;
  final String label;
  final FormItemKind kind;
  final FormItemKind? conditionalImageKind;
  final List<FormItem>? items;
  final List<FormSection>? sections;
  final Map<String, FormAnswer> initialAnswers;
  final Map<String, FormAnswer>? receiptAnswers;
  final String? lostConfirmation;
  FormApiFailureKind? saveFailure;
  final confirmationCalls = <(String, FormCommand<FormResponseDraftPayload>)>[];
  final _confirmed = <String, FormResponseDraft>{};
  int? _remoteVersion;
  bool _lostOnce = false;

  FormResponseDraft _commitWithLostConfirmation(
    String operation,
    FormCommand<FormResponseDraftPayload> command,
  ) {
    confirmationCalls.add((operation, command));
    if (_confirmed[command.requestId] case final receipt?) return receipt;
    if (_remoteVersion != null && command.expectedVersion != _remoteVersion) {
      throw const FormApiException(FormApiFailureKind.conflict, 'Conflict after duplicate request');
    }
    final receipt = FormResponseDraft(
      id: command.payload.responseId,
      occurrenceId: command.payload.occurrenceId,
      status: operation == 'submit'
          ? FormResponseDraftStatus.submitted
          : FormResponseDraftStatus.draft,
      answers: command.payload.answers,
      managementVersion: command.expectedVersion + 1,
    );
    _remoteVersion = receipt.managementVersion;
    _confirmed[command.requestId] = receipt;
    if (!_lostOnce) {
      _lostOnce = true;
      throw const FormApiException(FormApiFailureKind.unavailable, 'Confirmation lost');
    }
    return receipt;
  }

  final List<String> requestedOccurrences = [];
  int openCalls = 0;
  FormCommand<FormResponseDraftPayload>? saveCommand;
  final saveCalls = <FormCommand<FormResponseDraftPayload>>[];
  FormCommand<FormResponseDraftPayload>? submitCommand;
  FormCommand<FormResponseDraftPayload>? editCommand;

  @override
  Future<FormOccurrenceForResponse> getOccurrenceForResponse(String occurrenceId) async {
    requestedOccurrences.add(occurrenceId);
    if (loadGate != null) await loadGate;
    return FormOccurrenceForResponse(
      occurrence: FormOccurrence(
        id: occurrenceId,
        applicationId: 'application-1',
        formVersionId: 'version-1',
        opensAt: DateTime(2026),
        closesAt: DateTime(2026, 12, 31),
        status: FormOccurrenceStatus.open,
        managementVersion: 1,
      ),
      version: FormVersion(
        id: 'version-1',
        formId: 'form-1',
        number: 1,
        isPublished: true,
        sections:
            sections ??
            [
              FormSection(
                id: 'section-1',
                title: 'Cuidado',
                position: 0,
                items:
                    items ??
                    [
                      FormItem(
                        id: 'item-1',
                        kind: kind,
                        label: label,
                        position: 0,
                        isRequired: true,
                      ),
                      if (conditionalImageKind case final imageKind?)
                        FormItem(
                          id: 'image-1',
                          kind: imageKind,
                          label: 'Conditional image',
                          position: 1,
                          isRequired: true,
                          conditions: const [
                            FormCondition.yesNo(sourceItemId: 'item-1', expected: true),
                          ],
                        ),
                    ],
              ),
            ],
      ),
      participationId: 'participation-1',
      identityMode: FormIdentityMode.identified,
      canEdit: true,
    );
  }

  @override
  Future<FormResponseDraft> openResponseDraft(
    FormCommand<FormOpenResponseDraftPayload> command,
  ) async {
    openCalls++;
    return _draft(1, command.payload.occurrenceId);
  }

  @override
  Future<FormResponseDraft> saveResponseDraft(FormCommand<FormResponseDraftPayload> command) async {
    saveCommand = command;
    saveCalls.add(command);
    if (saveFailure != null) throw FormApiException(saveFailure!, 'Save denied');
    if (lostConfirmation == 'save') return _commitWithLostConfirmation('save', command);
    if (saveGate != null) await saveGate;
    return FormResponseDraft(
      id: command.payload.responseId,
      occurrenceId: command.payload.occurrenceId,
      status: FormResponseDraftStatus.draft,
      answers: receiptAnswers ?? command.payload.answers,
      managementVersion: command.expectedVersion + 1,
    );
  }

  @override
  Future<FormResponseDraft> submitResponse(FormCommand<FormResponseDraftPayload> command) async {
    submitCommand = command;
    if (lostConfirmation == 'submit') return _commitWithLostConfirmation('submit', command);
    if (submitGate != null) await submitGate;
    return FormResponseDraft(
      id: 'response-1',
      occurrenceId: command.payload.occurrenceId,
      status: FormResponseDraftStatus.submitted,
      answers: command.payload.answers,
      managementVersion: 3,
    );
  }

  @override
  Future<FormResponseDraft> editResponse(FormCommand<FormResponseDraftPayload> command) async {
    editCommand = command;
    if (lostConfirmation == 'edit') return _commitWithLostConfirmation('edit', command);
    return FormResponseDraft(
      id: 'response-1',
      occurrenceId: command.payload.occurrenceId,
      status: FormResponseDraftStatus.draft,
      answers: command.payload.answers,
      managementVersion: command.expectedVersion + 1,
    );
  }

  FormResponseDraft _draft(int version, String occurrenceId) => FormResponseDraft(
    id: 'response-$occurrenceId',
    occurrenceId: occurrenceId,
    status: FormResponseDraftStatus.draft,
    answers: initialAnswers,
    managementVersion: version,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
