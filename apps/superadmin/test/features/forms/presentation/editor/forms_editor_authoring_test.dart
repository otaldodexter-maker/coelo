import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/forms_authoring_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  final reads = <String>[];
  var catalogReads = 0;
  var failSave = false;
  FormApiFailureKind? saveFailure;
  var allowCatalog = false;
  var singleCandidate = false;
  FormApiFailureKind? catalogFailure;
  Completer<void>? readWait;
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
        kind: FormKind.form,
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
            items: [
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
    if (saveFailure != null) throw FormApiException(saveFailure!, 'Acesso negado');
    if (failSave) throw const FormApiException(FormApiFailureKind.unavailable, 'Resposta incerta');
    return FormDefinitionDto.fromJson({
      ...FormDefinitionDto.fromDomain(command.payload).toJson(),
      'management_version': command.expectedVersion + 1,
    }).toDomain();
  }
}
