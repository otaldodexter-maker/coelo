import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/development_forms_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/overview/forms_overview_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/forms_test_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// As diretrizes nativas de toque, rotulo e contraste ja sao verificadas no
/// shell, em Auth, em Locais e no Perfil do Principal, mas nao em Formularios.
/// Este arquivo fecha essa lacuna nas superficies do recorte.
void main() {
  Future<void> check(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1440, 1000),
    bool tapSize = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: page),
      ),
    );
    await tester.pumpAndSettle();
    if (tapSize) await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }

  // R08 H25: alca de 48px com pintura preservada e toggle rotulado.
  // O teste completo antes ignorado foi medido novamente com as tres
  // diretrizes aprovadas. Evidencia: 13-directory-accessibility.md.
  testWidgets('H25 forms directory resize targets meet tap size at desktop and 375', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [1440.0, 375.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: FormsDirectoryPage(api: DevelopmentFormsApi.seeded(), canManage: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Redimensionar coluna Nome'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  testWidgets('the forms directory meets tap size, labelling and contrast', (tester) async {
    await check(tester, FormsDirectoryPage(api: DevelopmentFormsApi.seeded(), canManage: true));
  });

  testWidgets('the forms editor meets tap size, labelling and contrast', (tester) async {
    await check(tester, const FormsEditorPage.development());
  });

  testWidgets('the forms overview meets tap size, labelling and contrast', (tester) async {
    await check(tester, const FormsOverviewPage.development(formId: 'form-dev-01'));
  });

  testWidgets('the response surface meets tap size, labelling and contrast', (tester) async {
    await check(tester, const FormResponsePage.development());
  });

  // A tela de preview do Testar foi escrita nesta rodada e nao tinha passado
  // pelas diretrizes. Codigo novo tem que atender a mesma barra que eu cobrei
  // do codigo antigo.
  testWidgets('the authored preview meets tap size, labelling and contrast', (tester) async {
    await check(
      tester,
      FormsTestPage(api: _PreviewApi(), formId: 'form-1'),
      size: const Size(1440, 2400),
    );
  });

  testWidgets('the development test surface meets tap size, labelling and contrast', (
    tester,
  ) async {
    await check(tester, const FormsTestPage.development(), size: const Size(1440, 2400));
  });

  for (final (label, page) in <(String, Widget)>[
    ('monitor', FormsOperationsPage.monitor(development: true)),
    ('respostas', FormsOperationsPage.responses(development: true)),
    ('arquivos', FormsOperationsPage.files(development: true)),
  ]) {
    testWidgets('$label meets tap size, labelling and contrast', (tester) async {
      await check(tester, page, size: const Size(1440, 1400));
    });
  }
}

final class _PreviewApi implements FormsApi {
  @override
  Future<FormEditorProjection> getEditor(String formId) async => FormEditorProjection(
    definition: FormDefinition(
      id: formId,
      institutionId: 'institution-1',
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Autorização de saída',
      sections: [
        FormSection(
          id: 'section-1',
          title: 'Responsável',
          position: 0,
          items: [
            for (final (index, kind) in FormItemKind.values.indexed)
              FormItem(
                id: 'item-$index',
                kind: kind,
                label: 'Pergunta ${kind.name}',
                position: index,
                options: kind == FormItemKind.singleChoice || kind == FormItemKind.multipleChoice
                    ? const [FormOption(id: 'option-1', label: 'Única opção', position: 0)]
                    : const [],
              ),
          ],
        ),
      ],
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
