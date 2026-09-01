import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  int openCalls = 0;
  FormCommand<FormResponseDraftPayload>? saveCommand;
  FormCommand<FormResponseDraftPayload>? submitCommand;
  FormCommand<FormResponseDraftPayload>? editCommand;

  @override
  Future<FormOccurrenceForResponse> getOccurrenceForResponse(String occurrenceId) async =>
      FormOccurrenceForResponse(
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
              items: [
                FormItem(
                  id: 'item-1',
                  kind: FormItemKind.shortText,
                  label: 'Como foi o acolhimento?',
                  position: 0,
                  isRequired: true,
                ),
              ],
            ),
          ],
        ),
        participationId: 'participation-1',
        identityMode: FormIdentityMode.identified,
        canEdit: true,
      );

  @override
  Future<FormResponseDraft> openResponseDraft(
    FormCommand<FormOpenResponseDraftPayload> command,
  ) async {
    openCalls++;
    return _draft(1);
  }

  @override
  Future<FormResponseDraft> saveResponseDraft(FormCommand<FormResponseDraftPayload> command) async {
    saveCommand = command;
    return FormResponseDraft(
      id: 'response-1',
      occurrenceId: command.payload.occurrenceId,
      status: FormResponseDraftStatus.draft,
      answers: command.payload.answers,
      managementVersion: 2,
    );
  }

  @override
  Future<FormResponseDraft> submitResponse(FormCommand<FormResponseDraftPayload> command) async {
    submitCommand = command;
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

  FormResponseDraft _draft(int version) => FormResponseDraft(
    id: 'response-1',
    occurrenceId: 'occurrence-1',
    status: FormResponseDraftStatus.draft,
    answers: const {},
    managementVersion: version,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
