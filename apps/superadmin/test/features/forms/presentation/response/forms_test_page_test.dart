import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/forms_test_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the editable definition without creating participation', (tester) async {
    final api = _TestApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormsTestPage(api: api, formId: 'form-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.requestedFormId, 'form-1');
    expect(find.text('Modo de teste'), findsOneWidget);
    expect(find.text('Pergunta de teste *'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('item-1')), 'Coelo');
    await tester.tap(find.text('Simular foto'));
    await tester.pumpAndSettle();
    expect(find.text('Imagem de teste 1'), findsOneWidget);
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir teste'));
    await tester.pumpAndSettle();
    expect(find.text('Teste concluído'), findsOneWidget);
    expect(
      find.text('Nenhuma resposta, participação, mídia ou métrica foi registrada.'),
      findsOneWidget,
    );
    expect(api.unexpectedCalls, 0);
  });

  testWidgets('fails closed when the Forms API is unavailable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormsTestPage(api: null, formId: 'form-1')));
    await tester.pumpAndSettle();

    expect(find.text('Teste indisponível'), findsOneWidget);
    expect(find.text('O serviço de Formulários não está disponível.'), findsOneWidget);
  });

  testWidgets('fails closed when the definition is not valid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FormsTestPage(api: _TestApi(invalid: true), formId: 'form-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teste indisponível'), findsOneWidget);
    expect(find.text('Revise a estrutura do formulário antes de testá-lo.'), findsOneWidget);
  });
}

final class _TestApi implements FormsApi {
  _TestApi({this.invalid = false});

  final bool invalid;
  String? requestedFormId;
  int unexpectedCalls = 0;

  @override
  Future<FormEditorProjection> getEditor(String formId) async {
    requestedFormId = formId;
    return FormEditorProjection(
      definition: FormDefinition(
        id: formId,
        institutionId: 'institution-1',
        kind: FormKind.form,
        identityMode: FormIdentityMode.identified,
        responseUnit: FormResponseUnit.person,
        title: invalid ? '' : 'Teste produtivo',
        sections: invalid
            ? const []
            : [
                FormSection(
                  id: 'section-1',
                  title: 'Seção',
                  position: 0,
                  items: [
                    FormItem(
                      id: 'item-1',
                      kind: FormItemKind.shortText,
                      label: 'Pergunta de teste',
                      position: 0,
                      isRequired: true,
                    ),
                    FormItem(
                      id: 'item-photo',
                      kind: FormItemKind.photo,
                      label: 'Foto de teste',
                      position: 1,
                      isRequired: true,
                    ),
                  ],
                ),
              ],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unexpectedCalls++;
    return super.noSuchMethod(invocation);
  }
}
