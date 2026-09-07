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
    kind: FormKind.form,
    identityMode: FormIdentityMode.identified,
    responseUnit: FormResponseUnit.person,
    managementVersion: version,
    sections: [
      FormSection(
        id: 'section-1',
        title: 'Section',
        position: 0,
        items: [
          FormItem(id: 'item-1', kind: FormItemKind.shortText, label: 'Question', position: 0),
        ],
      ),
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
