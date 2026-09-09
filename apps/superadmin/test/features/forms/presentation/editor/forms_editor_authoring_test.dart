import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/forms_authoring_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, _Api api, {String id = 'form-a'}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsEditorPage.authoring(authoringApi: api, formId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder title(String value) => find.byWidgetPredicate(
    (widget) => widget is TextFormField && widget.controller?.text == value,
  );

  Finder imageLimit(String key) => find.byKey(ValueKey('forms-gallery-$key-gallery'));

  _Api dateApi({DateTime? min, DateTime? max}) => _Api(manage: true)
    ..customItems = [
      FormItem(
        id: 'date',
        kind: FormItemKind.date,
        label: 'Data civil',
        position: 0,
        config: FormItemConfig(minDate: min, maxDate: max),
      ),
    ];

  Future<void> dateRule(WidgetTester tester, String name) async {
    final dynamic field = tester.widget(find.byKey(const Key('forms-editor-date-rule')));
    field.onChanged(field.options.singleWhere((dynamic value) => (value as Enum).name == name));
    await tester.pump();
  }

  Future<void> chooseDate(WidgetTester tester, String key, DateTime? day) async {
    tester
        .widget<CoeloDateRangeField>(find.byKey(Key(key)))
        .onChanged(day == null ? null : DateTimeRange(start: day, end: day));
    await tester.pump();
  }

  for (final rule in ['free', 'from', 'until', 'range']) {
    testWidgets('date controls preserve $rule configuration in unrelated autosave', (tester) async {
      final min = rule == 'from' || rule == 'range' ? DateTime.utc(2024, 2, 29) : null;
      final max = rule == 'until' || rule == 'range' ? DateTime.utc(2028, 1, 1) : null;
      final api = dateApi(min: min, max: max);
      await open(tester, api);
      expect(find.byKey(ValueKey('forms-editor-date-config-$rule')), findsOneWidget);
      expect(api.commands, isEmpty);
      await tester.enterText(title('Authorized title'), 'Unrelated title');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      final config = api.commands.single.payload.sections.single.items.single.config;
      expect(config.minDate, min);
      expect(config.maxDate, max);
    });
  }

  for (final automatic in [false, true]) {
    testWidgets('date controls edit and restore civil range automatic=$automatic', (tester) async {
      final api = dateApi(min: DateTime.utc(2024, 2, 29), max: DateTime.utc(2028, 1, 1));
      await open(tester, api);
      await chooseDate(tester, 'forms-editor-date-min', DateTime.utc(2025, 3, 1, 23, 45));
      await chooseDate(tester, 'forms-editor-date-max', DateTime.utc(2027, 12, 31, 13));
      if (automatic) {
        await tester.pump(const Duration(milliseconds: 800));
      } else {
        final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
        await tester.ensureVisible(save);
        await tester.tap(save);
      }
      await tester.pumpAndSettle();
      expect(api.commands, hasLength(1));
      final config = api.commands.single.payload.sections.single.items.single.config;
      expect(config.minDate, DateTime.utc(2025, 3, 1));
      expect(config.maxDate, DateTime.utc(2027, 12, 31));
      api.customItems = api.commands.single.payload.sections.single.items;
      await tester.pumpWidget(const SizedBox());
      await open(tester, api);
      final field = tester.widget<CoeloDateRangeField>(
        find.byKey(const Key('forms-editor-date-min')),
      );
      expect(field.value!.start, DateTime.utc(2025, 3, 1));
      expect(api.commands, hasLength(1));
    });
  }

  testWidgets('date controls free explicitly clears both bounds', (tester) async {
    final api = dateApi(min: DateTime.utc(2024), max: DateTime.utc(2028));
    await open(tester, api);
    await dateRule(tester, 'free');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    final config = api.commands.single.payload.sections.single.items.single.config;
    expect(config.minDate, isNull);
    expect(config.maxDate, isNull);
  });

  testWidgets('date controls incomplete rule and inverted range never save', (tester) async {
    final api = dateApi();
    await open(tester, api);
    await dateRule(tester, 'range');
    expect(
      tester.widget<CoeloDateRangeField>(find.byKey(const Key('forms-editor-date-min'))).value,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands, isEmpty);
    expect(find.text('Escolha a data mínima antes de salvar.'), findsWidgets);
    await chooseDate(tester, 'forms-editor-date-min', DateTime.utc(2028));
    await chooseDate(tester, 'forms-editor-date-max', DateTime.utc(2027));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.commands, isEmpty);
    expect(find.text('A data mínima deve ser anterior ou igual à data máxima.'), findsWidgets);
    expect(
      tester
          .widget<CoeloDateRangeField>(find.byKey(const Key('forms-editor-date-max')))
          .value!
          .start,
      DateTime.utc(2027),
    );
    await chooseDate(tester, 'forms-editor-date-max', DateTime.utc(2028));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(1));
  });

  testWidgets('date controls retained callback cannot cross rule A B A or API context', (
    tester,
  ) async {
    final api = dateApi(min: DateTime.utc(2024));
    await open(tester, api);
    final old = tester
        .widget<CoeloDateRangeField>(find.byKey(const Key('forms-editor-date-min')))
        .onChanged;
    await dateRule(tester, 'free');
    await dateRule(tester, 'from');
    old(DateTimeRange(start: DateTime.utc(2020), end: DateTime.utc(2020)));
    await tester.pump();
    expect(
      tester
          .widget<CoeloDateRangeField>(find.byKey(const Key('forms-editor-date-min')))
          .value!
          .start,
      DateTime.utc(2024),
    );
    final current = dateApi(min: DateTime.utc(2030));
    await open(tester, current);
    old(DateTimeRange(start: DateTime.utc(2020), end: DateTime.utc(2020)));
    await tester.pump(const Duration(seconds: 2));
    expect(current.commands, isEmpty);
    expect(
      tester
          .widget<CoeloDateRangeField>(find.byKey(const Key('forms-editor-date-min')))
          .value!
          .start,
      DateTime.utc(2030),
    );
    await tester.pumpWidget(const SizedBox());
    old(null);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date controls hydrate civil bounds before editing', (tester) async {
    final api = dateApi(min: DateTime.utc(2024, 2, 29), max: DateTime.utc(2027, 1, 1));
    await open(tester, api);
    expect(find.text('Intervalo permitido'), findsOneWidget);
    final minimum = tester.widget<CoeloDateRangeField>(
      find.byKey(const Key('forms-editor-date-min')),
    );
    final maximum = tester.widget<CoeloDateRangeField>(
      find.byKey(const Key('forms-editor-date-max')),
    );
    expect(minimum.value!.start, DateTime.utc(2024, 2, 29));
    expect(maximum.value!.start, DateTime.utc(2027, 1, 1));
    expect(minimum.selectionMode, CoeloDateSelectionMode.single);
    expect(api.commands, isEmpty);
  });

  testWidgets('date controls choose a civil day at 375px without a time picker', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = dateApi(min: DateTime.utc(2024, 2, 29));
    await open(tester, api);
    final field = find.byKey(const Key('forms-editor-date-min'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coelo-date-2024-02-20')));
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(
      api.commands.single.payload.sections.single.items.single.config.minDate,
      DateTime.utc(2024, 2, 20),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('date controls keep an incomplete later edit dirty after earlier receipt', (
    tester,
  ) async {
    final api = dateApi()..saveWait = Completer<void>();
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Earlier title');
    await tester.pump(const Duration(milliseconds: 800));
    await dateRule(tester, 'until');
    api.saveWait!.complete();
    await tester.pump();
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(1));
    await chooseDate(tester, 'forms-editor-date-min', DateTime.utc(2011, 12, 30));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(2));
    expect(api.commands.last.expectedVersion, 2);
    final config = api.commands.last.payload.sections.single.items.single.config;
    expect(config.minDate, isNull);
    expect(config.maxDate, DateTime.utc(2011, 12, 30));
  });

  testWidgets('short text maximum length survives unrelated autosave', (tester) async {
    final api = _Api(manage: true)
      ..customItems = [
        FormItem(
          id: 'short',
          kind: FormItemKind.shortText,
          label: 'Short text',
          position: 0,
          config: const FormItemConfig(maxLength: 123),
        ),
      ];
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Changed title');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands.single.payload.sections.single.items.single.config.maxLength, 123);
  });

  _Api galleryApi({FormItemConfig config = const FormItemConfig()}) => _Api(manage: true)
    ..customItems = [
      FormItem(
        id: 'gallery',
        kind: FormItemKind.gallery,
        label: 'Galeria',
        position: 0,
        config: config,
      ),
    ];

  for (final automatic in [false, true]) {
    testWidgets('gallery controls persist explicit limits automatic=$automatic', (tester) async {
      final api = galleryApi(config: const FormItemConfig(minImages: 2, maxImages: 5));
      await open(tester, api);
      expect(tester.widget<TextFormField>(imageLimit('min')).controller!.text, '2');
      expect(tester.widget<TextFormField>(imageLimit('max')).controller!.text, '5');
      expect(api.commands, isEmpty);
      await tester.enterText(imageLimit('min'), '3');
      await tester.enterText(imageLimit('max'), '4');
      if (automatic) {
        await tester.pump(const Duration(milliseconds: 800));
      } else {
        final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
        await tester.ensureVisible(save);
        await tester.tap(save);
      }
      await tester.pumpAndSettle();
      expect(api.commands, hasLength(1));
      final config = api.commands.single.payload.sections.single.items.single.config;
      expect(config.minImages, 3);
      expect(config.maxImages, 4);
      api.customItems = api.commands.single.payload.sections.single.items;
      await tester.pumpWidget(const SizedBox());
      await open(tester, api);
      expect(tester.widget<TextFormField>(imageLimit('min')).controller!.text, '3');
      expect(tester.widget<TextFormField>(imageLimit('max')).controller!.text, '4');
      expect(api.commands, hasLength(1));
    });
  }

  testWidgets('gallery controls keep absent limits absent and allow explicit defaults', (
    tester,
  ) async {
    final api = galleryApi();
    await open(tester, api);
    expect(tester.widget<TextFormField>(imageLimit('min')).controller!.text, isEmpty);
    expect(tester.widget<TextFormField>(imageLimit('max')).controller!.text, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
    await tester.enterText(imageLimit('min'), '1');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    var config = api.commands.last.payload.sections.single.items.single.config;
    expect(config.minImages, 1);
    expect(config.maxImages, isNull);
    await tester.enterText(imageLimit('min'), '');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    config = api.commands.last.payload.sections.single.items.single.config;
    expect(config.minImages, isNull);
    expect(config.maxImages, isNull);
  });

  for (final invalid in ['0', '6', '2.5', 'abc', '4']) {
    testWidgets('gallery controls reject $invalid before save and recover after correction', (
      tester,
    ) async {
      final api = galleryApi(config: const FormItemConfig(minImages: 2, maxImages: 3));
      await open(tester, api);
      await tester.enterText(imageLimit('min'), invalid);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(api.commands, isEmpty);
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.commands, isEmpty);
      expect(
        find.text(
          invalid == '4'
              ? 'O mínimo de imagens deve ser menor ou igual ao máximo.'
              : 'Informe limites de imagens inteiros entre 1 e 5.',
        ),
        findsWidgets,
      );
      expect(tester.widget<TextFormField>(imageLimit('max')).controller!.text, '3');
      await tester.enterText(imageLimit('min'), '3');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(api.commands, hasLength(1));
      expect(api.commands.single.payload.sections.single.items.single.config.minImages, 3);
    });
  }

  testWidgets('gallery controls reject a maximum below minimum without changing minimum', (
    tester,
  ) async {
    final api = galleryApi(config: const FormItemConfig(minImages: 2, maxImages: 5));
    await open(tester, api);
    await tester.enterText(imageLimit('max'), '1');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands, isEmpty);
    expect(tester.widget<TextFormField>(imageLimit('min')).controller!.text, '2');
    await tester.enterText(imageLimit('max'), '2');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands.single.payload.sections.single.items.single.config.maxImages, 2);
  });

  testWidgets('gallery controls retain invalid input entered during an earlier save', (
    tester,
  ) async {
    final api = galleryApi()..saveWait = Completer<void>();
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Earlier edit');
    await tester.pump(const Duration(milliseconds: 800));
    expect(api.commands, hasLength(1));
    await tester.enterText(imageLimit('min'), 'abc');
    api.saveWait!.complete();
    await tester.pump();
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(1));
    expect(tester.widget<TextFormField>(imageLimit('min')).controller!.text, 'abc');
    await tester.enterText(imageLimit('min'), '2');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(2));
    expect(api.commands.last.expectedVersion, 2);
    expect(api.commands.last.requestId, isNot(api.commands.first.requestId));
    expect(api.commands.last.payload.sections.single.items.single.config.minImages, 2);
  });

  testWidgets('gallery controls remain absent for photo', (tester) async {
    final api = _Api(manage: true)
      ..customItems = [FormItem(id: 'photo', kind: FormItemKind.photo, label: 'Foto', position: 0)];
    await open(tester, api);
    expect(find.text('Mínimo de imagens'), findsNothing);
    expect(find.text('Máximo de imagens'), findsNothing);
    expect(api.commands, isEmpty);
  });

  testWidgets('gallery controls duplicate edited limits without sharing controllers', (
    tester,
  ) async {
    final api = galleryApi();
    await open(tester, api);
    await tester.enterText(imageLimit('min'), '2');
    await tester.enterText(imageLimit('max'), '4');
    final duplicate = find.byTooltip('Duplicar pergunta');
    await tester.ensureVisible(duplicate);
    await tester.tap(duplicate);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(1));
    final items = api.commands.single.payload.sections.single.items;
    expect(items, hasLength(2));
    expect(items.map((item) => item.config.minImages), [2, 2]);
    expect(items.map((item) => item.config.maxImages), [4, 4]);
    final copiedMin = find.byKey(ValueKey('forms-gallery-min-${items.last.id}'));
    await tester.enterText(copiedMin, '3');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands.last.payload.sections.single.items.map((item) => item.config.minImages), [
      2,
      3,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery controls stack at 375px and support keyboard input', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = galleryApi();
    await open(tester, api);
    expect(
      tester.getTopLeft(imageLimit('max')).dy,
      greaterThan(tester.getBottomLeft(imageLimit('min')).dy),
    );
    await tester.ensureVisible(imageLimit('min'));
    await tester.tap(imageLimit('min'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: imageLimit('min'), matching: find.byType(EditableText)),
          )
          .keyboardType,
      TextInputType.number,
    );
    tester.testTextInput.enterText('2');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(api.commands.single.payload.sections.single.items.single.config.minImages, 2);
    expect(tester.takeException(), isNull);
  });

  for (final automatic in [false, true]) {
    for (final explicitLimits in [false, true]) {
      testWidgets(
        'gallery image limits explicit=$explicitLimits survive ${automatic ? 'autosave' : 'manual save'}',
        (tester) async {
          final api = _Api(manage: true);
          final wire = FormDefinitionDto.fromDomain(
            (await api.getEditor('form-a')).definition,
          ).toJson();
          final section = (wire['sections'] as List).single as Map<String, Object?>;
          final item = (section['items'] as List).first as Map<String, Object?>;
          final config = <String, Object?>{
            'allow_existing': true,
            if (explicitLimits) 'min_images': 2,
            if (explicitLimits) 'max_images': 5,
          };
          section['items'] = [
            {...item, 'kind': 'gallery', 'config': config},
          ];
          api.customItems = FormDefinitionDto.fromJson(wire).toDomain().sections.single.items;
          await open(tester, api);
          expect(api.commands, isEmpty);
          await tester.enterText(title('Authorized title'), 'Changed gallery title');
          if (automatic) {
            await tester.pump(const Duration(milliseconds: 800));
          } else {
            final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
            await tester.ensureVisible(save);
            await tester.tap(save);
          }
          await tester.pumpAndSettle();
          expect(api.commands, hasLength(1));
          final command = api.commands.single;
          expect(command.payload.title, 'Changed gallery title');
          expect(command.expectedVersion, 1);
          final saved = FormDefinitionDto.fromDomain(command.payload).toJson();
          final savedSection = (saved['sections'] as List).single as Map<String, Object?>;
          final savedItem = (savedSection['items'] as List).single as Map<String, Object?>;
          expect(savedItem['kind'], 'gallery');
          expect(savedItem['config'], config);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('yes-no false branch autosave keeps selected booleans per child', (tester) async {
    final api = _Api(manage: true)
      ..customItems = [
        FormItem(id: 'parent', kind: FormItemKind.yesNo, label: 'Parent', position: 0),
      ];
    await open(tester, api);
    tester
        .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
        .singleWhere((field) => field.label == 'Desdobrar por resposta')
        .onChanged!(true);
    await tester.pumpAndSettle();
    final selector = find.byKey(const ValueKey('forms-branch-boolean-parent'));
    tester.widget<CoeloAdminSingleSelectField<bool>>(selector).onChanged(false);
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Adicionar pergunta ao ramo'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(1));
    expect(
      api.commands.single.payload.sections.first.items.last.conditions.single.expectedYesNo,
      isFalse,
    );
    tester.widget<CoeloAdminSingleSelectField<bool>>(selector).onChanged(true);
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, hasLength(1));
    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Adicionar pergunta ao ramo'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(2));
    expect(
      api.commands.last.payload.sections.first.items
          .skip(1)
          .map((item) => item.conditions.single.expectedYesNo),
      [false, true],
    );
    expect(api.commands.last.expectedVersion, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choice branch autosave persists trigger without saving selector-only changes', (
    tester,
  ) async {
    final api = _Api(manage: true)
      ..customItems = [
        FormItem(
          id: 'parent',
          kind: FormItemKind.multipleChoice,
          label: 'Choice',
          position: 0,
          options: const [
            FormOption(id: 'a', label: 'A', position: 0),
            FormOption(id: 'b', label: 'B', position: 1),
          ],
        ),
      ];
    await open(tester, api);
    tester
        .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
        .singleWhere((field) => field.label == 'Desdobrar por resposta')
        .onChanged!(true);
    await tester.pumpAndSettle();
    final selector = find.byKey(const ValueKey('forms-branch-option-parent'));
    tester.widget<CoeloAdminSingleSelectField<String?>>(selector).onChanged('b');
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Adicionar pergunta ao ramo'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(1));
    final child = api.commands.single.payload.sections.first.items.last;
    expect(child.conditions.single.optionIds, {'b'});
    tester.widget<CoeloAdminSingleSelectField<String?>>(selector).onChanged('a');
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, hasLength(1));
    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Adicionar pergunta ao ramo'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(2));
    final items = api.commands.last.payload.sections.first.items;
    expect(items, hasLength(3));
    expect(items[1].id, child.id);
    expect(items[1].conditions.single.optionIds, {'b'});
    expect(items[2].conditions.single.optionIds, {'a'});
    expect(api.commands.last.expectedVersion, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authoring autosave debounces edits but never saves hydration', (tester) async {
    final api = _Api(manage: true);
    await open(tester, api);
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
    await tester.enterText(title('Authorized title'), 'First edit');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(title('First edit'), 'Latest edit');
    await tester.pump(const Duration(milliseconds: 799));
    expect(api.commands, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(api.commands, hasLength(1));
    expect(api.commands.single.payload.title, 'Latest edit');
    expect(api.commands.single.expectedVersion, 1);
    expect(find.text('Rascunho salvo.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(api.commands, hasLength(1));
  });

  testWidgets('authoring autosave serializes edits made while a save is in flight', (tester) async {
    final api = _Api(manage: true)..saveWait = Completer<void>();
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'First edit');
    await tester.pump(const Duration(milliseconds: 800));
    expect(api.commands, hasLength(1));
    await tester.enterText(title('First edit'), 'Later edit');
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, hasLength(1));
    api.saveWait!.complete();
    await tester.pump();
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(2));
    expect(api.commands.last.payload.title, 'Later edit');
    expect(api.commands.last.expectedVersion, 2);
    expect(api.commands.last.requestId, isNot(api.commands.first.requestId));
    expect(find.text('Rascunho salvo.'), findsOneWidget);
  });

  testWidgets('authoring autosave observes structure and question edits', (tester) async {
    final api = _Api(manage: true);
    await open(tester, api);
    await tester.tap(find.byTooltip('Duplicar seção'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(1));
    expect(api.commands.single.payload.sections, hasLength(2));
    final question = find
        .byWidgetPredicate(
          (widget) => widget is TextFormField && widget.controller?.text == 'Question A — cópia',
        )
        .first;
    await tester.ensureVisible(question);
    await tester.enterText(question, 'Changed question');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(2));
    expect(api.commands.last.payload.sections.last.items.first.label, 'Changed question');
  });

  testWidgets('authoring autosave pauses during discard and does not save discarded edits', (
    tester,
  ) async {
    final api = _Api(manage: true);
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Discard me');
    final cancel = find.widgetWithText(TextButton, 'Cancelar');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
    expect(find.text('Authorized title'), findsOneWidget);
  });

  for (final failure in [FormApiFailureKind.unavailable, FormApiFailureKind.conflict]) {
    testWidgets('authoring autosave pauses after $failure until explicit save', (tester) async {
      final api = _Api(manage: true)..saveFailure = failure;
      await open(tester, api);
      await tester.enterText(title('Authorized title'), 'Unconfirmed edit');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(api.commands, hasLength(1));
      await tester.enterText(title('Unconfirmed edit'), 'Later edit');
      await tester.pump(const Duration(seconds: 5));
      expect(api.commands, hasLength(1));
      expect(find.text('Rascunho salvo.'), findsNothing);
      api.saveFailure = null;
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(api.commands, hasLength(2));
      expect(
        identical(api.commands.first, api.commands.last),
        failure == FormApiFailureKind.unavailable,
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(api.commands.last.payload.title, 'Later edit');
    });
  }

  for (final replacement in ['dispose', 'api', 'form']) {
    testWidgets('authoring autosave cancels on $replacement before debounce', (tester) async {
      final api = _Api(manage: true);
      await open(tester, api);
      await tester.enterText(title('Authorized title'), 'Obsolete edit');
      if (replacement == 'dispose') {
        await tester.pumpWidget(const SizedBox());
      } else {
        await open(
          tester,
          replacement == 'api' ? _Api(manage: true) : api,
          id: replacement == 'form' ? 'new-form' : 'form-a',
        );
      }
      await tester.pump(const Duration(seconds: 2));
      expect(api.commands, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('manual save consumes pending autosave timer once', (tester) async {
    final api = _Api(manage: true);
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Manual edit');
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, hasLength(1));
  });

  testWidgets('authoring autosave ignores selection-only controller changes', (tester) async {
    final api = _Api(manage: true);
    await open(tester, api);
    tester.widget<TextFormField>(title('Authorized title')).controller!.selection =
        const TextSelection.collapsed(offset: 2);
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
  });

  testWidgets('authoring autosave resumes when discard is declined', (tester) async {
    final api = _Api(manage: true);
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Keep edit');
    final cancel = find.widgetWithText(TextButton, 'Cancelar');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands.single.payload.title, 'Keep edit');
  });

  testWidgets('authoring autosave does not retry revoked capability', (tester) async {
    final api = _Api(manage: true)..saveFailure = FormApiFailureKind.unauthorized;
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Denied edit');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(api.commands, hasLength(1));
    expect(find.text('Denied edit'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Salvar rascunho'))
          .onPressed,
      isNull,
    );
    await open(tester, _Api(manage: false));
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, hasLength(1));
  });

  testWidgets('authoring autosave allows an incomplete quick poll draft', (tester) async {
    final api = _Api(manage: true)..quickPoll = true;
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Draft with two questions');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(1));
    expect(api.commands.single.payload.kind, FormKind.quickPoll);
    expect(api.commands.single.payload.sections.single.items, hasLength(2));
  });

  testWidgets('authoring autosave resumes dirty creation after slow catalog search', (
    tester,
  ) async {
    final api = _Api(manage: true)..allowCatalog = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: FormsEditorPage.authoring(authoringApi: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Institution 1'));
    await tester.pumpAndSettle();
    final name = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Nome do formulário',
    );
    await tester.enterText(name, 'New draft');
    api.catalogWait = Completer<void>();
    await tester.tap(find.text('Buscar instituições'));
    await tester.pump(const Duration(seconds: 2));
    expect(api.commands, isEmpty);
    api.catalogWait!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(1));
    expect(api.commands.single.payload.title, 'New draft');
  });

  testWidgets('autosave retry replays a committed receipt after confirmation is lost', (
    tester,
  ) async {
    final api = _Api(manage: true)..loseCommittedReceipt = true;
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Committed edit');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.remoteVersion, 2);
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.enterText(title('Committed edit'), 'Next edit');
    await tester.pump(const Duration(seconds: 3));
    expect(api.commands, hasLength(1));
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(identical(api.commands.first, api.commands.last), isTrue);
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(3));
    expect(api.commands.last.expectedVersion, 2);
    expect(api.remoteVersion, 3);
    expect(find.text('Rascunho salvo.'), findsOneWidget);
  });

  testWidgets('autosave denial while delete dialog is open cannot remove local question', (
    tester,
  ) async {
    final api = _Api(manage: true)..saveFailure = FormApiFailureKind.unauthorized;
    await open(tester, api);
    await tester.enterText(title('Authorized title'), 'Pending title');
    final delete = find.byTooltip('Excluir pergunta').first;
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(api.commands, hasLength(1));
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir pergunta'));
    await tester.pumpAndSettle();
    api.saveFailure = null;
    await tester.tap(find.text('Revalidar acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Question A'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final replacement in ['api', 'page']) {
    testWidgets('retained institution callback cannot select after $replacement replacement', (
      tester,
    ) async {
      final first = _Api(manage: true)..allowCatalog = true;
      Widget app(_Api api) => MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: FormsEditorPage.authoring(authoringApi: api)),
      );
      await tester.pumpWidget(app(first));
      await tester.pumpAndSettle();
      final obsoleteSelect = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Institution 1'))
          .onPressed!;
      if (replacement == 'api') {
        await tester.pumpWidget(app(_Api(manage: true)..allowCatalog = true));
      } else {
        await tester.tap(find.text('Próximas instituições'));
      }
      await tester.pumpAndSettle();
      obsoleteSelect();
      await tester.pumpAndSettle();
      final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      expect(tester.widget<OutlinedButton>(save).onPressed, isNull);
      final currentName = replacement == 'api' ? 'Institution 1' : 'Institution 21';
      await tester.tap(find.widgetWithText(TextButton, currentName));
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(save).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  for (final create in [true, false]) {
    testWidgets('nominal authoring create=$create fits 375px and 200 percent text', (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api(manage: false)..allowCatalog = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: FormsEditorPage.authoring(authoringApi: api, formId: create ? null : 'form-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final footer = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('creation search denial invalidates previously selected institution', (tester) async {
    final api = _Api(manage: true)..allowCatalog = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: FormsEditorPage.authoring(authoringApi: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Institution 1'));
    await tester.pumpAndSettle();
    api.catalogFailure = FormApiFailureKind.unauthorized;
    await tester.tap(find.text('Buscar instituições'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Salvar rascunho'))
          .onPressed,
      isNull,
    );
    expect(find.text('Institution 1'), findsNothing);
  });

  for (final search in ['', 'specific']) {
    testWidgets('unique candidate auto-selection respects empty search: $search', (tester) async {
      final api = _Api(manage: true)
        ..allowCatalog = true
        ..singleCandidate = search.isEmpty;
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(body: FormsEditorPage.authoring(authoringApi: api)),
        ),
      );
      await tester.pumpAndSettle();
      if (search.isNotEmpty) {
        api.singleCandidate = true;
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) => widget is TextField && widget.decoration?.labelText == 'Buscar instituição',
          ),
          search,
        );
        await tester.tap(find.text('Buscar instituições'));
        await tester.pumpAndSettle();
      }
      final save = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Salvar rascunho'),
      );
      expect(save.onPressed != null, search.isEmpty);
    });
  }

  testWidgets('nominal save denial disables stale edit permission', (tester) async {
    final api = _Api(manage: true)..saveFailure = FormApiFailureKind.unauthorized;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsEditorPage.authoring(authoringApi: api, formId: 'form-a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextFormField && widget.controller?.text == 'Authorized title',
      ),
      'Local title before denial',
    );
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(save).onPressed, isNull);
    expect(find.text('Authorized title'), findsNothing);
    expect(find.text('Section A'), findsNothing);
    expect(find.byKey(const Key('forms-editor-unavailable')), findsOneWidget);
    api.saveFailure = null;
    await tester.tap(find.text('Revalidar acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Local title before denial'), findsOneWidget);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(identical(api.commands.first, api.commands.last), isTrue);
  });

  testWidgets('late nominal read cannot replace a different API context', (tester) async {
    final old = _Api(manage: true)..readWait = Completer<void>();
    final current = _Api(manage: false);
    Widget app(_Api api, String id) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: FormsEditorPage.authoring(authoringApi: api, formId: id),
      ),
    );
    await tester.pumpWidget(app(old, 'old-form'));
    await tester.pump();
    await tester.pumpWidget(app(current, 'current-form'));
    await tester.pumpAndSettle();
    old.readWait!.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Salvar rascunho'))
          .onPressed,
      isNull,
    );
    expect(current.reads, ['current-form']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late save receipt cannot attach to a new nominal context', (tester) async {
    final old = _Api(manage: true)..saveWait = Completer<void>();
    final current = _Api(manage: true);
    Widget app(_Api api, String id) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: FormsEditorPage.authoring(authoringApi: api, formId: id),
      ),
    );
    await tester.pumpWidget(app(old, 'old-form'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pumpWidget(app(current, 'current-form'));
    await tester.pumpAndSettle();
    old.saveWait!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Rascunho salvo.'), findsNothing);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(current.commands.single.payload.id, 'current-form');
    expect(current.commands.single.expectedVersion, 1);
    expect(current.commands.single.requestId, isNot(old.commands.single.requestId));
  });

  testWidgets('new nominal editor pages past 20 and creates with a stable UUID', (tester) async {
    final api = _Api(manage: true)..allowCatalog = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: FormsEditorPage.authoring(authoringApi: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.catalogReads, 1);
    expect(api.reads, isEmpty);
    final next = find.text('Próximas instituições');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(api.catalogReads, 2);
    final select = find.text('Institution 21');
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();
    final title = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Nome do formulário',
    );
    await tester.enterText(title, 'New draft');
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.commands.single.payload.institutionId, 'institution-21');
    expect(api.commands.single.payload.id, matches(RegExp(r'^[a-f0-9-]{36}$')));
    expect(api.commands.single.expectedVersion, 0);
    final createdId = api.commands.single.payload.id;
    api.saveFailure = FormApiFailureKind.unauthorized;
    await tester.tap(save);
    await tester.pumpAndSettle();
    api.saveFailure = null;
    await tester.tap(find.text('Revalidar acesso'));
    await tester.pumpAndSettle();
    expect(api.reads, [createdId]);
    expect(api.catalogReads, 2);
  });

  testWidgets('nominal save retries the same command and preserves later local edits', (
    tester,
  ) async {
    final api = _Api(manage: true)..failSave = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsEditorPage.authoring(authoringApi: api, formId: 'form-a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.commands.length, 1);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações locais?'), findsNothing);
    expect(
      find.text('Confirme o salvamento anterior antes de descartar alterações locais.'),
      findsOneWidget,
    );
    final title = find.byWidgetPredicate(
      (widget) => widget is TextFormField && widget.controller?.text == 'Authorized title',
    );
    await tester.enterText(title, 'Later local title');
    api.failSave = false;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(identical(api.commands[0], api.commands[1]), isTrue);
    expect(find.text('Later local title'), findsOneWidget);
    expect(
      find.text('Salvamento anterior confirmado. Há alterações locais ainda não salvas.'),
      findsOneWidget,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.commands.last.requestId, isNot(api.commands.first.requestId));
    expect(api.commands.last.expectedVersion, 2);
    expect(api.commands.last.payload.title, 'Later local title');
  });

  for (final manage in [false, true]) {
    testWidgets('nominal existing editor manage=$manage opens without catalog', (tester) async {
      final api = _Api(manage: manage);
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: FormsEditorPage.authoring(authoringApi: api, formId: 'form-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.reads, ['form-a']);
      expect(api.catalogReads, 0);
      expect(find.byKey(const Key('forms-editor-unavailable')), findsNothing);
      expect(find.text('Authorized title'), findsWidgets);
      if (!manage) {
        await tester.ensureVisible(find.byKey(const ValueKey('forms-question-card-item-b')));
        await tester.pumpAndSettle();
        expect(find.text('Second question help'), findsOneWidget);
      }
      final save = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Salvar rascunho'),
      );
      expect(save.onPressed != null, manage);
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('forms-editor-publish'))).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

final class _Api implements FormsAuthoringApi {
  _Api({required this.manage});
  final bool manage;
  List<FormItem>? customItems;
  final reads = <String>[];
  var catalogReads = 0;
  var failSave = false;
  var quickPoll = false;
  var loseCommittedReceipt = false;
  var remoteVersion = 1;
  final receipts = <String, FormDefinition>{};
  FormApiFailureKind? saveFailure;
  var allowCatalog = false;
  var singleCandidate = false;
  FormApiFailureKind? catalogFailure;
  Completer<void>? readWait;
  Completer<void>? catalogWait;
  Completer<void>? saveWait;
  final commands = <FormCommand<FormDefinition>>[];
  @override
  Future<FormsAuthoringEditor> getEditor(String formId) async {
    reads.add(formId);
    await readWait?.future;
    return FormsAuthoringEditor(
      definition: FormDefinition(
        id: formId,
        institutionId: 'institution-a',
        kind: quickPoll ? FormKind.quickPoll : FormKind.form,
        identityMode: FormIdentityMode.identified,
        responseUnit: FormResponseUnit.person,
        title: 'Authorized title',
        status: FormStatus.draft,
        managementVersion: 1,
        sections: [
          FormSection(
            id: 'section-a',
            title: 'Section A',
            position: 0,
            items:
                customItems ??
                [
                  FormItem(
                    id: 'item-a',
                    kind: FormItemKind.shortText,
                    label: 'Question A',
                    position: 0,
                  ),
                  FormItem(
                    id: 'item-b',
                    kind: FormItemKind.shortText,
                    label: 'Question B',
                    helpText: 'Second question help',
                    position: 1,
                  ),
                ],
          ),
        ],
      ),
      institution: const FormsAuthoringInstitution(
        id: 'institution-a',
        publicName: 'Institution A',
      ),
      canManage: manage,
    );
  }

  @override
  Future<FormsAuthoringInstitutionPage> listInstitutions(
    FormsAuthoringInstitutionQuery query,
  ) async {
    catalogReads++;
    await catalogWait?.future;
    if (catalogFailure != null) throw FormApiException(catalogFailure!, 'Acesso negado');
    if (singleCandidate) {
      return FormsAuthoringInstitutionPage(
        items: const [FormsAuthoringInstitution(id: 'institution-1', publicName: 'Institution 1')],
      );
    }
    if (allowCatalog) {
      return FormsAuthoringInstitutionPage(
        items: [
          for (var i = query.cursor == null ? 1 : 21; i <= (query.cursor == null ? 20 : 21); i++)
            FormsAuthoringInstitution(id: 'institution-$i', publicName: 'Institution $i'),
        ],
        nextCursor: query.cursor == null
            ? const FormsAuthoringInstitutionCursor(nameKey: 'institution 20', id: 'institution-20')
            : null,
      );
    }
    throw StateError('An existing editor must not load the creation catalog.');
  }

  @override
  Future<FormDefinition> saveDraft(FormCommand<FormDefinition> command) async {
    commands.add(command);
    await saveWait?.future;
    if (receipts[command.requestId] case final receipt?) return receipt;
    if (loseCommittedReceipt && command.expectedVersion != remoteVersion) {
      throw const FormApiException(FormApiFailureKind.conflict, 'Conflito de versão');
    }
    if (saveFailure != null) throw FormApiException(saveFailure!, 'Acesso negado');
    if (failSave) throw const FormApiException(FormApiFailureKind.unavailable, 'Resposta incerta');
    final saved = FormDefinitionDto.fromJson({
      ...FormDefinitionDto.fromDomain(command.payload).toJson(),
      'management_version': command.expectedVersion + 1,
    }).toDomain();
    if (loseCommittedReceipt) {
      remoteVersion = saved.managementVersion;
      receipts[command.requestId] = saved;
      if (receipts.length == 1) {
        throw const FormApiException(FormApiFailureKind.unavailable, 'Confirmação perdida');
      }
    }
    return saved;
  }
}
