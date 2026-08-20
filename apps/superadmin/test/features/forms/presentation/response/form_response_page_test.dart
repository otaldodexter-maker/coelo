import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_superadmin/features/forms/data/form_anonymous_edit_secret_store.dart';
import 'package:coelo_superadmin/features/forms/data/form_asset_picker.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final config in <({String name, Size size, Brightness brightness})>[
    (name: '375_light', size: const Size(375, 800), brightness: Brightness.light),
    (name: '768_dark', size: const Size(768, 900), brightness: Brightness.dark),
    (name: '1024_light', size: const Size(1024, 900), brightness: Brightness.light),
    (name: '1440_dark', size: const Size(1440, 900), brightness: Brightness.dark),
  ]) {
    testWidgets('response golden ${config.name}', (tester) async {
      await tester.binding.setSurfaceSize(config.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: config.brightness),
          home: FormResponsePage(
            api: _ResponseApi(FormIdentityMode.identified),
            occurrenceId: 'occurrence-1',
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(FormResponsePage),
        matchesGoldenFile('goldens/form_response_${config.name}.png'),
      );
    });
  }

  testWidgets('opens an anonymous draft, preserves the exact copy and submits visible answers', (
    tester,
  ) async {
    final api = _ResponseApi(FormIdentityMode.anonymous);
    final secrets = _Secrets();
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(
          api: api,
          occurrenceId: 'occurrence-1',
          secretStore: secrets,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Suas respostas são anônimas e ninguém saberá que foi você que respondeu'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('answer-name')), '  Coelo  ');
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Coelo'), findsOneWidget);
    await tester.tap(find.text('Confirmar envio'));
    await tester.pumpAndSettle();

    expect(api.submitted?.answers['answer-name']?.value, isA<FormShortTextValue>());
    expect((api.submitted!.answers['answer-name']!.value as FormShortTextValue).value, 'Coelo');
    expect(api.saved, isTrue);
    expect(secrets.savedResponseId, 'response-1');
    expect(find.text('Resposta enviada'), findsOneWidget);
  });

  testWidgets('removes a hidden answer and reports a lost anonymous secret fail closed', (
    tester,
  ) async {
    final api = _ResponseApi(FormIdentityMode.anonymous, existingDraft: true);
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(
          api: api,
          occurrenceId: 'occurrence-1',
          secretStore: _Secrets(returnSavedSecret: false),
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Não é possível editar esta resposta anônima neste dispositivo.'),
      findsOneWidget,
    );
    expect(find.text('Confirmar envio'), findsNothing);
  });

  testWidgets('keeps 200 percent text responsive without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: FormResponsePage(
            api: _ResponseApi(FormIdentityMode.identified),
            occurrenceId: 'occurrence-1',
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('answers a date with the shared Coelo picker', (tester) async {
    final api = _ResponseApi(
      FormIdentityMode.identified,
      extraItems: [
        FormItem(
          id: 'answer-date',
          kind: FormItemKind.date,
          label: 'Data do encontro',
          position: 1,
          isRequired: true,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(
          api: api,
          occurrenceId: 'occurrence-1',
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data).toList(),
      contains('Data do encontro *'),
    );
    await tester.tap(find.text('Selecionar data'));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloDateRangePicker), findsOneWidget);
    await tester.tap(find.text('Hoje'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Selecionar data'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('answer-name')), 'Coelo');
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Revise suas respostas'), findsOneWidget);
  });

  testWidgets('captures and uploads a Photo with visible progress result', (tester) async {
    final api = _ResponseApi(
      FormIdentityMode.identified,
      extraItems: [
        FormItem(
          id: 'answer-photo',
          kind: FormItemKind.photo,
          label: 'Foto do trabalho',
          position: 1,
          isRequired: true,
        ),
      ],
    );
    var pickedKind = FormItemKind.information;
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(
          api: api,
          occurrenceId: 'occurrence-1',
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
          assetPicker: (kind, limit) async {
            pickedKind = kind;
            expect(limit, 1);
            return [
              FormPickedAsset(bytes: Uint8List.fromList([1, 2]), mimeType: 'image/jpeg'),
            ];
          },
          assetUploader: ({required itemId, required picked, onProgress}) async {
            onProgress?.call(0.5);
            onProgress?.call(1);
            return FormAsset(
              id: 'asset-1',
              itemId: itemId,
              mimeType: picked.mimeType,
              byteLength: picked.bytes.length,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(pickedKind, FormItemKind.photo);
    expect(find.text('Imagem 1'), findsOneWidget);
    expect(find.byTooltip('Remover imagem 1'), findsOneWidget);
  });

  testWidgets('edits an existing submitted response only after review confirmation', (
    tester,
  ) async {
    final api = _ResponseApi(
      FormIdentityMode.identified,
      existingDraft: true,
      submittedDraft: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FormResponsePage(
          api: api,
          occurrenceId: 'occurrence-1',
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('answer-name')), 'Resposta corrigida');
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(api.saved, isFalse);
    await tester.tap(find.text('Confirmar alteração'));
    await tester.pumpAndSettle();

    expect(api.edited, isTrue);
    expect(api.submitted, isNull);
    expect(find.text('Resposta atualizada'), findsOneWidget);
  });
}

final class _Secrets implements FormAnonymousEditSecretStore {
  _Secrets({this.returnSavedSecret = true});
  final bool returnSavedSecret;
  String? savedResponseId;
  String? value;

  @override
  String generate() => List.filled(43, 's').join();
  @override
  Future<void> save({required String responseId, required String secret}) async {
    savedResponseId = responseId;
    value = secret;
  }

  @override
  Future<String?> read(String responseId) async => returnSavedSecret ? value : null;
  @override
  Future<void> bindOccurrence({required String occurrenceId, required String responseId}) async {}
  @override
  Future<String?> responseIdForOccurrence(String occurrenceId) async => null;
  @override
  Future<void> remove(String responseId) async => value = null;
}

final class _ResponseApi implements FormsApi {
  _ResponseApi(
    this.identityMode, {
    this.existingDraft = false,
    this.submittedDraft = false,
    this.extraItems = const [],
  });
  final FormIdentityMode identityMode;
  final bool existingDraft;
  final bool submittedDraft;
  final List<FormItem> extraItems;
  FormResponseDraftPayload? submitted;
  bool saved = false;
  bool edited = false;

  FormResponseDraft get _draft => FormResponseDraft(
    id: 'response-1',
    occurrenceId: 'occurrence-1',
    status: submittedDraft ? FormResponseDraftStatus.submitted : FormResponseDraftStatus.draft,
    answers: const {},
    managementVersion: 1,
  );

  @override
  Future<FormOccurrenceForResponse> getOccurrenceForResponse(String occurrenceId) async =>
      FormOccurrenceForResponse(
        occurrence: FormOccurrence(
          id: occurrenceId,
          applicationId: 'application-1',
          formVersionId: 'version-1',
          opensAt: DateTime.now().subtract(const Duration(hours: 1)),
          closesAt: DateTime.now().add(const Duration(hours: 1)),
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
              title: 'Sobre você',
              position: 0,
              items: [
                FormItem(
                  id: 'answer-name',
                  kind: FormItemKind.shortText,
                  label: 'Como você se chama?',
                  position: 0,
                  isRequired: true,
                ),
                ...extraItems,
              ],
            ),
          ],
        ),
        participationId: 'participation-1',
        identityMode: identityMode,
        draft: existingDraft ? _draft : null,
        canEdit: true,
      );

  @override
  Future<FormResponseDraft> openResponseDraft(
    FormCommand<FormOpenResponseDraftPayload> command,
  ) async => _draft;

  @override
  Future<FormResponseDraft> saveResponseDraft(FormCommand<FormResponseDraftPayload> command) async {
    saved = true;
    return FormResponseDraft(
      id: _draft.id,
      occurrenceId: _draft.occurrenceId,
      status: FormResponseDraftStatus.draft,
      answers: command.payload.answers,
      managementVersion: 2,
    );
  }

  @override
  Future<FormResponseDraft> submitResponse(FormCommand<FormResponseDraftPayload> command) async {
    submitted = command.payload;
    return FormResponseDraft(
      id: _draft.id,
      occurrenceId: _draft.occurrenceId,
      status: FormResponseDraftStatus.submitted,
      answers: command.payload.answers,
      managementVersion: 2,
    );
  }

  @override
  Future<FormResponseDraft> editResponse(FormCommand<FormResponseDraftPayload> command) async {
    edited = true;
    return FormResponseDraft(
      id: _draft.id,
      occurrenceId: _draft.occurrenceId,
      status: FormResponseDraftStatus.submitted,
      answers: command.payload.answers,
      managementVersion: 2,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
