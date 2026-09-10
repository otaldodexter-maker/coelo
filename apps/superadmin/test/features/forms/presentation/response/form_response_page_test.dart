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

  for (final required in [true, false]) {
    for (final count in [1, 2, 5, 6]) {
      testWidgets('gallery bounds restored count $count required $required', (tester) async {
        final ids = List.generate(count, (index) => 'asset-$index');
        final api = _ResponseApi(
          items: [
            FormItem(
              id: 'item-1',
              kind: FormItemKind.gallery,
              label: 'Gallery',
              position: 0,
              isRequired: required,
              config: const FormItemConfig(minImages: 2, maxImages: 5),
            ),
          ],
          initialAnswers: {'item-1': FormAnswer.gallery(itemId: 'item-1', assetIds: ids)},
        );
        await tester.binding.setSurfaceSize(const Size(1000, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await open(tester, api);
        await tester.tap(find.byKey(const Key('form-response-review')));
        await tester.pumpAndSettle();
        if (count < 2 || count > 5) {
          expect(find.text('Revisão da resposta'), findsNothing);
          expect(find.text('Esta galeria exige entre 2 e 5 imagens.'), findsOneWidget);
          expect(find.byKey(const Key('form-response-submit')), findsNothing);
          expect(api.submitCommand, isNull);
        } else {
          expect(find.text('Revisão da resposta'), findsOneWidget);
          await tester.tap(find.byKey(const Key('form-response-submit')));
          await tester.pumpAndSettle();
          expect(
            (api.submitCommand!.payload.answers['item-1']!.value as FormAssetValue).assetIds,
            ids,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final imageKind in [FormItemKind.photo, FormItemKind.gallery]) {
    for (final required in [true, false]) {
      testWidgets('empty assets omitted from incomplete save $imageKind required $required', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = _ResponseApi(
          items: [
            FormItem(
              id: 'item-1',
              kind: imageKind,
              label: 'Image',
              position: 0,
              isRequired: required,
              config: const FormItemConfig(minImages: 2, maxImages: 5),
            ),
          ],
          initialAnswers: {
            'item-1': imageKind == FormItemKind.photo
                ? FormAnswer.photo(itemId: 'item-1', assetIds: [])
                : FormAnswer.gallery(itemId: 'item-1', assetIds: []),
          },
        );
        await open(tester, api);
        await tester.tap(find.byKey(const Key('form-response-save-draft')));
        await tester.pumpAndSettle();
        expect(api.saveCommand!.payload.answers, isEmpty);
        await tester.tap(find.byKey(const Key('form-response-review')));
        await tester.pumpAndSettle();
        if (required) {
          expect(find.text('Revisão da resposta'), findsNothing);
          expect(
            find.text(
              'Este formulário exige anexo e o envio protegido ainda não está disponível nesta superfície.',
            ),
            findsOneWidget,
          );
          expect(api.submitCommand, isNull);
        } else {
          expect(find.text('Revisão da resposta'), findsOneWidget);
          await tester.tap(find.byKey(const Key('form-response-submit')));
          await tester.pumpAndSettle();
          expect(api.submitCommand!.payload.answers, isEmpty);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('gallery bounds ignore hidden restored answer', (tester) async {
    final api = _ResponseApi(
      items: [
        FormItem(id: 'source', kind: FormItemKind.yesNo, label: 'Show gallery', position: 0),
        FormItem(
          id: 'item-1',
          kind: FormItemKind.gallery,
          label: 'Gallery',
          position: 1,
          isRequired: true,
          config: const FormItemConfig(minImages: 2, maxImages: 5),
          conditions: const [FormCondition.yesNo(sourceItemId: 'source', expected: true)],
        ),
      ],
      initialAnswers: {
        'source': FormAnswer.yesNo(itemId: 'source', value: false),
        'item-1': FormAnswer.gallery(itemId: 'item-1', assetIds: ['asset-a']),
      },
    );
    await open(tester, api);
    expect(find.text('Anexo indisponível'), findsNothing);
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    expect(find.text('Revisão da resposta'), findsOneWidget);
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    expect(api.submitCommand!.payload.answers.keys, ['source']);
    expect(tester.takeException(), isNull);
  });

  for (final imageKind in [FormItemKind.photo, FormItemKind.gallery]) {
    testWidgets('optional empty assets omitted from direct submit $imageKind', (tester) async {
      final api = _ResponseApi(
        items: [
          FormItem(
            id: 'item-1',
            kind: imageKind,
            label: 'Image',
            position: 0,
            config: const FormItemConfig(minImages: 2, maxImages: 5),
          ),
        ],
        initialAnswers: {
          'item-1': imageKind == FormItemKind.photo
              ? FormAnswer.photo(itemId: 'item-1', assetIds: [])
              : FormAnswer.gallery(itemId: 'item-1', assetIds: []),
        },
      );
      await tester.binding.setSurfaceSize(const Size(1000, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await open(tester, api);
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pumpAndSettle();
      expect(find.text('Revisão da resposta'), findsOneWidget);
      await tester.tap(find.byKey(const Key('form-response-submit')));
      await tester.pumpAndSettle();
      expect(api.saveCalls, isEmpty);
      expect(api.submitCommand!.payload.answers, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty required gallery omitted from incomplete autosave', (tester) async {
    final api = _ResponseApi(
      items: [
        FormItem(id: 'note', kind: FormItemKind.shortText, label: 'Note', position: 0),
        FormItem(
          id: 'item-1',
          kind: FormItemKind.gallery,
          label: 'Gallery',
          position: 1,
          isRequired: true,
          config: const FormItemConfig(minImages: 2, maxImages: 5),
        ),
      ],
      initialAnswers: {'item-1': FormAnswer.gallery(itemId: 'item-1', assetIds: [])},
    );
    await open(tester, api);
    await tester.enterText(find.byKey(const Key('form-response-item-note')), 'Draft');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.saveCalls, hasLength(1));
    expect(api.saveCalls.single.payload.answers.keys, ['note']);
    expect(api.submitCommand, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final imageKind in [FormItemKind.photo, FormItemKind.gallery]) {
    testWidgets('review restored required media can be reviewed $imageKind', (tester) async {
      final ids = List.generate(
        imageKind == FormItemKind.photo ? 1 : 5,
        (index) => '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
      );
      final answer = imageKind == FormItemKind.photo
          ? FormAnswer.photo(itemId: 'item-1', assetIds: ids)
          : FormAnswer.gallery(itemId: 'item-1', assetIds: ids);
      final api = _ResponseApi(kind: imageKind, initialAnswers: {'item-1': answer});
      await tester.binding.setSurfaceSize(const Size(1000, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await open(tester, api);
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pumpAndSettle();
      expect(
        find.text('Revisão da resposta'),
        findsOneWidget,
        reason:
            'Server-restored media already satisfies the required answer without selecting a new upload.',
      );
      expect(find.textContaining('${ids.length} arquivo(s)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('form-response-submit')));
      await tester.pumpAndSettle();
      expect((api.submitCommand!.payload.answers['item-1']!.value as FormAssetValue).assetIds, ids);
      expect(find.text('Resposta enviada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final imageKind in [FormItemKind.photo, FormItemKind.gallery]) {
    testWidgets('review restored empty required media remains unavailable $imageKind', (
      tester,
    ) async {
      final answer = imageKind == FormItemKind.photo
          ? FormAnswer.photo(itemId: 'item-1', assetIds: [])
          : FormAnswer.gallery(itemId: 'item-1', assetIds: []);
      final api = _ResponseApi(kind: imageKind, initialAnswers: {'item-1': answer});
      await open(tester, api);
      await tester.tap(find.byKey(const Key('form-response-review')));
      await tester.pumpAndSettle();
      expect(find.text('Revisão da resposta'), findsNothing);
      expect(find.text('Anexo indisponível'), findsOneWidget);
      expect(find.byKey(const Key('form-response-submit')), findsNothing);
      expect(api.submitCommand, isNull);
    });
  }

  testWidgets('review restored media never crosses to replacement context', (tester) async {
    final first = _ResponseApi(
      kind: FormItemKind.photo,
      initialAnswers: {
        'item-1': FormAnswerDto.fromJson({
          'item_id': 'item-1',
          'kind': 'photo',
          'asset_ids': ['00000000-0000-4000-8000-000000000031'],
          'text_value': null,
          'integer_value': null,
          'decimal_value': null,
          'money_minor_units': null,
          'date_value': null,
          'yes_no_value': null,
          'option_ids': <String>[],
          'scale_value': null,
        }).toDomain(),
      },
    );
    final second = _ResponseApi(kind: FormItemKind.photo);
    await open(tester, first);
    final oldReview = tester
        .widget<FilledButton>(find.byKey(const Key('form-response-review')))
        .onPressed!;
    await open(tester, second, occurrence: 'occurrence-2');
    oldReview();
    await tester.pumpAndSettle();
    expect(find.text('Revisão da resposta'), findsNothing);
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    expect(find.text('Revisão da resposta'), findsNothing);
    await tester.tap(find.byKey(const Key('form-response-save-draft')));
    await tester.pumpAndSettle();
    expect(second.saveCommand?.payload.answers, isEmpty);
    expect(second.saveCommand?.payload.occurrenceId, 'occurrence-2');
    expect(first.submitCommand, isNull);
    expect(second.submitCommand, isNull);
  });

  testWidgets('review restored submitted photo can cancel and confirm unchanged media', (
    tester,
  ) async {
    final answer = FormAnswerDto.fromJson({
      'item_id': 'item-1',
      'kind': 'photo',
      'asset_ids': ['00000000-0000-4000-8000-000000000032'],
      'text_value': null,
      'integer_value': null,
      'decimal_value': null,
      'money_minor_units': null,
      'date_value': null,
      'yes_no_value': null,
      'option_ids': <String>[],
      'scale_value': null,
    }).toDomain();
    final api = _ResponseApi(
      kind: FormItemKind.photo,
      initialAnswers: {'item-1': answer},
      initialStatus: FormResponseDraftStatus.submitted,
    );
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, api);
    expect(find.textContaining('1 arquivo(s)'), findsOneWidget);
    await tester.tap(find.text('Editar resposta'));
    await tester.pumpAndSettle();
    expect(find.text('Anexo indisponível'), findsOneWidget);
    await tester.tap(find.text('Cancelar edição'));
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada'), findsOneWidget);
    expect(api.editCommand, isNull);
    await tester.tap(find.text('Editar resposta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    expect(find.text('Revisão da resposta'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('form-response-submit')));
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    expect((api.editCommand?.payload.answers['item-1']?.value as FormAssetValue).assetIds, [
      '00000000-0000-4000-8000-000000000032',
    ]);
    expect(api.submitCommand, isNull);
    expect(find.text('Resposta enviada'), findsOneWidget);
  });
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
    expect(api.editCommand, isNull);
    expect(
      tester
          .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
          .controller
          .text,
      '12.0',
    );
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    expect(
      api.editCommand!.payload.answers['item-1'],
      api.submitCommand!.payload.answers['item-1'],
    );
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

  testWidgets('editing a submitted response changes nothing until review and confirmation', (
    tester,
  ) async {
    final api = _ResponseApi();
    await open(tester, api);
    final field = find.byKey(const Key('form-response-item-item-1'));
    await tester.enterText(field, 'Resposta enviada original');
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    final saveCount = api.saveCalls.length;
    await tester.tap(find.text('Editar resposta'));
    await tester.pumpAndSettle();
    expect(api.editCommand, isNull);
    expect(field, findsOneWidget);
    expect(find.byKey(const Key('form-response-save-draft')), findsNothing);
    await tester.enterText(field, 'Resposta revisada');
    await tester.pump(const Duration(seconds: 2));
    expect(api.editCommand, isNull);
    expect(api.saveCalls.length, saveCount);
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    expect(
      api.editCommand!.payload.answers['item-1']!.value,
      isA<FormShortTextValue>().having((value) => value.value, 'revision', 'Resposta revisada'),
    );
    expect(find.text('Resposta enviada'), findsOneWidget);
    expect(find.textContaining('Resposta revisada'), findsOneWidget);
  });

  testWidgets('cancelling a local submitted revision restores the confirmed answers', (
    tester,
  ) async {
    final api = _ResponseApi();
    await open(tester, api);
    final field = find.byKey(const Key('form-response-item-item-1'));
    await tester.enterText(field, 'Resposta confirmada');
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar resposta'));
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Rascunho local descartado');
    await tester.tap(find.text('Cancelar edição'));
    await tester.pumpAndSettle();
    expect(api.editCommand, isNull);
    expect(find.text('Resposta enviada'), findsOneWidget);
    expect(find.textContaining('Resposta confirmada'), findsOneWidget);
    expect(find.textContaining('Rascunho local descartado'), findsNothing);
  });

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
        } else {
          await tester.tap(find.byKey(const Key('form-response-submit')));
        }
        await tester.pumpAndSettle();
      }

      if (operation != 'save') {
        await tester.tap(find.byKey(const Key('form-response-review')));
        await tester.pumpAndSettle();
        if (operation == 'edit') {
          await tester.tap(find.byKey(const Key('form-response-submit')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Editar resposta'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('form-response-item-item-1')),
            'Revised answer',
          );
          await tester.tap(find.byKey(const Key('form-response-review')));
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

  testWidgets('multiple-choice union drops only newly hidden branch answers before submit', (
    tester,
  ) async {
    final api = _ResponseApi(
      initialAnswers: {
        'root': FormAnswer.multipleChoice(itemId: 'root', optionIds: {'a', 'b'}),
        'leaf-a': FormAnswer.shortText(itemId: 'leaf-a', value: 'Answer A'),
        'leaf-b': FormAnswer.shortText(itemId: 'leaf-b', value: 'Answer B'),
      },
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
        for (final id in ['a', 'b'])
          FormItem(
            id: 'leaf-$id',
            kind: FormItemKind.shortText,
            label: 'Leaf $id',
            position: id == 'a' ? 1 : 2,
            conditions: [
              FormCondition.choice(sourceItemId: 'root', optionIds: {id}),
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
    expect(find.byKey(const Key('form-response-item-leaf-a')), findsOneWidget);
    expect(find.byKey(const Key('form-response-item-leaf-b')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'A'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-response-item-leaf-a')), findsNothing);
    expect(find.byKey(const Key('form-response-item-leaf-b')), findsOneWidget);
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Answer A'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    expect(api.submitCommand?.payload.answers.keys.toSet(), {'root', 'leaf-b'});
    expect(tester.takeException(), isNull);
  });

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
    expect(api.editCommand, isNull);
    expect(find.byKey(const Key('form-response-save-draft')), findsNothing);
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-response-submit')));
    await tester.pumpAndSettle();
    expect(api.editCommand?.expectedVersion, 3);
    expect(find.text('Resposta enviada'), findsOneWidget);
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

  // Limites numéricos e de texto — residual C02/R01 (forms.respond, forms.location-answer).
  // Os quatro RED da r48: a resposta aceitava valores fora da faixa declarada na autoria.
  _ResponseApi limited(FormItemKind kind, {num? min, num? max, int? maxLength}) => _ResponseApi(
    items: [
      FormItem(
        id: 'item-1',
        kind: kind,
        label: 'Limitada',
        position: 0,
        config: FormItemConfig(minValue: min, maxValue: max, maxLength: maxLength),
      ),
    ],
  );

  Future<void> typeAndSettle(WidgetTester tester, String raw) async {
    await tester.enterText(find.byKey(const Key('form-response-item-item-1')), raw);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  for (final (kind, max, refused, accepted) in <(FormItemKind, num, String, String)>[
    (FormItemKind.integer, 10, '11', '10'),
    (FormItemKind.decimal, 10, '10,5', '10'),
    // Money limits are declared in minor units, the same unit the answer stores.
    (FormItemKind.money, 100000, '1100', '1000'),
  ]) {
    testWidgets('${kind.name} above the declared maximum never reaches the draft', (tester) async {
      final api = limited(kind, max: max);
      await open(tester, api);
      await typeAndSettle(tester, refused);
      expect(api.saveCalls, isEmpty);
      expect(find.text('Revise os valores numéricos antes de salvar.'), findsWidgets);

      await tester.tap(find.byKey(const Key('form-response-save-draft')));
      await tester.pump();
      expect(api.saveCalls, isEmpty);

      await typeAndSettle(tester, accepted);
      expect(api.saveCalls, hasLength(1));
    });

    testWidgets('${kind.name} below the declared minimum never reaches the draft', (tester) async {
      final api = limited(kind, min: kind == FormItemKind.money ? 100000 : 10);
      await open(tester, api);
      await typeAndSettle(tester, kind == FormItemKind.integer ? '9' : '9,5');
      expect(api.saveCalls, isEmpty);

      await typeAndSettle(tester, accepted);
      expect(api.saveCalls, hasLength(1));
    });
  }

  testWidgets('money answer is compared against the declared limit in the same unit', (
    tester,
  ) async {
    // R$ 10,50 is 1050 minor units; a maximum of R$ 10,00 is 1000 minor units.
    final api = limited(FormItemKind.money, max: 1000);
    await open(tester, api);
    await typeAndSettle(tester, '10,50');
    expect(api.saveCalls, isEmpty);

    await typeAndSettle(tester, '10,00');
    expect(api.saveCalls, hasLength(1));
    expect(
      api.saveCalls.single.payload.answers['item-1']!.value,
      isA<FormMoneyValue>().having((value) => value.minorUnits, 'minorUnits', 1000),
    );
  });

  testWidgets('a value inside the declared range still saves', (tester) async {
    final api = limited(FormItemKind.integer, min: 1, max: 10);
    await open(tester, api);
    await typeAndSettle(tester, '10');
    expect(api.saveCalls, hasLength(1));
    expect(
      api.saveCalls.single.payload.answers['item-1']!.value,
      isA<FormIntegerValue>().having((value) => value.value, 'value', 10),
    );
  });

  testWidgets('short text longer than the declared maximum never reaches the draft', (
    tester,
  ) async {
    final api = limited(FormItemKind.shortText, maxLength: 5);
    await open(tester, api);
    await typeAndSettle(tester, 'abcdef');
    expect(api.saveCalls, isEmpty);

    await typeAndSettle(tester, 'abcde');
    expect(api.saveCalls, hasLength(1));
    expect(
      api.saveCalls.single.payload.answers['item-1']!.value,
      isA<FormShortTextValue>().having((value) => value.value, 'value', 'abcde'),
    );
  });

  // Dinheiro guardado em minorUnits era exibido dividindo por 100 sem formatar,
  // entao 1050 voltava ao campo como "10.5" e 1000 como "10.0", em vez da
  // notacao civil que o autor ve no editor.
  testWidgets('a saved money answer reopens in civil notation', (tester) async {
    for (final (minorUnits, shown) in <(int, String)>[
      (1050, '10,50'),
      (1000, '10,00'),
      (1005, '10,05'),
      (5, '0,05'),
    ]) {
      final api = _ResponseApi(
        items: [
          FormItem(id: 'item-1', kind: FormItemKind.money, label: 'Valor', position: 0),
        ],
        initialAnswers: {'item-1': FormAnswer.money(itemId: 'item-1', minorUnits: minorUnits)},
      );
      await open(tester, api);
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('form-response-item-item-1'))).initialValue,
        shown,
        reason: 'minorUnits $minorUnits',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the review summary shows money in civil notation too', (tester) async {
    final api = _ResponseApi(
      items: [
        FormItem(id: 'item-1', kind: FormItemKind.money, label: 'Valor', position: 0),
      ],
      initialAnswers: {'item-1': FormAnswer.money(itemId: 'item-1', minorUnits: 1050)},
    );
    await open(tester, api);
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pumpAndSettle();
    expect(find.text('10,50'), findsWidgets);
    expect(find.text('10.5'), findsNothing);
  });

  testWidgets('reopened money survives a round trip through the draft', (tester) async {
    final api = _ResponseApi(
      items: [
        FormItem(id: 'item-1', kind: FormItemKind.money, label: 'Valor', position: 0),
      ],
      initialAnswers: {'item-1': FormAnswer.money(itemId: 'item-1', minorUnits: 1050)},
    );
    await open(tester, api);
    await tester.enterText(find.byKey(const Key('form-response-item-item-1')), '10,50');
    await tester.pump(const Duration(seconds: 2));
    // Reescrever o mesmo valor exibido nao pode alterar o que sera gravado.
    if (api.saveCalls.isNotEmpty) {
      expect(
        api.saveCalls.last.payload.answers['item-1']!.value,
        isA<FormMoneyValue>().having((value) => value.minorUnits, 'minorUnits', 1050),
      );
    }
  });

  testWidgets('a refused text says what to review, not to review numbers', (tester) async {
    final api = limited(FormItemKind.shortText, maxLength: 5);
    await open(tester, api);
    await typeAndSettle(tester, 'abcdef');
    expect(api.saveCalls, isEmpty);
    // A recusa foi de tamanho de texto; mandar revisar valores numericos
    // enviaria a pessoa ao campo errado.
    expect(find.text('Revise os valores numéricos antes de salvar.'), findsNothing);
    expect(find.text('Revise as respostas antes de salvar.'), findsWidgets);
  });

  testWidgets('repairing a refused text back to the stored value still autosaves', (tester) async {
    final api = _ResponseApi(
      items: [
        FormItem(
          id: 'item-1',
          kind: FormItemKind.shortText,
          label: 'Limitada',
          position: 0,
          config: const FormItemConfig(maxLength: 5),
        ),
      ],
      initialAnswers: {'item-1': FormAnswer.shortText(itemId: 'item-1', value: 'abcde')},
    );
    await open(tester, api);
    await typeAndSettle(tester, 'abcdefgh');
    expect(api.saveCalls, isEmpty);

    // Voltar exatamente ao texto ja guardado deixa as respostas iguais, entao
    // _setAnswer sai cedo sem agendar nada. A tela mesmo assim anuncia
    // alteracoes nao salvas, e sem reagendar o autosave nada nunca limpa isso:
    // fica dizendo que ha mudanca pendente quando nao ha.
    await typeAndSettle(tester, 'abcde');
    expect(find.text('Revise as respostas antes de salvar.'), findsNothing);
    expect(find.text('Alterações ainda não salvas.'), findsNothing);
  });

  // O autor pode declarar um intervalo de datas na pergunta, e o servidor
  // recusa data fora dele. O seletor do respondente ignorava esse intervalo e
  // oferecia 120 anos para tras e 20 para a frente, entao a pessoa escolhia
  // uma data que o backend ia recusar.
  _ResponseApi dateApi({DateTime? min, DateTime? max, DateTime? answer}) => _ResponseApi(
    items: [
      FormItem(
        id: 'item-1',
        kind: FormItemKind.date,
        label: 'Data',
        position: 0,
        config: FormItemConfig(minDate: min, maxDate: max),
      ),
    ],
    initialAnswers: answer == null
        ? const {}
        : {'item-1': FormAnswer.date(itemId: 'item-1', value: answer)},
  );

  Future<DatePickerDialog> openPicker(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    return tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
  }

  testWidgets('the date picker offers only the authored range', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(
      tester,
      dateApi(min: DateTime.utc(2026, 3, 1), max: DateTime.utc(2026, 9, 30)),
    );
    final picker = await openPicker(tester);
    // showDatePicker normaliza para data local sem hora, entao comparo os
    // componentes em vez do DateTime exato.
    expect((picker.firstDate.year, picker.firstDate.month, picker.firstDate.day), (2026, 3, 1));
    expect((picker.lastDate.year, picker.lastDate.month, picker.lastDate.day), (2026, 9, 30));
  });

  testWidgets('a stored answer outside the authored range does not crash the picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(
      tester,
      dateApi(
        min: DateTime.utc(2026, 3, 1),
        max: DateTime.utc(2026, 9, 30),
        answer: DateTime.utc(2020, 1, 15),
      ),
    );
    final picker = await openPicker(tester);
    expect(tester.takeException(), isNull);
    expect(picker.initialDate, isNotNull);
    expect(picker.initialDate!.isBefore(picker.firstDate), isFalse);
    expect(picker.initialDate!.isAfter(picker.lastDate), isFalse);
  });

  testWidgets('without an authored range the picker keeps its wide fallback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, dateApi());
    final picker = await openPicker(tester);
    expect(picker.lastDate.year - picker.firstDate.year, greaterThan(100));
  });

  testWidgets('an out-of-range value cannot be submitted either', (tester) async {
    final api = limited(FormItemKind.integer, max: 10);
    await open(tester, api);
    await typeAndSettle(tester, '5');
    await tester.tap(find.byKey(const Key('form-response-review')));
    await tester.pump();
    expect(find.byKey(const Key('form-response-submit')), findsOneWidget);

    // An out-of-range edit withdraws the reviewed state, so send is unreachable.
    await typeAndSettle(tester, '11');
    expect(find.byKey(const Key('form-response-submit')), findsNothing);
    expect(api.submitCommand, isNull);
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
    this.initialStatus = FormResponseDraftStatus.draft,
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
  final FormResponseDraftStatus initialStatus;
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
      status: operation == 'submit' || operation == 'edit'
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
      status: FormResponseDraftStatus.submitted,
      answers: command.payload.answers,
      managementVersion: command.expectedVersion + 1,
    );
  }

  FormResponseDraft _draft(int version, String occurrenceId) => FormResponseDraft(
    id: 'response-$occurrenceId',
    occurrenceId: occurrenceId,
    status: initialStatus,
    answers: initialAnswers,
    managementVersion: version,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
