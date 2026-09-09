import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/forms_test_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('development preview preserves the selected form context', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FormsTestPage.development(formId: 'form-dev-02')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enquete rápida sobre transporte'), findsOneWidget);
  });
  Widget app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
    theme: CoeloTheme.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: child,
    ),
  );

  testWidgets('production fails closed without an authorized occurrence', (tester) async {
    await tester.pumpWidget(app(const FormsTestPage()));

    expect(find.byKey(const Key('form-response-unavailable')), findsOneWidget);
    expect(find.textContaining('ocorrência autorizada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production test surface delegates to the authorized response flow', (tester) async {
    final api = _TestOccurrenceApi();
    await tester.pumpWidget(app(FormsTestPage(api: api, occurrenceId: 'occurrence-1')));
    await tester.pumpAndSettle();

    expect(api.requestedOccurrenceId, 'occurrence-1');
    expect(find.text('Compartilhe um cuidado importante'), findsOneWidget);
    expect(find.text('Fixture local'), findsNothing);
  });

  testWidgets('development validates, navigates, preserves answer and finishes only locally', (
    tester,
  ) async {
    await tester.pumpWidget(app(const FormsTestPage.development()));

    expect(find.text('Teste do formulário'), findsOneWidget);
    expect(find.text('Pesquisa das famílias'), findsOneWidget);
    expect(find.text('Resposta identificada'), findsOneWidget);
    expect(find.text('Fixture local · nenhuma resposta será persistida'), findsOneWidget);
    expect(find.text('Etapa 1 de 2'), findsOneWidget);

    await tester.drag(find.byKey(const Key('forms-test-scroll')), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-test-next')));
    await tester.pump();
    expect(find.text('Selecione uma opção para continuar.'), findsOneWidget);
    expect(find.text('Etapa 1 de 2'), findsOneWidget);

    await tester.tap(find.text('Muito boa'));
    await tester.enterText(
      find.byKey(const Key('forms-test-comment')),
      'A comunicação está clara.',
    );
    await tester.tap(find.byKey(const Key('forms-test-next')));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 2 de 2'), findsOneWidget);
    expect(find.text('Revise sua resposta'), findsOneWidget);
    expect(find.text('Muito boa'), findsWidgets);
    expect(find.text('A comunicação está clara.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('forms-test-back')));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 1 de 2'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('forms-test-comment'))).controller!.text,
      'A comunicação está clara.',
    );

    await tester.tap(find.byKey(const Key('forms-test-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-test-finish')));
    await tester.pumpAndSettle();
    expect(find.text('Teste concluído nesta demonstração'), findsOneWidget);
    expect(find.textContaining('Nenhuma persistência remota'), findsOneWidget);
    await tester.tap(find.text('Recomeçar teste'));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 1 de 2'), findsOneWidget);
    expect(find.text('Teste concluído nesta demonstração'), findsNothing);
  });

  testWidgets('development alterna preview e modo anônimo sem capturar identidade', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(app(const FormsTestPage.development(anonymous: true)));

    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.textContaining('não registra identidade'), findsOneWidget);
    expect(find.textContaining('Respondendo como'), findsNothing);
    expect(find.byKey(const Key('forms-test-preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('forms-test-preview-mobile')));
    await tester.pumpAndSettle();
    final mobile = tester.getSize(find.byKey(const Key('forms-test-preview')));
    expect(mobile.width, lessThanOrEqualTo(375));

    await tester.tap(find.text('Identificada'));
    await tester.pumpAndSettle();
    expect(find.text('Resposta identificada'), findsOneWidget);
    expect(find.textContaining('Respondendo como'), findsOneWidget);
  });

  testWidgets('development remains overflow-free at responsive widths and 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1200);
      await tester.pumpWidget(
        app(const FormsTestPage.development(), textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $width px');
    }
  });

  // Residual C02/R01, forms.test: faltava preview produtivo sem resposta real.
  // O caminho com occurrenceId ja delega ao fluxo de resposta autorizado; o que
  // nao existia era prever o formulario autorado sem criar ocorrencia nem rascunho.
  testWidgets('production previews the authored form without opening a response', (tester) async {
    final api = _TestDefinitionApi();
    await tester.pumpWidget(app(FormsTestPage(api: api, formId: 'form-7')));
    await tester.pumpAndSettle();

    expect(api.requestedFormIds, ['form-7']);
    expect(find.text('Autorização de saída'), findsOneWidget);
    expect(find.text('Quem retira a criança *'), findsOneWidget);
    expect(find.text('Meio de transporte'), findsOneWidget);
    expect(find.text('A pé'), findsOneWidget);
    // Nenhum comando de escrita: sem abrir rascunho, salvar ou enviar.
    expect(api.commands, isEmpty);
    expect(find.byKey(const Key('forms-test-no-persistence')), findsOneWidget);
  });

  testWidgets('the preview never offers a control that could answer', (tester) async {
    await tester.pumpWidget(app(FormsTestPage(api: _TestDefinitionApi(), formId: 'form-7')));
    await tester.pumpAndSettle();

    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      // Os unicos chips habilitados são os de largura do preview.
      if (chip.label case Text(:final data) when data == 'A pé' || data == 'Carro') {
        expect(chip.onSelected, isNull, reason: 'option $data must not be answerable');
      }
    }
    expect(find.byKey(const Key('forms-test-next')), findsNothing);
    expect(find.byKey(const Key('forms-test-finish')), findsNothing);
  });

  testWidgets('a refused preview fails closed instead of showing a neutral form', (tester) async {
    final api = _TestDefinitionApi(failure: FormApiFailureKind.unauthorized);
    await tester.pumpWidget(app(FormsTestPage(api: api, formId: 'form-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forms-test-unavailable')), findsOneWidget);
    expect(find.text('Autorização de saída'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a preview that returns after dispose changes nothing', (tester) async {
    final gate = Completer<void>();
    final api = _TestDefinitionApi(gate: gate.future);
    await tester.pumpWidget(app(FormsTestPage(api: api, formId: 'form-7')));
    await tester.pump();
    await tester.pumpWidget(app(const SizedBox()));
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an authorized occurrence still wins over the definition preview', (tester) async {
    final occurrence = _TestOccurrenceApi();
    await tester.pumpWidget(
      app(FormsTestPage(api: occurrence, occurrenceId: 'occurrence-1', formId: 'form-7')),
    );
    await tester.pumpAndSettle();

    expect(occurrence.requestedOccurrenceId, 'occurrence-1');
    expect(find.text('Compartilhe um cuidado importante'), findsOneWidget);
  });

  testWidgets('without api or form the production surface stays fail-closed', (tester) async {
    await tester.pumpWidget(app(FormsTestPage(api: _TestDefinitionApi())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-response-unavailable')), findsOneWidget);
  });
}

final class _TestDefinitionApi implements FormsApi {
  _TestDefinitionApi({this.failure, this.gate});

  final FormApiFailureKind? failure;
  final Future<void>? gate;
  final requestedFormIds = <String>[];
  final commands = <Object>[];

  @override
  Future<FormEditorProjection> getEditor(String formId) async {
    requestedFormIds.add(formId);
    if (gate case final gate?) await gate;
    if (failure case final failure?) {
      throw FormApiException(failure, 'refused');
    }
    return FormEditorProjection(
      definition: FormDefinition(
        id: formId,
        institutionId: 'institution-1',
        kind: FormKind.form,
        identityMode: FormIdentityMode.identified,
        responseUnit: FormResponseUnit.person,
        title: 'Autorização de saída',
        status: FormStatus.draft,
        managementVersion: 1,
        sections: [
          FormSection(
            id: 'section-1',
            title: 'Responsável',
            position: 0,
            items: [
              FormItem(
                id: 'item-1',
                kind: FormItemKind.shortText,
                label: 'Quem retira a criança',
                position: 0,
                isRequired: true,
              ),
              FormItem(
                id: 'item-2',
                kind: FormItemKind.singleChoice,
                label: 'Meio de transporte',
                position: 1,
                options: const [
                  FormOption(id: 'option-1', label: 'A pé', position: 0),
                  FormOption(id: 'option-2', label: 'Carro', position: 1),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    commands.add(invocation.memberName);
    return super.noSuchMethod(invocation);
  }
}

final class _TestOccurrenceApi implements FormsApi {
  String? requestedOccurrenceId;

  @override
  Future<FormOccurrenceForResponse> getOccurrenceForResponse(String occurrenceId) async {
    requestedOccurrenceId = occurrenceId;
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
            title: 'Terapia ocupacional',
            position: 0,
            items: [
              FormItem(
                id: 'item-1',
                kind: FormItemKind.shortText,
                label: 'Compartilhe um cuidado importante',
                position: 0,
              ),
            ],
          ),
        ],
      ),
      participationId: 'participation-1',
      identityMode: FormIdentityMode.identified,
      canEdit: true,
      draft: FormResponseDraft(
        id: 'response-1',
        occurrenceId: occurrenceId,
        status: FormResponseDraftStatus.draft,
        answers: const {},
        managementVersion: 1,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
