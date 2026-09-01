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
