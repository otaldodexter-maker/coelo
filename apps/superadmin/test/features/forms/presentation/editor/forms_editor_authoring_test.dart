import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/forms_authoring_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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
