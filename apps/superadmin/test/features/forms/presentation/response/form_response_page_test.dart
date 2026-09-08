import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-response-item-leaf')), 'Obsolete branch');
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
    this.initialAnswers = const {},
    this.receiptAnswers,
  });

  final Future<void>? loadGate;
  final Future<void>? saveGate;
  final Future<void>? submitGate;
  final String label;
  final FormItemKind kind;
  final FormItemKind? conditionalImageKind;
  final List<FormItem>? items;
  final Map<String, FormAnswer> initialAnswers;
  final Map<String, FormAnswer>? receiptAnswers;
  final List<String> requestedOccurrences = [];
  int openCalls = 0;
  FormCommand<FormResponseDraftPayload>? saveCommand;
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
        sections: [
          FormSection(
            id: 'section-1',
            title: 'Cuidado',
            position: 0,
            items:
                items ??
                [
                  FormItem(id: 'item-1', kind: kind, label: label, position: 0, isRequired: true),
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
    if (saveGate != null) await saveGate;
    return FormResponseDraft(
      id: command.payload.responseId,
      occurrenceId: command.payload.occurrenceId,
      status: FormResponseDraftStatus.draft,
      answers: receiptAnswers ?? command.payload.answers,
      managementVersion: 2,
    );
  }

  @override
  Future<FormResponseDraft> submitResponse(FormCommand<FormResponseDraftPayload> command) async {
    submitCommand = command;
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
