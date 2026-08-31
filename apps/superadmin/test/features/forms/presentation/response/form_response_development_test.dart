import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resposta identificada permite retomar revisar e enviar localmente', (tester) async {
    await _pump(tester, const FormResponsePage.development());

    expect(find.text('Pesquisa das famílias'), findsOneWidget);
    expect(find.text('Resposta identificada'), findsOneWidget);
    expect(find.text('Rascunho retomado'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Comunicação clara');
    await tester.tap(find.text('Revisar resposta'));
    await tester.pumpAndSettle();
    expect(find.text('Revisão da resposta'), findsOneWidget);
    expect(find.text('Comunicação clara'), findsOneWidget);
    await tester.tap(find.text('Enviar resposta'));
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada nesta demonstração'), findsOneWidget);
  });

  testWidgets('falha visual preserva os dados locais', (tester) async {
    await _pump(tester, const FormResponsePage.development(failSubmission: true));

    await tester.enterText(find.byType(TextFormField).first, 'Não perder este conteúdo');
    await tester.tap(find.text('Revisar resposta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar resposta'));
    await tester.pumpAndSettle();

    expect(find.textContaining('não foi enviada'), findsOneWidget);
    await tester.tap(find.text('Voltar e editar'));
    await tester.pumpAndSettle();
    expect(find.text('Não perder este conteúdo'), findsOneWidget);
  });

  testWidgets('anônima alerta que segredo perdido é irrecuperável', (tester) async {
    await _pump(tester, const FormResponsePage.development(anonymous: true, secretLost: true));

    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.textContaining('segredo anônimo foi perdido'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('upload representa progresso cancelamento falha e indisponibilidade', (tester) async {
    await _pump(tester, const FormResponsePage.development());

    expect(find.byKey(const Key('form-response-upload-progress')), findsOneWidget);
    expect(find.text('Cancelar upload'), findsOneWidget);
    expect(find.text('Falha no envio de imagem'), findsOneWidget);
    expect(find.text('Mídia protegida indisponível'), findsOneWidget);
    expect(find.textContaining('storage_path'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
  });

  testWidgets('estado de autosave percorre marcadores visuais aprovados', (tester) async {
    await _pump(tester, const FormResponsePage.development());

    for (final label in const ['Alterado', 'Salvando', 'Salvo', 'Conflito', 'Falha']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(768, 1100);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: child));
  await tester.pumpAndSettle();
}
