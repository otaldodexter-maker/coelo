import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('detail does not project a response from another form in the route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: FormsOperationsPage.responseDetail(
          api: _Api(_detail()),
          formId: 'other-form',
          responseId: 'response-1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Operação indisponível'), findsOneWidget);
    expect(find.text('Seção original'), findsNothing);
    expect(find.text('Primeira pergunta original'), findsNothing);
    expect(find.text('Pessoa indevida'), findsNothing);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'original detail preserves question order, labels and privacy at 200% $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: FormsOperationsPage.responseDetail(
              api: _Api(_detail()),
              responseId: 'response-1',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Conteúdo das perguntas indisponível'), findsNothing);
        expect(find.text('Primeira pergunta original'), findsOneWidget);
        expect(find.text('Opção original selecionada'), findsOneWidget);
        expect(find.text('Não'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Primeira pergunta original')).dy,
          lessThan(tester.getTopLeft(find.text('Segunda pergunta original')).dy),
        );
        expect(find.textContaining('Pessoa indevida'), findsNothing);
        expect(find.textContaining('2026'), findsNothing);
        expect(find.textContaining('option-original'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Pessoa indevida|2026|occurrence-private|version-original')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  // O detalhe de resposta e uma superficie PRODUTIVA (a rota passa api real),
  // e nao tinha nenhuma cobertura de dinheiro. Este e o mesmo valor que o
  // respondente digitou, entao precisa ser lido da mesma forma nas duas telas.
  testWidgets('money answers read in civil notation, including zero cents and negatives', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: FormsOperationsPage.responseDetail(api: _Api(_numericDetail()), responseId: 'response-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10,50'), findsOneWidget);
    expect(find.text('10,00'), findsOneWidget);
    expect(find.text('-3,05'), findsOneWidget);
    // Nunca a divisao crua, que era o defeito da tela de resposta.
    expect(find.text('10.5'), findsNothing);
    expect(find.text('10.0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('media answer opens only the protected normal route on explicit request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var mediaOpened = 0;
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, _) => FormsOperationsPage.responseDetail(
            api: _Api(_detail(media: true)),
            responseId: 'response-1',
          ),
        ),
        GoRoute(
          path: SuperadminRoutes.formMedia,
          name: SuperadminRoutes.formMediaName,
          builder: (_, state) {
            mediaOpened++;
            return Text('Protected ${state.pathParameters['assetId']}');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(mediaOpened, 0);
    expect(find.textContaining('https://'), findsNothing);
    await tester.tap(find.text('Ver mídia 1'));
    await tester.pumpAndSettle();
    expect(mediaOpened, 1);
    expect(find.text('Protected 90000000-0000-4000-8000-000000000001'), findsOneWidget);
  });
}

FormResponseDetail _detail({bool media = false}) => FormResponseDetail(
  summary: FormResponseSummary(
    id: 'response-1',
    occurrenceId: 'occurrence-private',
    formVersionId: 'version-original',
    identityMode: FormIdentityMode.anonymous,
    respondentLabel: 'Pessoa indevida',
    submittedAt: DateTime.utc(2026, 9, 8),
  ),
  originalVersion: FormVersion(
    id: 'version-original',
    formId: 'form-1',
    number: 2,
    isPublished: true,
    sections: [
      FormSection(
        id: 'section-1',
        title: 'Seção original',
        position: 0,
        items: media
            ? [
                FormItem(
                  id: 'media-1',
                  kind: FormItemKind.photo,
                  label: 'Foto original',
                  position: 0,
                ),
              ]
            : [
                FormItem(
                  id: 'question-2',
                  kind: FormItemKind.yesNo,
                  label: 'Segunda pergunta original',
                  position: 5,
                ),
                FormItem(
                  id: 'question-1',
                  kind: FormItemKind.singleChoice,
                  label: 'Primeira pergunta original',
                  position: 0,
                  options: const [
                    FormOption(
                      id: 'option-original',
                      label: 'Opção original selecionada',
                      position: 0,
                    ),
                  ],
                ),
              ],
      ),
    ],
  ),
  answers: media
      ? {
          'media-1': FormAnswer.photo(
            itemId: 'media-1',
            assetIds: ['90000000-0000-4000-8000-000000000001'],
          ),
        }
      : {
          'question-1': FormAnswer.singleChoice(itemId: 'question-1', optionId: 'option-original'),
          'question-2': FormAnswer.yesNo(itemId: 'question-2', value: false),
        },
);

FormResponseDetail _numericDetail() => FormResponseDetail(
  summary: FormResponseSummary(
    id: 'response-1',
    occurrenceId: 'occurrence-private',
    formVersionId: 'version-original',
    identityMode: FormIdentityMode.anonymous,
    submittedAt: DateTime.utc(2026, 9, 8),
  ),
  originalVersion: FormVersion(
    id: 'version-original',
    formId: 'form-1',
    number: 2,
    isPublished: true,
    sections: [
      FormSection(
        id: 'section-1',
        title: 'Seção original',
        position: 0,
        items: [
          FormItem(id: 'money-1', kind: FormItemKind.money, label: 'Valor pago', position: 0),
          FormItem(id: 'money-2', kind: FormItemKind.money, label: 'Valor devolvido', position: 1),
          FormItem(id: 'money-3', kind: FormItemKind.money, label: 'Ajuste', position: 2),
        ],
      ),
    ],
  ),
  answers: {
    'money-1': FormAnswer.money(itemId: 'money-1', minorUnits: 1050),
    'money-2': FormAnswer.money(itemId: 'money-2', minorUnits: 1000),
    'money-3': FormAnswer.money(itemId: 'money-3', minorUnits: -305),
  },
);

final class _Api implements FormsApi {
  _Api(this.detail);
  final FormResponseDetail detail;
  @override
  Future<FormResponseDetail> getResponseDetail(String responseId) async => detail;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
